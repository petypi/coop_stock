-- FUNCTION: public.sp_ofs_sync_cancel_orders()

-- DROP FUNCTION public.sp_ofs_sync_cancel_orders();

CREATE OR REPLACE FUNCTION public.sp_ofs_sync_cancel_orders(
	)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE --results text;
	mycursorid		INT;
	myid			INT;
	_order_id		INT;
	_ofc_id         INT;
	_userid			INT;
	_count			INT;
    _order_line_id	INT;
    _cancelled_qty	INT;
    _ordered_qty	INT;
    _column_exists 	VARCHAR(32);
    _new_line_id	INT;
    

BEGIN

   
    
	DROP TABLE IF EXISTS temp_order_cancel;
	CREATE TEMP TABLE temp_order_cancel
	(
		id				INT,
		order_id		INT,
		ofc_id			INT,
		user_id			INT,
        order_line_id	INT,
        cancelled_qty	INT,
        ordered_qty		INT
	)
	ON COMMIT DROP;

    Insert Into temp_order_cancel (id, order_id, ofc_id, user_id, order_line_id, cancelled_qty, ordered_qty)
	Select id, order_id, ofs_warehouseid, create_uid, order_line_id, cancelled_qty, 0
	FROM ofs_cancel_order WHERE processed = false; 
    
    Update temp_order_cancel SET ordered_qty = product_uom_qty
    From sale_order_line
    Where sale_order_line.id = temp_order_cancel.order_line_id;
    
  	mycursorid = 1;    
   
	DECLARE cur_orders CURSOR FOR SELECT id, order_id, ofc_id, user_id, order_line_id, cancelled_qty , ordered_qty
    from temp_order_cancel;
	BEGIN
		OPEN cur_orders;	
		LOOP
			-- fetch row into the film
			FETCH cur_orders INTO myid, _order_id, _ofc_id, _userid, _order_line_id, _cancelled_qty, _ordered_qty;
			-- exit when no more row to fetch
			EXIT WHEN NOT FOUND;
            
            _order_line_id = COALESCE(_order_line_id,0);
               
			RAISE NOTICE 'Cancelling Order Line (%) (%) (%) (%) (%) (%)', _order_id, _ofc_id, _userid, _order_line_id, _cancelled_qty, _ordered_qty ;
/*			
            _count = 0;
            Select Count(id) from account_invoice Where state <> 'cancel' 
            And id in (Select Invoice_id From sale_order_invoice_rel Where order_id = _order_id) Into _count;
            _count = COALESCE(_count,0);
            
			IF _count = 0 THEN 
*/
            
			IF _order_line_id = 0 THEN
            	Update sale_order_line SET state = 'cancel' , write_uid = _userid, write_date = now()  
                Where order_id = _order_id And ofc_id = _ofc_id;
            ELSE
                IF _cancelled_qty < _ordered_qty THEN
                    INSERT INTO sale_order_line
                        (create_uid,create_date,write_date,write_uid,
                        product_uos_qty, product_uom,sequence, order_id,price_unit,
                        product_uom_qty,discount, product_uos, invoiced, name,
                        delivered_qty,purchased_qty, company_id,salesman_id, state,
                        product_id, order_partner_id, th_weight,type,address_allotment_id, 
                        delay, procurement_id, commission_tier_id, classification, commission, 
                        promotion_line, original_line)
                    SELECT _userid,now() create_date,now() write_date,_userid,
                        product_uos_qty, product_uom,sequence, order_id,price_unit,
                        _cancelled_qty product_uom_qty,discount, product_uos, 'false' invoiced, name,
                        null delivered_qty,null purchased_qty, company_id,salesman_id, 'cancel' state,
                        product_id, order_partner_id, th_weight,type,address_allotment_id, 
                        0 delay, null procurement_id, commission_tier_id, 'retail' classification, commission * (_cancelled_qty / _ordered_qty) ,
                        'false' promotion_line, _order_line_id
                    FROM sale_order_line WHERE id = _order_line_id And order_id = _order_id  And ofc_id = _ofc_id 
                    RETURNING id INTO _new_line_id;

                    Insert Into sale_order_tax (order_line_id, tax_id)
                    Select _new_line_id, tax_id From sale_order_tax Where order_line_id = _order_line_id;

                    Update sale_order_line SET product_uom_qty = product_uom_qty - _cancelled_qty ,
                        commission = commission * ((_ordered_qty - _cancelled_qty) / _ordered_qty)
                    WHERE id = _order_line_id ;

                    Update sale_order_line SET product_uom_qty = 0, commission = 0 WHERE id = _order_line_id And product_uom_qty < 0;
                ELSE
                    Update sale_order_line SET state = 'cancel' , write_uid = _userid, write_date = now()  
                    Where id = _order_line_id And order_id = _order_id And ofc_id = _ofc_id;            
                END IF;
        	END IF;

			_count = 0;
           	Select Count(id) from sale_order_line WHERE order_id = _order_id and STATE = 'confirmed' INTO _count;
          	_count = COALESCE(_count,0);
           	IF _count = 0 THEN
           		UPDATE sale_order SET state = 'cancel' , write_uid = _userid, write_date = now()  WHERE id = _order_id;
           	END IF;            

          	UPDATE ofs_cancel_order SET processed = true WHERE id = myid;
/*
            END IF;
*/            
            mycursorid = mycursorid + 1;
		END LOOP;

		-- Close the cursor
		CLOSE cur_orders;
		RAISE NOTICE 'Finished All Cancellations';
	END;
END

$function$;

ALTER FUNCTION public.sp_ofs_sync_cancel_orders() OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync_cancel_orders() TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync_cancel_orders() TO odoo;



