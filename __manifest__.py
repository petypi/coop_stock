# -*- coding: utf-8 -*-
{
    "name": "Copia Stock Customisations",

    "summary": """
        Stock, Warehouse, Inventory etc
		""",

    "description": """
Customisations for the following:
* Parent warehouse.
* Allows for selection of products that can be stocked in the location
""",
    "author": "Cyrus Waithaka",
    "website": "http://www.copiakenya.com",
    "category": "Warehouse",
    "version": "0.1",
    "depends": ["base","stock", "copia_product" ,"copia_accounting","account_reports"
     ],
    "data": [
        "views/warehouse_matrix.xml",
        "data/scheduler_data.xml",
        "views/product_stock_per_location_view.xml"
        # "data/get_account_usertypeid.sql",
        # "data/get_available_qoh.sql",
        # "data/get_availableqoh.sql",
        # "data/get_childlocations.sql",
        # "data/get_client_vendor.sql",
        # "data/get_datediff.sql",
        # "data/get_defaultcurrency.sql",
        # "data/get_expected_qoh.sql",
        # "data/get_ir_property_datetime.sql",
        # "data/get_ir_property_float.sql",
        # "data/get_ir_property_integer.sql",
        # "data/get_ir_property_text.sql",
        # "data/get_ir_property_value.sql",
        # "data/get_isfullyinvoiced.sql",
        # "data/get_itemfulfillmentcenter.sql",
        # "data/get_itemlocationid.sql",
        # "data/get_locationid.sql",
        # "data/get_newdeliverydate.sql",
        # "data/get_nextsequence.sql",
        # "data/get_orderprepayment.sql",
        # "data/get_pending_in_qoh.sql",
        # "data/get_pendingout_qty.sql",
        # "data/get_pickingtypeid.sql",
        # "data/get_previousagentorders.sql",
        # "data/get_previouscustomerorders.sql",
        # "data/get_qty_on_hand.sql",
        # "data/get_qtyonhand.sql",
        # "data/get_taxamount.sql",
        # "data/proc_confirmorders.sql",
        # "data/sp_confirmorders.sql",
        # "data/sp_createpurchaserequisition.sql",
        # "data/sp_ofs_sync_cancel_orders.sql",
        # "data/sp_ofs_sync_cancel_receipts.sql",
        # "data/sp_ofs_sync_invoice.sql",
        # "data/sp_ofs_sync_kitting.sql",
        # "data/sp_ofs_sync.sql"
    ],
    "demo": [
    ],
}
