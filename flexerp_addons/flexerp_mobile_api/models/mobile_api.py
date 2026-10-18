# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import base64
from datetime import timedelta
from uuid import uuid4

from odoo import api, fields, models
from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.tools import float_compare, float_round

# Offline-queued attendance: accept client timestamps within this window.
ATTENDANCE_MAX_FUTURE_SKEW = timedelta(minutes=5)
ATTENDANCE_MAX_AGE = timedelta(days=7)


class FlexerpMobileApi(models.AbstractModel):
    _name = 'flexerp.mobile.api'
    _description = 'FlexERP Mobile API Helpers'

    # ------------------------------------------------------------------
    # Security helpers
    # ------------------------------------------------------------------
    @api.model
    def _is_platform_admin(self, user=None):
        """Platform Super Admin only (the group implies base.group_system).

        ``base.group_erp_manager`` (Access Rights) is NOT a platform admin.
        """
        user = user or self.env.user
        return (
            user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
            or user.has_group('base.group_system')
        )

    @api.model
    def _require_company_access(self, company=None, company_id=None):
        if company_id is not None:
            company = self.env['res.company'].browse(int(company_id))
        company = company or self.env.company
        if not company or not company.exists():
            raise AccessError(self.env._('Vendor slot not found.'))
        user = self.env.user
        if self._is_platform_admin(user):
            return company
        if company.id not in user.company_ids.ids:
            raise AccessError(self.env._('You cannot access this vendor slot.'))
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
                f'{label or model_name} module is not installed on this database.',
            )

    @api.model
    def _require_any_commerce(self, company=None):
        """Partners/products only when at least one commerce feature is on."""
        company = self._require_company_access(company=company or self.env.company)
        features = self.env['flexerp.feature.flag'].get_mobile_features(company.id)
        commerce_keys = ('pos', 'sales', 'crm', 'inventory', 'purchase')
        if not any(features.get(k) for k in commerce_keys):
            raise AccessError(
                self.env._('No commerce feature is enabled for this vendor '
                '(POS, Sales, CRM, Inventory, or Purchase).'),
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
            ('res_id', 'in', user.all_group_ids.ids),
        ])
        return [f'{rec.module}.{rec.name}' for rec in data]

    @api.model
    def _assert_record_company(self, record, company_field='company_id'):
        if not record:
            raise AccessError(self.env._('Record not found.'))
        company = getattr(record, company_field, False)
        if company:
            self._require_company_access(company=company)
        return record

    @api.model
    def _approval_record_company(self, record, res_model):
        company = False
        if res_model in ('hr.leave', 'hr.holidays'):
            company = getattr(record, 'company_id', False)
            # employee_id may be empty — never dereference a falsy Many2one.
            if not company and record.employee_id:
                company = record.employee_id.company_id
        elif 'company_id' in record._fields:
            company = record.company_id
        return company

    @api.model
    def _assert_approval_record_company(self, record, res_model):
        """Ensure approval target belongs to an accessible vendor company."""
        if not record or not record.exists():
            return record
        company = self._approval_record_company(record, res_model)
        if not company:
            if not self._is_platform_admin():
                raise AccessError(self.env._('Cannot act on approval without company scope.'))
            return record
        self._require_company_access(company=company)
        return record

    # ------------------------------------------------------------------
    # Bootstrap
    # ------------------------------------------------------------------
    @api.model
    def bootstrap(self, company_id=None, app_version=None):
        user = self.env.user
        company = self.env['res.company'].browse(int(company_id)) if company_id else self.env.company
        company = self._require_company_access(company=company)
        api = self._with_slot(company)

        Flag = api.env['flexerp.feature.flag']
        Flag.ensure_flags_for_company(company)
        features = Flag.get_mobile_features(company.id)

        companies = []
        for comp in user.company_ids:
            companies.append({
                'id': comp.id,
                'name': comp.name,
                'vendor_id': comp.flexerp_vendor_code or f'VND-{comp.id:03d}',
                'features': Flag.get_mobile_features(comp.id),
                'is_active': bool(comp.flexerp_is_active_vendor),
            })

        min_version = api.env['ir.config_parameter'].sudo().get_str(
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
            # Clients start live/poll from here so they never replay history.
            'live_last_event_id': api._live_company_max_id(),
        }

    @api.model
    def switch_company(self, company_id):
        company = self._require_company_access(company_id=company_id)
        user = self.env.user
        # Default company must be one of the user's allowed companies (also for admins).
        if company.id not in user.company_ids.ids:
            raise AccessError(self.env._('You can only switch to a vendor slot you belong to.'))
        user.sudo().write({'company_id': company.id})
        return self._with_slot(company).bootstrap(company_id=company.id)

    # ------------------------------------------------------------------
    # Admin / tenants / users
    # ------------------------------------------------------------------
    @api.model
    def list_tenants(self):
        if not self._is_platform_admin():
            raise AccessError(self.env._('Only platform Super Admin can list all tenants.'))
        companies = self.env['res.company'].sudo().search([
            ('flexerp_is_active_vendor', '=', True),
        ])
        if not companies:
            companies = self.env['res.company'].sudo().search([])
        return [c.get_flexerp_tenant_payload() for c in companies]

    @api.model
    def update_tenant_features(self, company_id, features=None, preset=None):
        if not self._is_platform_admin():
            raise AccessError(self.env._('Only platform Super Admin can update features.'))
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
        """Approve or reject a pending mail.activity and related business record.

        Non platform admins may only act on activities whose related record
        belongs to a company they are allowed in; vendor admins acting on
        someone else's activity are further restricted to their current slot.
        """
        api = self._with_slot()
        action = (action or 'approve').lower()
        if action not in ('approve', 'reject', 'cancel'):
            raise UserError(self.env._('Unknown approval action.'))
        # sudo: only to locate the activity; access is checked explicitly below.
        activity_sudo = api.env['mail.activity'].sudo().browse(int(activity_id or 0))
        if not activity_sudo.exists():
            raise UserError(self.env._('Approval activity not found.'))

        user = api.env.user
        is_admin = api._is_platform_admin()
        is_assignee = activity_sudo.user_id == user
        is_vendor_admin = user.has_group('flexerp_vendor_rbac.group_vendor_admin')
        if not (is_admin or is_assignee or is_vendor_admin):
            raise AccessError(self.env._('Not allowed to act on this approval.'))

        res_model = activity_sudo.res_model
        res_id = activity_sudo.res_id
        record_sudo = False
        if res_model and res_id and res_model in api.env:
            candidate = api.env[res_model].sudo().browse(res_id)
            if candidate.exists():
                record_sudo = candidate

        if not is_admin:
            if record_sudo:
                api._assert_approval_record_company(record_sudo, res_model)
                if is_vendor_admin and not is_assignee:
                    company = api._approval_record_company(record_sudo, res_model)
                    if company != api.env.company:
                        raise AccessError(self.env._('Vendor admins can only act on approvals of their current slot.'))
            elif not is_assignee:
                raise AccessError(self.env._('Cannot act on approval without company scope.'))

        # Platform admins act with full rights; everyone else with their own
        # access rights (no sudo) on both the activity and the business record.
        if is_admin:
            activity = activity_sudo
            record = record_sudo
        else:
            env = api.env
            company = record_sudo and api._approval_record_company(record_sudo, res_model)
            if company:
                # Validated above: the user belongs to this company.
                env = api.with_company(company).env
            activity = activity_sudo.with_env(env)
            record = record_sudo.with_env(env) if record_sudo else False

        if action == 'approve':
            if record:
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
            if record:
                if res_model == 'sale.order' and record.state in ('draft', 'sent') and hasattr(record, 'action_cancel'):
                    record.action_cancel()
                elif res_model == 'purchase.order' and record.state in ('draft', 'sent', 'to approve') and hasattr(record, 'button_cancel'):
                    record.button_cancel()
                elif res_model in ('hr.leave', 'hr.holidays') and hasattr(record, 'action_refuse'):
                    record.action_refuse()
            activity.unlink()
            return {'ok': True, 'action': 'reject', 'activity_id': activity_id, 'res_model': res_model, 'res_id': res_id}

        raise UserError(self.env._('Unknown approval action.'))

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
    def pos_open_session(self, config_id, opening_cash=None):
        api = self._with_slot()
        api._require_feature('pos')
        config = api.env['pos.config'].browse(int(config_id))
        if not config.exists():
            raise UserError(self.env._('POS configuration not found.'))
        api._assert_record_company(config)
        config.open_session_if_not_opened()
        session = config.current_session_id
        if not session:
            raise UserError(self.env._('Could not open a POS session for this configuration.'))
        if session.state == 'opening_control':
            # Same as the POS UI opening popup: default to the expected opening
            # balance so no artificial cash difference is booked.
            cash = config._get_opening_balance() if opening_cash is None else float(opening_cash)
            session.set_opening_control(cash, '')
        return {
            'session_id': session.id,
            'config_id': config.id,
            'name': session.name,
            'state': session.state,
        }

    @api.model
    def pos_close_session(self, session_id, counted_cash=None):
        api = self._with_slot()
        api._require_feature('pos')
        session = api.env['pos.session'].browse(int(session_id))
        if not session.exists():
            raise UserError(self.env._('POS session not found.'))
        api._assert_record_company(session)
        if session.state == 'closed':
            return {'session_id': session.id, 'state': session.state, 'already_closed': True}
        if session.state == 'opening_control':
            session.set_opening_control(session.config_id._get_opening_balance(), '')
        closing = {}
        cash_pm = session.config_id._get_cash_payment_method()
        if cash_pm:
            if counted_cash is None:
                expected = session.get_closing_control_data().get('default_cash_details') or {}
                counted_cash = expected.get('amount', 0.0)
            closing[cash_pm.id] = float(counted_cash)
        result = session.close_session_from_ui(closing)
        session.invalidate_recordset()
        if session.state != 'closed':
            # Fail loud — mobile must not locally mark closed while Odoo is still open.
            message = (result or {}).get('message') if isinstance(result, dict) else None
            raise UserError(
                message or f'POS session close incomplete (state={session.state}). '
                'Resolve cash control in Odoo backend, then retry.',
            )
        return {'session_id': session.id, 'state': session.state}

    @api.model
    def pos_sync_products(self, config_id=None, limit=120, offset=0):
        api = self._with_slot()
        api._require_feature('pos')
        domain = [
            ('sale_ok', '=', True),
            ('available_in_pos', '=', True),
            '|', ('company_id', '=', False), ('company_id', '=', api.env.company.id),
        ]
        Product = api.env['product.product'].with_company(api.env.company)
        products = Product.search(domain, limit=int(limit or 120), offset=int(offset or 0), order='id asc')
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

    def _pos_order_mobile_dict(self, order, invoice_id=False, invoice_name=False, invoice_error=None, idempotent=False):
        return {
            'id': order.id,
            'order_id': order.id,  # legacy key, same as ``id``
            'name': order.name or order.pos_reference,
            'uuid': order.uuid,
            'amount_total': order.amount_total,
            'amount_tax': order.amount_tax,
            'amount_paid': order.amount_paid,
            'state': order.state,
            'invoice_id': invoice_id,
            'invoice_name': invoice_name,
            'invoice_error': invoice_error,
            'idempotent': idempotent,
            'partner_id': order.partner_id.id if order.partner_id else False,
            'partner_name': order.partner_id.display_name if order.partner_id else 'Walk-in',
        }

    @api.model
    def _pos_pick_payment_method(self, session, method_name):
        payment_methods = session.config_id.payment_method_ids.filtered(lambda pm: pm.type != 'pay_later')
        if not payment_methods:
            raise UserError(self.env._('No payment methods configured on this POS.'))
        method_name = (method_name or 'cash').lower()
        for pm in payment_methods:
            if method_name == 'cash' and pm.type == 'cash':
                return pm
        for pm in payment_methods:
            if method_name in (pm.name or '').lower():
                return pm
        return payment_methods[0]

    @api.model
    def _pos_line_values(self, session, product, qty, discount, partner):
        """Server-side price/tax computation for one POS line (client prices are ignored)."""
        config = session.config_id
        company = session.company_id
        currency = config.currency_id
        pricelist = config.pricelist_id
        if pricelist:
            price = pricelist._get_product_price(product, qty, currency=currency)
        else:
            price = product.with_company(company).lst_price
        Tax = self.env['account.tax']
        taxes = product.taxes_id.filtered_domain(Tax._check_company_domain(company))
        fpos = config.default_fiscal_position_id
        taxes_after_fpos = fpos.map_tax(taxes)
        price_unit = Tax._fix_tax_included_price_company(price, taxes, taxes_after_fpos, company)
        net_price = price_unit * (1 - discount / 100.0)
        computed = taxes_after_fpos.compute_all(net_price, currency, qty, product=product, partner=partner)
        return {
            'product_id': product.id,
            'qty': qty,
            'price_unit': price_unit,
            'discount': discount,
            'tax_ids': [(6, 0, taxes.ids)],
            'price_subtotal': computed['total_excluded'],
            'price_subtotal_incl': computed['total_included'],
            'full_product_name': product.display_name,
        }

    @api.model
    def pos_push_order(self, payload):
        """Create a paid POS order from the mobile app.

        Prices, taxes and totals are always computed server-side; the client
        only sends products, quantities, per-line ``discount`` (percent) and an
        optional ``uuid`` used for idempotent offline retries.
        """
        api = self._with_slot()
        api._require_feature('pos')
        payload = dict(payload or {})
        session = api.env['pos.session'].browse(int(payload.get('session_id') or 0))
        if not session.exists():
            raise UserError(self.env._('POS session not found.'))
        api._assert_record_company(session)

        # Client UUID makes offline/retry pushes idempotent (no double sale).
        order_uuid = str(payload.get('uuid') or '').strip()
        if order_uuid:
            # sudo: uuid is globally unique; company access is asserted on the hit.
            existing = api.env['pos.order'].sudo().search([('uuid', '=', order_uuid)], limit=1)
            if existing:
                api._assert_record_company(existing)
                existing = existing.with_env(api.env).with_company(existing.company_id)
                inv = existing.account_move
                return api._pos_order_mobile_dict(
                    existing,
                    invoice_id=inv.id if inv else False,
                    invoice_name=inv.name if inv else False,
                    idempotent=True,
                )
        else:
            order_uuid = str(uuid4())

        if session.state not in ('opened', 'opening_control'):
            raise UserError(self.env._('POS session is not open.'))

        lines = payload.get('lines') or []
        if not lines:
            raise ValidationError(self.env._('Order must contain at least one line.'))

        partner = api.env['res.partner']
        if payload.get('partner_id'):
            partner = partner.browse(int(payload['partner_id']))
            if not partner.exists():
                raise ValidationError(self.env._('Customer not found.'))
            # Shared partners (no company) are fine; otherwise must be in an allowed slot.
            api._assert_record_company(partner)

        Product = api.env['product.product'].with_company(session.company_id)
        parsed = []
        qty_by_product = {}
        for line in lines:
            product = Product.browse(int(line.get('product_id') or 0))
            if not product.exists():
                raise ValidationError(self.env._('Product not found.'))
            api._assert_record_company(product)
            if not product.sale_ok:
                raise ValidationError(f'{product.display_name} cannot be sold.')
            qty = float(line.get('qty') if line.get('qty') is not None else 1.0)
            if float_compare(qty, 0.0, precision_digits=6) <= 0:
                raise ValidationError(self.env._('Line quantity must be positive.'))
            discount = float(line.get('discount') or 0.0)
            if discount < 0.0 or discount > 100.0:
                raise ValidationError(self.env._('Line discount must be between 0 and 100 percent.'))
            parsed.append((product, qty, discount))
            qty_by_product[product] = qty_by_product.get(product, 0.0) + qty

        # Stock availability check (prevent silent oversell of tracked products)
        for product, qty in qty_by_product.items():
            if not product.is_storable:
                continue
            available = product.qty_available
            if float_compare(available, qty, precision_digits=2) < 0:
                raise UserError(
                    f'Insufficient stock for {product.display_name}: need {qty}, have {available}.',
                )

        payment_method = api._pos_pick_payment_method(session, payload.get('payment_method'))
        if session.state == 'opening_control':
            session.set_opening_control(session.config_id._get_opening_balance(), '')

        PosOrder = api.env['pos.order'].with_company(session.company_id)
        order = PosOrder.create({
            'session_id': session.id,
            'company_id': session.company_id.id,
            'config_id': session.config_id.id,
            'uuid': order_uuid,
            'partner_id': partner.id or False,
            'amount_tax': 0.0,
            'amount_total': 0.0,
            'amount_paid': 0.0,
            'amount_return': 0.0,
            'lines': [
                (0, 0, api._pos_line_values(session, product, qty, discount, partner))
                for product, qty, discount in parsed
            ],
        })
        order._compute_prices()

        config = session.config_id
        amount_due = order.amount_total
        if config.cash_rounding and (not config.only_round_cash_method or payment_method.type == 'cash'):
            amount_due = float_round(
                amount_due,
                precision_rounding=config.rounding_method.rounding,
                rounding_method=config.rounding_method.rounding_method,
            )
        order.add_payment({
            'pos_order_id': order.id,
            'amount': order.currency_id.round(amount_due),
            'payment_method_id': payment_method.id,
        })
        # Standard POS completion: recompute prices, mark paid, stock moves, costs.
        order._process_saved_order(False)

        invoice_id = False
        invoice_name = False
        invoice_error = None
        features = api.env['flexerp.feature.flag'].get_mobile_features(api.env.company.id)
        if payload.get('create_invoice') and features.get('invoicing'):
            try:
                with api.env.cr.savepoint():
                    inv_result = api.invoice_create_from_pos(order.id)
                invoice_id = inv_result.get('invoice_id')
                invoice_name = inv_result.get('name')
            except (UserError, ValidationError, AccessError) as e:
                invoice_error = str(e)
        api.env['flexerp.live.event']._emit(api.env.company.id, 'sale', {
            'order_id': order.id,
            'name': order.name,
            'amount_total': order.amount_total,
            'invoice_id': invoice_id,
        })
        api.env['flexerp.live.event']._emit(api.env.company.id, 'stock', {
            'source': 'pos_order',
            'order_id': order.id,
        })
        return api._pos_order_mobile_dict(
            order,
            invoice_id=invoice_id,
            invoice_name=invoice_name,
            invoice_error=invoice_error,
        )

    # ------------------------------------------------------------------
    # Stock
    # ------------------------------------------------------------------
    @api.model
    def _company_product_domain(self, api):
        return ['|', ('company_id', '=', False), ('company_id', '=', api.env.company.id)]

    @api.model
    def _assert_barcode_unique(self, api, barcode, exclude_product_id=None):
        code = (barcode or '').strip()
        if not code:
            return
        domain = self._company_product_domain(api) + [('barcode', '=', code)]
        if exclude_product_id:
            domain = ['&'] + domain + [('id', '!=', int(exclude_product_id))]
        if api.env['product.product'].sudo().search_count(domain):
            raise UserError(f'Barcode {code} is already used for another product in this vendor.')

    @api.model
    def _ean13_check_digit(self, twelve_digits):
        digits = [int(c) for c in twelve_digits]
        odd = sum(digits[i] for i in range(0, 12, 2))
        even = sum(digits[i] for i in range(1, 12, 2))
        return str((10 - ((odd + even * 3) % 10)) % 10)

    @api.model
    def stock_lookup_barcode(self, barcode):
        api = self._with_slot()
        api._require_feature('inventory')
        code = (barcode or '').strip()
        if not code:
            return False
        Product = api.env['product.product'].with_company(api.env.company)
        company_domain = self._company_product_domain(api)
        product = Product.search(company_domain + [('barcode', '=', code)], limit=1)
        if not product:
            product = Product.search(company_domain + [('default_code', '=', code)], limit=1)
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
    def stock_validate_picking(self, picking_id, create_backorder=True):
        """Validate a transfer without interactive wizards.

        Partially processed transfers create a backorder unless
        ``create_backorder`` is False. Any other wizard Odoo still requires
        (e.g. lots/serials, zero-demand confirmation) is reported back with
        ``requires_action`` instead of being silently ignored.
        """
        api = self._with_slot()
        api._require_feature('warehouse')
        picking = api.env['stock.picking'].browse(int(picking_id))
        if not picking.exists():
            raise UserError(self.env._('Transfer not found.'))
        api._assert_record_company(picking)
        if picking.state == 'done':
            return {'id': picking.id, 'state': picking.state, 'requires_action': False, 'backorder_ids': []}
        ctx = {'skip_backorder': True}
        if not create_backorder:
            ctx['picking_ids_not_to_backorder'] = picking.ids
        res = picking.with_context(**ctx).button_validate()
        picking.invalidate_recordset()
        if isinstance(res, dict) and res.get('type') == 'ir.actions.act_window' and picking.state != 'done':
            return {
                'id': picking.id,
                'state': picking.state,
                'requires_action': True,
                'action_model': res.get('res_model'),
                'message': res.get('name') or 'Additional confirmation is required in the Odoo backend.',
                'backorder_ids': [],
            }
        if picking.state == 'done':
            api.env['flexerp.live.event']._emit(api.env.company.id, 'stock', {
                'source': 'picking',
                'picking_id': picking.id,
            })
        return {
            'id': picking.id,
            'state': picking.state,
            'requires_action': False,
            'backorder_ids': picking.backorder_ids.ids,
        }

    @api.model
    def stock_adjust(self, product_id, quantity_delta, location_id=None, reason=None):
        """Inventory adjustment for current vendor slot (transactional)."""
        api = self._with_slot()
        api._require_feature('inventory')
        if not api.env.user.has_group('stock.group_stock_user'):
            raise AccessError(self.env._('Inventory adjustments require stock user rights.'))
        company = api.env.company
        product = api.env['product.product'].browse(int(product_id or 0))
        if not product.exists():
            raise UserError(self.env._('Product not found.'))
        api._assert_record_company(product)
        if product.company_id and product.company_id != company:
            raise AccessError(self.env._('Product belongs to another vendor slot.'))
        if location_id:
            location = api.env['stock.location'].browse(int(location_id))
            if not location.exists():
                raise UserError(self.env._('Location not found.'))
            # Must be an internal location owned by the current slot (no shared/virtual ones).
            if location.company_id != company or location.usage != 'internal':
                raise AccessError(self.env._('Location does not belong to this vendor slot.'))
        else:
            location = api.env['stock.warehouse'].search(
                [('company_id', '=', company.id)], limit=1,
            ).lot_stock_id
        if not location:
            raise UserError(self.env._('No stock location for this vendor slot.'))
        delta = float(quantity_delta or 0.0)
        # Serialize concurrent adjusts on the same product+location.
        api.env.cr.execute(
            "SELECT id FROM product_product WHERE id = %s FOR UPDATE",
            (product.id,),
        )
        Quant = api.env['stock.quant'].with_context(inventory_mode=True)
        quant = Quant.search([
            ('product_id', '=', product.id),
            ('location_id', '=', location.id),
            ('company_id', '=', company.id),
            ('lot_id', '=', False),
            ('package_id', '=', False),
            ('owner_id', '=', False),
        ], limit=1)
        if quant:
            new_qty = quant.quantity + delta
            if float_compare(new_qty, 0.0, precision_digits=2) < 0:
                raise UserError(self.env._('Adjustment would make stock negative.'))
            quant.inventory_quantity = new_qty
        else:
            if float_compare(delta, 0.0, precision_digits=2) < 0:
                raise UserError(self.env._('No quant to decrease.'))
            quant = Quant.create({
                'product_id': product.id,
                'location_id': location.id,
                'inventory_quantity': delta,
            })
        quant._apply_inventory()
        result = {
            'product_id': product.id,
            'location_id': location.id,
            'stock_on_hand': product.with_company(company).qty_available,
            'reason': reason or 'mobile_adjust',
        }
        api.env['flexerp.live.event']._emit(company.id, 'stock', result)
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
        company = order.company_id
        return {
            'order_id': order.id,
            'name': order.name or order.pos_reference,
            'state': order.state,
            'amount_total': order.amount_total,
            'partner_name': order.partner_id.display_name if order.partner_id else 'Walk-in',
            'partner_phone': order.partner_id.phone or '',
            'date_order': fields.Datetime.to_string(order.date_order) if order.date_order else None,
            'company_name': company.name,
            'company_phone': company.phone or (company.partner_id.phone if company.partner_id else '') or '',
            'company_email': company.email or (company.partner_id.email if company.partner_id else '') or '',
            'vendor_id': company.flexerp_vendor_code or f'VND-{company.id:03d}',
            'lines': lines,
            'invoice_id': order.account_move.id if order.account_move else False,
        }

    @api.model
    def invoice_detail(self, move_id):
        api = self._with_slot()
        api._require_feature('invoicing')
        move = api.env['account.move'].browse(int(move_id))
        api._assert_record_company(move)
        company = move.company_id
        return {
            'id': move.id,
            'name': move.name,
            'partner_name': move.partner_id.display_name,
            'partner_vat': move.partner_id.vat or '',
            'partner_phone': move.partner_id.phone or move.partner_id.mobile or '',
            'company_name': company.name,
            'company_phone': company.phone or (company.partner_id.phone if company.partner_id else '') or '',
            'company_email': company.email or (company.partner_id.email if company.partner_id else '') or '',
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
    def _walk_in_partner(self, company):
        """One shared 'POS Walk-in' customer per company (found or created once)."""
        xmlid_name = f'flexerp_pos_walk_in_company_{company.id}'
        IMD = self.env['ir.model.data'].sudo()
        partner = self.env.ref(f'flexerp_mobile_api.{xmlid_name}', raise_if_not_found=False)
        if partner and partner.exists():
            return partner.sudo()
        # sudo: internal bookkeeping partner, scoped to the (already checked) company.
        partner = self.env['res.partner'].sudo().create({
            'name': 'POS Walk-in',
            'company_id': company.id,
            'customer_rank': 1,
        })
        IMD.create({
            'module': 'flexerp_mobile_api',
            'name': xmlid_name,
            'model': 'res.partner',
            'res_id': partner.id,
            'noupdate': True,
        })
        return partner

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
            order.partner_id = api._walk_in_partner(order.company_id)
        if hasattr(order, 'action_pos_order_invoice'):
            # Defer Odoo's own invoice PDF (no wkhtmltopdf round-trip on the
            # POS hot path); the mobile app fetches the branded PDF on demand.
            order.with_context(generate_pdf=False).action_pos_order_invoice()
        elif hasattr(order, '_generate_pos_order_invoice'):
            order._generate_pos_order_invoice()
        else:
            raise UserError(self.env._('This Odoo build cannot invoice POS orders.'))
        move = order.account_move
        if not move:
            raise UserError(self.env._('Invoice was not created from POS order.'))
        api.env['flexerp.live.event']._emit(api.env.company.id, 'invoice', {
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
        pdf_url = None
        if not (phone or '').strip():
            raise ValidationError(self.env._('phone is required.'))
        if move_id:
            api._require_feature('invoicing')
            move = api.env['account.move'].browse(int(move_id))
            api._assert_record_company(move)
            currency_name = move.currency_id.name if move.currency_id else 'LKR'
            store_phone = move.company_id.phone or ''
            customer = move.partner_id.display_name or 'Customer'
            message = (
                f'Invoice {move.name}\n'
                f'Customer: {customer}\n'
                f'Amount: {move.amount_total:.2f} {currency_name}\n'
                f'Status: {move.payment_state}\n'
                f'From: {move.company_id.name}'
                + (f' ({store_phone})' if store_phone else '')
            )
            pdf_url = api._invoice_share_pdf_url(move)
            pdf_note = f'\nPDF: {pdf_url}' if pdf_url else ''
        elif pos_order_id:
            api._require_feature('pos')
            order = api.env['pos.order'].browse(int(pos_order_id))
            api._assert_record_company(order)
            currency_name = (
                order.currency_id.name
                if hasattr(order, 'currency_id') and order.currency_id
                else (order.company_id.currency_id.name if order.company_id.currency_id else 'LKR')
            )
            store_phone = order.company_id.phone or ''
            customer = order.partner_id.display_name if order.partner_id else 'Walk-in'
            message = (
                f'Receipt {order.name or order.pos_reference}\n'
                f'Customer: {customer}\n'
                f'Amount: {order.amount_total:.2f} {currency_name}\n'
                f'From: {order.company_id.name}'
                + (f' ({store_phone})' if store_phone else '')
            )
        else:
            raise ValidationError(self.env._('move_id or pos_order_id is required.'))
        result = api.env['flexerp.whatsapp.service']._send_text(phone, message + pdf_note)
        result['pdf_url'] = pdf_url
        return result

    @api.model
    def _invoice_share_pdf_url(self, move):
        """Absolute portal URL (with access token) downloading the invoice PDF."""
        if move.state != 'posted':
            return None
        # sudo: generating/reading the portal access token of an already-checked invoice.
        move_sudo = move.sudo()
        path = move_sudo.get_portal_url(report_type='pdf', download=True)
        return f'{move_sudo.get_base_url().rstrip("/")}{path}'

    @api.model
    def _live_company_ids(self):
        # Slot users: current vendor company only. Platform admins: all accessible companies.
        if self._is_platform_admin():
            return self.env.user.company_ids.ids
        return [self.env.company.id]

    @api.model
    def _live_company_max_id(self):
        return self.env['flexerp.live.event']._max_event_id(self._live_company_ids())

    @api.model
    def live_poll(self, since_id=0, limit=50):
        """Events after ``since_id``. ``since_id <= 0`` returns no events, only the cursor."""
        api = self._with_slot()
        company_ids = api._live_company_ids()
        try:
            since_id = int(since_id or 0)
        except (TypeError, ValueError):
            since_id = 0
        limit = max(1, min(int(limit or 50), 500))
        if since_id <= 0:
            # Fresh client: start from "now", never replay history.
            last_id = api.env['flexerp.live.event']._max_event_id(company_ids)
            return {'events': [], 'last_id': last_id, 'latest_id': last_id}
        # sudo: domain is restricted to the user's slot(s) computed above.
        events = api.env['flexerp.live.event'].sudo().search([
            ('company_id', 'in', company_ids),
            ('id', '>', since_id),
        ], limit=limit, order='id asc')
        last_id = events[-1].id if events else since_id
        return {
            'events': [e.to_mobile_dict() for e in events],
            'last_id': last_id,
            'latest_id': last_id,  # legacy key, same as ``last_id``
        }

    @api.model
    def payment_link_create(self, amount, order_ref=None, return_url=None):
        api = self._with_slot()
        api._require_feature('payments')
        return api.env['flexerp.payment.gateway'].create_pay_link(
            amount=amount,
            order_ref=order_ref,
            return_url=return_url,
            company=api.env.company,
        )

    @api.model
    def payment_link_status(self, reference, mark_paid=False):
        api = self._with_slot()
        api._require_feature('payments')
        # link_status scopes the lookup to the user's companies and only lets
        # platform admins mark a link as paid manually.
        result = api.env['flexerp.payment.gateway'].link_status(reference, mark_paid=bool(mark_paid))
        if result.get('status') == 'paid':
            api.env['flexerp.live.event']._emit(api.env.company.id, 'payment', {
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
            'phone': p.phone or '',
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
    def products_list(self, limit=120, search=None, category_id=None, offset=0):
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
        products = Product.search(
            domain, limit=int(limit or 120), offset=int(offset or 0), order='id asc',
        )
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
    def products_generate_barcode(self):
        """Allocate an unused Sri Lanka-style EAN-13 (479…) for this vendor slot."""
        api = self._with_slot()
        api._require_any_commerce()
        company = api.env.company
        prefix = f'479{company.id % 1000:03d}'
        for _ in range(40):
            body = f'{prefix}{fields.Datetime.now().strftime("%H%M%S")}{uuid4().hex[:2]}'[:12]
            if len(body) < 12:
                body = body.ljust(12, '0')
            code = body + self._ean13_check_digit(body)
            try:
                self._assert_barcode_unique(api, code)
                return {'barcode': code, 'company_id': company.id}
            except UserError:
                continue
        raise UserError('Could not allocate a unique barcode. Try again.')

    @api.model
    def products_create(self, vals):
        api = self._with_slot()
        api._require_any_commerce()
        name = (vals.get('name') or '').strip()
        if not name:
            raise ValidationError('Product name is required.')
        barcode = (vals.get('barcode') or '').strip()
        if not barcode:
            barcode = self.products_generate_barcode()['barcode']
        else:
            self._assert_barcode_unique(api, barcode)
        features = api.env['flexerp.feature.flag'].get_mobile_features(api.env.company.id)
        Product = api.env['product.product'].with_company(api.env.company).sudo()
        create_vals = {
            'name': name,
            'barcode': barcode,
            'default_code': vals.get('default_code') or vals.get('sku') or False,
            'list_price': float(vals.get('list_price') or vals.get('lst_price') or 0.0),
            'standard_price': float(vals.get('standard_price') or 0.0),
            'sale_ok': True,
            'purchase_ok': True,
            'type': vals.get('type') or 'product',
            'company_id': api.env.company.id,
            'available_in_pos': bool(features.get('pos')),
        }
        if vals.get('categ_id'):
            create_vals['categ_id'] = int(vals['categ_id'])
        product = Product.create(create_vals)
        return {
            'id': product.id,
            'name': product.display_name,
            'barcode': product.barcode or '',
            'default_code': product.default_code or '',
            'list_price': product.lst_price,
            'qty_available': product.with_company(api.env.company).qty_available,
        }

    @api.model
    def products_update(self, product_id, vals):
        api = self._with_slot()
        api._require_any_commerce()
        product = api.env['product.product'].browse(int(product_id))
        if not product.exists():
            raise UserError('Product not found.')
        if product.company_id and product.company_id.id != api.env.company.id:
            raise AccessError('Product belongs to another vendor slot.')
        write_vals = {}
        if vals.get('name'):
            write_vals['name'] = vals['name'].strip()
        if 'list_price' in vals or 'lst_price' in vals:
            write_vals['list_price'] = float(vals.get('list_price') or vals.get('lst_price') or 0.0)
        if 'standard_price' in vals:
            write_vals['standard_price'] = float(vals.get('standard_price') or 0.0)
        if 'default_code' in vals or 'sku' in vals:
            write_vals['default_code'] = vals.get('default_code') or vals.get('sku') or False
        if 'barcode' in vals:
            barcode = (vals.get('barcode') or '').strip()
            if barcode:
                self._assert_barcode_unique(api, barcode, exclude_product_id=product.id)
            write_vals['barcode'] = barcode or False
        if 'categ_id' in vals and vals.get('categ_id'):
            write_vals['categ_id'] = int(vals['categ_id'])
        if write_vals:
            product.sudo().write(write_vals)
        return {
            'id': product.id,
            'name': product.display_name,
            'barcode': product.barcode or '',
            'default_code': product.default_code or '',
            'list_price': product.lst_price,
            'qty_available': product.with_company(api.env.company).qty_available,
        }

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
        api.env['flexerp.live.event']._emit(api.env.company.id, 'stock', {
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
    def _leave_type_field(self):
        """Odoo 20 replaced hr.leave.type / holiday_status_id by hr.work.entry.type / work_entry_type_id."""
        if 'work_entry_type_id' in self.env['hr.leave']._fields:
            return 'work_entry_type_id'
        return 'holiday_status_id'

    @api.model
    def hr_leave_types(self):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.leave', 'Time Off')
        field = api._leave_type_field()
        Type = api.env[api.env['hr.leave']._fields[field].comodel_name]
        domain = [('active', '=', True)]
        if 'time_off_selectable' in Type._fields:
            domain.append(('time_off_selectable', '=', True))
        if 'company_id' in Type._fields:
            domain += ['|', ('company_id', '=', False), ('company_id', '=', api.env.company.id)]
        return [{'id': t.id, 'name': t.name} for t in Type.search(domain)]

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
        return [{'id': loc.id, 'name': loc.complete_name} for loc in locs]

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
    def _payment_result(self, move, payments, idempotent):
        move.invalidate_recordset(['amount_residual', 'payment_state'])
        return {
            'move_id': move.id,
            'payment_state': move.payment_state,
            'amount_residual': move.amount_residual,
            'action': bool(payments),
            'idempotent': idempotent,
            'payment_id': payments[:1].id or False,
            'uuid': payments[:1].flexerp_client_uuid or False,
        }

    @api.model
    def register_invoice_payment(self, move_id, amount=None, journal_id=None, payment_date=None, memo=None, uuid=None):
        """Register an invoice payment. ``uuid`` (optional client idempotency key)
        makes offline retries safe: a replay returns the original payment's result.
        """
        api = self._with_slot()
        api._require_feature('payments')
        move = api.env['account.move'].browse(int(move_id))
        if not move.exists():
            raise UserError(self.env._('Invoice not found.'))
        api._assert_record_company(move)
        client_uuid = str(uuid or '').strip() or False
        if client_uuid:
            # sudo: lookup by idempotency key; company access asserted on the hit.
            domain = [('flexerp_client_uuid', '=', client_uuid)]
            if not api._is_platform_admin():
                domain.append(('company_id', 'in', api.env.user.company_ids.ids))
            existing = api.env['account.payment'].sudo().search(domain, limit=1)
            if existing:
                api._assert_record_company(existing)
                if move not in (existing.invoice_ids | existing.reconciled_invoice_ids):
                    raise ValidationError(self.env._('This payment uuid was already used for another invoice.'))
                return api._payment_result(move, existing, idempotent=True)
        if move.state != 'posted':
            raise UserError(self.env._('Invoice must be posted before registering payment.'))
        move.invalidate_recordset(['amount_residual', 'payment_state'])
        # Offline/retry safety: already settled invoices return current state (no double pay).
        if float_compare(move.amount_residual, 0.0, precision_digits=2) <= 0:
            return {
                'move_id': move.id,
                'payment_state': move.payment_state,
                'amount_residual': move.amount_residual,
                'action': False,
                'idempotent': True,
            }
        pay_amount = amount if amount is not None else move.amount_residual
        if float_compare(pay_amount, 0.0, precision_digits=2) <= 0:
            raise UserError(self.env._('Payment amount must be positive.'))
        if float_compare(pay_amount, move.amount_residual, precision_digits=2) > 0:
            raise UserError(self.env._('Payment amount exceeds invoice residual.'))
        wizard = api.env['account.payment.register'].with_context(
            active_model='account.move',
            active_ids=move.ids,
        ).create({
            'amount': pay_amount,
            'payment_date': payment_date or fields.Date.context_today(api),
            'communication': memo or move.name,
        })
        if journal_id:
            wizard.journal_id = int(journal_id)
        if wizard.is_register_payment_on_draft:
            wizard.payment_difference_handling = 'open'
        payments = wizard._create_payments()
        if client_uuid:
            # sudo: stamping the idempotency key on payments just created by this user.
            payments.sudo().write({'flexerp_client_uuid': client_uuid})
        result = api._payment_result(move, payments, idempotent=False)
        api.env['flexerp.live.event']._emit(api.env.company.id, 'invoice', {
            'move_id': move.id,
            'payment_state': result['payment_state'],
            'amount_residual': result['amount_residual'],
        })
        return result

    # ------------------------------------------------------------------
    # HR
    # ------------------------------------------------------------------
    @api.model
    def hr_list_employees(self, limit=50):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.employee', 'HR')
        # Non-HR users (e.g. vendor admins) may only read the public employee directory.
        model = 'hr.employee' if api.env.user.has_group('hr.group_hr_user') else 'hr.employee.public'
        employees = api.env[model].search([
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
        company_id = api.env.company.id
        # Always constrain by employee company; AND leave.company_id when present.
        employee_domain = [
            '|',
            ('employee_id.company_id', '=', False),
            ('employee_id.company_id', '=', company_id),
        ]
        if 'company_id' in api.env['hr.leave']._fields:
            domain = [
                '&',
                '|', ('company_id', '=', False), ('company_id', '=', company_id),
            ] + employee_domain
        else:
            domain = employee_domain
        leaves = api.env['hr.leave'].search(domain, limit=limit, order='date_from desc')
        return [{
            'id': leave.id,
            'employee': leave.employee_id.name,
            'type': leave[api._leave_type_field()].name,
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
            raise UserError(self.env._('No employee linked to this user.'))
        leave = api.env['hr.leave'].create({
            'name': name or 'Time Off',
            'employee_id': employee.id,
            api._leave_type_field(): int(holiday_status_id),
            'request_date_from': date_from,
            'request_date_to': date_to,
            'date_from': date_from,
            'date_to': date_to,
        })
        return {'id': leave.id, 'state': leave.state}

    @api.model
    def _attendance_time(self, timestamp=None):
        """Validated UTC time for an (optionally offline-queued) attendance punch.

        ``timestamp`` is a UTC 'YYYY-MM-DD HH:MM:SS' string. It may not be in the
        future (beyond a small clock skew) nor older than 7 days; when absent,
        the server time is used.
        """
        now = fields.Datetime.now()
        if not timestamp:
            return now
        try:
            ts = fields.Datetime.to_datetime(str(timestamp).strip())
        except ValueError as e:
            raise ValidationError(self.env._('Invalid timestamp, expected UTC "YYYY-MM-DD HH:MM:SS".')) from e
        if not ts:
            return now
        if ts > now + ATTENDANCE_MAX_FUTURE_SKEW:
            raise ValidationError(self.env._('Attendance timestamp cannot be in the future.'))
        if ts < now - ATTENDANCE_MAX_AGE:
            raise ValidationError(self.env._('Attendance timestamp is older than 7 days.'))
        return min(ts, now)

    @api.model
    def hr_attendance_check(self, check_in=True, latitude=None, longitude=None, timestamp=None):
        api = self._with_slot()
        api._require_feature('hr')
        api._require_odoo_model('hr.attendance', 'Attendances')
        employee = api.env['hr.employee'].search([
            ('user_id', '=', api.env.uid),
            ('company_id', '=', api.env.company.id),
        ], limit=1) or api.env['hr.employee'].search([('user_id', '=', api.env.uid)], limit=1)
        if not employee:
            raise UserError(self.env._('No employee linked to this user.'))
        punch_time = api._attendance_time(timestamp)
        # Coordinates are only stored when the client actually sent both;
        # the server never assumes a default location.
        has_coords = latitude is not None and longitude is not None
        # sudo: employees may not have attendance write rights; scoped to own employee.
        Attendance = api.env['hr.attendance'].sudo()
        if check_in:
            vals = {
                'employee_id': employee.id,
                'check_in': punch_time,
            }
            if has_coords:
                vals.update({'in_latitude': float(latitude), 'in_longitude': float(longitude)})
            att = Attendance.create(vals)
            return {'id': att.id, 'check_in': fields.Datetime.to_string(att.check_in), 'status': 'checked_in'}
        open_att = Attendance.search([
            ('employee_id', '=', employee.id),
            ('check_out', '=', False),
        ], limit=1, order='check_in desc')
        if not open_att:
            raise UserError(self.env._('No open attendance to check out.'))
        if punch_time < open_att.check_in:
            raise ValidationError(self.env._('Check-out time cannot be before check-in time.'))
        vals = {'check_out': punch_time}
        if has_coords:
            vals.update({'out_latitude': float(latitude), 'out_longitude': float(longitude)})
        open_att.write(vals)
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
