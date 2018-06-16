-- FUNCTION: public.sp_ofs_sync_kitting(integer, integer)

-- DROP FUNCTION public.sp_ofs_sync_kitting(integer, integer);

CREATE OR REPLACE FUNCTION public.sp_ofs_sync_kitting(
	_ofs_warehouse_id integer,
	_ofs_receipt_id integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

-- */

DECLARE 
/*
	_ofs_warehouse_id	INT;
	_ofs_receipt_id		INT;
*/
	_items        		INT;
	_user_id           	INT;
	_now                TIMESTAMP;
	_date               DATE;
	_order_id       	INT;
	_order_name     	VARCHAR(50);
	_pickingid     		INT;
	_agent_warehouse_id INT;
	_picking_int_id    	INT;
	_picking_out_id    	INT;
	_transit_int_id    	INT;
	_invoice_id      	INT;
	_sequenceid       	INT;
	_sequencename     	varchar(50);
	_weight     		numeric(12,4);
	_weight_uom 	 	numeric(12,4);
	_column_exists      VARCHAR(32);
	_receipt_ref        VARCHAR(32);
	_instance_id    	INT;
	_exception_id      	INT;
	_product_id			INT;
	_product_uom_qty	INT;
	_order_line_id		INT;
		
BEGIN
/*
	_ofs_warehouse_id = 1;
	_ofs_receipt_id = 4 ;
*/	
	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='ofs_delivery' and column_name='ofs_receiptid';
	IF _column_exists IS NULL THEN
		ALTER TABLE ofs_delivery ADD COLUMN  ofs_receiptid int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='ofs_delivery' and column_name='picking_int_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE ofs_delivery ADD COLUMN  picking_int_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='ofs_delivery' and column_name='picking_out_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE ofs_delivery ADD COLUMN  picking_out_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='ofs_delivery' and column_name='transit_int_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE ofs_delivery ADD COLUMN  transit_int_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='ofs_delivery' and column_name='invoice_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE ofs_delivery ADD COLUMN  invoice_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='ofs_delivery' and column_name='remarks';
	IF _column_exists IS NULL THEN
		ALTER TABLE ofs_delivery ADD COLUMN  remarks varchar(250) DEFAULT NULL;
	END IF;
	
	
	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_picking' and column_name='ofs_warehouseid';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_picking ADD COLUMN  ofs_warehouseid int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_picking' and column_name='ofs_receiptid';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_picking ADD COLUMN  ofs_receiptid int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_picking' and column_name='receipt_ref';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_picking ADD COLUMN  receipt_ref int DEFAULT NULL;
	END IF;
	
	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_picking' and column_name='is_reversed';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_picking ADD COLUMN  is_reversed boolean DEFAULT false;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_picking' and column_name='reversal_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_picking ADD COLUMN  reversal_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_move' and column_name='is_reversed';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_move ADD COLUMN  is_reversed boolean DEFAULT false;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_move' and column_name='reversal_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_move ADD COLUMN  reversal_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_move' and column_name='order_line_id';
	IF _column_exists IS NULL THEN
		ALTER TABLE stock_move ADD COLUMN  order_line_id int DEFAULT NULL;
	END IF;	

	_items = 0;
	Select count(id) FROM stock_picking Where ofs_warehouseid = _ofs_warehouse_id
	and ofs_receiptid = _ofs_receipt_id And  state <> 'cancel' Into _items ;
	IF _items > 0 THEN
		Update ofs_delivery SET processed = true , remarks = 'Duplicate Stock Picking Detected'
		Where warehouse_id = ofs_warehouse_id and ofs_receiptid  = ofs_receipt_id and processed = false;

		RAISE NOTICE 'Duplicate Stock Picking Detected (%) (%)',  ofs_warehouse_id, ofs_receipt_id;
		RETURN;
	END IF;
        
	_now = now();
	_date = current_date;        
        
	DROP TABLE IF EXISTS temp_saleorder_lines;
	CREATE TEMP TABLE temp_saleorder_lines
	(
		order_line_id           int,
		create_uid              varchar(5),
		create_date             TIMESTAMP,
		write_date              TIMESTAMP,
		write_uid               varchar(5),
		product_id              INT,
		product_name            VARCHAR(150),
		order_partner_id        INT,
		order_id                INT,
		order_name              VARCHAR(50),
		receipt_ref             VARCHAR(50),
		ordered_qty				INT,
		price_unit              numeric(12,4),            
		product_uom_qty         INT,
		product_uom             INT,
		weight                  numeric(12,4),
		company_id              INT,
		warehouse_id            INT,
		default_ofc_id          INT,
		line_id                 INT,
		product_qoh             INT,
		adjustment              INT,
		deliverydate			date
	)
	ON COMMIT DROP;

	INSERT INTO temp_saleorder_lines
		(order_line_id, create_uid, create_date, write_date, write_uid, product_id, product_name,
		order_partner_id, order_id,ordered_qty, price_unit,product_uom_qty, line_id, warehouse_id,
		product_uom, weight, default_ofc_id, product_qoh, adjustment, receipt_ref, deliverydate)                
	SELECT sale_order_line.ID, sale_order_line.create_uid, sale_order_line.create_date,
		sale_order_line.write_date, sale_order_line.write_uid, sale_order_line.product_id,
		sale_order_line.name, order_partner_id, sale_order_line.order_id,
		sale_order_line.product_uom_qty ordered_qty, 0 as price_unit, 
		qty as product_uom_qty, ofs_delivery.line_id, _ofs_warehouse_id, product_uom,  
		qty * COALESCE(product_product.weight ,0) weight, COALESCE(default_ofc_id,_ofs_warehouse_id) , 
		0 as product_qoh , 0 as adjustment, ofs_delivery.receipt_ref,
		COALESCE(sale_order.date_delivery, _date + INTERVAL '1 day') as deliverydate
	FROM sale_order_line
	INNER JOIN ofs_delivery ON
		sale_order_line.id = ofs_delivery.line_id
	INNER JOIN sale_order ON
		sale_order_line.order_id = sale_order.id
	INNER JOIN product_product ON
		sale_order_line.product_id = product_product."id"
	INNER JOIN product_template ON
		product_product.product_tmpl_id = product_template."id"
	WHERE
		ofs_delivery.warehouse_id = _ofs_warehouse_id
		and ofs_delivery.ofs_receipt_id  = _ofs_receipt_id
		and ofs_delivery.processed = 'false'
		and sale_order.state Not in ('draft','cancel')
	ORDER BY sale_order_line.id DESC;
	

	Select COALESCE(user_id,1), receipt_ref FROM ofs_delivery 
	WHERE warehouse_id = _ofs_warehouse_id AND ofs_receipt_id = _ofs_receipt_id LIMIT 1 
	INTO _user_id, _receipt_ref;
		

	Select order_id, default_ofc_id, order_name FROM temp_saleorder_lines limit 1 
	INTO _order_id, _agent_warehouse_id, _order_name;

	UPDATE temp_saleorder_lines SET
		order_name = sale_order.name
	FROM sale_order
	Where sale_order.id = temp_saleorder_lines.order_id;
	
	UPDATE temp_saleorder_lines SET product_qoh = get_qtyonhand(get_locationid(_ofs_warehouse_id,'stock'),product_id);		

	_items = 0;
	_weight = 0;

	Select Sum(weight), count(_items) FROM temp_saleorder_lines Into _weight, _items ;
 
	-- RAISE NOTICE 'Kitting Details (Weight & Items) (%)(%)', _total_weight, _items;
	IF _items = 0 THEN
		Update ofs_delivery Set
			processed = 'true',
			remarks = 'invalid order'
		Where warehouse_id = _ofs_warehouse_id and ofs_receiptid = _ofs_receipt_id and processed = 'false';
		RAISE NOTICE 'Invalid Order or No Items Found'; 
		return;
	END IF;
        
 
/* START OF STOCK EXCEPTION */

-- /*
	Update temp_saleorder_lines SET adjustment = product_uom_qty - product_qoh;

	Update stock_exceptions SET kitted_qty = kitted_qty + product_uom_qty,
		adjusted_qty = 0 --adjusted_qty = adjusted_qty + adjustment
	FROM temp_saleorder_lines
	WHERE stock_exceptions.product_id = temp_saleorder_lines.product_id
		And stock_exceptions.warehouse_id = _ofs_warehouse_id
		And stock_exceptions.sync_date = _date
		And stock_exceptions.state = 'new';

	INSERT INTO stock_exceptions
		(create_uid,create_date,write_date,write_uid,
		warehouse_id, product_id,state,sync_date,
		initial_qoh,kitted_qty, adjusted_qty )
	SELECT '1' create_uid,now() create_date,now() write_date, '1' write_uid,
		warehouse_id, product_id,'new',_date,
		product_qoh, product_uom_qty, 0 adjustment
	FROM temp_saleorder_lines
	WHERE adjustment > 0
		And product_id Not in (Select product_id from stock_exceptions 
		where warehouse_id = _ofs_warehouse_id And state = 'new' and sync_date = _date);
-- */
/* END OF STOCK EXCEPTION */

	DROP TABLE IF EXISTS temp_stock_moves;
	CREATE TEMP TABLE temp_stock_moves
	(
		id                  INT,
		product_id          INT,
		picking_id          INT,
		location_id         INT,
		location_dest_id    INT
	)
	ON COMMIT DROP;       
	

	
	DROP TABLE IF EXISTS quants_consumed;
	CREATE TEMP TABLE quants_consumed
	(
		quant_id    	INT,
		quant_qty		INT,
		quant_cost		numeric(12,4),
		order_line_id	INT,
		quant_total		numeric(12,4),
		move_id			INT
	);	
	
	DECLARE _quants CURSOR FOR SELECT product_id, product_uom_qty, order_line_id from temp_saleorder_lines;
	BEGIN
		OPEN _quants;	
		LOOP
			FETCH _quants INTO _product_id, _product_uom_qty, _order_line_id;
			EXIT WHEN NOT FOUND;
			-- RAISE NOTICE 'Consuming Quants for (%) (%) (%) (%) (%)', _product_id, _ofs_warehouse_id, _product_uom_qty, _user_id, _order_line_id;     
			
			Insert Into quants_consumed (quant_id, quant_qty, quant_cost, order_line_id)
			Select quant_id, quant_qty, unit_cost, order_line_id
			From sp_consumestockquants (_product_id, _ofs_warehouse_id, _product_uom_qty, _user_id, _order_line_id);	
			
		END LOOP;
		CLOSE _quants;
	END;

-- Select * From sp_consumestockquants (1, 1, 1, 1, 4);

	Update quants_consumed Set quant_total = quant_cost * quant_qty;

	DROP TABLE IF EXISTS quants_totals;
	CREATE TEMP TABLE quants_totals
	(
		quant_qty		INT,
		order_line_id	INT,
		quant_total		numeric(12,4),
		line_cost		numeric(12,4)
	);
	
	Insert Into quants_totals (order_line_id, quant_qty, quant_total)
	Select order_line_id, Sum(quant_qty), Sum(quant_total) from quants_consumed 
	Where quant_qty > 0 Group By order_line_id;
	
	Update quants_totals Set line_cost = quant_total / quant_qty; 
	
	Update temp_saleorder_lines SET price_unit = quants_totals.line_cost 
	from quants_totals Where temp_saleorder_lines.order_line_id = quants_totals.order_line_id;
	

	_picking_int_id = null;
	_picking_out_id = null;
	_transit_int_id = null;

/* START OF STOCK to OUTPUT (FC / DEPOT) */		
	BEGIN

		/*Stock Picking Sequence - INT*/
		SELECT * FROM get_NextSequence(22) INTO _sequenceid, _sequencename;
			
		INSERT INTO stock_picking
			(origin, create_uid, write_uid, write_date, create_date, date, 
			recompute_pack_op, launch_pack_operations, 
			location_id, location_dest_id, priority, 
			picking_type_id, partner_id, move_type, company_id, note,
			state, group_id, name, min_date,max_date, carrier_tracking_ref,
			number_of_packages, carrier_id, weight, weight_uom_id, volume, carrier_price,
			ref, product_return_id, receipt_ref, wave_id, is_reversed)
		Select sale_order.name origin, _user_id create_uid, _user_id write_uid, _now write_date, _now create_date, _date date, 
			false as recompute_pack_op, false as launch_pack_operations, 
			get_locationid(_ofs_warehouse_id,'stock') location_id, 
			get_locationid(_ofs_warehouse_id,'output') location_dest_id, 
			1 as priority, 
			get_pickingtypeid(_ofs_warehouse_id, 'outgoing', get_locationid(_ofs_warehouse_id,'stock'), 
							 get_locationid(_ofs_warehouse_id,'customer')) picking_type_id, 
			partner_id, 'direct' move_type, sale_order.company_id, null note,
			'done' as state, null group_id, _sequencename as name,  _date min_date,_date max_date, null carrier_tracking_ref,
			null number_of_packages, null carrier_id, _weight as weight, 3 as weight_uom_id, null volume, null carrier_price,
			'sale,order,' || order_id as ref, null product_return_id, receipt_ref, null wave_id, false as is_reversed
		FROM sale_order
		INNER JOIN res_partner ON
			res_partner.id = sale_order.partner_id
		WHERE sale_order.id = _order_id
		RETURNING id INTO _pickingid;
        _picking_int_id = _pickingid;

/*
		INSERT INTO wkf_instance (wkf_id,uid,res_id,res_type,state)
		SELECT '15',_user_id, _pickingid,'stock.picking','active'
		RETURNING ID INTO _instance_id;

		INSERT INTO wkf_workitem (act_id,inst_id,state)
		SELECT 34,_instance_id,'complete';

		INSERT INTO wkf_instance (wkf_id,uid,res_id,res_type,state)
		SELECT '8',_user_id, _pickingid,'stock.picking','active'
		RETURNING ID INTO _instance_id;

		INSERT INTO wkf_workitem (act_id,inst_id,state)
		SELECT 34,_instance_id,'complete';
*/            

		Insert Into stock_move
			(create_uid, create_date, write_date, write_uid, origin, 
			restrict_partner_id, product_uom, price_unit, company_id, date, 
			product_uom_qty, procure_method, product_qty, partner_id, priority,
			picking_type_id, location_id, sequence, order_line_id, state, ordered_qty,
			-- origin_returned_move_id, product_packaging, restrict_lot_id, 
			date_expected, procurement_id,  warehouse_id, inventory_id,
			partially_available, propagate, move_dest_id, scrapped, 
			product_id, name, split_from, rule_id, location_dest_id,
			group_id, picking_id,  to_refund_so,
			weight, weight_uom_id, is_done, is_reversed)

		Select _user_id create_uid, _now create_date, _now write_date, _user_id write_uid, sale_order.name origin, 
			null restrict_partner_id, product_uom, price_unit, sale_order.company_id, _date date, 
			product_uom_qty, 'make_to_stock' procure_method, product_uom_qty product_qty, partner_id, 1 priority,
			get_pickingtypeid(_ofs_warehouse_id, 'outgoing', get_locationid(_ofs_warehouse_id,'stock'), 
				get_locationid(_ofs_warehouse_id,'customer')) as picking_type_id, 
			get_locationid(_ofs_warehouse_id,'stock') location_id, 10 as sequence, order_line_id, 'done' as state, ordered_qty,
			-- origin_returned_move_id, product_packaging, restrict_lot_id, 
			deliverydate date_expected, null procurement_id,  _ofs_warehouse_id as warehouse_id, null inventory_id,
			false as partially_available, true as propagate, null move_dest_id, false as scrapped, 
			product_id, product_name as name, null split_from, null rule_id, get_locationid(_ofs_warehouse_id,'output') location_dest_id,
			null group_id, _pickingid picking_id, false as to_refund_so, weight, 3 as weight_uom_id, true as is_done, false as is_reversed
		FROM temp_saleorder_lines 
		INNER JOIN sale_order ON
			temp_saleorder_lines.order_id = sale_order.id
		INNER JOIN res_partner ON
			res_partner.id = sale_order.partner_id;		
			
			
		Update quants_consumed Set move_id = stock_move.id from stock_move 
		Where stock_move.picking_id = _picking_int_id
			And stock_move.order_line_id = quants_consumed.order_line_id;
			
        Insert Into stock_quant_move_rel (quant_id, move_id)
        Select quant_id, move_id from quants_consumed;
		
		Update stock_quant set negative_move_id = move_id from quants_consumed 
		Where quant_qty < 0 And stock_quant.id = quants_consumed.quant_id;
		
	END;		
/* END OF STOCK to OUTPUT (FC / DEPOT) */
	

/* START OF FC OUTPUT to DEPOT OUTPUT */	
	IF _agent_warehouse_id <> _ofs_warehouse_id THEN 
	
		/*Stock Picking Sequence - OUT*/
		SELECT * FROM get_NextSequence(22) INTO _sequenceid, _sequencename;
		
		
		INSERT INTO stock_picking
			(origin, create_uid, write_uid, write_date, create_date, date, 
			recompute_pack_op, launch_pack_operations, 
			location_id, location_dest_id, priority, 
			picking_type_id, partner_id, move_type, company_id, note,
			state, group_id, name, min_date,max_date, carrier_tracking_ref,
			number_of_packages, carrier_id, weight, weight_uom_id, volume, carrier_price,
			ref, product_return_id, receipt_ref, wave_id, is_reversed)			

		Select sale_order.name origin, _user_id create_uid, _user_id write_uid, _now write_date, _now create_date, _date date, 
			false as recompute_pack_op, false as launch_pack_operations, 
			get_locationid(_ofs_warehouse_id,'output') location_id, 
			get_locationid(_agent_warehouse_id,'output') location_dest_id, 
			1 as priority, 
			get_pickingtypeid(_ofs_warehouse_id, 'outgoing', get_locationid(_ofs_warehouse_id,'stock'), 
							 get_locationid(_ofs_warehouse_id,'customer')) picking_type_id, 
			partner_id, 'direct' move_type, sale_order.company_id, null note,
			'done' as state, null group_id, _sequencename as name,  _date min_date,_date max_date, null carrier_tracking_ref,
			null number_of_packages, null carrier_id, _weight as weight, 3 as weight_uom_id, null volume, null carrier_price,
			'sale,order,' || order_id as ref, null product_return_id, receipt_ref, null wave_id, false as is_reversed
		FROM sale_order
		INNER JOIN res_partner ON
			res_partner.id = sale_order.partner_id
		WHERE sale_order.id = _order_id
		RETURNING id INTO _pickingid;        
        _transit_int_id = _pickingid;

/*
		INSERT INTO wkf_instance (wkf_id,uid,res_id,res_type,state)
		SELECT '15',_user_id, _pickingid,'stock.picking','active'
		RETURNING ID INTO _instance_id;

		INSERT INTO wkf_workitem (act_id,inst_id,state)
		SELECT 34,_instance_id,'complete';

		INSERT INTO wkf_instance (wkf_id,uid,res_id,res_type,state)
		SELECT '8',_user_id, _pickingid,'stock.picking','active'
		RETURNING ID INTO _instance_id;

		INSERT INTO wkf_workitem (act_id,inst_id,state)
		SELECT 34,_instance_id,'complete';
*/	

		Insert Into stock_move
			(create_uid, create_date, write_date, write_uid, origin, 
			restrict_partner_id, product_uom, price_unit, company_id, date, 
			product_uom_qty, procure_method, product_qty, partner_id, priority,
			picking_type_id, location_id, sequence, order_line_id, state, ordered_qty,
			-- origin_returned_move_id, product_packaging, restrict_lot_id, 
			date_expected, procurement_id,  warehouse_id, inventory_id,
			partially_available, propagate, move_dest_id, scrapped, 
			product_id, name, split_from, rule_id, location_dest_id,
			group_id, picking_id,  to_refund_so,
			weight, weight_uom_id, is_done, is_reversed)

		Select _user_id create_uid, _now create_date, _now write_date, _user_id write_uid, sale_order.name origin, 
			null restrict_partner_id, product_uom, price_unit, sale_order.company_id, _date date, 
			product_uom_qty, 'make_to_stock' procure_method, product_uom_qty product_qty, partner_id, 1 priority,
			get_pickingtypeid(_ofs_warehouse_id, 'outgoing', get_locationid(_ofs_warehouse_id,'stock'), 
				get_locationid(_ofs_warehouse_id,'customer')) as picking_type_id, 
			get_locationid(_ofs_warehouse_id,'output') location_id, 10 as sequence, order_line_id, 'done' as state, ordered_qty,
			-- origin_returned_move_id, product_packaging, restrict_lot_id, 
			deliverydate date_expected, null procurement_id,  _ofs_warehouse_id as warehouse_id, null inventory_id,
			false as partially_available, true as propagate, null move_dest_id, false as scrapped, 
			product_id, product_name as name, null split_from, null rule_id, get_locationid(_agent_warehouse_id,'output') location_dest_id,
			null group_id, _pickingid picking_id, false as to_refund_so, weight, 3 as weight_uom_id, true as is_done, false as is_reversed
		FROM temp_saleorder_lines 
		INNER JOIN sale_order ON
			temp_saleorder_lines.order_id = sale_order.id
		INNER JOIN res_partner ON
			res_partner.id = sale_order.partner_id;
	
	END IF;
/* END OF FC OUTPUT to DEPOT OUTPUT */	

		
/* START OF OUTPUT (FC/DEPOT) to CUSTOMER */			
	BEGIN

		/*Stock Picking Sequence - OUT*/
		SELECT * FROM get_NextSequence(21) INTO _sequenceid, _sequencename;
			
		INSERT INTO stock_picking
			(origin, create_uid, write_uid, write_date, create_date, date, 
			recompute_pack_op, launch_pack_operations, 
			location_id, location_dest_id, priority, 
			picking_type_id, partner_id, move_type, company_id, note,
			state, group_id, name, min_date,max_date, carrier_tracking_ref,
			number_of_packages, carrier_id, weight, weight_uom_id, volume, carrier_price,
			ref, product_return_id, receipt_ref, wave_id, is_reversed)			

		Select sale_order.name origin, _user_id create_uid, _user_id write_uid, _now write_date, _now create_date, _date date, 
			false as recompute_pack_op, false as launch_pack_operations, 
			get_locationid(_agent_warehouse_id,'output') location_id, 
			get_locationid(_agent_warehouse_id,'customer') location_dest_id, 
			1 as priority, 
			get_pickingtypeid(_ofs_warehouse_id, 'outgoing', get_locationid(_ofs_warehouse_id,'stock'), 
							 get_locationid(_ofs_warehouse_id,'customer')) picking_type_id, 
			partner_id, 'direct' move_type, sale_order.company_id, null note,
			'assigned' as state, null group_id, _sequencename as name,  _date min_date,_date max_date, null carrier_tracking_ref,
			null number_of_packages, null carrier_id, _weight as weight, 3 as weight_uom_id, null volume, null carrier_price,
			'sale,order,' || order_id as ref, null product_return_id, receipt_ref, null wave_id, false as is_reversed
		FROM sale_order
		INNER JOIN res_partner ON
			res_partner.id = sale_order.partner_id
		WHERE sale_order.id = _order_id
		RETURNING id INTO _pickingid;        
        _picking_out_id = _pickingid;

/*
		INSERT INTO wkf_instance (wkf_id,uid,res_id,res_type,state)
		SELECT '15',_user_id, _pickingid,'stock.picking','active'
		RETURNING ID INTO _instance_id;

		INSERT INTO wkf_workitem (act_id,inst_id,state)
		SELECT 34,_instance_id,'complete';

		INSERT INTO wkf_instance (wkf_id,uid,res_id,res_type,state)
		SELECT '8',_user_id, _pickingid,'stock.picking','active'
		RETURNING ID INTO _instance_id;

		INSERT INTO wkf_workitem (act_id,inst_id,state)
		SELECT 34,_instance_id,'complete';
*/

		Insert Into stock_move
			(create_uid, create_date, write_date, write_uid, origin, 
			restrict_partner_id, product_uom, price_unit, company_id, date, 
			product_uom_qty, procure_method, product_qty, partner_id, priority,
			picking_type_id, location_id, sequence, order_line_id, state, ordered_qty,
			-- origin_returned_move_id, product_packaging, restrict_lot_id, 
			date_expected, procurement_id,  warehouse_id, inventory_id,
			partially_available, propagate, move_dest_id, scrapped, 
			product_id, name, split_from, rule_id, location_dest_id,
			group_id, picking_id,  to_refund_so,
			weight, weight_uom_id, is_done, is_reversed)
		Select _user_id create_uid, _now create_date, _now write_date, _user_id write_uid, sale_order.name origin, 
			null restrict_partner_id, product_uom, price_unit, sale_order.company_id, _date date, 
			product_uom_qty, 'make_to_stock' procure_method, product_uom_qty product_qty, partner_id, 1 priority,
			get_pickingtypeid(_ofs_warehouse_id, 'outgoing', get_locationid(_ofs_warehouse_id,'stock'), 
				get_locationid(_ofs_warehouse_id,'customer')) as picking_type_id, 
			get_locationid(_agent_warehouse_id,'output') location_id, 10 as sequence, order_line_id, 'assigned' as state, ordered_qty,
			-- origin_returned_move_id, product_packaging, restrict_lot_id, 
			deliverydate date_expected, null procurement_id,  _ofs_warehouse_id as warehouse_id, null inventory_id,
			false as partially_available, true as propagate, null move_dest_id, false as scrapped, 
			product_id, product_name as name, null split_from, null rule_id, get_locationid(_agent_warehouse_id,'customer') location_dest_id,
			null group_id, _pickingid picking_id, false as to_refund_so, weight, 3 as weight_uom_id, false as is_done, false as is_reversed
		FROM temp_saleorder_lines 
		INNER JOIN sale_order ON
			temp_saleorder_lines.order_id = sale_order.id
		INNER JOIN res_partner ON
			res_partner.id = sale_order.partner_id;		
	END;
/* END OF OUTPUT (FC/DEPOT) to CUSTOMER */

	INSERT INTO temp_stock_moves (id, product_id, picking_id, location_id, location_dest_id)
	Select id, product_id, picking_id, location_id, location_dest_id from stock_move
	Where origin = _order_name and picking_id in (_picking_out_id, _picking_int_id, _transit_int_id );

	Update stock_move set move_dest_id = temp_stock_moves.id
	From temp_stock_moves
	Where stock_move.origin = _order_name
		And stock_move.product_id = temp_stock_moves.product_id
		And stock_move.picking_id <> temp_stock_moves.picking_id
		And stock_move.location_dest_id = temp_stock_moves.location_id
		And stock_move.picking_id in (_picking_out_id, _picking_int_id, _transit_int_id );

/*SHOULD BE BEFORE INVOICING CODE*/
	Update ofs_delivery Set
		picking_out_id = _picking_out_id,
		picking_int_id = _picking_int_id,
		transit_int_id = _transit_int_id,
		processed = 'true',
		remarks = 'processed successfully'
	Where warehouse_id = _ofs_warehouse_id and ofs_receipt_id = _ofs_receipt_id and processed = 'false';

	---- RAISE NOTICE 'Calling Invoicing Details (%)(%) (%)', stock_picking_int_id, ofs_warehouse_id, ofs_receipt_id;
	PERFORM sp_ofs_sync_invoice(_picking_int_id,_ofs_warehouse_id,_ofs_receipt_id);

    Update stock_picking set ofs_warehouseid = _ofs_warehouse_id, ofs_receiptid = _ofs_receipt_id 
    Where id in (_picking_out_id, _picking_int_id, _transit_int_id );
	

-- END $$;

-- /*

END;	
			

$function$;

ALTER FUNCTION public.sp_ofs_sync_kitting(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync_kitting(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync_kitting(integer, integer) TO odoo;


