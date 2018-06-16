-- FUNCTION: public.get_datediff(character varying, timestamp without time zone, timestamp without time zone)

-- DROP FUNCTION public.get_datediff(character varying, timestamp without time zone, timestamp without time zone);

CREATE OR REPLACE FUNCTION public.get_datediff(
	units character varying,
	start_t timestamp without time zone,
	end_t timestamp without time zone)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

   DECLARE
     diff_interval INTERVAL; 
     diff INT = 0;
     years_diff INT = 0;
   BEGIN
     IF units IN ('yy', 'yyyy', 'year', 'mm', 'm', 'month') THEN
       years_diff = DATE_PART('year', end_t) - DATE_PART('year', start_t);
 
       IF units IN ('yy', 'yyyy', 'year') THEN
         -- SQL Server does not count full years passed (only difference between year parts)
         RETURN years_diff;
       ELSE
         -- If end month is less than start month it will subtracted
         RETURN years_diff * 12 + (DATE_PART('month', end_t) - DATE_PART('month', start_t)); 
       END IF;
     END IF;
 
     -- Minus operator returns interval 'DDD days HH:MI:SS'  
     diff_interval = end_t - start_t;
 
     diff = diff + DATE_PART('day', diff_interval);
 
     IF units IN ('wk', 'ww', 'week') THEN
       diff = diff/7;
       RETURN diff;
     END IF;
 
     IF units IN ('dd', 'd', 'day') THEN
       RETURN diff;
     END IF;
 
     diff = diff * 24 + DATE_PART('hour', diff_interval); 
 
     IF units IN ('hh', 'hour') THEN
        RETURN diff;
     END IF;
 
     diff = diff * 60 + DATE_PART('minute', diff_interval);
 
     IF units IN ('mi', 'n', 'minute') THEN
        RETURN diff;
     END IF;
 
     diff = diff * 60 + DATE_PART('second', diff_interval);
 
     RETURN diff;
   END;
   
$function$;

ALTER FUNCTION public.get_datediff(character varying, timestamp without time zone, timestamp without time zone)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_datediff(character varying, timestamp without time zone, timestamp without time zone) TO public;
GRANT EXECUTE ON FUNCTION public.get_datediff(character varying, timestamp without time zone, timestamp without time zone) TO odoo;



