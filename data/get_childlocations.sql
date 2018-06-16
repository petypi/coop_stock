-- FUNCTION: public.get_childlocationsinteger

-- DROP FUNCTION public.get_childlocationsinteger;

CREATE OR REPLACE FUNCTION public.get_childlocations(
	locationid integer)
    RETURNS TABLE(location_id integer, location_name character varying, complete_name character varying)
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
    ROWS 1000.0
AS $function$

BEGIN
	RETURN QUERY SELECT n.id, n.name, n.complete_name from stock_location as n, stock_location as p 
	where n.parent_left between p.parent_left and p.parent_right and p.id = locationid
	Order by n.complete_name;
END; 

$function$;

ALTER FUNCTION public.get_childlocations(integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_childlocations(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_childlocations(integer) TO odoo;



