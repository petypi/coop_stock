-- FUNCTION: public.get_locationid(integer, character varying)

-- DROP FUNCTION public.get_locationid(integer, character varying);

CREATE OR REPLACE FUNCTION public.get_locationid(
	warehouse_id integer,
	location_type character varying)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
fullname 		varchar(250);
warehouse_name	varchar(50);
location_id		INT;

BEGIN
	IF location_type = 'loss' THEN
		location_type = 'Inventory loss';
	END IF;

	IF location_type in ('customer','supplier','procurement','production') THEN		
		Select id from stock_location where usage = location_type  INTO location_id LIMIT 1;
	ELSEIF location_type in ('Inventory loss','Scrapped') THEN
		Select id from stock_location where usage = 'inventory' And name = location_type LIMIT 1 INTO location_id;
	ELSE 
		IF location_type = 'stock' THEN	
			Select lot_stock_id from stock_warehouse Where id = warehouse_id INTO location_id;
		ELSEIF location_type = 'output' THEN	
			Select wh_output_stock_loc_id from stock_warehouse Where id = warehouse_id INTO location_id;
		ELSEIF location_type = 'input' THEN	
			Select wh_input_stock_loc_id from stock_warehouse Where id = warehouse_id INTO location_id;
		END IF;
	END IF;

	RETURN location_id;
END; 

$function$;

ALTER FUNCTION public.get_locationid(integer, character varying)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_locationid(integer, character varying) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_locationid(integer, character varying) TO odoo;


