-- FUNCTION: public.sp_confirmorders(date, integer)

-- DROP FUNCTION public.sp_confirmorders(date, integer);

CREATE OR REPLACE FUNCTION public.sp_confirmorders(
	orderdate date,
	sale_order_id integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE --results text;
   	mycursorid            	INT;
    mysalesorderid          INT;
    mysalesordername       	varchar(32);
    var_column_exists   	VARCHAR(32);
    _today                 	date;
    _date                   date;
    _ordertotal             money;
    _unitprice              money;
    _zeroamount             money;
	_dayofweek   		varchar(20);
    _count					INT;

BEGIN

        _today = current_date;
        _today = (now() at time zone 'Africa/Nairobi')::date;
        
    	_ordertotal = 10000;
    	_unitprice = 6000;
    	_zeroamount = 0;
		_dayofweek = TRIM(to_char(_today, 'day')); 

		if _dayofweek = 'sunday' then
			return;
		end if;
	
        DROP TABLE IF EXISTS temp_saleorders;
        CREATE LOCAL TEMP TABLE temp_saleorders
        (
			myid                  	INT,
			create_uid              VARCHAR(5),
			create_date            	TIMESTAMP,
			write_date              TIMESTAMP,
			write_uid               VARCHAR(5),
			origin                  VARCHAR(20),
			salesordername          VARCHAR(30),
			customer_id             INT,
			partner_id       		INT,
			company_id              INT,
			date_delivery           date,
			date_order              date,
			client_order_ref        varchar(200),
			orderMode               varchar(15),
			pricelist_id            INT,
			user_id                 INT,
			highvalue               boolean,
			islayaway               boolean,
			amounttotal             money,
			totalprepayment         money
        )

        ON COMMIT DROP;

    IF sale_order_id = 0 THEN
        INSERT INTO temp_saleorders
            (myid , create_uid, create_date, write_date, write_uid, origin,
            salesordername, customer_id, partner_id, company_id,
            date_delivery, date_order, client_order_ref, orderMode,
            pricelist_id, user_id, highvalue, islayaway, amounttotal, totalprepayment)
        SELECT id , create_uid, create_date, write_date, write_uid, origin,
            name, customer_id, partner_id, company_id,
            date_delivery, date_order, client_order_ref, mode,
            pricelist_id, user_id, false, islayaway, amount_total, _zeroamount
        FROM sale_order
        WHERE
           	date_order <= orderDate AND
			---- Name in ('SO377052','','') AND
           	-- is_duplicate = 'f'
            coalesce( is_duplicate,false) = 'f'
            AND "state" = 'draft'
            AND confirmation_date is Null;
    ELSE
        INSERT INTO temp_saleorders
            (myid , create_uid, create_date, write_date, write_uid, origin,
            salesordername, customer_id, partner_id, company_id,
            date_delivery, date_order, client_order_ref, orderMode,
            pricelist_id, user_id, highvalue, islayaway, amounttotal, totalprepayment)
        SELECT id , create_uid, create_date, write_date, write_uid, origin,
            name, customer_id, partner_id, company_id,
            date_delivery, date_order, client_order_ref, mode,
            pricelist_id, user_id, false, islayaway, amount_total, _zeroamount
        FROM sale_order
        WHERE
            date_order <= orderDate AND
            sale_order.ID = sale_order_id
            AND coalesce( is_duplicate,false) = 'f'
            AND "state" = 'draft'
            AND confirmation_date is Null;
    END IF;

	-------Start of Order Fulfillment Center Changes
	-------=========================================
	var_column_exists = null;
	SELECT column_name INTO var_column_exists
	FROM information_schema.columns
	WHERE table_name='sale_order_line' and column_name='ofc_id';
	IF var_column_exists IS NULL THEN
		ALTER TABLE sale_order_line ADD COLUMN  ofc_id INT DEFAULT NULL;
	END IF;

	var_column_exists = null;
	SELECT column_name INTO var_column_exists
	FROM information_schema.columns
	WHERE table_name='sale_order_line' and column_name='default_ofc_id';
	IF var_column_exists IS NULL THEN
		ALTER TABLE sale_order_line ADD COLUMN  default_ofc_id INT DEFAULT NULL;
	END IF;

	var_column_exists = null;
	SELECT column_name INTO var_column_exists
	FROM information_schema.columns
	WHERE table_name='sale_order_line' and column_name='previousagentorders';
	IF var_column_exists IS NULL THEN
		ALTER TABLE sale_order_line ADD COLUMN  previousagentorders INT DEFAULT NULL;
	END IF;

	var_column_exists = null;
	SELECT column_name INTO var_column_exists
	FROM information_schema.columns
	WHERE table_name='sale_order_line' and column_name='previouscustorders';
	IF var_column_exists IS NULL THEN
		ALTER TABLE sale_order_line ADD COLUMN  previouscustorders INT DEFAULT NULL;
	END IF;

	var_column_exists = null;
	SELECT column_name INTO var_column_exists
	FROM information_schema.columns
	WHERE table_name='sale_order_line' and column_name='ofc_location_id';
	IF var_column_exists IS NULL THEN
		ALTER TABLE sale_order_line ADD COLUMN  ofc_location_id INT DEFAULT NULL;
	END IF;

	var_column_exists = null;
	SELECT column_name INTO var_column_exists
	FROM information_schema.columns
	WHERE table_name='sale_order_line' and column_name='is_bulk';
	IF var_column_exists IS NULL THEN
		ALTER TABLE sale_order_line ADD COLUMN  is_bulk boolean DEFAULT false;
	END IF;

	DROP TABLE IF EXISTS temp_saleorders_lines;
	CREATE TEMP TABLE temp_saleorders_lines
	(
		myid                    INT,
		order_id                INT,
		product_id              INT,
		partner_id       		INT,
		customer_id        		INT,
		shop_id                 INT,
		warehouse_id            INT,
		ofc_id                  INT,
		price_unit              money,
		previousagentorders     numeric(12,2),
		previouscustorders      numeric(12,2),
		ofc_locationid          INT,
		product_uom_qty         INT,
		weight                  numeric(12,4),
		weight_net              numeric(12,4),
		item_size               varchar(32),
		bulky_item              boolean,
		highvalue				boolean
	)
	ON COMMIT DROP;

	INSERT INTO temp_saleorders_lines
	(myID, product_id,order_id, price_unit, product_uom_qty, weight, item_size)
	SELECT sale_order_line.id, sale_order_line.product_id, sale_order_line.order_id,
			sale_order_line.price_unit, sale_order_line.product_uom_qty ,
			sale_order_line.product_uom_qty * product_product.weight,
			product_template.size
	FROM sale_order_line
	INNER JOIN product_product ON
			sale_order_line.product_id = product_product."id"
	INNER JOIN product_template ON
			product_product.product_tmpl_id = product_template."id"
	WHERE order_id in (Select myid from temp_saleorders);

	UPDATE sale_order SET state = 'cancel'
	WHERE sale_order.ID Not in (Select order_id from temp_saleorders_lines)
	And sale_order.id in (Select myid from temp_saleorders);

	DELETE FROM temp_saleorders Where myid NOT in (Select order_id from temp_saleorders_lines);
    
/*
Select count(myid) from temp_saleorders Into _count;    
RAISE NOTICE 'Count is (%) ',  _count;
*/

	Update temp_saleorders_lines SET
			partner_id = temp_saleorders.partner_id,
			customer_id = temp_saleorders.partner_id
	From temp_saleorders
	Where temp_saleorders.myid = temp_saleorders_lines.order_id;

	Update temp_saleorders_lines SET bulky_item = false;
	Update temp_saleorders_lines SET bulky_item = true Where item_size = 'big';
	Update temp_saleorders_lines SET bulky_item = true Where weight >= 10;
	Update temp_saleorders_lines SET bulky_item = false Where product_id in 
	(Select id from product_product Where product_tmpl_id in
	(Select id from product_template where categ_id in
	(Select id from product_category Where parent_id in (354,352)))); --Building and Construction and Animal Feeds
	
	Update temp_saleorders_lines set warehouse_id = get_agentwarehouse_id(partner_id);
	Update temp_saleorders_lines set ofc_id = get_itemfulfillmentcenter(warehouse_id, product_id);
	Update temp_saleorders_lines set previousagentorders = get_previousagentorders(partner_id);
	Update temp_saleorders_lines set previouscustorders = get_previouscustomerorders(customer_id);
	Update temp_saleorders_lines set ofc_locationid = get_itemlocationid(ofc_id, product_id);

	Update sale_order_line SET
		previousagentorders = temp_saleorders_lines.previousagentorders,
		previouscustorders = temp_saleorders_lines.previouscustorders,
		ofc_id = temp_saleorders_lines.ofc_id ,
		default_ofc_id = temp_saleorders_lines.warehouse_id ,
		ofc_location_id = temp_saleorders_lines.ofc_locationid ,
		is_bulk = temp_saleorders_lines.bulky_item
	from temp_saleorders_lines
	Where sale_order_line.id = temp_saleorders_lines.myid;

	update sale_order_line set ofc_location_id = get_itemlocationid(ofc_id, product_id)
	where ofc_id is not null and ofc_location_id is null;

    -------End of Order Fulfillment Center Changes
    -------=======================================

	------High Value Orders Code
	------======================	
	Update temp_saleorders_lines SET highvalue = true;
	Update temp_saleorders_lines SET highvalue = false Where product_id in 
	(Select id from product_product Where product_tmpl_id in
	(Select id from product_template where categ_id in
	(Select id from product_category Where parent_id in (365)))); --Retail / FoodStuff
	
	DROP TABLE IF EXISTS temp_saleorders_highvalue;
	CREATE LOCAL TEMP TABLE temp_saleorders_highvalue
	(
			order_id               	INT,
			highvaluetotal          money
	)
	ON COMMIT DROP;
	
	Insert Into temp_saleorders_highvalue (order_id, highvaluetotal)
	Select order_id, Sum(price_unit * product_uom_qty) 
	FROM temp_saleorders_lines
	WHERE highvalue = true
	GROUP BY order_id;
	
	Update temp_saleorders_highvalue SET highvaluetotal = COALESCE(highvaluetotal,_zeroamount);
	
	Update temp_saleorders SET amounttotal = 0;
	Update temp_saleorders SET amounttotal = highvaluetotal 
	FROM temp_saleorders_highvalue
	WHERE temp_saleorders_highvalue.order_id = temp_saleorders.myid;		
	

/*	
	Update temp_saleorders SET highvalue = true WHERE partner_id in
	(Select partner_id From temp_saleorders
	Group By partner_id Having Sum(amounttotal) >= _ordertotal);
*/

	-- Orders Above 10K
	Update temp_saleorders SET highvalue = true WHERE amounttotal >= _ordertotal;
	
/*	
	--Split Orders Above 10K
	Update temp_saleorders SET highvalue = true WHERE highvalue = false And
	partner_id in (Select partner_id From temp_saleorders
	Group By partner_id Having Sum(amounttotal) >= _ordertotal);
*/	
	
	Update temp_saleorders SET highvalue = true
	From temp_saleorders_lines
	WHERE temp_saleorders_lines.order_id = temp_saleorders.myid
	And temp_saleorders_lines.highvalue = true
	And temp_saleorders.highvalue = false
	And price_unit >= _unitprice;

	-- Update temp_saleorders SET highvalue = true, totalprepayment = 0;

	Update temp_saleorders SET totalprepayment = get_orderprepayment (myid) Where highvalue = true;
	Update temp_saleorders SET totalprepayment = get_orderprepayment (myid) Where islayaway = true;

	Update temp_saleorders SET highvalue = false WHERE highvalue = true and totalprepayment >= amounttotal / 2;
	Update temp_saleorders SET highvalue = true WHERE islayaway = true;
	Update temp_saleorders SET highvalue = false WHERE islayaway = true and totalprepayment >= amounttotal;

	----Cancel Normal Orders After 2 days of No Downpayment
	--_date = orderdate - INTERVAL '3 day';
	if _dayofweek = 'monday' then
    	_date = _today - INTERVAL '3 day';
    else
    	_date = _today - INTERVAL '2 day';
    end if; 
	
	-- UPDATE wkf_instance Set "state" = 'active'
	-- WHERE res_type = 'sale.order' And "state" <> 'active'
	-- AND res_id in (SELECT myid FROM temp_SaleOrders  Where highvalue = true And islayaway = false And date_order < _date);

-- RAISE NOTICE 'Cancel Date (%) ',  _date;

	UPDATE sale_order_line SET "state" = 'cancel' Where order_id in (SELECT myid FROM temp_SaleOrders  Where highvalue = true And islayaway = false And date_order < _date);
	UPDATE sale_order SET "state" = 'cancel', note = 'High Value Order Cancelled by Order Confirmation Process'
	Where id in (SELECT myid FROM temp_SaleOrders  Where highvalue = true And islayaway = false And date_order < _date);

	----Change Forecasted Delivery Date for orders qualifing prepayment
	UPDATE sale_order SET date_delivery = get_newdeliverydate(id, _today) WHERE date_order < orderdate 
	And id in (SELECT myid FROM temp_SaleOrders  Where highvalue = false  And totalprepayment > _zeroamount);
	-----End of High Value Orders Code
	-----=============================

	----Confirm Orders
	UPDATE wkf_instance Set "state" = 'active'
	WHERE res_type = 'sale.order' And "state" <> 'active'
	AND res_id in (SELECT myid FROM temp_SaleOrders  Where highvalue = false);

	UPDATE sale_order_line SET "state" = 'confirmed' Where order_id in (SELECT myid FROM temp_SaleOrders  Where highvalue = false);
	UPDATE sale_order SET "state" = 'progress', confirmation_date = _today
	Where id in (SELECT myid FROM temp_SaleOrders  Where highvalue = false);
END;

$function$;

ALTER FUNCTION public.sp_confirmorders(date, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.sp_confirmorders(date, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_confirmorders(date, integer) TO odoo;


