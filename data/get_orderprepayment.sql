-- FUNCTION: public.get_orderprepayment(integer)

-- DROP FUNCTION public.get_orderprepayment(integer);

CREATE OR REPLACE FUNCTION public.get_orderprepayment(
	orderid integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
totalprepayment		numeric(12,4);

BEGIN
	totalprepayment = 0;
    
	select Sum(amount) from account_voucher WHERE order_id = orderid and state in ('booked') INTO totalprepayment;

	RETURN COALESCE(totalprepayment,0);
END;

$function$;

ALTER FUNCTION public.get_orderprepayment(integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_orderprepayment(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_orderprepayment(integer) TO odoo;



