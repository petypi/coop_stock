-- FUNCTION: public.get_ir_property_float(character varying, character varying, integer)

-- DROP FUNCTION public.get_ir_property_float(character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.get_ir_property_float(
	ir_name character varying,
	ir_res_name character varying,
	ir_res_id integer)
    RETURNS float
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
	
	Select value_float from ir_property
    Where name = ir_name And res_id = _res_id
    LIMIT 1 INTO _value;
    
    IF COALESCE(_value,'')= '' THEN
        Select value_text from ir_property
        Where name = ir_name And res_id is Null
        LIMIT 1 INTO _value;  
    END IF;
  
    RETURN CAST( _value AS FLOAT);

END;

$function$;

ALTER FUNCTION public.get_ir_property_float(character varying, character varying, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_ir_property_float(character varying, character varying, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_ir_property_float(character varying, character varying, integer) TO odoo;


