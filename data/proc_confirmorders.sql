-- FUNCTION: public.proc_confirmorders date, boolean

-- DROP FUNCTION public.proc_confirmorders date, boolean;

CREATE OR REPLACE FUNCTION public.proc_confirmorders(
	orderdate date,
	createpr boolean)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE _today		date;
BEGIN	

	_today = current_date;
    _today = (now() at time zone 'Africa/Nairobi')::date;
        
    PERFORM sp_confirmorders(orderDate, 0);	

	IF createpr = true THEN
		PERFORM sp_createpurchaserequisition(orderDate);
	END IF;

END;

$function$;

ALTER FUNCTION public.proc_confirmorders(date, boolean) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.proc_confirmorders(date, boolean) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.proc_confirmorders(date, boolean) TO odoo;


