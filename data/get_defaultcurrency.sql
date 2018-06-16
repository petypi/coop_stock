-- FUNCTION: public.get_defaultcurrency(integer)

-- DROP FUNCTION public.get_defaultcurrency(integer);

CREATE OR REPLACE FUNCTION public.get_defaultcurrency(
	_company_id integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
_currency_id	INT;

BEGIN

	Select currency_id from res_company 
    Where id = _company_id INTO _currency_id;   

	RETURN _currency_id;
END; 

$function$;

ALTER FUNCTION public.get_defaultcurrency(integer) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_defaultcurrency(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_defaultcurrency(integer) TO odoo;


