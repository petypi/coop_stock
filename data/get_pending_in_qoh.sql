-- FUNCTION: public.get_pending_in_qoh(integer, integer)

-- DROP FUNCTION public.get_pending_in_qoh(integer, integer);

CREATE OR REPLACE FUNCTION public.get_pending_in_qoh(
	locationid integer,
	productid integer)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE qtyonhand NUMERIC (12, 2) ;
BEGIN
	WITH q_in AS (
		SELECT
			SUM (M .product_qty / u.factor) AS qty,
			M .product_id --, m.product_uom
		FROM
			stock_move M
		JOIN product_uom u ON u. ID = M .product_uom
		WHERE
			location_id NOT IN (
				SELECT
					location_id
				FROM
					get_ChildLocations (locationid)
			)
		AND location_dest_id IN (
			SELECT 				location_id
			FROM
				get_ChildLocations (locationid)
		)
		AND M .product_id = productid
		AND STATE IN ('assigned', 'confirmed') /*Pending QOH */
		-- and state = 'done' /*QOH */
		-- and state in ('done','assigned','confirmed')  /*Forecasted QOH */
		AND picking_id IN (
			SELECT
				ID
			FROM
				stock_picking
			WHERE
				TYPE = 'in'
		)
		GROUP BY
			M .product_id --, m.product_uom
	),
	q_out AS (
		SELECT
			SUM (M .product_qty / u.factor) AS qty,
			M .product_id --, m.product_uom
		FROM
			stock_move M
		JOIN product_uom u ON u. ID = M .product_uom
		WHERE
			location_dest_id NOT IN (
				SELECT
					location_id
				FROM
					get_ChildLocations (locationid)
			)
		AND location_id IN (
			SELECT
				location_id
			FROM
				get_ChildLocations (locationid)
		)
		AND M .product_id = productid
		AND STATE IN ('assigned', 'confirmed') /*Pending QOH */
		-- and state = 'done' /*QOH */
		-- and state in ('done','assigned','confirmed')  /*Forecasted QOH */
		AND picking_id IN (
			SELECT
				ID
			FROM
				stock_picking
			WHERE
				TYPE = 'in'
		)
		GROUP BY
			M .product_id --, m.product_uom
	) SELECT
		COALESCE (i.qty, 0) - COALESCE (o.qty, 0) AS qoh
	FROM
		q_in i
	LEFT JOIN q_out o ON i.product_id = o.product_id --JOIN product_product p on p.id = i.product_id
	-- JOIN product_template t on t.id = p.product_tmpl_id
	-- WHERE p.active = 'true' and t.sale_ok = 'true'
	-- GROUP BY  i.product_id, p.default_code, p.name
	INTO qtyonhand ; 
	
	RETURN COALESCE(qtyonhand,0) ;
	
	END ; 

$function$;

ALTER FUNCTION public.get_pending_in_qoh(integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_pending_in_qoh(integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_pending_in_qoh(integer, integer) TO odoo;



