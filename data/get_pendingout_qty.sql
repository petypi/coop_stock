-- FUNCTION: public.get_expected_qoh(integer, integer)

-- DROP FUNCTION public.get_expected_qoh(integer, integer);

CREATE OR REPLACE FUNCTION public.get_pendingout_qty(
	warehouseid 	integer,
	productid 		integer
	)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

        
Declare _expected_out           NUMERIC(12,2);

BEGIN
        
	SELECT SUM(sol.product_uom_qty) FROM sale_order so
	LEFT JOIN sale_order_line sol ON sol.order_id = so.id
	INNER JOIN res_partner_data par ON so.partner_id = par.id
	WHERE so.state in ('draft','progress') AND so.date_delivery > CURRENT_DATE
	AND date_order <= CURRENT_DATE  AND sol.product_id = productid
	AND par.id = warehouseid
	INTO _expected_out;
	
	_expected_out = COALESCE(_expected_out,0);
        
	RETURN _expected_out;
	
END;
        
        
$function$;

ALTER FUNCTION public.get_pendingout_qty(integer, integer) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_pendingout_qty(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_pendingout_qty(integer, integer) TO odoo;




