-- FUNCTION: public.sp_createpurchaserequisition(date)

-- DROP FUNCTION public.sp_createpurchaserequisition(date);

CREATE OR REPLACE FUNCTION public.sp_createpurchaserequisition(
	_confirm_date date)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE
	_warehouse_id	INT;
	_companyid	INT;
	_sequenceid	INT;
	_sequencename	varchar(50);
	_requisitionid	INT;
    _warehouse_name	varchar(50);
	_user		INT;    

BEGIN

/*
   RETURNS TABLE(sproduct_id integer, sdefault_code character varying, sproduct_name character varying, sorigin character varying, sproduct_tmpl_id integer, swarehouseid integer, slocationid integer, scompanyid integer, sqty_ordered numeric, spo_qty_ordered numeric, sqtyonhand integer, spo_qtyonhand integer, stopurchase_qty integer, schild_id integer, scateg_id integer, scategory_name character varying character varying, spurchase_uom_id integer, spurchase_factor numeric)
DECLARE
	_confirm_date date :='2016-12-13';
	_warehouse_id integer :=0;
	_companyid		integer :=0;
	_sequenceid		integer :=0;
	_sequencename	varchar(50) :='''';
	_requisitionid	integer :=0; 
 */

	_user = 1;
    
	DROP TABLE IF EXISTS t_saleorders;
	CREATE TEMPORARY TABLE t_saleorders
	(
		id					INT,
		salesordername 		VARCHAR(30),
		partner_id			INT,
		company_id			INT,
		copia_date_order	date,
		date_delivery		date,
		date_order			date,
        warehouse_id		INT
	)
	ON COMMIT DROP ;
	INSERT INTO t_saleorders
		(id, salesordername, partner_id, company_id,date_delivery, date_order)
	SELECT id, name, partner_id, company_id, date_delivery, date_order
	FROM sale_order
	WHERE 
		confirmation_date = _confirm_date
		AND is_duplicate = 'f'
		AND "state" Not in ('draft','cancel','rejected')
        AND requisitioned = 'f'
		AND confirmation_date is Not Null;
   
    Update t_saleorders set warehouse_id = get_agentwarehouse_id(partner_id);

-- RETURN QUERY  select * from t_saleorders;
-- RETURN;

	DROP TABLE IF EXISTS t_saleorder_lines;
	CREATE TEMP TABLE t_saleorder_lines
	(
		order_id		INT,
		product_id		INT,
		product_name 	VARCHAR(300),
		company_id		INT,
		product_uom_id	INT,
		order_qty		numeric(10,6),
		order_name		varchar(30),
		agent_type_name 	varchar(20),
		purchase_uom_id		INT,
		purchase_factor		numeric(10,6),
/*		
		parent_product_id	INT,
		parent_tmpl_id		INT,
		parent_uom_id		INT,
		parent_factor		numeric(10,6),
		parent_uom_qty		numeric(12,4),
*/
		purchase_qty		numeric(12,4),
        ofc_id				INT
	)
	ON COMMIT DROP;
    
	INSERT INTO t_saleorder_lines
		(order_id,product_id, product_name, company_id, product_uom_id, 
		order_qty, purchase_uom_id, purchase_factor)      
		-- order_qty, purchase_uom_id, parent_product_id, purchase_factor)		
	SELECT order_id,ol.product_id, ol.name, ol.company_id, ol.product_uom, 
		product_uom_qty ,product_template.uom_po_id, po_uom.factor
		-- product_uom_qty ,product_template.uom_po_id, parent_product_id, po_uom.factor
	From sale_order_line ol
	inner join product_product on product_product.id = ol.product_id
	inner join product_template on product_product.product_tmpl_id = product_template.id
	join product_uom po_uom on po_uom.id = product_template.uom_po_id
	Where order_id in (Select id from t_saleorders);

	Update t_saleorder_lines SET 
		order_name = salesordername,
        ofc_id = warehouse_id
	From t_saleorders           
	Where t_saleorders.id = t_saleorder_lines.order_id;
    
	Update t_saleorder_lines set ofc_id = get_itemfulfillmentcenter(ofc_id, product_id);
    
/*Start of Parent Child Workings*/
/*
	Update t_saleorder_lines SET 
		parent_tmpl_id = product_product.product_tmpl_id
	From product_product 
	Where product_product.id = t_saleorder_lines.product_id;

	Update t_saleorder_lines SET 
		parent_uom_id = product_template.uom_po_id
	From product_template 
	Where product_template.id = t_saleorder_lines.parent_tmpl_id;    

	Update t_saleorder_lines SET 
		parent_factor = product_uom.factor
	From product_uom 
	Where product_uom.id = t_saleorder_lines.parent_uom_id;

	UPDATE t_saleorder_lines SET parent_uom_qty = order_qty * parent_factor ,
		purchase_factor = parent_factor,
		purchase_uom_id = parent_uom_id
	WHERE parent_factor is not null ;
*/
/*End of Parent Child Workings*/

	UPDATE t_saleorder_lines SET purchase_qty = order_qty * purchase_factor;    

-- ----sp_createpurchaserequisition3
-- RETURN QUERY select * from  t_saleorder_lines; ---- Where parent_product_id is not  null ; ---Where Product_ID = '14235';
-- RETURN;

	DROP TABLE IF EXISTS t_product_orders;
	CREATE TEMP TABLE t_product_orders
	(
    	product_id	INT,
		orders 		VARCHAR(9000000)
	)
	ON COMMIT DROP;

	DROP TABLE IF EXISTS t_requisition_lines;
	-- --CREATE GLOBAL TEMP TABLE t_requisition_lines
	CREATE TEMP TABLE t_requisition_lines
	(
		product_id		INT,
		default_code 	VARCHAR(30),
		product_name 	VARCHAR(250),
		origin 			VARCHAR(9000000),
        product_tmpl_id	INT,
		warehouseid		INT,
		locationid		INT,
		companyid		INT,
		qty_ordered		numeric(12,4),
		po_qty_ordered	numeric(12,4),
		qtyonhand		INT, 
		po_qtyonhand	INT,
		topurchase_qty	INT,
        child_id		INT,
        categ_id		INT,
		category_name 	VARCHAR(50),
        purchase_uom_id		INT,
        purchase_factor		numeric(12,6),
		pending_out		numeric(12,4),
		pending_in		numeric(12,4),
		product_max_qty 		numeric(12,4),
		product_min_qty 		numeric(12,4),
		projected_qty   		numeric(12,4),
		qty_multiple    		numeric(12,4),
		reorder_qty             numeric(12,4),
		required_qty    		numeric(12,4),
		ordered_qty             numeric(12,4)
	)
	ON COMMIT DROP;               

	Insert Into t_requisition_lines
	(
		product_id, companyid, purchase_uom_id,warehouseid, 
        purchase_factor,po_qty_ordered, qty_ordered
	)

    Select -- Distinct 
    	product_id, sol.company_id, purchase_uom_id ,ofc_id, 
        purchase_factor,Sum(purchase_qty),Sum(order_qty)
    From t_saleorder_lines sol
    inner join t_saleorders on t_saleorders.id = sol.order_id
    Group By product_id, sol.company_id, purchase_uom_id , 
    	ofc_id, purchase_factor ;

    Update t_requisition_lines SET     	       
        product_tmpl_id = product_product.product_tmpl_id
    From product_product 
    Where product_product.id = t_requisition_lines.product_id;

    Update t_requisition_lines SET 
        categ_id = product_template.categ_id,
        default_code = product_template.default_code, 
        product_name = CONCAT('[', product_template.default_code, '] ', product_template.name)
    From product_template 
    Where product_template.id = t_requisition_lines.product_tmpl_id;
 
 -- select default_code, * from product_template
 
 
    /*
    Update t_requisition_lines SET 
        child_id = product_product.child_id
    From product_product 
    Where product_product.id = t_requisition_lines.product_tmpl_id;
    */

    Update t_requisition_lines SET 
    	category_name = product_category.name
    From product_category 
    Where product_category.id = t_requisition_lines.categ_id;   

	UPDATE t_requisition_lines SET locationid = get_locationid (warehouseid,'stock'),topurchase_qty = 0;	
    UPDATE t_requisition_lines SET qtyonhand = get_qtyonhand(locationid, product_id);
    UPDATE t_requisition_lines SET po_qtyonhand = qtyonhand * purchase_factor;

	INSERT INTO t_product_orders (product_id, orders)
	SELECT t_requisition_lines.product_id, array_to_string(ARRAY(
    SELECT order_name FROM t_saleorder_lines
    WHERE t_saleorder_lines.product_id = t_requisition_lines.product_id ORDER BY order_id) ,', ', '') As Orders
	FROM t_requisition_lines
	ORDER BY t_requisition_lines.product_id;

	Update t_requisition_lines SET origin = t_product_orders.orders FROM t_product_orders
	WHERE t_product_orders.product_id = t_requisition_lines.product_id;

	DROP TABLE IF EXISTS t_pending_orders;
	CREATE TEMP TABLE t_pending_orders
	(
		product_id			INT,
		default_code 		VARCHAR(30),
		product_name  		VARCHAR(250),
    	pending_qty 		INT
	)
	ON COMMIT DROP;
	INSERT INTO t_pending_orders (product_id, default_code, product_name, pending_qty)
	SELECT pp.id,  pt.default_code, pt.name,  --pc2.name, pc.name, 
		sum(sol.product_uom_qty) from sale_order so                                                   
	left join sale_order_line sol ON sol.order_id = so.id 
	left join product_product pp ON pp.id = sol.product_id 
	left join product_template pt ON pp.product_tmpl_id = pt.id  
	-- ----left join product_category pc ON pc.id = pt.categ_id 
	-- ----left join product_category pc2 on  pc2.id = pc.parent_id 
	where so.state='progress' and so.date_delivery > orderDate  
		And date_order < orderDate
		And confirmation_date < _today		
	group by pp.id, pt.default_code, pt.name; --, pc2.name, pc.name;

	Update t_requisition_lines SET pending_out = pending_qty
	FROM t_pending_orders
	Where t_pending_orders.product_id = t_requisition_lines.product_id;

	UPDATE t_requisition_lines SET pending_in = get_pending_in_qoh(locationid, product_id);
	UPDATE t_requisition_lines SET pending_in = COALESCE(pending_in,0)  * purchase_factor, 
		pending_out = COALESCE(pending_out,0)  * purchase_factor;

	UPDATE t_requisition_lines SET topurchase_qty = ABS(po_qtyonhand - pending_out) + po_qty_ordered WHERE (po_qtyonhand - pending_out) < 0;
	UPDATE t_requisition_lines SET topurchase_qty = po_qty_ordered - (po_qtyonhand - pending_out)
	WHERE (po_qtyonhand - pending_out) < po_qty_ordered And (po_qtyonhand - pending_out) >= 0;
	
-- RETURN QUERY select * from  t_requisition_lines Order by product_id desc;
-- RETURN;

	Update t_requisition_lines SET
		product_max_qty = stock_warehouse_orderpoint.product_max_qty,
		product_min_qty = stock_warehouse_orderpoint.product_min_qty,
		qty_multiple = stock_warehouse_orderpoint.qty_multiple
	FROM stock_warehouse_orderpoint
	WHERE stock_warehouse_orderpoint.warehouse_id = t_requisition_lines.warehouseid
		And stock_warehouse_orderpoint.location_id = t_requisition_lines.locationid
		And stock_warehouse_orderpoint.company_id = t_requisition_lines.companyid
		And stock_warehouse_orderpoint.product_id = t_requisition_lines.product_id
		And stock_warehouse_orderpoint.active = true;

	UPDATE t_requisition_lines SET reorder_qty = 0, required_qty = 0,
		product_max_qty = COALESCE(product_max_qty,0),
		product_min_qty = COALESCE(product_min_qty,0),
		ordered_qty = COALESCE(ordered_qty,0),
		qty_multiple = COALESCE(qty_multiple,1);

	UPDATE t_requisition_lines SET projected_qty = qtyonhand - (ordered_qty + pending_out);
	UPDATE t_requisition_lines SET required_qty = product_max_qty - projected_qty WHERE projected_qty <= product_min_qty;
	UPDATE t_requisition_lines SET reorder_qty = floor((required_qty/qty_multiple) * purchase_factor)  WHERE projected_qty <= product_min_qty ;
	UPDATE t_requisition_lines SET reorder_qty = COALESCE(reorder_qty,0) WHERE projected_qty <= product_min_qty;
		

	DECLARE cur_requisitions CURSOR FOR SELECT DISTINCT warehouseid, companyid from t_requisition_lines;
	BEGIN
		OPEN cur_requisitions;
		LOOP
		-- fetch row into the film
		FETCH cur_requisitions INTO _warehouse_id, _companyid;
		-- exit when no more row to fetch
		EXIT WHEN NOT FOUND;
		RAISE NOTICE 'Creating Purchase Requistion for Warehouse (%)', _warehouse_id;
		SELECT * FROM get_NextSequence(37) INTO _sequenceID, _sequencename;
        
        SELECT name from stock_warehouse where id = _warehouse_id  INTO _warehouse_name;
		INSERT INTO purchase_requisition
			(create_uid,create_date,write_date,write_uid,origin,
			description, exclusive, date_end, warehouse_id, user_id,
			name, date_start, company_id,state, type, all_selected)
		Select _user create_uid,now() create_date,now() write_date, _user write_uid, 'SOs for ' ||  to_char(_confirm_date, 'DD Mon YYYY'),
			NULL as description, 'multiple' as "exclusive", NULL as date_end, _warehouse_id as warehouse_id, _user as user_id,
			CONCAT(_sequencename,'(',_warehouse_name,')') as "name", current_date as date_start, _companyid as company_id,'in_progress' as "state", 
			'Retail' as "type", 'f' all_selected
		RETURNING id INTO _requisitionid;

		Insert Into purchase_requisition_line
			(create_uid,create_date,write_date,write_uid,origin,
			category, pending_out, pending_in, reorder_qty,
        	qty_to_purchase, product_id, product_uom_id,company_id,
			requisition_id,product_qty,qty_available,selected_flag,user_id)
		Select _user create_uid,now() create_date,now() write_date, _user write_uid, origin,
			category_name, pending_out, pending_in, reorder_qty,
			topurchase_qty as qty_to_purchase, product_id, purchase_uom_id, companyid company_id, 
			_requisitionid requisition_id,po_qty_ordered product_qty,po_qtyonhand qty_available, 'f' selected_flag,null user_id
		From t_requisition_lines 
        Where warehouseid = _warehouse_id and companyid = _companyid;

		RAISE NOTICE 'Finished Purchase Requistion for Warehouse (%)', _warehouse_id;

	END LOOP;
   	-- ----Close the cursor
   	CLOSE cur_requisitions;
	END;   

    UPDATE sale_order SET requisitioned = 't' WHERE ID IN (SELECT id from t_saleorders);
END;

$function$;

ALTER FUNCTION public.sp_createpurchaserequisition(date)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.sp_createpurchaserequisition(date) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_createpurchaserequisition(date) TO odoo;





