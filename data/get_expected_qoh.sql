-- FUNCTION: public.get_expected_qoh(integer, integer)

-- DROP FUNCTION public.get_expected_qoh(integer, integer);

CREATE OR REPLACE FUNCTION public.get_expected_qoh(
	agentid integer,
	productid integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

        
Declare 
		_expected_qoh       	NUMERIC(12,2);
		_warehouse_id        	INT;
		_fulfillment_id      	INT;

BEGIN
	IF agentid = 0 THEN
		_warehouse_id = 1;
	ELSE
		SELECT warehouse_id FROM res_partner_data WHERE id = agentid INTO _warehouse_id;
	END IF;

	SELECT get_itemfulfillmentcenter(warehouseid, productid) INTO _fulfillment_id;
	SELECT get_available_qoh(_fulfillment_id, productid) INTO _expected_qoh;

	RETURN _expected_qoh;
END;
        
$function$;

ALTER FUNCTION public.get_expected_qoh(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_expected_qoh(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_expected_qoh(integer, integer) TO odoo;



