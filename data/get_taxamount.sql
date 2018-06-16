-- FUNCTION: public.get_taxamount(money, integer, numeric, numeric, character varying, boolean, boolean)

-- DROP FUNCTION public.get_taxamount(money, integer, numeric, numeric, character varying, boolean, boolean);

CREATE OR REPLACE FUNCTION public.get_taxamount(
	unit_price money,
	quantity integer,
	ac_tax_amount numeric,
	ac_ttl_tax_amount numeric,
	ac_tax_type character varying,
	ac_tax_price_include boolean,
	ac_include_base_amount boolean)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare tax_amount		Numeric(12,2);
		total_amount	Numeric(12,2);
BEGIN

/*	----To be done Later when required
	if ac_include_base_amount = 'true' THEN
    BEGIN  

    END;
*/

	total_amount = unit_price * quantity;   

	IF ac_tax_type = 'percent' THEN
    	tax_amount = (total_amount/ (1 + ac_ttl_tax_amount)) * ac_tax_amount;
    ELSIF ac_tax_type = 'fixed' THEN
    	tax_amount = ac_tax_amount * quantity;
 /*	
 	----To be done Later when required
    ELSIF ac_tax_type = 'code' THEN 
    ELSIF ac_tax_type = 'balance' THEN
*/    
    END IF;    

	RETURN tax_amount;

END;

$function$;

ALTER FUNCTION public.get_taxamount(money, integer, numeric, numeric, character varying, boolean, boolean) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_taxamount(money, integer, numeric, numeric, character varying, boolean, boolean) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_taxamount(money, integer, numeric, numeric, character varying, boolean, boolean) TO odoo;


