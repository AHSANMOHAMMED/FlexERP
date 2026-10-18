# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import base64
from uuid import uuid4

from odoo import api, fields, models
from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.tools import float_compare


class FlexerpMobileApi(models.AbstractModel):
    _name = 'flexerp.mobile.api'
    _description = 'FlexERP Mobile API Helpers'

    # ------------------------------------------------------------------
    # Security helpers
    # ------------------------------------------------------------------
    @api.model
    def _is_platform_admin(self, user=None):
        user = user or self.env.user
        return (
            user.has_group('base.group_system')
            or user.has_group('base.group_erp_manager')
            or user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
        )

    @api.model
    def _require_company_access(self, company=None, company_id=None):
        if company_id is not None:
            company = self.env['res.company'].browse(int(company_id))
        company = company or self.env.company
        if not company or not company.exists():
            raise AccessError('Vendor slot not found.')
        user = self.env.user
        if self._is_platform_admin(user):
            return company
        if company.id not in user.company_ids.ids:
            raise AccessError('You cannot access this vendor slot.')
        return company

    @api.model
    def _require_feature(self, key, company=None):
        company = self._require_company_access(company=company or self.env.company)
        features = self.env['flexerp.feature.flag'].get_mobile_features(company.id)
        if not features.get(key):
            raise AccessError(f'Feature "{key}" is disabled for this vendor.')
        return features

    @api.model
    def _require_odoo_model(self, model_name, label=None):
        """Soft-optional apps: fail clearly when module is not installed."""
        if model_name not in self.env:
            raise UserError(
                f'{label or model_name} module is not installed on this database.'
            )

    @api.model
    def _require_any_commerce(self, company=None):
        """Partners/products only when at least one commerce feature is on."""
        company = self._require_company_access(company=company or self.env.company)
        features = self.env['flexerp.feature.flag'].get_mobile_features(company.id)
        commerce_keys = ('pos', 'sales', 'crm', 'inventory', 'purchase')
        if not any(features.get(k) for k in commerce_keys):
            raise AccessError(
                'No commerce feature is enabled for this vendor '
                '(POS, Sales, CRM, Inventory, or Purchase).'
            )
        return features

    @api.model
    def _with_slot(self, company=None):
        company = self._require_company_access(company=company or self.env.company)
        return self.with_company(company).with_context(
            allowed_company_ids=company.ids if not self._is_platform_admin() else self.env.user.company_ids.ids,
        )

    @api.model
    def _detect_role(self, user=None):
        user = user or self.env.user
        if self._is_platform_admin(user):
            return 'superAdmin'
        if user.has_group('flexerp_vendor_rbac.group_vendor_admin'):
            return 'vendorAdmin'
        if user.has_group('flexerp_vendor_rbac.group_vendor_cashier'):
            return 'posCashier'
        if user.has_group('point_of_sale.group_pos_user'):
            return 'posCashier'
        if user.has_group('stock.group_stock_user'):
            return 'warehouseOp'
        if user.has_group('account.group_account_invoice'):
            return 'accountant'
        if user.has_group('sales_team.group_sale_salesman'):
            return 'salesRep'
        return 'employee'

    @api.model
    def _group_xmlids(self, user=None):
        user = user or self.env.user
        data = self.env['ir.model.data'].sudo().search([
            ('model', '=', 'res.groups'),
            ('res_id', 'in', user.groups_id.ids),
        ])
        return [f'{rec.module}.{rec.name}' for rec in data]

    @api.model
    def _assert_record_company(self, record, company_field='company_id'):
        if not record:
            raise AccessError('Record not found.')
        company = getattr(record, company_field, False)
        if company:
            self._require_company_access(company=company)
        return record

    # ------------------------------------------------------------------
    # Bootstrap
    # ------------------------------------------------------------------
    @api.model
    def bootstrap(self, company_id=None, app_version=None):
        user = self.env.user
        company = self.env['res.company'].browse(company_id) if company_id else self.env.company
        company = self._require_company_access(company=company)
        api = self._with_slot(company)

        Flag = api.env['flexerp.feature.flag']
        Flag.ensure_flags_for_company(company)
        features = Flag.get_mobile_features(company.id)

        companies = []
        for comp in user.company_ids:
            Flag.ensure_flags_for_company(comp)
            companies.append({
                'id': comp.id,
                'name': comp.name,
                'vendor_id': comp.flexerp_vendor_code or f'VND-{comp.id:03d}',
                'features': Flag.get_mobile_features(comp.id),
                'is_active': bool(comp.flexerp_is_active_vendor),
            })

        min_version = api.env['ir.config_parameter'].sudo().get_param(
            'flexerp.mobile.min_version', '1.0.0',
        )
        currency = company.currency_id
        return {
            'uid': user.id,
            'name': user.name,
            'email': user.login,
            'role': api._detect_role(user),
            'groups': api._group_xmlids(user),
            'company_id': company.id,
            'company_name': company.name,
            'vendor_id': company.flexerp_vendor_code or f'VND-{company.id:03d}',
            'currency_name': currency.name if currency else 'LKR',
            'currency_symbol': currency.symbol if currency else 'Rs',
            'features': features,
            'companies': companies,
            'app_min_version': min_version,
            'server_time': fields.Datetime.now().isoformat(),
        }

    @api.model
    def switch_company(self, company_id):
        company = self._require_company_access(company_id=company_id)
        self.env.user.sudo().write({'company_id': company.id})
        return self._with_slot(company).bootstrap(company_id=company.id)

    # ------------------------------------------------------------------
    # Admin / tenants / users
    # ------------------------------------------------------------------
    @api.model
    def list_tenants(self):
        if not self._is_platform_admin():
            raise AccessError('Only platform Super Admin can list all tenants.')
        companies = self.env['res.company'].sudo().search([
            ('flexerp_is_active_vendor', '=', True),
        ])
        if not companies:
            companies = self.env['res.company'].sudo().search([])
        for company in companies:
            self.env['flexerp.feature.flag'].ensure_flags_for_company(company)
        return [c.get_flexerp_tenant_payload() for c in companies]

    @api.model
    def update_tenant_features(self, company_id, features=None, preset=None):
        if not self._is_platform_admin():
            raise AccessError('Only platform Super Admin can update features.')
        company = self.env['res.company'].sudo().browse(int(company_id))
        if preset:
            company.flexerp_preset = preset if preset in ('small_shop', 'mall', 'custom') else 'custom'
            if preset in ('small_shop', 'mall'):
                self.env['flexerp.feature.flag'].apply_preset(company.id, preset)
        if features is not None:
            company.flexerp_preset = 'custom'
            self.env['flexerp.feature.flag'].set_mobile_features(company.id, features)
        return company.get_flexerp_tenant_payload()

    @api.model
    def provision_tenant(self, **vals):
        return self.env['flexerp.vendor.slot'].provision_slot(vals)

    @api.model
    def deactivate_tenant(self, company_id):
        return self.env['flexerp.vendor.slot'].deactivate_slot(company_id)

    @api.model
    def list_tenant_users(self, company_id):
        return self.env['flexerp.vendor.slot'].list_slot_users(company_id)

    @api.model
    def create_tenant_user(self, company_id, **vals):
        return self.env['flexerp.vendor.slot'].create_slot_user(company_id, vals)

    @api.model
    def set_tenant_user_active(self, user_id, active=True):
        return self.env['flexerp.vendor.slot'].set_slot_user_active(user_id, active=active)

    @api.model
    def list_approvals(self, limit=40, company_id=None):
        """Pending activities scoped to the user or selected vendor companies."""
        if self._is_platform_admin():
            company_ids = (
                [int(company_id)] if company_id
                else self.env.user.company_ids.ids
            )
            domain = [
                ('date_deadline', '!=', False),
                ('user_id.company_id', 'in', company_ids),
            ]
        else:
            domain = [
                ('user_id', '=', self.env.uid),
                ('date_deadline', '!=', False),
            ]
        activities = self.env['mail.activity'].sudo().search(
            domain, limit=limit, order='date_deadline asc',
        )
        return [{
            'id': a.id,
            'summary': a.summary or a.activity_type_id.name,
            'note': a.note or '',
            'date_deadline': fields.Date.to_string(a.date_deadline) if a.date_deadline else None,
            'res_model': a.res_model,
            'res_id': a.res_id,
            'user_name': a.user_id.name,
        } for a in activities]

    @api.model
    def approval_action(self, activity_id, action='approve'):
        """Approve or reject a pending mail.activity and related business record."""
        activity = self.env['mail.activity'].sudo().browse(int(activity_id))
        if not activity.exists():
            raise UserError('Approval activity not found.')
        if not self._is_platform_admin() and activity.user_id != self.env.user:
            # Vendor admins may act on activities assigned to them in their companies.
            if not self.env.user.has_group('flexerp_vendor_rbac.group_vendor_admin'):
                raise AccessError('Not allowed to act on this approval.')
        action = (action or 'approve').lower()
        res_model = activity.res_model
        res_id = activity.res_id
        record = self.env[res_model].sudo().browse(res_id) if res_model and res_id else False

        if action == 'approve':
            if record and record.exists():
                if res_model == 'sale.order' and record.state in ('draft', 'sent'):
                    record.action_confirm()
                elif res_model == 'purchase.order' and hasattr(record, 'button_confirm') and record.state in ('draft', 'sent'):
                    record.button_confirm()
                elif res_model in ('hr.leave', 'hr.holidays') and hasattr(record, 'action_approve'):
                    record.action_approve()
                elif res_model == 'account.move' and record.state == 'draft' and hasattr(record, 'action_post'):
                    record.action_post()
            activity.action_done()
            return {'ok': True, 'action': 'approve', 'activity_id': activity_id, 'res_model': res_model, 'res_id': res_id}

        if action in ('reject', 'cancel'):
            if record and record.exists():
                if res_model == 'sale.order' and record.state in ('draft', 'sent') and hasattr(record, 'action_cancel'):
                    record.action_cancel()
                elif res_model == 'purchase.order' and record.state in ('draft', 'sent', 'to approve') and hasattr(record, 'button_cancel'):
                    record.button_cancel()
                elif res_model in ('hr.leave', 'hr.holidays') and hasattr(record, 'action_refuse'):
                    record.action_refuse()
            activity.unlink()
            return {'ok': True, 'action': 'reject', 'activity_id': activity_id, 'res_model': res_model, 'res_id': res_id}

        raise UserError('Unknown approval action.')

    # ------------------------------------------------------------------
    # POS
    # ------------------------------------------------------------------
    @api.model
    def pos_list_configs(self):
        api = self._with_slot()
        api._require_feature('pos')
        configs = api.env['pos.config'].search([('company_id', '=', api.env.company.id)])
        return [{
            'id': c.id,
            'name': c.name,
            'current_session_id': c.current_session_id.id if c.current_session_id else False,
            'current_session_state': c.current_session_id.state if c.current_session_id else False,
        } for c in configs]

    @api.model
    def pos_open_session(self, config_id):
        api = self._with_slot()
        api._require_feature('pos')
        config = api.env['pos.config'].browse(int(config_id))
        api._assert_record_company(config)
        config.open_session_if_not_opened()
        session = config.current_session_id
        return {
            'session_id': session.id,
            'config_id': config.id,
            'name': session.name,
            'state': session.state,
        }

    @api.model
    def pos_close_session(self, session_id):
        api = self._with_slot()
        api._require_feature('pos')
        session = api.env['pos.session'].browse(int(session_id))
        api._assert_record_company(session)
        if session.state == 'opened':
            session.action_pos_session_closing_control()
        if session.state in ('closing_control', 'opened'):
            try:
                session.action_pos_session_close()
            except Exception:
                pass
        return {'session_id': session.id, 'state': session.state}

    @api.model
    def pos_sync_products(self, config_id=None, limit=500):
        api = self._with_slot()
        api._require_feature('pos')
        domain = [
            ('sale_ok', '=', True),
            ('available_in_pos', '=', True),
            '|', ('company_id', '=', False), ('company_id', '=', api.env.company.id),
        ]
        Product = api.env['product.product'].with_company(api.env.company)
        products = Product.search(domain, limit=limit)
        vendor_id = api.env.company.flexerp_vendor_code or f'VND-{api.env.company.id:03d}'
        rows = products.read([
            'display_name', 'barcode', 'default_code', 'lst_price',
            'standard_price', 'qty_available', 'categ_id',
        ])
        return [{
            'id': row['id'],
            'name': row['display_name'],
            'barcode': row['barcode'] or '',
            'sku': row['default_code'] or '',
            'category': row['categ_id'][1] if row['categ_id'] else '',
            'selling_price': row['lst_price'],
            'cost_price': row['standard_price'],
            'stock_on_hand': row['qty_available'],
            'vendor_id': vendor_id,
        } for row in rows]

    @api.model
    def pos_push_order(self, payload):
        api = self._with_slot()
        api._require_feature('pos')
        session = api.env['pos.session'].browse(int(payload.get('session_id')))
        api._assert_record_company(session)
        if not session or session.state not in ('opened', 'opening_control'):
            raise UserError('POS session is not open.')

        lines = payload.get('lines') or []
        if not lines:
            raise ValidationError('Order must contain at least one line.')

        # Stock availability check (prevent silent oversell)
        for line in lines:
            product = api.env['product.product'].browse(int(line['product_id']))
            qty = float(line.get('qty') or 1.0)
            available = product.with_company(api.env.company).qty_available
            if product.type == 'product' and float_compare(available, qty, precision_digits=2) < 0:
                raise UserError(
                    f'Insufficient stock for {product.display_name}: need {qty}, have {available}.'
                )

        amount_total = float(payload.get('amount_total') or 0.0)
        order_uuid = payload.get('uuid') or str(uuid4())
        payment_methods = session.config_id.payment_method_ids
        if not payment_methods:
            raise UserError('No payment methods configured on this POS.')

        method_name = (payload.get('payment_method') or 'cash').lower()
        payment_method = payment_methods[0]
        for pm in payment_methods:
            name = (pm.name or '').lower()
            if method_name in name or (method_name == 'cash' and pm.is_cash_count):
                payment_method = pm
                break

        line_commands = []
        for line in lines:
            product = api.env['product.product'].browse(int(line['product_id']))
            qty = float(line.get('qty') or 1.0)
            price = float(line.get('price_unit') if line.get('price_unit') is not None else product.lst_price)
            line_commands.append((0, 0, {
                'product_id': product.id,
                'qty': qty,
                'price_unit': price,
                'price_subtotal': price * qty,
                'price_subtotal_incl': price * qty,
                'full_product_name': product.display_name,
            }))

        order = api.env['pos.order'].create({
            'session_id': session.id,
            'company_id': session.company_id.id,
            'config_id': session.config_id.id,
            'amount_tax': 0.0,
            'amount_total': amount_total,
            'amount_paid': amount_total,
            'amount_return': 0.0,
            'uuid': order_uuid,
            'state': 'paid',
            'partner_id': payload.get('partner_id') or False,
            'lines': line_commands,
            'payment_ids': [(0, 0, {
                'amount': amount_total,
                'payment_method_id': payment_method.id,
                'session_id': session.id,
            })],
        })
        invoice_id = False
        invoice_name = False
        features = api.env['flexerp.feature.flag'].get_mobile_features(api.env.company.id)
        if payload.get('create_invoice') and features.get('invoicing'):
            try:
                inv_result = api.invoice_create_from_pos(order.id)
                invoice_id = inv_result.get('invoice_id')
                invoice_name = inv_result.get('name')
            except Exception:
                invoice_id = False
        api.env['flexerp.live.event'].emit(api.env.company.id, 'sale', {
            'order_id': order.id,
            'name': order.name,
            'amount_total': order.amount_total,
            'invoice_id': invoice_id,
        })
        api.env['flexerp.live.event'].emit(api.env.company.id, 'stock', {
            'source': 'pos_order',
            'order_id': order.id,
        })
        return {
            'order_id': order.id,
            'name': order.name or order.pos_reference,
            'uuid': order.uuid,
            'amount_total': order.amount_total,
            'state': order.state,
            'invoice_id': invoice_id,
            'invoice_name': invoice_name,
            'partner_id': order.partner_id.id if order.partner_id else False,
            'partner_name': order.partner_id.display_name if order.partner_id else 'Walk-in',
        }

    # ------------------------------------------------------------------
    # Stock
    # ------------------------------------------------------------------
    @api.model
    def stock_lookup_barcode(self, barcode):
        api = self._with_slot()
        api._require_feature('inventory')
        product = api.env['product.product'].search([('barcode', '=', barcode)], limit=1)
        if not product:
            product = api.env['product.product'].search([('default_code', '=', barcode)], limit=1)
        if not product:
            return False
        quants = api.env['stock.quant'].search([
            ('product_id', '=', product.id),
            ('location_id.usage', '=', 'internal'),
            ('company_id', 'in', [False, api.env.company.id]),
        ])
        return {
            'id': product.id,
            'name': product.display_name,
            'barcode': product.barcode or '',
            'sku': product.default_code or '',
            'selling_price': product.lst_price,
            'cost_price': product.standard_price,
            'stock_on_hand': product.with_company(api.env.company).qty_available,
            'locations': [{
                'location_id': q.location_id.id,
                'location_name': q.location_id.complete_name,
                'quantity': q.quantity,
                'reserved': q.reserved_quantity,
            } for q in quants],
            'vendor_id': api.env.company.flexerp_vendor_code or f'VND-{api.env.company.id:03d}',
        }

    @api.model
    def stock_list_quants(self, limit=80, search=None):
        api = self._with_slot()
        api._require_feature('inventory')
        domain = [
            ('location_id.usage', '=', 'internal'),
            ('company_id', 'in', [False, api.env.company.id]),
        ]
        if search:
            domain = [
                '&', '&',
                ('location_id.usage', '=', 'internal'),
                ('company_id', 'in', [False, api.env.company.id]),
                '|', '|',
                ('product_id.name', 'ilike', search),
                ('product_id.barcode', 'ilike', search),
                ('product_id.default_code', 'ilike', search),
            ]
        quants = api.env['stock.quant'].search(domain, limit=limit)
        return [{
            'id': q.id,
            'product_id': q.product_id.id,
            'product_name': q.product_id.display_name,
            'barcode': q.product_id.barcode or '',
            'sku': q.product_id.default_code or '',
            'location': q.location_id.complete_name,
            'quantity': q.quantity,
            'reserved': q.reserved_quantity,
        } for q in quants]

    @api.model
    def stock_list_pickings(self, limit=50):
        api = self._with_slot()
        api._require_feature('warehouse')
        pickings = api.env['stock.picking'].search([
            ('company_id', '=', api.env.company.id),
            ('state', 'in', ['assigned', 'confirmed', 'waiting', 'done']),
        ], limit=limit)
        return [{
            'id': p.id,
            'name': p.name,
            'state': p.state,
            'partner': p.partner_id.display_name if p.partner_id else '',
            'origin': p.origin or '',
            'picking_type': p.picking_type_id.code,
            'scheduled_date': fields.Datetime.to_string(p.scheduled_date) if p.scheduled_date else None,
        } for p in pickings]

    @api.model
    def stock_picking_detail(self, picking_id):
        api = self._with_slot()
        api._require_feature('warehouse')
        picking = api.env['stock.picking'].browse(int(picking_id))
        api._assert_record_company(picking)
        return {
            'id': picking.id,
            'name': picking.name,
            'state': picking.state,
            'partner': picking.partner_id.display_name if picking.partner_id else '',
            'origin': picking.origin or '',
            'picking_type': picking.picking_type_id.code,
            'lines': [{
                'move_id': move.id,
                'product_id': move.product_id.id,
                'product_name': move.product_id.display_name,
                'barcode': move.product_id.barcode or '',
                'product_uom_qty': move.product_uom_qty,
                'quantity': move.quantity,
                'location_src': move.location_id.complete_name,
                'location_dest': move.location_dest_id.complete_name,
            } for move in picking.move_ids],
        }

    @api.model
    def stock_validate_picking(self, picking_id):
        api = self._with_slot()
        api._require_feature('warehouse')
        picking = api.env['stock.picking'].browse(int(picking_id))
        api._assert_record_company(picking)
        picking.button_validate()
        return {'id': picking.id, 'state': picking.state}

    @api.model
    def stock_adjust(self, product_id, quantity_delta, location_id=None, reason=None):
        """Inventory adjustment for current vendor slot (transactional)."""
        api = self._with_slot()
        api._require_feature('inventory')
        product = api.env['product.product'].browse(int(product_id))
        if not product.exists():
            raise UserError('Product not found.')
        Quant = api.env['stock.quant'].sudo()
        if location_id:
            location = api.env['stock.location'].browse(int(location_id))
        else:
            location = api.env['stock.warehouse'].search(
                [('company_id', '=', api.env.company.id)], limit=1,
            ).lot_stock_id
        if not location:
            raise UserError('No stock location for this vendor slot.')
        quant = Quant.search([
            ('product_id', '=', product.id),
            ('location_id', '=', location.id),
            ('company_id', 'in', [False, api.env.company.id]),
        ], limit=1)
        if quant:
            new_qty = quant.quantity + float(quantity_delta)
            if float_compare(new_qty, 0.0, precision_digits=2) < 0:
                raise UserError('Adjustment would make stock negative.')
            quant.inventory_quantity = new_qty
            quant.action_apply_inventory()
        else:
            if float(quantity_delta) < 0:
                raise UserError('No quant to decrease.')
            Quant.with_context(inventory_mode=True).create({
                'product_id': product.id,
                'location_id': location.id,
                'inventory_quantity': float(quantity_delta),
                'company_id': api.env.company.id,
            }).action_apply_inventory()
        result = {
            'product_id': product.id,
            'stock_on_hand': product.with_company(api.env.company).qty_available,
            'reason': reason or 'mobile_adjust',
        }
        api.env['flexerp.live.event'].emit(api.env.company.id, 'stock', result)
        return result

    # ------------------------------------------------------------------
    # POS receipt / invoice from POS
    # ------------------------------------------------------------------
    @api.model
    def pos_order_receipt(self, order_id):
        api = self._with_slot()
        api._require_feature('pos')
        order = api.env['pos.order'].browse(int(order_id))
        api._assert_record_company(order)
        lines = [{
            'product_name': line.full_product_name or line.product_id.display_name,
            'qty': line.qty,
            'price_unit': line.price_unit,
            'price_subtotal': line.price_subtotal_incl or line.price_subtotal,
        } for line in order.lines]
        return {
            'order_id': order.id,
            'name': order.name or order.pos_reference,
            'state': order.state,
            'amount_total': order.amount_total,
            'partner_name': order.partner_id.display_name if order.partner_id else 'Walk-in',
            'partner_phone': order.partner_id.phone or order.partner_id.mobile or '',
            'date_order': fields.Datetime.to_string(order.date_order) if order.date_order else None,
            'company_name': order.company_id.name,
            'vendor_id': order.company_id.flexerp_vendor_code or f'VND-{order.company_id.id:03d}',
            'lines': lines,
            'invoice_id': order.account_move.id if order.account_move else False,
        }

    @api.model
    def invoice_detail(self, move_id):
        api = self._with_slot()
        api._require_feature('invoicing')
        move = api.env['account.move'].browse(int(move_id))
        api._assert_record_company(move)
        return {
            'id': move.id,
            'name': move.name,
            'partner_name': move.partner_id.display_name,
            'partner_vat': move.partner_id.vat or '',
            'partner_phone': move.partner_id.phone or move.partner_id.mobile or '',
            'amount_total': move.amount_total,
            'amount_residual': move.amount_residual,
            'amount_untaxed': move.amount_untaxed,
            'amount_tax': move.amount_tax,
            'currency_name': move.currency_id.name if move.currency_id else 'LKR',
            'state': move.state,
            'payment_state': move.payment_state,
            'invoice_date': fields.Date.to_string(move.invoice_date) if move.invoice_date else None,
            'lines': [{
                'name': line.name,
                'quantity': line.quantity,
                'price_unit': line.price_unit,
                'price_subtotal': line.price_subtotal,
            } for line in move.invoice_line_ids if not line.display_type],
        }

    @api.model
    def invoice_create_from_pos(self, order_id):
        api = self._with_slot()
        api._require_feature('invoicing')
        order = api.env['pos.order'].browse(int(order_id))
        api._assert_record_company(order)
        if order.account_move:
            return {
                'invoice_id': order.account_move.id,
                'name': order.account_move.name,
                'state': order.account_move.state,
                'payment_state': order.account_move.payment_state,
            }
        if not order.partner_id:
            partner = api.env['res.partner'].sudo().create({
                'name': 'POS Walk-in',
                'company_id': api.env.company.id,
            })
            order.partner_id = partner
        if hasattr(order, 'action_pos_order_invoice'):
            order.action_pos_order_invoice()
        elif hasattr(order, '_generate_pos_order_invoice'):
            order._generate_pos_order_invoice()
        else:
            raise UserError('This Odoo build cannot invoice POS orders.')
        move = order.account_move
        if not move:
            raise UserError('Invoice was not created from POS order.')
        api.env['flexerp.live.event'].emit(api.env.company.id, 'invoice', {
            'invoice_id': move.id,
            'name': move.name,
            'order_id': order.id,
        })
        return {
            'invoice_id': move.id,
            'name': move.name,
            'state': move.state,
            'payment_state': move.payment_state,
        }

    @api.model
    def invoice_pdf(self, move_id):
        api = self._with_slot()
        api._require_feature('invoicing')
        move = api.env['account.move'].browse(int(move_id))
        api._assert_record_company(move)
        report = api.env.ref('flexerp_invoice_branding.action_report_flexerp_branded_invoice')
        pdf_content, _ = report._render_qweb_pdf(report.report_name, res_ids=move.ids)
        return {
            'invoice_id': move.id,
            'name': move.name,
            'filename': f'{move.name or "invoice"}.pdf'.replace('/', '-'),
            'pdf_base64': base64.b64encode(pdf_content).decode('ascii'),
            'mimetype': 'application/pdf',
        }

    @api.model
    def whatsapp_send_invoice(self, phone, move_id=None, pos_order_id=None):
        api = self._with_slot()
        message = 'FlexERP invoice'
        pdf_note = ''
        if move_id:
            api._require_feature('invoicing')
            move = api.env['account.move'].browse(int(move_id))
            api._assert_record_company(move)
            currency_name = move.currency_id.name if move.currency_id else 'LKR'
            message = (
                f'Invoice {move.name}\n'
                f'Amount: {move.amount_total:.2f} {currency_name}\n'
                f'Status: {move.payment_state}\n'
                f'From: {move.company_id.name}'
            )
            pdf_note = f' Invoice ID {move.id}.'
        elif pos_order_id:
            api._require_feature('pos')
            order = api.env['pos.order'].browse(int(pos_order_id))
            api._assert_record_company(order)
            currency_name = (
                order.currency_id.name
                if hasattr(order, 'currency_id') and order.currency_id
                else (order.company_id.currency_id.name if order.company_id.currency_id else 'LKR')
            )
            message = (
                f'Receipt {order.name or order.pos_reference}\n'
                f'Amount: {order.amount_total:.2f} {currency_name}\n'
                f'From: {order.company_id.name}'
            )
        else:
            raise ValidationError('move_id or pos_order_id is required.')
        result = api.env['flexerp.whatsapp.service'].send_text(phone, message + pdf_note)
        return result

    @api.model
    def live_poll(self, since_id=0, limit=50):
        api = self._with_slot()
        company_ids = api.env.company.ids
        if self._is_platform_admin():
            company_ids = self.env.user.company_ids.ids
        domain = [('company_id', 'in', company_ids)]
        if since_id:
            domain.append(('id', '>', int(since_id)))
        events = api.env['flexerp.live.event'].sudo().search(domain, limit=int(limit or 50), order='id asc')
        return {
            'events': [e.to_mobile_dict() for e in events],
            'latest_id': events[-1].id if events else int(since_id or 0),
        }

    @api.model
    def payment_link_create(self, amount, order_ref=None, return_url=None):
        api = self._with_slot()
        api._require_feature('payments')
        result = api.env['flexerp.payment.gateway'].create_pay_link(
            amount=amount,
            order_ref=order_ref,
            return_url=return_url,
            company=api.env.company,
        )
        return result

    @api.model
    def payment_link_status(self, reference, mark_paid=False):
        api = self._with_slot()
        api._require_feature('payments')
        result = api.env['flexerp.payment.gateway'].link_status(reference, mark_paid=mark_paid)
        if result.get('status') == 'paid':
            api.env['flexerp.live.event'].emit(api.env.company.id, 'payment', {
                'reference': reference,
                'status': 'paid',
            })
        return result

    # ------------------------------------------------------------------
    # Partners / Products / POS history / Purchase / CRM stages / Leave types
    # ------------------------------------------------------------------
    @api.model
    def partners_list(self, limit=80, search=None, partner_type='customer'):
        api = self._with_slot()
        api._require_any_commerce()
        domain = ['|', ('company_id', '=', False), ('company_id', '=', api.env.company.id)]
        if partner_type == 'supplier':
            domain.append(('supplier_rank', '>', 0))
        elif partner_type == 'customer':
            domain.append(('customer_rank', '>', 0))
        if search:
            domain = ['&'] + domain + ['|', '|',
                ('name', 'ilike', search),
                ('phone', 'ilike', search),
                ('email', 'ilike', search),
            ]
        partners = api.env['res.partner'].search(domain, limit=int(limit or 80))
        return [{
            'id': p.id,
            'name': p.name,
            'email': p.email or '',
            'phone': p.phone or p.mobile or '',
            'city': p.city or '',
            'street': p.street or '',
            'vat': p.vat or '',
            'credit_limit': getattr(p, 'credit_limit', 0.0) or 0.0,
            'credit': getattr(p, 'credit', 0.0) or 0.0,
            'customer_rank': p.customer_rank,
            'supplier_rank': p.supplier_rank,
        } for p in partners]

    @api.model
    def partners_create(self, vals):
        api = self._with_slot()
        api._require_any_commerce()
        vals = dict(vals or {})
        partner = api.env['res.partner'].create({
            'name': vals.get('name') or 'Partner',
            'email': vals.get('email') or False,
            'phone': vals.get('phone') or False,
            'city': vals.get('city') or False,
            'street': vals.get('street') or False,
            'vat': vals.get('vat') or False,
            'customer_rank': int(vals.get('customer_rank') or 1),
            'supplier_rank': int(vals.get('supplier_rank') or 0),
            'company_id': api.env.company.id,
        })
        return {
            'id': partner.id,
            'name': partner.name,
            'email': partner.email or '',
            'phone': partner.phone or '',
        }

    @api.model
    def products_list(self, limit=200, search=None, category_id=None):
        api = self._with_slot()
        api._require_any_commerce()
        domain = [('sale_ok', '=', True), '|', ('company_id', '=', False), ('company_id', '=', api.env.company.id)]
        if search:
            domain = ['&'] + domain + ['|', '|',
                ('name', 'ilike', search),
                ('default_code', 'ilike', search),
                ('barcode', 'ilike', search),
            ]
        if category_id:
            domain.append(('categ_id', 'child_of', int(category_id)))
        Product = api.env['product.product'].with_company(api.env.company)
        products = Product.search(domain, limit=int(limit or 200))
        rows = products.read([
            'display_name', 'default_code', 'barcode', 'lst_price', 'standard_price',
            'qty_available', 'categ_id', 'uom_id', 'type',
        ])
        return [{
            'id': row['id'],
            'name': row['display_name'],
            'default_code': row['default_code'] or '',
            'barcode': row['barcode'] or '',
            'list_price': row['lst_price'],
            'standard_price': row['standard_price'],
            'qty_available': row['qty_available'],
            'categ_id': row['categ_id'][0] if row['categ_id'] else False,
            'categ_name': row['categ_id'][1] if row['categ_id'] else '',
            'uom': row['uom_id'][1] if row['uom_id'] else '',
            'type': row['type'],
        } for row in rows]

    @api.model
    def product_categories(self, limit=80):
        api = self._with_slot()
        api._require_any_commerce()
        cats = api.env['product.category'].search([], limit=int(limit or 80))
        return [{'id': c.id, 'name': c.complete_name or c.name} for c in cats]

    @api.model
    def pos_list_orders(self, limit=40):
        api = self._with_slot()
        api._require_feature('pos')
        orders = api.env['pos.order'].search(
            [('company_id', '=', api.env.company.id)],
            limit=int(limit or 40),
            order='date_order desc',
        )
        return [{
            'id': o.id,
            'name': o.name or o.pos_reference,
            'pos_reference': o.pos_reference or o.name,
            'partner_name': o.partner_id.display_name if o.partner_id else 'Walk-in',
            'amount_total': o.amount_total,
            'state': o.state,
            'date_order': fields.Datetime.to_string(o.date_order) if o.date_order else None,
            'payment_method': o.payment_ids[:1].payment_method_id.name if o.payment_ids else '',
        } for o in orders]

    @api.model
    def purchase_list_orders(self, limit=50):
        api = self._with_slot()
        api._require_feature('purchase')
        api._require_odoo_model('purchase.order', 'Purchase')
        orders = api.env['purchase.order'].search(
            [('company_id', '=', api.env.company.id)],
            limit=int(limit or 50),
            order='date_order desc',
        )
        return [{
            'id': o.id,
            'name': o.name,
            'partner_name': o.partner_id.display_name,
            'amount_total': o.amount_total,
            'state': o.state,
            'date_order': fields.Datetime.to_string(o.date_order) if o.date_order else None,
        } for o in orders]

    @api.model
    def purchase_create_order(self, partner_id, lines, confirm=False):
        api = self._with_slot()
        api._require_feature('purchase')
        api._require_odoo_model('purchase.order', 'Purchase')
        order_lines = []
        for line in lines or []:
            order_lines.append((0, 0, {
                'product_id': int(line['product_id']),
                'product_qty': float(line.get('qty') or 1.0),
                'price_unit': float(line.get('price_unit') or 0.0),
                'name': line.get('name') or 'Line',
            }))
        order = api.env['purchase.order'].create({
            'partner_id': int(partner_id),
            'company_id': api.env.company.id,
            'order_line': order_lines,
        })
        if confirm and hasattr(order, 'button_confirm'):
            order.button_confirm()
        api.env['flexerp.live.event'].emit(api.env.company.id, 'stock', {
            'source': 'purchase',
            'order_id': order.id,
        })
        return {'id': order.id, 'name': order.name, 'state': order.state, 'amount_total': order.amount_total}

    @api.model
    def crm_list_stages(self):
        api = self._with_slot()
        api._require_feature('crm')
        api._require_odoo_model('crm.stage', 'CRM')
        stages = api.env['crm.stage'].search([], order='sequence, id')
        return [{'id': s.id, 'name': s.name, 'sequence': s.sequence} for s in stages]

    @api.model
    def hr_leave_types(self):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.leave.type', 'Time Off')
        types = api.env['hr.leave.type'].search([('active', '=', True)])
        return [{'id': t.id, 'name': t.name} for t in types]

    @api.model
    def sales_order_detail(self, order_id):
        api = self._with_slot()
        api._require_feature('sales')
        order = api.env['sale.order'].browse(int(order_id))
        api._assert_record_company(order)
        return {
            'id': order.id,
            'name': order.name,
            'partner_id': order.partner_id.id,
            'partner_name': order.partner_id.display_name,
            'amount_total': order.amount_total,
            'state': order.state,
            'date_order': fields.Datetime.to_string(order.date_order) if order.date_order else None,
            'lines': [{
                'id': line.id,
                'product_id': line.product_id.id,
                'name': line.name,
                'qty': line.product_uom_qty,
                'price_unit': line.price_unit,
                'price_subtotal': line.price_subtotal,
            } for line in order.order_line],
        }

    @api.model
    def stock_list_locations(self, limit=40):
        api = self._with_slot()
        api._require_feature('inventory')
        locs = api.env['stock.location'].search([
            ('usage', '=', 'internal'),
            '|', ('company_id', '=', False), ('company_id', '=', api.env.company.id),
        ], limit=int(limit or 40))
        return [{'id': l.id, 'name': l.complete_name} for l in locs]

    # ------------------------------------------------------------------
    # Sales / CRM
    # ------------------------------------------------------------------
    @api.model
    def sales_list_orders(self, limit=50):
        api = self._with_slot()
        api._require_feature('sales')
        orders = api.env['sale.order'].search(
            [('company_id', '=', api.env.company.id)], limit=limit,
        )
        return [{
            'id': o.id,
            'name': o.name,
            'partner_name': o.partner_id.display_name,
            'partner_id': o.partner_id.id,
            'amount_total': o.amount_total,
            'state': o.state,
            'date_order': fields.Datetime.to_string(o.date_order) if o.date_order else None,
        } for o in orders]

    @api.model
    def sales_create_order(self, partner_id, lines, confirm=False):
        api = self._with_slot()
        api._require_feature('sales')
        partner = api.env['res.partner'].browse(int(partner_id))
        order_lines = []
        for line in lines or []:
            order_lines.append((0, 0, {
                'product_id': int(line['product_id']),
                'product_uom_qty': float(line.get('qty') or 1.0),
                'price_unit': float(line.get('price_unit') or 0.0),
                'name': line.get('name') or 'Line',
            }))
        order = api.env['sale.order'].create({
            'partner_id': partner.id,
            'company_id': api.env.company.id,
            'order_line': order_lines,
        })
        if confirm:
            order.action_confirm()
        return {'id': order.id, 'name': order.name, 'state': order.state, 'amount_total': order.amount_total}

    @api.model
    def sales_confirm_order(self, order_id):
        api = self._with_slot()
        api._require_feature('sales')
        order = api.env['sale.order'].browse(int(order_id))
        api._assert_record_company(order)
        order.action_confirm()
        return {'id': order.id, 'name': order.name, 'state': order.state}

    @api.model
    def crm_list_leads(self, limit=50):
        api = self._with_slot()
        api._require_feature('crm')
        api._require_odoo_model('crm.lead', 'CRM')
        leads = api.env['crm.lead'].search(
            [('company_id', 'in', [False, api.env.company.id])], limit=limit,
        )
        return [{
            'id': lead.id,
            'name': lead.name,
            'partner_name': lead.partner_id.display_name if lead.partner_id else lead.contact_name or '',
            'expected_revenue': lead.expected_revenue,
            'stage': lead.stage_id.name if lead.stage_id else 'New',
            'stage_id': lead.stage_id.id if lead.stage_id else False,
            'priority': lead.priority or '0',
            'phone': lead.phone or '',
            'email': lead.email_from or '',
        } for lead in leads]

    @api.model
    def crm_create_lead(self, name, expected_revenue=0.0, phone=None, email=None):
        api = self._with_slot()
        api._require_feature('crm')
        api._require_odoo_model('crm.lead', 'CRM')
        lead = api.env['crm.lead'].create({
            'name': name,
            'expected_revenue': expected_revenue,
            'phone': phone,
            'email_from': email,
            'company_id': api.env.company.id,
        })
        return {'id': lead.id, 'name': lead.name}

    @api.model
    def crm_set_stage(self, lead_id, stage_id):
        api = self._with_slot()
        api._require_feature('crm')
        api._require_odoo_model('crm.lead', 'CRM')
        lead = api.env['crm.lead'].browse(int(lead_id))
        if lead.company_id:
            api._assert_record_company(lead)
        lead.stage_id = int(stage_id)
        return {'id': lead.id, 'stage_id': lead.stage_id.id, 'stage': lead.stage_id.name}

    # ------------------------------------------------------------------
    # Accounting
    # ------------------------------------------------------------------
    @api.model
    def accounting_list_invoices(self, move_type='out_invoice', limit=50):
        api = self._with_slot()
        api._require_feature('invoicing')
        moves = api.env['account.move'].search([
            ('company_id', '=', api.env.company.id),
            ('move_type', '=', move_type),
        ], limit=limit)
        return [{
            'id': m.id,
            'name': m.name,
            'partner_name': m.partner_id.display_name,
            'partner_vat': m.partner_id.vat or '',
            'amount_untaxed': m.amount_untaxed,
            'amount_tax': m.amount_tax,
            'amount_total': m.amount_total,
            'amount_residual': m.amount_residual,
            'state': m.state,
            'payment_state': m.payment_state,
            'invoice_date': fields.Date.to_string(m.invoice_date) if m.invoice_date else None,
            'invoice_date_due': fields.Date.to_string(m.invoice_date_due) if m.invoice_date_due else None,
        } for m in moves]

    @api.model
    def accounting_list_journals(self):
        api = self._with_slot()
        api._require_feature('payments')
        journals = api.env['account.journal'].search([
            ('company_id', '=', api.env.company.id),
            ('type', 'in', ['bank', 'cash']),
        ])
        return [{'id': j.id, 'name': j.name, 'type': j.type} for j in journals]

    @api.model
    def register_invoice_payment(self, move_id, amount=None, journal_id=None, payment_date=None, memo=None):
        api = self._with_slot()
        api._require_feature('payments')
        move = api.env['account.move'].browse(int(move_id))
        api._assert_record_company(move)
        if move.state != 'posted':
            raise UserError('Invoice must be posted before registering payment.')
        wizard = api.env['account.payment.register'].with_context(
            active_model='account.move',
            active_ids=move.ids,
        ).create({
            'amount': amount if amount is not None else move.amount_residual,
            'payment_date': payment_date or fields.Date.context_today(api),
            'communication': memo or move.name,
        })
        if journal_id:
            wizard.journal_id = int(journal_id)
        action = wizard.action_create_payments()
        api.env['flexerp.live.event'].emit(api.env.company.id, 'invoice', {
            'move_id': move.id,
            'payment_state': move.payment_state,
            'amount_residual': move.amount_residual,
        })
        return {
            'move_id': move.id,
            'payment_state': move.payment_state,
            'amount_residual': move.amount_residual,
            'action': bool(action),
        }

    # ------------------------------------------------------------------
    # HR
    # ------------------------------------------------------------------
    @api.model
    def hr_list_employees(self, limit=50):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.employee', 'HR')
        employees = api.env['hr.employee'].search([
            '|', ('company_id', '=', False), ('company_id', '=', api.env.company.id),
        ], limit=limit)
        return [{
            'id': e.id,
            'name': e.name,
            'job_title': e.job_title or '',
            'department': e.department_id.name if e.department_id else '',
            'work_email': e.work_email or '',
            'work_phone': e.work_phone or '',
        } for e in employees]

    @api.model
    def hr_list_leaves(self, limit=50):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.leave', 'Time Off')
        domain = [
            '|',
            ('employee_id.company_id', '=', False),
            ('employee_id.company_id', '=', api.env.company.id),
        ]
        if 'company_id' in api.env['hr.leave']._fields:
            domain = [
                '|', ('company_id', '=', False), ('company_id', '=', api.env.company.id),
            ]
        leaves = api.env['hr.leave'].search(domain, limit=limit, order='date_from desc')
        return [{
            'id': leave.id,
            'employee': leave.employee_id.name,
            'type': leave.holiday_status_id.name,
            'date_from': fields.Datetime.to_string(leave.date_from) if leave.date_from else None,
            'date_to': fields.Datetime.to_string(leave.date_to) if leave.date_to else None,
            'state': leave.state,
        } for leave in leaves]

    @api.model
    def hr_submit_leave(self, holiday_status_id, date_from, date_to, name=None):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.leave', 'Time Off')
        employee = api.env['hr.employee'].search([('user_id', '=', api.env.uid)], limit=1)
        if not employee:
            raise UserError('No employee linked to this user.')
        leave = api.env['hr.leave'].create({
            'name': name or 'Time Off',
            'employee_id': employee.id,
            'holiday_status_id': int(holiday_status_id),
            'request_date_from': date_from,
            'request_date_to': date_to,
            'date_from': date_from,
            'date_to': date_to,
        })
        return {'id': leave.id, 'state': leave.state}

    @api.model
    def hr_attendance_check(self, check_in=True, latitude=None, longitude=None):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.attendance', 'Attendances')
        employee = api.env['hr.employee'].search([('user_id', '=', api.env.uid)], limit=1)
        if not employee:
            raise UserError('No employee linked to this user.')
        Attendance = api.env['hr.attendance'].sudo()
        if check_in:
            att = Attendance.create({
                'employee_id': employee.id,
                'check_in': fields.Datetime.now(),
            })
            if latitude is not None or longitude is not None:
                att.write({
                    'in_latitude': latitude or 0.0,
                    'in_longitude': longitude or 0.0,
                })
            return {'id': att.id, 'check_in': fields.Datetime.to_string(att.check_in), 'status': 'checked_in'}
        open_att = Attendance.search([
            ('employee_id', '=', employee.id),
            ('check_out', '=', False),
        ], limit=1, order='check_in desc')
        if not open_att:
            raise UserError('No open attendance to check out.')
        open_att.write({'check_out': fields.Datetime.now()})
        if latitude is not None or longitude is not None:
            open_att.write({
                'out_latitude': latitude or 0.0,
                'out_longitude': longitude or 0.0,
            })
        return {
            'id': open_att.id,
            'check_in': fields.Datetime.to_string(open_att.check_in),
            'check_out': fields.Datetime.to_string(open_att.check_out),
            'status': 'checked_out',
        }

    # ------------------------------------------------------------------
    # Executive KPIs
    # ------------------------------------------------------------------
    @api.model
    def executive_kpis(self):
        api = self._with_slot()
        api._require_feature('executive')
        company = api.env.company
        Sale = api.env['sale.order']
        Move = api.env['account.move']
        Picking = api.env['stock.picking']
        today = fields.Date.context_today(api)
        so_today = Sale.search([
            ('company_id', '=', company.id),
            ('state', 'in', ['sale', 'done']),
            ('date_order', '>=', fields.Datetime.to_string(fields.Datetime.start_of(today, 'day'))),
        ])
        revenue = sum(so_today.mapped('amount_total'))
        unpaid = Move.search_count([
            ('company_id', '=', company.id),
            ('move_type', '=', 'out_invoice'),
            ('payment_state', 'in', ['not_paid', 'partial']),
            ('state', '=', 'posted'),
        ])
        pending_ship = Picking.search_count([
            ('company_id', '=', company.id),
            ('picking_type_code', '=', 'outgoing'),
            ('state', '=', 'assigned'),
        ])
        return {
            'company_id': company.id,
            'vendor_id': company.flexerp_vendor_code or f'VND-{company.id:03d}',
            'today_revenue': revenue,
            'today_orders': len(so_today),
            'unpaid_invoices': unpaid,
            'pending_shipments': pending_ship,
        }
