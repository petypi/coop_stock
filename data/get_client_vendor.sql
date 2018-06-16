-- FUNCTION: public.get_client_vendor

-- DROP FUNCTION public.get_client_vendor (int);

CREATE OR REPLACE FUNCTION public.get_client_vendor(
	client_id int)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
vendor_id		integer;
vendors			integer;


BEGIN
	vendors = 0;
    
	select Count(distinct partner_id) from sale_order where customer_id = client_id INTO vendors;
    IF vendors = 1 THEN
		select partner_id from sale_order where customer_id = client_id LIMIT 1 INTO vendor_id; 
    END IF;
	RETURN vendor_id;
END;

$function$;

ALTER FUNCTION public.get_client_vendor(int)OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_client_vendor(int) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_client_vendor(int) TO odoo;


