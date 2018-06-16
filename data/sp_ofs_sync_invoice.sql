-- FUNCTION: public.sp_ofs_sync_invoice(integer, integer, integer)

-- DROP FUNCTION public.sp_ofs_sync_invoice(integer, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_ofs_sync_invoice(
	_picking_int_id integer,
	_warehouse_id integer,
	_receipt_id integer)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100.0
    VOLATILE 
AS $function$

DECLARE
		_receipt_name        varchar(32);
		_account_move_id         INT;
		_period_id               INT;
		_journal_id              INT;
		_order_id           	INT;
		_picking_id              INT;
		_picking_name            varchar(50);
		_origin_name             varchar(50);
		_ordername          varchar(50);
		_invoice_id      INT;
		_sequenceid       INT;
		_sequencename     varchar(50);
		_column_exists       VARCHAR(32);
		_invoice_date            date;
		_delivery_date          date;
		_amount_tax              numeric(12,2);
		_amount_total            numeric(12,2);
		_amount_untaxed          numeric(12,2);
		_commission_payable 	numeric(12,2);
		_loyalty_program_id     INT;
		_loyalty_period_id       INT;
		_loyalty_name            varchar(250);
		_loyalty_amount          numeric(12,2);
		_loyalty_coeff           numeric(12,2);
		_sale_user_id           INT;
		_now                    date;
		_user_id                INT;
		_cust_partner_id        INT;
		_partner_id      		INT;
		_company_id             INT;
		_currency_id			INT;
		_netamount              numeric(12,2);
		_redemvalue             numeric(12,2);
		_redem_account_id       INT;
		_sale_account_id        INT;
		_islayaway              boolean;
		_receivable_ac          INT;
		_items					INT;
        _fullyinvoiced			BOOLEAN;

BEGIN

	_now = now();
	Select user_id, receipt_ref, COALESCE(date_delivery,date), order_id from ofs_delivery
	WHERE warehouse_id = _warehouse_id and ofs_receipt_id = _receipt_id limit 1
	INTO _user_id, _receipt_name, _delivery_date, _order_id;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='account_invoice' and column_name='ofs_id';
	IF _column_exists IS NULL THEN
	ALTER TABLE account_invoice ADD COLUMN  ofs_id int DEFAULT NULL;
	END IF;

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='account_invoice' and column_name='ofs_receipt_id';
	IF _column_exists IS NULL THEN
	ALTER TABLE account_invoice ADD COLUMN  ofs_receipt_id int DEFAULT NULL;
	END IF;
    
    _column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='stock_picking' and column_name='invoiced';
	IF _column_exists IS NULL THEN
	ALTER TABLE stock_picking ADD COLUMN  invoiced boolean DEFAULT false;
	END IF;
    

    

	_column_exists = null;
	SELECT column_name INTO _column_exists
	FROM information_schema.columns
	WHERE table_name='account_invoice_line' and column_name='order_line_id';
	IF _column_exists IS NULL THEN
	ALTER TABLE account_invoice_line ADD COLUMN  order_line_id int DEFAULT NULL;
	END IF;
    
	_items = 0;
	Select count(id) FROM account_invoice Where ofs_id = _warehouse_id 
    and ofs_receipt_id = _receipt_id And state <> 'cancel' Into _items ;
	IF _items > 0 THEN
		return;
	END IF;

	select name from sale_order where id = _order_id limit 1 INTO _ordername;
	_origin_name = _picking_name || ':' || _ordername;

	DROP TABLE IF EXISTS temp_saleorders_lines;
	CREATE TEMP TABLE temp_saleorders_lines
	(
		order_line_id           INT,
		product_id              INT,
		product_name            VARCHAR(150),
		order_partner_id        INT,
		order_id                INT,
		order_name              VARCHAR(50),
		price_unit              numeric(10,2),
		price_subtotal          numeric(10,2),
		quantity                INT,
		product_uom             INT,
		product_uom_qty         INT,
		commission_tier_id      INT,
		amount_line_commission  numeric(10,2),
		product_tmpl_id         INT,
		percentage_commission   numeric(10,2),
		tax_amount_payable      numeric(10,2),
		categ_id                INT,
		account_id              INT,
        agent_type_id			INT
	)
	ON COMMIT DROP;
		

	INSERT INTO temp_saleorders_lines
		(order_line_id, product_id, product_name, order_partner_id, 
         order_id,price_unit, product_uom, quantity)
	SELECT sale_order_line.id, sale_order_line.product_id, sale_order_line.name,
		order_partner_id, order_id,price_unit,product_uom, 0 as quantity
	FROM sale_order_line
	INNER JOIN product_product ON
		sale_order_line.product_id = product_product."id"
	INNER JOIN product_template ON
		product_product.product_tmpl_id = product_template."id"
	WHERE order_id  = _order_id
	ORDER BY id DESC;

	Update temp_saleorders_lines SET
		order_name = sale_order.name
	From sale_order
	Where sale_order.id = temp_saleorders_lines.order_id;

	Update temp_saleorders_lines SET
		product_tmpl_id = product_product.product_tmpl_id
	From product_product
	Where product_product.id = temp_saleorders_lines.product_id;

	Update temp_saleorders_lines SET
		agent_type_id = res_partner.agent_type_id
	From res_partner
	Where res_partner.id = temp_saleorders_lines.order_partner_id;
    
	Update temp_saleorders_lines SET
		commission_tier_id = product_template.commissiontier_id,
		categ_id = product_template.categ_id
	From product_template
	Where product_template.id = temp_saleorders_lines.product_tmpl_id;
    
/*
	Update temp_saleorders_lines SET
		percentage_commission = product_tier.percentage_commission
	From product_tier
	Where product_tier.id = temp_saleorders_lines.commission_tier_id;
*/

	Update temp_saleorders_lines SET quantity = product_qty
	FROM stock_move
	Where stock_move.product_id = temp_saleorders_lines.product_id
	And stock_move.order_line_id = temp_saleorders_lines.order_line_id
	And stock_move.picking_id = _picking_int_id;

	DELETE FROM temp_saleorders_lines WHERE quantity = 0;
	---- Update temp_saleorders_lines SET account_id = get_ir_property_value ('property_account_receivable_id','res.partner',order_partner_id,'account.account');

	DROP TABLE IF EXISTS temp_product_taxes;
	CREATE TEMP TABLE temp_product_taxes
	(
		product_id              INT,
		tax_id                  INT,
		name                   VARCHAR(64),
		price_unit              money,
		quantity                INT,
		price_include           boolean,
		include_base_amount     boolean,
		type                    varchar(20),
		tax_amount              numeric(12,6),
		ttl_tax_amount          numeric(12,6),
		tax_account_id          INT,
		tax_amount_payable      numeric(12,2)
	)
	ON COMMIT DROP;
		
	Insert Into temp_product_taxes (product_id, tax_id)
	Select prod_id, tax_id from product_taxes_rel Where prod_id in (Select product_tmpl_id from temp_saleorders_lines);
	-- Select prod_id, tax_id from product_taxes_rel Where prod_id in (Select product_id from temp_saleorders_lines);
	
	Update temp_product_taxes SET
	price_unit = temp_saleorders_lines.price_unit,
	quantity = temp_saleorders_lines.quantity
	FROM temp_saleorders_lines
	Where 
		temp_saleorders_lines.product_tmpl_id = temp_product_taxes.product_id;
		-- temp_saleorders_lines.product_id = temp_product_taxes.product_id;

	Update temp_product_taxes SET
	name = account_tax.name  ,
	price_include = account_tax.price_include,
	type = account_tax.amount_type,
	tax_amount = account_tax.amount ,
	-- tax_code_id = account_tax.tax_code_id,
	tax_account_id = account_tax.account_id ,
	include_base_amount = account_tax.include_base_amount
	FROM account_tax
	Where account_tax.id = temp_product_taxes.tax_id
	And account_tax.Active = 'true';

	DROP TABLE IF EXISTS temp_product_taxes_total;
	CREATE TEMP TABLE temp_product_taxes_total
	(
		product_id              INT,
		total_tax_amount        numeric(12,6)
	)
	ON COMMIT DROP;
	
	Insert Into temp_product_taxes_total (product_id, total_tax_amount)
	Select product_id, sum(tax_amount) From temp_product_taxes Group By product_id;

	Update temp_product_taxes SET
		ttl_tax_amount = total_tax_amount
	FROM temp_product_taxes_total
	WHERE 
		temp_product_taxes_total.product_id = temp_product_taxes.product_id;

	UPDATE temp_product_taxes SET
	tax_amount_payable = get_taxamount(price_unit, quantity, tax_amount, ttl_tax_amount, type, price_include, include_base_amount);

-- ----RETURN QUERY select * from temp_product_taxes;
-- ----RETURN   ;
	DROP TABLE IF EXISTS temp_product_taxes_payable;
	CREATE TEMP TABLE temp_product_taxes_payable
	(
		product_id              INT,
		tax_amount              numeric(12,6)
	)
	ON COMMIT DROP;

	Insert Into temp_product_taxes_payable (product_id, tax_amount)
	Select product_id, sum(tax_amount_payable) From temp_product_taxes Group By product_id;

	Update temp_saleorders_lines SET
	tax_amount_payable = tax_amount
	FROM temp_product_taxes_payable
	WHERE 
		temp_product_taxes_payable.product_id = temp_saleorders_lines.product_tmpl_id;
		-- temp_product_taxes_payable.product_id = temp_saleorders_lines.product_id;	
	
	

	Update temp_saleorders_lines SET tax_amount_payable = COALESCE(tax_amount_payable,0);
	Update temp_saleorders_lines SET price_subtotal = (price_unit * quantity) - COALESCE(tax_amount_payable,0);

	Update temp_saleorders_lines SET amount_line_commission = ( price_subtotal * COALESCE(percentage_commission,0))/ 100;

	Select Sum( price_unit * quantity) , Sum(amount_line_commission), Sum(price_subtotal)
	from temp_saleorders_lines
	INTO _amount_total, _commission_payable, _amount_untaxed;
	_amount_tax = _amount_total - _amount_untaxed;

	DROP TABLE IF EXISTS temp_saleorders;
	CREATE LOCAL TEMP TABLE temp_saleorders
	(
		id						INT,
		salesordername          VARCHAR(30),
		cust_partner_id              INT,
		partner_id       INT,
		company_id              INT,
		experiment_id           INT,
		is_layaway              boolean,
		shop_id                 INT,
		route_id                INT,
		total_amount            money,
		loyalty_program_id      INT,
		loyalty_amount_used		money,
		delivery_date           date,
		sale_user_id            INT,
		team_id					INT
	)
	ON COMMIT DROP;

	INSERT INTO temp_saleorders
	(id, salesOrderName, cust_partner_id, partner_id, team_id, -- loyalty_program_id,  
	company_id, is_layaway, delivery_date, sale_user_id)
	SELECT id, name, customer_id, partner_id, team_id, -- loyalty_program_id, 
	company_id, islayaway, date_delivery, user_id
	FROM sale_order 
	WHERE sale_order.id = _order_id;

	Update temp_saleorders set route_id = res_partner.route_id
	From res_partner
	Where res_partner.id = temp_saleorders.partner_id;
/*
	Update temp_saleorders set loyalty_amount_used = ofs_delivery.credit_used
	From ofs_delivery
	Where temp_saleorders.id = ofs_delivery.order_id;
*/

	select cust_partner_id, partner_id, company_id, loyalty_program_id , loyalty_amount_used, is_layaway, delivery_date, sale_user_id
	FROM temp_saleorders
	INTO _cust_partner_id, _partner_id, _company_id, _loyalty_program_id, _loyalty_amount, _islayaway, _invoice_date, _sale_user_id;
	
	_currency_id = get_defaultcurrency(_company_id);
	_invoice_date = COALESCE(_delivery_date,_invoice_date);
	_loyalty_amount = COALESCE(_loyalty_amount,0);	

	Select get_ir_property_value ('property_account_receivable_id','res.partner',_partner_id,'account.account') INTO _receivable_ac;
	Select default_debit_account_id from account_journal Where Code = 'INV' LIMIT 1 INTO _sale_account_id;
	Select default_debit_account_id from account_journal Where Code = 'LPJ' LIMIT 1 INTO _redem_account_id;
	_redemvalue = 0;
	_netamount = _amount_total;

	Update temp_saleorders_lines SET account_id = _receivable_ac;

/*Start of Copia Credit - Copia Pesa Redemption*/    

/*    
	IF _loyalty_program_id IS NOT NULL THEN
		SELECT redeem_period_id, name,amount, coeff from get_loyalty_redemption_details(_cust_partner_id,_loyalty_program_id,_loyalty_amount)
		INTO _loyalty_period_id, _loyalty_name, _loyalty_amount, _loyalty_coeff;		
		--RAISE NOTICE 'Calling 1 (%) (%) (%) ', _redemvalue, _loyalty_amount, _netamount;
		_redemvalue = ABS(_loyalty_amount);
		_netamount = _amount_total - _redemvalue;		
		IF _netamount < 0 THEN
			_redemvalue = amount_total;
			_netamount = 0;				
		END IF;		
		RAISE NOTICE 'Copia Credit Redemption Details (%) (%) (%) ', _redemvalue, loyalty_amount, _netamount;
		--return;		
		IF _redemvalue > 0 THEN
			Insert Into loyalty_program_line
			(create_uid,create_date,write_date,write_uid,
			loyalty_program_id,description,type,state,
			point_coeff_used,amount_points,cust_partner_id,name)
			Select _user_id create_uid,now() create_date,now() write_date,_user_id write_uid,
			_loyalty_program_id, origin_name, 'r','done',
			_loyalty_coeff, _loyalty_amount, _cust_partner_id, _loyalty_name;
		END IF;
	END IF;
*/
/*Start of Copia Credit - Copia Pesa Redemption*/ 

-- RETURN QUERY select * from temp_saleorders_lines;
-- RETURN ;

/*Start of Invoicing*/ 
	SELECT * FROM get_NextSequence(8) INTO _sequenceid, _sequencename;
	Insert Into account_invoice
        (create_uid,create_date,write_date,write_uid,origin, 
        date_due,  reference,  number, account_id,
        company_id, currency_id, partner_id,   user_id, partner_bank_id,
        reference_type, journal_id, amount_tax,state, type,
        reconciled,residual,move_name,date_invoice,amount_untaxed, move_id,
        amount_total,name,sent,commercial_partner_id,
        ofs_id, ofs_receipt_id, receipt_ref, 
        amount_total_company_signed, residual_signed, team_id, amount_commission)
	Select _user_id create_uid,_now create_date,_now write_date,_user_id  write_uid, _origin_name origin, 
		_invoice_date as date_due,  null reference,  _sequencename as number, _receivable_ac account_id,
		_company_id company_id, _currency_id as currency_id, _partner_id as partner_id, _user_id as user_id, null partner_bank_id,
		'none' reference_type, 1 journal_id, _amount_tax, 'open' as state, 'out_invoice'as type,
		'false' as reconciled,_netamount as residual,'/' as move_name,_invoice_date as date_invoice,_amount_untaxed, null as move_id,
		_amount_total, '' as name, 'false' sent,_partner_id commercial_partner_id,
		_warehouse_id as ofs_id, _receipt_id as ofs_receipt_id, _receipt_name as receipt_ref, 
		_netamount as amount_total_company_signed, 	_netamount residual_signed, team_id, 0 as amount_commission
	FROM temp_saleorders
	RETURNING id INTO _invoice_id;

	Insert Into account_invoice_line
        (create_uid,create_date,write_date,write_uid,origin,
        uom_id, account_id,name,invoice_id,price_unit,price_subtotal,
        company_id,discount,quantity,partner_id,product_id,
        currency_id, sequence, price_subtotal_signed, order_line_id,
        layout_category_sequence, commission, commission_subtotal)
	SELECT _user_id create_uid,_now create_date,_now write_date,_user_id write_uid,_origin_name as origin,
        product_uom as uom_id, _sale_account_id as account_id,product_name as name,_invoice_id as invoice_id,price_unit,price_subtotal,
        _company_id as company_id,0 discount,quantity,_partner_id as partner_id,product_id,
        _currency_id as currency_id, 10 as sequence, price_subtotal as price_subtotal_signed, order_line_id,
        0 layout_category_sequence, 0 commission, 0 commission_subtotal
	FROM temp_saleorders_lines
    UNION ALL
	SELECT _user_id create_uid,_now create_date,_now write_date,_user_id write_uid,_origin_name as origin,
        null uom_id, _redem_account_id account_id,_loyalty_name as name, _invoice_id as invoice_id, _redemvalue price_unit,_redemvalue price_subtotal,
        _company_id as company_id,0 discount,1 quantity,_partner_id as partner_id,null product_id,
        _currency_id as currency_id, 10 as sequence, _redemvalue as price_subtotal_signed, null order_line_id,
        0 layout_category_sequence, 0 commission, 0 commission_subtotal
	WHERE _redemvalue > 0;
    
	INSERT INTO account_invoice_line_tax (invoice_line_id, tax_id)    
	SELECT account_invoice_line.id, tax_id
	from account_invoice_line
	Join temp_product_taxes ON temp_product_taxes.product_id = account_invoice_line.product_id
	where account_invoice_line.invoice_id = _invoice_id;
    
    Insert INTO sale_order_line_invoice_rel (invoice_line_id, order_line_id) 
    Select id, order_line_id from account_invoice_line Where invoice_id = _invoice_id;

	Insert Into account_invoice_tax
        (create_uid, create_date, write_date, write_uid, 
        account_id, sequence, manual, company_id,
        currency_id, amount, tax_id, name)
     Select _user_id create_uid,_now create_date,_now write_date,_user_id write_uid,
        tax_account_id as account_id, 1 as sequence, 'false' manual,_company_id company_id,
        _currency_id currency_id, tax_amount_payable as amount, tax_id, name
     From temp_product_taxes Where tax_amount_payable > 0;   
/* End of Invoicing*/ 

	

/*Start of Account Move*/ 
	Insert Into account_move	
		(create_uid, create_date, write_date, write_uid, date, name, 
		state, ref, company_id,  journal_id, currency_id, amount, 
		matched_percentage, narration,  partner_id, statement_line_id)
	Select _user_id create_uid, _now create_date, _now write_date,_user_id write_uid, _invoice_date as date, _sequencename as name,
		'posted' state,replace(_sequencename,'/','') as ref, _company_id,1 as journal_id, _currency_id as Currency_id, 0 as amount,
		0 as matched_percentage, _origin_name as narration, _partner_id, null as statement_line_id
	RETURNING id INTO _account_move_id;
    
    Update account_invoice SET move_id = _account_move_id Where id = _invoice_id;

    Insert Into account_move_line
		(create_uid, create_date, write_date, write_uid, date, 
		journal_id, date_maturity, user_type_id, partner_id, blocked, 
		company_id, ref, account_id, move_id, product_id, 
		name, reconciled, tax_exigible, product_uom_id, quantity,		
		credit, credit_cash_basis, 	debit,  debit_cash_basis, 
		balance_cash_basis, balance, amount_residual, amount_residual_currency,		
		invoice_id, tax_line_id, amount_currency)
	Select _user_id create_uid,now() create_date,now() write_date,_user_id write_uid, _invoice_date as date,
		1 as journal_id,_invoice_date date_maturity, get_account_usertypeid(_sale_account_id) as user_type_id, _partner_id as partner_id, false as blocked,
		_company_id as company_id, _picking_name as ref, _sale_account_id as account_id, _account_move_id as move_id, product_id, 
		left(product_name,64) as name, false as reconciled, true as tax_exigible, product_uom as product_uom_id, quantity,
		price_subtotal as credit, 0 as credit_cash_basis, 0 as debit, 0 as debit_cash_basis,
		0 as balance_cash_basis, price_subtotal * -1 as balance , 0 as amount_residual, 0 as amount_residual_currency,
		_invoice_id as invoice_id, null tax_line_id , 0 as amount_currency
	FROM temp_saleorders_lines
	UNION ALL
	Select _user_id create_uid,now() create_date,now() write_date,_user_id write_uid, _invoice_date as date,
		1 as journal_id,_invoice_date date_maturity, get_account_usertypeid(tax_account_id) as  user_type_id, _partner_id as partner_id, false as blocked,
		_company_id as company_id, _picking_name as ref, tax_account_id as account_id, _account_move_id as move_id, null product_id, 
		temp_product_taxes.name as name, false as reconciled, true as tax_exigible, null product_uom_id, 1 as quantity,
		tax_amount_payable as credit, 0 as credit_cash_basis, 0 as debit, 0 as debit_cash_basis,
		0 as balance_cash_basis, tax_amount_payable * -1 as balance , 0 as amount_residual, 0 as amount_residual_currency,
		_invoice_id as invoice_id, tax_id as tax_line_id , 0 as amount_currency
	From temp_product_taxes Where tax_amount_payable > 0
	UNION ALL
	Select _user_id create_uid,now() create_date,now() write_date,_user_id write_uid, _invoice_date as date,
		1 as journal_id,_invoice_date date_maturity, get_account_usertypeid(_redem_account_id) as  user_type_id, _partner_id as partner_id, false as blocked,
		_company_id as company_id, _picking_name as ref, _redem_account_id as account_id, _account_move_id as move_id, null product_id, 
		'Copia Pesa Redemption - ' || _origin_name as name, false as reconciled, true as tax_exigible, null product_uom_id, 1 as quantity,
		0 as credit, 0 as credit_cash_basis, _redemvalue as debit, 0 as debit_cash_basis,
		0 as balance_cash_basis, _redemvalue  as balance , 0 as amount_residual, 0 as amount_residual_currency,
		null as invoice_id, null as tax_line_id , 0 as amount_currency
	Where _redemvalue > 0	
	UNION ALL
	Select _user_id create_uid,now() create_date,now() write_date,_user_id write_uid, _invoice_date as date,
		1 as journal_id,_invoice_date date_maturity, get_account_usertypeid(_receivable_ac) as  user_type_id, _partner_id as partner_id, false as blocked,
		_company_id as company_id, _picking_name as ref, _receivable_ac as account_id, _account_move_id as move_id, null product_id, 
		'/' as name, false as reconciled, true as tax_exigible, null product_uom_id, 1 as quantity,
		0 as credit, 0 as credit_cash_basis, _netamount as debit, 0 as debit_cash_basis,
		0 as balance_cash_basis, _netamount  as balance , 0 as amount_residual, 0 as amount_residual_currency,
		null as invoice_id, null as tax_line_id , 0 as amount_currency
	Where _netamount > 0;
/*End of Account Move*/ 	

/*
	SELECT  get_isfullyinvoiced(_order_id) INTO _fullyinvoiced;        
	IF _fullyinvoiced = true THEN
		Update sale_order set shipped = true, state = 'done' where id = _order_id ;
	END IF;
select * from sale_order;
select * from stock_picking;
*/

	Update stock_picking set invoiced = true where id = _picking_int_id ;
	Update ofs_delivery Set invoice_id = _invoice_id
	Where warehouse_id = _warehouse_id and ofs_receiptid = _receipt_id
		and  picking_int_id = _picking_int_id ;
END;

$function$;

ALTER FUNCTION public.sp_ofs_sync_invoice(integer, integer, integer)
    OWNER TO odoo;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync_invoice(integer, integer, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_ofs_sync_invoice(integer, integer, integer) TO odoo;


