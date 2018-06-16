-- FUNCTION: public.get_qty_on_hand(integer, character varying)

-- DROP FUNCTION public.get_qty_on_hand(integer, character varying);

CREATE OR REPLACE FUNCTION public.get_qty_on_hand(
	locationid integer,
	product_code character varying)
    RETURNS TABLE(product_id integer, defaultcode character varying, product_name character varying, qty_on_hand numeric, qty_in numeric, qty_out numeric)
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
    ROWS 1000.0
AS $function$

Declare 

_productid 	INT;

BEGIN

select id from product_product where default_code = product_code And active = 't' Into _productid LIMIT 1;

RETURN QUERY

with 
q_in as (
    select sum(m.product_qty/u.factor) as qty, m.product_id, m.product_uom
    from stock_move m
    join product_uom u on u.id = m.product_uom
    where location_id not in (select location_id FROM get_childlocations(locationid))
		and location_dest_id in (select location_id FROM get_childlocations(locationid))
    and m.product_id = _productid
    and state = 'done'
    group by m.product_id, m.product_uom
),
q_out as (
    select sum(m.product_qty/u.factor) as qty, m.product_id, m.product_uom
    from stock_move m
    join product_uom u on u.id = m.product_uom
    where location_dest_id not in (select location_id FROM get_childlocations(locationid))
    and location_id in (select location_id FROM get_childlocations(locationid))
    and m.product_id = _productid
    and state = 'done'
    group by m.product_id, m.product_uom
)

SELECT  i.product_id, p.default_code, p.name, sum(i.qty - o.qty) as qoh , sum(i.qty) as qty_in , sum(o.qty) as qty_out
FROM
    q_in i 
JOIN q_out o on i.product_id = o.product_id
JOIN product_product p on p.id = i.product_id
GROUP BY  i.product_id, p.default_code, p.name
ORDER BY p.default_code asc;

END; 

$function$;

ALTER FUNCTION public.get_qty_on_hand(integer, character varying)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_qty_on_hand(integer, character varying) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_qty_on_hand(integer, character varying) TO odoo;



