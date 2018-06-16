-- FUNCTION: public.get_ir_property_value(character varying, character varying, integer, character varying)

-- DROP FUNCTION public.get_ir_property_value(character varying, character varying, integer, character varying);

CREATE OR REPLACE FUNCTION public.get_ir_property_value(
	ir_name character varying,
	ir_res_name character varying,
	ir_res_id integer,
	ir_value_reference character varying)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare _value_reference     varchar(250);
        _res_id              varchar(300);
BEGIN
	_res_id = ir_res_name || ',' || to_char(ir_res_id,'99999999');
	_res_id = replace(_res_id,' ','');
	ir_value_reference = ir_value_reference || ',';
	
	Select value_reference from ir_property
    Where name = ir_name And res_id = _res_id
    LIMIT 1 INTO _value_reference;
    _value_reference = replace(_value_reference,ir_value_reference,'');
    
    IF COALESCE(_value_reference,'')= '' THEN
        Select value_reference from ir_property
        Where name = ir_name And res_id is Null
        LIMIT 1 INTO _value_reference;
        _value_reference = replace(_value_reference,ir_value_reference,'');    
    END IF;


    RETURN CAST( _value_reference AS INT);

END;

$function$;

ALTER FUNCTION public.get_ir_property_value(character varying, character varying, integer, character varying)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_ir_property_value(character varying, character varying, integer, character varying) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_ir_property_value(character varying, character varying, integer, character varying) TO odoo;


