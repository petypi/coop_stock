-- FUNCTION: public.get_itemlocationidinteger, integer

-- DROP FUNCTION public.get_itemlocationidinteger, integer;

CREATE OR REPLACE FUNCTION public.get_itemlocationid(
	warehouseid integer,
	productid integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
	defaultlocation	integer;
	locationid		integer;

BEGIN
	select id from ofc_locations where warehouse_id = warehouseid and is_default = true LIMIT 1 INTO defaultlocation;    

	Select location_id from location_product_rel Where product_id = productid
	And location_id in (Select id from ofc_locations where warehouse_id = warehouseid) INTO locationid;        

	IF locationid IS NULL THEN
		locationid = defaultlocation;
	END IF;

	RETURN locationid;

END;

$function$;

ALTER FUNCTION public.get_itemlocationid(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_itemlocationid(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_itemlocationid(integer, integer) TO odoo;


