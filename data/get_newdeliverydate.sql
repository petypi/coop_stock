-- FUNCTION: public.get_newdeliverydate(integer, date)

-- DROP FUNCTION public.get_newdeliverydate(integer, date);

CREATE OR REPLACE FUNCTION public.get_newdeliverydate(
	orderid integer,
	fromdate date)
    RETURNS date
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
sladays		int;
newdate		date;
dayofweek   varchar(20);

BEGIN
	sladays = 0;
    
	select get_datediff('day',date_order, date_delivery) from sale_order WHERE id = orderid INTO sladays;
	
	newdate =  fromdate;
	
	IF sladays = 1 THEN
		newdate =  fromdate;
	ELSIF sladays = 2 THEN
		newdate =  fromdate + INTERVAL '1 day';
	ELSIF sladays = 3 THEN
		newdate =  fromdate + INTERVAL '2 day';
	ELSIF sladays = 4 THEN
		newdate =  fromdate + INTERVAL '3 day';
	ELSIF sladays = 5 THEN
		newdate =  fromdate + INTERVAL '4 day';
	ELSIF sladays = 6 THEN
		newdate =  fromdate + INTERVAL '5 day';
	ELSIF sladays = 7 THEN
		newdate =  fromdate + INTERVAL '6 day';
	END IF;

	dayofweek = TRIM(to_char(newdate, 'day'));

	IF dayofweek = 'sunday' THEN
		newdate =  newdate + INTERVAL '1 day';
	END IF;
	
	RETURN newdate;
END;

$function$;

ALTER FUNCTION public.get_newdeliverydate(integer, date)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_newdeliverydate(integer, date) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_newdeliverydate(integer, date) TO odoo;




