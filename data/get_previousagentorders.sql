-- FUNCTION: public.get_previousagentorders(integer)

-- DROP FUNCTION public.get_previousagentorders(integer);

CREATE OR REPLACE FUNCTION public.get_previousagentorders(
	agent_id integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare totalorders		numeric;

BEGIN
	select count (id) from sale_order where partner_id = agent_id and state = 'done' and is_duplicate = 'f' INTO totalorders; 
	RETURN totalorders;
END;

$function$;

ALTER FUNCTION public.get_previousagentorders(integer) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_previousagentorders(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_previousagentorders(integer) TO odoo;


