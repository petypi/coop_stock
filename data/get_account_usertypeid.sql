-- FUNCTION: public.get_account_usertypeid(integer)

-- DROP FUNCTION public.get_account_usertypeid(integer);

CREATE OR REPLACE FUNCTION public.get_account_usertypeid(
	_account_id integer)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
_usertypeid	INT;

BEGIN

	Select user_type_id from account_account 
    Where id = _account_id INTO _usertypeid;   

	RETURN _usertypeid;
END; 

$function$;

ALTER FUNCTION public.get_account_usertypeid(integer) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_account_usertypeid(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_account_usertypeid(integer) TO odoo;


