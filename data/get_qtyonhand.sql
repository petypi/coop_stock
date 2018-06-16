-- FUNCTION: public.get_qtyonhand(integer, integer)

-- DROP FUNCTION public.get_qtyonhand(integer, integer);

CREATE OR REPLACE FUNCTION public.get_qtyonhand(
	locationid integer,
	productid integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
qtyonhand					NUMERIC(12,2);

BEGIN

with 
q_in as (
    select sum(m.product_qty/u.factor) as qty, m.product_id--, m.product_uom
    from stock_move m
    join product_uom u on u.id = m.product_uom
    where location_id not in (select location_id FROM get_childlocations(locationid))
		and location_dest_id in (select location_id FROM get_childlocations(locationid))
    and m.product_id = productid
    and state = 'done' /*QOH */
    -- and state in ('done','assigned','confirmed')  /*Forecasted QOH */
    group by m.product_id--, m.product_uom
),
q_out as (
    select sum(m.product_qty/u.factor) as qty, m.product_id--, m.product_uom
    from stock_move m
    join product_uom u on u.id = m.product_uom
    where location_dest_id not in  (select location_id FROM get_childlocations(locationid))
    and location_id in  (select location_id FROM get_childlocations(locationid))
    and m.product_id = productid
    and state = 'done' /*QOH */
    -- and state in ('done','assigned','confirmed')  /*Forecasted QOH */
    group by m.product_id--, m.product_uom
)
SELECT  COALESCE(i.qty,0) - COALESCE(o.qty,0) as qoh
FROM
    q_in i 
LEFT JOIN q_out o on i.product_id = o.product_id
--JOIN product_product p on p.id = i.product_id
--JOIN product_template t on t.id = p.product_tmpl_id
--WHERE p.active = 'true' and t.sale_ok = 'true'
--GROUP BY  i.product_id, p.default_code, p.name
INTO qtyonhand;

RETURN COALESCE(qtyonhand,0);

END;

$function$;

ALTER FUNCTION public.get_qtyonhand(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_qtyonhand(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_qtyonhand(integer, integer) TO odoo;


