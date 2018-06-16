-- FUNCTION: public.get_availableqoh(integer)

-- DROP FUNCTION public.get_availableqoh(integer);

CREATE OR REPLACE FUNCTION public.get_availableqoh(
	productid 		integer
	)
	RETURNS TABLE(warehouse_id integer, warehouse_name character varying, available_qoh NUMERIC(12,2))
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

BEGIN	
	
	RETURN QUERY SELECT id, name, get_available_qoh(id, productid) from stock_warehouse; 
END;       
        
$function$;

ALTER FUNCTION public.get_availableqoh(integer) OWNER TO odoo;
GRANT EXECUTE ON FUNCTION public.get_availableqoh(integer) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_availableqoh(integer) TO odoo;