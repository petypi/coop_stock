from itertools import groupby
from odoo import models, _


class ProductStockperLocationReport(models.AbstractModel):
    _name = "product.stock.per.location.report"
    _description = "Stock in Multiple Locations per Product Report"
    _inherit = "account.report"

    filter_date = {"date_from": "", "date_to": "", "filter": "this_month"}
    filter_unfold_all = False

    def set_context(self, options):
        ctx = super(ProductStockperLocationReport, self).set_context(options)
        ctx['strict_range'] = True
        return ctx

    def get_report_name(self):
        return _("Stock in Multiple Locations per Product Report")

    def get_templates(self):
        templates = super(ProductStockperLocationReport, self).get_templates()
        templates["line_template"] = "copia_stock.line_template_product_stock_per_location_report"
        templates["main_template"] = "copia_stock.template_product_stock_per_location_report"
        return templates

    def get_columns_name(self, options):
        return [
            {},
            {"name": _("Product_name")},
            {"name": _("Location")},
            {"name": _("Quantity"), "class": "number"},
        ]

    def _get_query(self, options, line_id=None):
        result = []
        if line_id is None:
            _p_query = ""
        else:
            _p_query = "AND p.id = {}".format(line_id.replace("product_", ""))

        _query = """
            WITH qoh AS (
                SELECT 
                    product_id, location_id, SUM(quantity)
                FROM stock_quant
                GROUP BY product_id, location_id
            )
            
            SELECT
                p.id "product_id",
                p.default_code || ' - ' || t.name "product_name",
                l.id "location_id",
                l.complete_name "location",
                COALESCE(qoh.sum, 0) "qty"
            FROM product_product p
            JOIN product_template t ON t.id = p.product_tmpl_id
            LEFT JOIN qoh ON qoh.product_id = p.id
            JOIN stock_location l ON l.id = qoh.location_id
            WHERE l.usage = 'internal' {}
            ORDER BY p.id ASC, l.id ASC;
        """.format(_p_query)

        self.env.cr.execute(_query, ())

        res = self.env.cr.dictfetchall()
        filtered = filter(lambda x: x.get('qty') != 0, res)
        for p, q in groupby(sorted(filtered, key=lambda k: k.get("product_id")), lambda k: k.get("product_id")):
            _g = [i for i in q]
            result.append(
                (p, {
                    "product_name": _g[0].get("product_name"),
                    "qty": sum([j.get("qty") for j in _g]),
                    "lines": _g
                })
            )

        return result

    def get_lines(self, options, line_id=None):
        lines = []
        unfold_all = self.env.context.get('print_mode') and not options.get('unfolded_lines') or \
                     options.get('product_id')

        result = self._get_query(options, line_id)
        qty = 0.0
        for p, q in result:
            qty += q["qty"]
            lines.append({
                "id": "product_{}".format(p),
                "name": q["product_name"],
                "columns": [{
                    "name": q["qty"]
                }],
                "level": 2,
                "unfoldable": True,
                "unfolded": "product_".format(p) in options.get('unfolded_lines') or unfold_all,
                "colspan": 3
            })
            if "product_{}".format(p) in options.get("unfolded_lines") or unfold_all:
                child_lines = []
                _lines = q["lines"]

                for l in _lines:
                    child_lines.append({
                        "id": l.get("location_id"),
                        "parent_id": "product_{}".format(p),
                        "name": l.get("location"),
                        "columns": [
                            {"name": l.get("location")},
                            {"name": l.get("qty")}
                        ],
                        "level": 4
                    })

                lines += child_lines

        if not line_id:
            lines.append({
                "id": "grouped_products_total",
                "name": _("Total"),
                "level": 0,
                "class": "o_account_reports_domain_total",
                "columns": [
                    {"name": qty}
                ],
                "colspan": 3
            })

        return lines
