-- FUNCTION: public.get_itemfulfillmentcenter(integer, integer)

-- DROP FUNCTION public.get_itemfulfillmentcenter(integer, integer);

CREATE OR REPLACE FUNCTION public.get_itemfulfillmentcenter(
	warehouseid integer,
	productid integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
ofc_id			integer;
parent_id		integer;
product_exists 	integer;

BEGIN
	ofc_id = warehouseid;
	select parent_warehouse_id from stock_warehouse where id = warehouseid INTO parent_id;

	IF parent_id IS NOT NULL THEN
		select product_product_id from location_product_rel where product_product_id = productid 
        and ofc_locations_id in (Select id from ofc_locations Where warehouse_id = warehouseid)
        LIMIT 1 INTO product_exists;
  
		IF product_exists IS NULL THEN
  			ofc_id = parent_id;        
		END IF;
	END IF;

	RETURN ofc_id;

END;

$function$;

ALTER FUNCTION public.get_itemfulfillmentcenter(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_itemfulfillmentcenter(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_itemfulfillmentcenter(integer, integer) TO odoo;


