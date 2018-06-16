-- FUNCTION: public.get_isfullyinvoiced(integer)

-- DROP FUNCTION public.get_isfullyinvoiced(integer);

CREATE OR REPLACE FUNCTION public.get_isfullyinvoiced(
	_orderid integer)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
	_return			boolean;
    _items_ordered	INT;
    _items_invoiced	INT;

BEGIN
	_return = true;
	Select Sum(product_uom_qty) from sale_order_line Where order_id = _orderid And state <> 'cancel' 
    INTO _items_ordered;
    
    Select sum(quantity) from account_invoice_line 
    Where order_line_id in (Select id from sale_order_line Where order_id = _orderid) 
    INTO _items_invoiced;
    
    IF _items_ordered > _items_invoiced THEN
    	_return = false;
    END IF;
                                                                        
	RETURN _return;
END;

$function$;

ALTER FUNCTION public.get_isfullyinvoiced(integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_isfullyinvoiced(integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_isfullyinvoiced(integer) TO odoo;


