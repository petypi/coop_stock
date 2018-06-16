-- FUNCTION: public.get_pickingtypeid integer, character varying, integer, integer

-- DROP FUNCTION public.get_pickingtypeid (integer, character varying, integer, integer);


CREATE OR REPLACE FUNCTION public.get_pickingtypeid(
	_warehouse_id 	int,
	_pickingtype 	character varying,
    _source_id		int,
    _destination_id	int
)
    RETURNS integer
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

Declare 
_picking_type_id	INT;

BEGIN

	Select id from stock_picking_type 
    Where active = true 
        And warehouse_id = _warehouse_id
        And Code = _pickingtype
        And COALESCE(default_location_src_id,_source_id) = _source_id 
        And COALESCE(default_location_dest_id,_destination_id) = _destination_id
    INTO _picking_type_id;   


	RETURN _picking_type_id;
END; 

$function$;

ALTER FUNCTION public.get_pickingtypeid(integer, character varying, integer, integer) OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.get_pickingtypeid(integer, character varying, integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_pickingtypeid(integer, character varying, integer, integer) TO odoo;


   




