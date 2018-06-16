from odoo import models, fields, api, _
import logging
_logger = logging.getLogger(__name__)

class StockWarehouse(models.Model):
    _inherit = "stock.warehouse"

    product_ids = fields.Many2many('product.product', 'warehouse_product_rel', id1='warehouse_id',
                                               id2='product_id', string='Products Stocked')
    parent_warehouse_id = fields.Many2one('stock.warehouse', ondelete='cascade')


class StockMove(models.Model):
    _inherit = "stock.move"

    @api.model
    def _fifo_vacuum(self):
        """ Every moves that need to be fixed are identifiable by having a negative `remaining_qty`.
        """
        for move in self.filtered(lambda m: (m._is_in() or m._is_out()) and m.remaining_qty < 0):
            domain = [
                ('remaining_qty', '>', 0),
                '|',
                    ('date', '>', move.date),
                    '&',
                        ('date', '=', move.date),
                        ('id', '>', move.id)
            ]
            domain += move._get_in_domain()
            candidates = self.search(domain, order='date, id')
            if not candidates:
                continue
            qty_to_take_on_candidates = abs(move.remaining_qty)
            tmp_value = 0
            for candidate in candidates:
                if candidate.remaining_qty <= qty_to_take_on_candidates:
                    qty_taken_on_candidate = candidate.remaining_qty
                else:
                    qty_taken_on_candidate = qty_to_take_on_candidates

                value_taken_on_candidate = qty_taken_on_candidate * candidate.price_unit
                candidate_vals = {
                    'remaining_qty': candidate.remaining_qty - qty_taken_on_candidate,
                    'remaining_value': candidate.remaining_value - value_taken_on_candidate,
                }
                candidate.write(candidate_vals)

                qty_to_take_on_candidates -= qty_taken_on_candidate
                tmp_value += value_taken_on_candidate
                if qty_to_take_on_candidates == 0:
                    break

            remaining_value_before_vacuum = move.remaining_value

            # If `remaining_qty` should be updated to 0, we wipe `remaining_value`. If it was set
            # it was only used to infer the correction entry anyway.
            new_remaining_qty = -qty_to_take_on_candidates
            new_remaining_value = 0 if not new_remaining_qty else move.remaining_value + tmp_value
            move.write({
                'remaining_value': new_remaining_value,
                'remaining_qty': new_remaining_qty,
            })

            if move.product_id.valuation == 'real_time':
                # If `move.remaining_value` is negative, it means that we initially valued this move at
                # an estimated price *and* posted an entry. `tmp_value` is the real value we took to
                # compensate and should always be positive, but if the remaining value is still negative
                # we have to take care to not overvalue by decreasing the correction entry by what's
                # already been posted.
                corrected_value = tmp_value
                
                def num_after_point(x):
                    s = str(x)
                    if not '.' in s:
                        return 0
                    return len(s) - s.index('.') - 1
                round_corrected_value_no = num_after_point(corrected_value)
                _logger.warning('************************BEFORE ROUNDING************************************** -  (%s)', (corrected_value))
                if round_corrected_value_no > 2:
                    corrected_value = round(corrected_value, 2)
                    _logger.warning('************************AFTER ROUNDING************************************** -  (%s)', (corrected_value))
                round_before_vacuum_no = num_after_point(remaining_value_before_vacuum)
                _logger.warning('*******************************BEFORE ROUNDING remaining_value_before_vacuum************************************** -  (%s)', (remaining_value_before_vacuum))
                if round_before_vacuum_no > 2:
                    remaining_value_before_vacuum = round(remaining_value_before_vacuum, 2)
                    _logger.warning('*******************************AFTER ROUNDING remaining_value_before_vacuum************************************** -  (%s)', (remaining_value_before_vacuum))

                
                if remaining_value_before_vacuum < 0:
                    corrected_value += remaining_value_before_vacuum

                if move._is_in():
                    # If we just compensated an IN move that has a negative remaining
                    # quantity, it means the move has returned more items than it received.
                    # The correction should behave as a return too. As `_account_entry_move`
                    # will post the natural values for an IN move (credit IN account, debit
                    # OUT one), we inverse the sign to create the correct entries.
                    move.with_context(force_valuation_amount=-corrected_value)._account_entry_move()
                else:
                    move.with_context(force_valuation_amount=corrected_value)._account_entry_move()

