-- FUNCTION: public.get_expected_qoh(integer, integer)

-- DROP FUNCTION public.get_expected_qoh(integer, integer);

CREATE OR REPLACE FUNCTION public.get_available_qoh(
	warehouseid 	integer,
	productid 		integer
	)
	--RETURNS TABLE(warehouse_id integer, available_qoh NUMERIC(12,2))
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$
        
Declare _qtyonhand             	NUMERIC(12,2);
		_expected_out           NUMERIC(12,2);
		_expected_qoh       	NUMERIC(12,2);
		_locationid           	INT;

BEGIN	
	
	
	SELECT get_locationid (warehouseid, 'stock') INTO _locationid;
	SELECT get_qtyonhand (_locationid, productid) INTO _qtyonhand;		
	SELECT get_pendingout_qty ( warehouseid, productid) INTO _expected_out;       
	_expected_qoh = 0;
	_expected_out = COALESCE(_expected_out,0);
	_expected_qoh = COALESCE(_qtyonhand,0) - _expected_out;
	
	RETURN _expected_qoh;
END;
        
        
$function$;

ALTER FUNCTION public.get_available_qoh(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_available_qoh(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_available_qoh(integer, integer) TO odoo;