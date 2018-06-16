-- FUNCTION: public.sp_ofs_sync

-- DROP FUNCTION public.sp_ofs_sync;

CREATE OR REPLACE FUNCTION public.sp_ofs_sync()
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE --results text;
    _mycursorid     INT;
    _ofc_id         INT;
    _ofc_receiptid  INT;
    _order_line_id	INT;
    _qty         	INT;
    _id            	INT;

BEGIN

    PERFORM sp_ofs_sync_cancel_receipts();

    PERFORM sp_ofs_sync_cancel_orders();

	DROP TABLE IF EXISTS temp_kitting;
	CREATE LOCAL TEMP TABLE temp_kitting
	(
		ofc_id          INT,
		receipt_id      INT
	)
	ON COMMIT DROP;

	INSERT INTO temp_kitting (ofc_id, receipt_id)
	SELECT distinct warehouse_id, ofs_receiptid 
	from ofs_delivery where processed = false LIMIT 500;

-- /*
	_mycursorid = 1;

	DECLARE cur_kittings CURSOR FOR SELECT ofc_id, receipt_id from temp_kitting;
	BEGIN
		OPEN cur_kittings;
		LOOP
			-- fetch row into the film
			FETCH cur_kittings INTO _ofc_id, _ofc_receiptid;
			-- exit when no more row to fetch
			EXIT WHEN NOT FOUND;
			RAISE NOTICE 'Calling Kitting (%)(%) (%)', _ofc_id, _ofc_receiptid, _mycursorid;


			DROP TABLE IF EXISTS temp_deliveries;
			CREATE TEMP TABLE temp_deliveries
			(
				myid            INT,
				order_line_id   INT,
				qty         	INT
			);

            INSERT INTO temp_deliveries (order_line_id, qty)
            SELECT distinct line_id, qty FROM ofs_delivery
            WHERE warehouse_id = _ofc_id and ofs_receiptid  = _ofc_receiptid And processed = false ;

            DECLARE cur_delivery CURSOR FOR SELECT order_line_id, qty from temp_deliveries;
			BEGIN
				OPEN cur_delivery;
				LOOP
					-- fetch row into the film
					FETCH cur_delivery INTO _order_line_id, _qty;
					-- exit when no more row to fetch
					EXIT WHEN NOT FOUND;
					RAISE NOTICE 'Calling Delivery (%) (%)',  _order_line_id, _qty;

					SELECT id from ofs_delivery WHERE warehouse_id = _ofc_id
					and ofs_receiptid  = _ofc_receiptid And processed = false
					and line_id = _order_line_id And qty = _qty 
					ORDER BY ID LIMIT 1 INTO _id;

					Update ofs_delivery SET processed = true , remarks = 'possible duplicate'
					Where id <> _id AND warehouse_id = _ofc_id and ofs_receiptid  = _ofc_receiptid
                    And line_id = _order_line_id And qty = _qty and processed = false;

					END LOOP;
				CLOSE cur_delivery;
			END;

            PERFORM sp_ofs_sync_kitting(_ofc_id, _ofc_receiptid);

            _mycursorid = _mycursorid + 1;
        END LOOP;

        -- Close the cursor
        CLOSE cur_kittings;

        RAISE NOTICE 'Finished All Kittings';
    END;
-- */
END;


$function$;

ALTER FUNCTION public.sp_ofs_sync() OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync() TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync() TO odoo;


