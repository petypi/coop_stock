-- FUNCTION: public.get_ir_property_integer(character varying, character varying, integer)

-- DROP FUNCTION public.get_ir_property_integer(character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.get_ir_property_integer(
	ir_name character varying,
	ir_res_name character varying,
	ir_res_id integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
		_value   	varchar(250);
        _res_id    	varchar(300);
        _value_type	varchar(200);
        
BEGIN
	_res_id = ir_res_name || ',' || to_char(ir_res_id,'99999999');
	_res_id = replace(_res_id,' ','');
	
	Select value_integer from ir_property
    Where name = ir_name And res_id = _res_id
    LIMIT 1 INTO _value;
    
    IF COALESCE(_value,'')= '' THEN
        Select value_text from ir_property
        Where name = ir_name And res_id is Null
        LIMIT 1 INTO _value;  
    END IF;
    
  
    RETURN CAST( _value AS INTEGER);

END;

$function$;

ALTER FUNCTION public.get_ir_property_integer(character varying, character varying, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_ir_property_integer(character varying, character varying, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_ir_property_integer(character varying, character varying, integer) TO odoo;


