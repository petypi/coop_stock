-- FUNCTION: public.get_previouscustomerorders(integer)

-- DROP FUNCTION public.get_previouscustomerorders(integer);

CREATE OR REPLACE FUNCTION public.get_previouscustomerorders(
	customerid integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare totalorders		numeric;

BEGIN
	select count (id) from sale_order where customer_id = customerid and state = 'done' and is_duplicate = 'f' INTO totalorders; 
	RETURN totalorders;
END;

$function$;

ALTER FUNCTION public.get_previouscustomerorders(integer) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_previouscustomerorders(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_previouscustomerorders(integer) TO odoo;


