# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import http
from odoo.http import request, route


class FlexerpMobileController(http.Controller):
    """Thin JSON-RPC HTTP facade for FlexERP mobile clients."""

    def _api(self):
        return request.env['flexerp.mobile.api']

    @route('/flexerp/mobile/bootstrap', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def bootstrap(self, company_id=None, app_version=None, **kwargs):
        return self._api().bootstrap(company_id=company_id, app_version=app_version)

    @route('/flexerp/mobile/company/switch', type='jsonrpc', auth='user', methods=['POST'])
    def company_switch(self, company_id=None, **kwargs):
        return self._api().switch_company(company_id)

    # Admin
    @route('/flexerp/mobile/admin/tenants', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def admin_tenants(self, **kwargs):
        return self._api().list_tenants()

    @route('/flexerp/mobile/admin/tenant/features', type='jsonrpc', auth='user', methods=['POST'])
    def admin_tenant_features(self, company_id=None, features=None, preset=None, **kwargs):
        return self._api().update_tenant_features(company_id, features=features, preset=preset)

    @route('/flexerp/mobile/admin/tenant/provision', type='jsonrpc', auth='user', methods=['POST'])
    def admin_tenant_provision(self, **vals):
        return self._api().provision_tenant(**vals)

    @route('/flexerp/mobile/admin/tenant/deactivate', type='jsonrpc', auth='user', methods=['POST'])
    def admin_tenant_deactivate(self, company_id=None, **kwargs):
        return self._api().deactivate_tenant(company_id)

    @route('/flexerp/mobile/admin/users', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def admin_users(self, company_id=None, **kwargs):
        return self._api().list_tenant_users(company_id)

    @route('/flexerp/mobile/admin/users/create', type='jsonrpc', auth='user', methods=['POST'])
    def admin_users_create(self, company_id=None, **vals):
        return self._api().create_tenant_user(company_id, **vals)

    @route('/flexerp/mobile/admin/users/active', type='jsonrpc', auth='user', methods=['POST'])
    def admin_users_active(self, user_id=None, active=True, **kwargs):
        return self._api().set_tenant_user_active(user_id, active=active)

    @route('/flexerp/mobile/admin/approvals', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def admin_approvals(self, limit=40, company_id=None, **kwargs):
        return self._api().list_approvals(limit=limit, company_id=company_id)

    # POS
    @route('/flexerp/mobile/pos/configs', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def pos_configs(self, **kwargs):
        return self._api().pos_list_configs()

    @route('/flexerp/mobile/pos/session/open', type='jsonrpc', auth='user', methods=['POST'])
    def pos_session_open(self, config_id=None, **kwargs):
        return self._api().pos_open_session(config_id)

    @route('/flexerp/mobile/pos/session/close', type='jsonrpc', auth='user', methods=['POST'])
    def pos_session_close(self, session_id=None, **kwargs):
        return self._api().pos_close_session(session_id)

    @route('/flexerp/mobile/pos/products', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def pos_products(self, config_id=None, limit=500, **kwargs):
        return self._api().pos_sync_products(config_id=config_id, limit=limit)

    @route('/flexerp/mobile/pos/order', type='jsonrpc', auth='user', methods=['POST'])
    def pos_order(self, **payload):
        data = payload.get('payload') if isinstance(payload.get('payload'), dict) else payload
        return self._api().pos_push_order(data)

    @route('/flexerp/mobile/pos/order/receipt', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def pos_order_receipt(self, order_id=None, **kwargs):
        return self._api().pos_order_receipt(order_id)

    @route('/flexerp/mobile/pos/orders', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def pos_orders(self, limit=40, **kwargs):
        return self._api().pos_list_orders(limit=limit)

    # Partners / catalog
    @route('/flexerp/mobile/partners', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def partners(self, limit=80, search=None, partner_type='customer', **kwargs):
        return self._api().partners_list(limit=limit, search=search, partner_type=partner_type)

    @route('/flexerp/mobile/partners/create', type='jsonrpc', auth='user', methods=['POST'])
    def partners_create(self, **vals):
        return self._api().partners_create(vals)

    @route('/flexerp/mobile/products', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def products(self, limit=200, search=None, category_id=None, **kwargs):
        return self._api().products_list(limit=limit, search=search, category_id=category_id)

    @route('/flexerp/mobile/products/categories', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def product_categories(self, limit=80, **kwargs):
        return self._api().product_categories(limit=limit)

    @route('/flexerp/mobile/purchase/orders', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def purchase_orders(self, limit=50, **kwargs):
        return self._api().purchase_list_orders(limit=limit)

    @route('/flexerp/mobile/purchase/order/create', type='jsonrpc', auth='user', methods=['POST'])
    def purchase_order_create(self, partner_id=None, lines=None, confirm=False, **kwargs):
        return self._api().purchase_create_order(partner_id, lines or [], confirm=confirm)

    @route('/flexerp/mobile/crm/stages', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def crm_stages(self, **kwargs):
        return self._api().crm_list_stages()

    @route('/flexerp/mobile/hr/leave/types', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def hr_leave_types(self, **kwargs):
        return self._api().hr_leave_types()

    @route('/flexerp/mobile/sales/order/detail', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def sales_order_detail(self, order_id=None, **kwargs):
        return self._api().sales_order_detail(order_id)

    @route('/flexerp/mobile/stock/locations', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def stock_locations(self, limit=40, **kwargs):
        return self._api().stock_list_locations(limit=limit)

    # Stock
    @route('/flexerp/mobile/stock/barcode', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def stock_barcode(self, barcode=None, **kwargs):
        return self._api().stock_lookup_barcode(barcode)

    @route('/flexerp/mobile/stock/quants', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def stock_quants(self, limit=80, search=None, **kwargs):
        return self._api().stock_list_quants(limit=limit, search=search)

    @route('/flexerp/mobile/stock/pickings', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def stock_pickings(self, limit=50, **kwargs):
        return self._api().stock_list_pickings(limit=limit)

    @route('/flexerp/mobile/stock/picking', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def stock_picking(self, picking_id=None, **kwargs):
        return self._api().stock_picking_detail(picking_id)

    @route('/flexerp/mobile/stock/picking/validate', type='jsonrpc', auth='user', methods=['POST'])
    def stock_picking_validate(self, picking_id=None, **kwargs):
        return self._api().stock_validate_picking(picking_id)

    @route('/flexerp/mobile/stock/adjust', type='jsonrpc', auth='user', methods=['POST'])
    def stock_adjust(self, product_id=None, quantity_delta=0, location_id=None, reason=None, **kwargs):
        return self._api().stock_adjust(product_id, quantity_delta, location_id=location_id, reason=reason)

    # Sales / CRM
    @route('/flexerp/mobile/sales/orders', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def sales_orders(self, limit=50, **kwargs):
        return self._api().sales_list_orders(limit=limit)

    @route('/flexerp/mobile/sales/order/create', type='jsonrpc', auth='user', methods=['POST'])
    def sales_order_create(self, partner_id=None, lines=None, confirm=False, **kwargs):
        return self._api().sales_create_order(partner_id, lines or [], confirm=confirm)

    @route('/flexerp/mobile/sales/order/confirm', type='jsonrpc', auth='user', methods=['POST'])
    def sales_order_confirm(self, order_id=None, **kwargs):
        return self._api().sales_confirm_order(order_id)

    @route('/flexerp/mobile/crm/leads', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def crm_leads(self, limit=50, **kwargs):
        return self._api().crm_list_leads(limit=limit)

    @route('/flexerp/mobile/crm/lead/create', type='jsonrpc', auth='user', methods=['POST'])
    def crm_lead_create(self, name=None, expected_revenue=0.0, phone=None, email=None, **kwargs):
        return self._api().crm_create_lead(name, expected_revenue=expected_revenue, phone=phone, email=email)

    @route('/flexerp/mobile/crm/lead/stage', type='jsonrpc', auth='user', methods=['POST'])
    def crm_lead_stage(self, lead_id=None, stage_id=None, **kwargs):
        return self._api().crm_set_stage(lead_id, stage_id)

    # Accounting
    @route('/flexerp/mobile/accounting/invoices', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def accounting_invoices(self, move_type='out_invoice', limit=50, **kwargs):
        return self._api().accounting_list_invoices(move_type=move_type, limit=limit)

    @route('/flexerp/mobile/accounting/journals', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def accounting_journals(self, **kwargs):
        return self._api().accounting_list_journals()

    @route('/flexerp/mobile/accounting/invoice/detail', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def accounting_invoice_detail(self, move_id=None, **kwargs):
        return self._api().invoice_detail(move_id)

    @route('/flexerp/mobile/accounting/invoice/create_from_pos', type='jsonrpc', auth='user', methods=['POST'])
    def accounting_invoice_from_pos(self, order_id=None, **kwargs):
        return self._api().invoice_create_from_pos(order_id)

    @route('/flexerp/mobile/invoice/pdf', type='jsonrpc', auth='user', methods=['POST'])
    def invoice_pdf(self, move_id=None, **kwargs):
        return self._api().invoice_pdf(move_id)

    @route('/flexerp/mobile/invoice/whatsapp/send', type='jsonrpc', auth='user', methods=['POST'])
    def invoice_whatsapp_send(self, phone=None, move_id=None, pos_order_id=None, **kwargs):
        return self._api().whatsapp_send_invoice(phone, move_id=move_id, pos_order_id=pos_order_id)

    @route('/flexerp/mobile/payment/register', type='jsonrpc', auth='user', methods=['POST'])
    def payment_register(self, move_id=None, amount=None, journal_id=None, payment_date=None, memo=None, **kwargs):
        return self._api().register_invoice_payment(
            move_id, amount=amount, journal_id=journal_id, payment_date=payment_date, memo=memo,
        )

    @route('/flexerp/mobile/payment/link/create', type='jsonrpc', auth='user', methods=['POST'])
    def payment_link_create(self, amount=None, order_ref=None, return_url=None, **kwargs):
        return self._api().payment_link_create(amount, order_ref=order_ref, return_url=return_url)

    @route('/flexerp/mobile/payment/link/status', type='jsonrpc', auth='user', methods=['POST'])
    def payment_link_status(self, reference=None, mark_paid=False, **kwargs):
        return self._api().payment_link_status(reference, mark_paid=mark_paid)

    @route('/flexerp/mobile/live/poll', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def live_poll(self, since_id=0, limit=50, **kwargs):
        return self._api().live_poll(since_id=since_id, limit=limit)

    # HR
    @route('/flexerp/mobile/hr/employees', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def hr_employees(self, limit=50, **kwargs):
        return self._api().hr_list_employees(limit=limit)

    @route('/flexerp/mobile/hr/leaves', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def hr_leaves(self, limit=50, **kwargs):
        return self._api().hr_list_leaves(limit=limit)

    @route('/flexerp/mobile/hr/leave/submit', type='jsonrpc', auth='user', methods=['POST'])
    def hr_leave_submit(self, holiday_status_id=None, date_from=None, date_to=None, name=None, **kwargs):
        return self._api().hr_submit_leave(holiday_status_id, date_from, date_to, name=name)

    @route('/flexerp/mobile/hr/attendance', type='jsonrpc', auth='user', methods=['POST'])
    def hr_attendance(self, check_in=True, latitude=None, longitude=None, **kwargs):
        return self._api().hr_attendance_check(
            check_in=check_in, latitude=latitude, longitude=longitude,
        )

    # Executive
    @route('/flexerp/mobile/executive/kpis', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def executive_kpis(self, **kwargs):
        return self._api().executive_kpis()
