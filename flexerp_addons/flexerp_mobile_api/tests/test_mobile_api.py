# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from datetime import timedelta

from odoo import fields
from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.models import get_public_method
from odoo.tests import new_test_user, tagged

from odoo.addons.flexerp_tenant_features.models.feature_flag import FEATURE_KEYS
from odoo.addons.point_of_sale.tests.common import TestPoSCommon


@tagged('post_install', '-at_install')
class TestFlexerpMobileApi(TestPoSCommon):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.company_a = cls.company
        cls.company_b = cls.setup_other_company(name='FlexERP Vendor B')['company']
        Flag = cls.env['flexerp.feature.flag'].sudo()
        for company in (cls.company_a, cls.company_b):
            Flag.set_mobile_features(company.id, dict.fromkeys(FEATURE_KEYS, True))

        def user(login, group, company):
            return new_test_user(
                cls.env, login=login, groups=group,
                company_id=company.id, company_ids=[(6, 0, company.ids)],
            )

        cls.admin_a = user('flex_admin_a', 'flexerp_vendor_rbac.group_vendor_admin', cls.company_a)
        cls.cashier_a = user('flex_cashier_a', 'flexerp_vendor_rbac.group_vendor_cashier', cls.company_a)
        cls.admin_b = user('flex_admin_b', 'flexerp_vendor_rbac.group_vendor_admin', cls.company_b)
        cls.platform_admin = cls.env.ref('base.user_admin')
        cls.platform_admin.write({'company_ids': [(4, cls.company_a.id), (4, cls.company_b.id)]})

        cls.tax7 = cls.taxes['tax7']
        cls.product_tea = cls.env['product.product'].create({
            'name': 'Mobile Tea',
            'lst_price': 100.0,
            'available_in_pos': True,
            'is_storable': False,
            'taxes_id': [(6, 0, cls.tax7.ids)],
            'company_id': cls.company_a.id,
        })
        cls.product_storable = cls.env['product.product'].create({
            'name': 'Mobile Rice Bag',
            'lst_price': 50.0,
            'available_in_pos': True,
            'is_storable': True,
            'taxes_id': [(5, 0, 0)],
            'company_id': cls.company_a.id,
        })
        cls.product_b = cls.env['product.product'].with_company(cls.company_b).create({
            'name': 'Vendor B Only',
            'lst_price': 10.0,
            'is_storable': True,
            'company_id': cls.company_b.id,
        })
        cls.partner_a = cls.env['res.partner'].create({
            'name': 'Mobile Customer A',
            'phone': '+94 77 123 4567',
            'customer_rank': 1,
            'company_id': cls.company_a.id,
        })
        cls.partner_b = cls.env['res.partner'].create({
            'name': 'Mobile Customer B',
            'customer_rank': 1,
            'company_id': cls.company_b.id,
        })

    def _api(self, user, company=None):
        company = company or user.company_id
        return (
            self.env['flexerp.mobile.api']
            .with_user(user)
            .with_context(allowed_company_ids=company.ids)
            .with_company(company)
        )

    # ------------------------------------------------------------------
    # Bootstrap / roles
    # ------------------------------------------------------------------
    def test_bootstrap_vendor_admin(self):
        self.env['flexerp.live.event']._emit(self.company_a.id, 'sale', {'x': 1})
        last_a = self.env['flexerp.live.event']._emit(self.company_a.id, 'stock', {'x': 2})
        self.env['flexerp.live.event']._emit(self.company_b.id, 'sale', {'x': 3})
        res = self._api(self.admin_a).bootstrap()
        self.assertEqual(res['role'], 'vendorAdmin')
        self.assertEqual(res['company_id'], self.company_a.id)
        self.assertIn('flexerp_vendor_rbac.group_vendor_admin', res['groups'])
        self.assertTrue(res['features']['pos'])
        self.assertEqual([c['id'] for c in res['companies']], [self.company_a.id])
        self.assertEqual(res['live_last_event_id'], last_a.id, 'Only the slot events count')

    def test_bootstrap_cashier(self):
        res = self._api(self.cashier_a).bootstrap()
        self.assertEqual(res['role'], 'posCashier')
        self.assertEqual(res['live_last_event_id'], 0)
        with self.assertRaises(AccessError):
            self._api(self.cashier_a).bootstrap(company_id=self.company_b.id)

    def test_erp_manager_is_not_platform_admin(self):
        self.admin_a.group_ids |= self.env.ref('base.group_erp_manager')
        api = self._api(self.admin_a)
        self.assertFalse(api._is_platform_admin())
        with self.assertRaises(AccessError):
            api.list_tenants()

    def test_switch_company_requires_membership(self):
        with self.assertRaises(AccessError):
            self._api(self.admin_a).switch_company(self.company_b.id)
        res = self._api(self.platform_admin, self.company_a).switch_company(self.company_b.id)
        self.assertEqual(res['company_id'], self.company_b.id)

    # ------------------------------------------------------------------
    # Cross-tenant isolation
    # ------------------------------------------------------------------
    def _sale_order(self, company, partner, product):
        return self.env['sale.order'].sudo().with_company(company).create({
            'partner_id': partner.id,
            'company_id': company.id,
            'order_line': [(0, 0, {'product_id': product.id, 'product_uom_qty': 1})],
        })

    def test_approval_action_cross_tenant(self):
        order_b = self._sale_order(self.company_b, self.partner_b, self.product_b)
        activity_b = order_b.activity_schedule(
            'mail.mail_activity_data_todo', user_id=self.admin_b.id,
            date_deadline=fields.Date.today(),
        )
        with self.assertRaises(AccessError):
            self._api(self.admin_a).approval_action(activity_b.id, 'approve')
        self.assertEqual(order_b.state, 'draft')
        self.assertTrue(activity_b.exists())

        order_a = self._sale_order(self.company_a, self.partner_a, self.product_tea)
        activity_a = order_a.activity_schedule(
            'mail.mail_activity_data_todo', user_id=self.cashier_a.id,
            date_deadline=fields.Date.today(),
        )
        # cashier is neither assignee of B's activity nor vendor admin
        with self.assertRaises(AccessError):
            self._api(self.cashier_a).approval_action(activity_b.id, 'approve')
        res = self._api(self.admin_a).approval_action(activity_a.id, 'approve')
        self.assertTrue(res['ok'])
        self.assertEqual(order_a.state, 'sale')

    def test_stock_adjust_isolation(self):
        api = self._api(self.admin_a)
        res = api.stock_adjust(self.product_storable.id, 5)
        self.assertEqual(res['stock_on_hand'], 5)
        res = api.stock_adjust(self.product_storable.id, -2)
        self.assertEqual(res['stock_on_hand'], 3)
        with self.assertRaises(UserError):
            api.stock_adjust(self.product_storable.id, -10)

        location_b = self.env['stock.warehouse'].search([('company_id', '=', self.company_b.id)], limit=1).lot_stock_id
        with self.assertRaises(AccessError):
            api.stock_adjust(self.product_storable.id, 1, location_id=location_b.id)
        with self.assertRaises(AccessError):
            api.stock_adjust(self.product_b.id, 1)
        # cashier has no stock rights
        with self.assertRaises(AccessError):
            self._api(self.cashier_a).stock_adjust(self.product_storable.id, 1)

    def test_payment_link_status_isolation(self):
        Gateway = self.env['flexerp.payment.gateway']
        link_b = Gateway.create_pay_link(25.0, order_ref='B-1', company=self.company_b)
        link_a = self._api(self.admin_a).payment_link_create(40.0, order_ref='A-1')
        self.assertTrue(link_a['ok'])

        api_a = self._api(self.admin_a)
        self.assertEqual(api_a.payment_link_status(link_b['reference'])['status'], 'not_found')
        self.assertEqual(api_a.payment_link_status(link_a['reference'])['status'], 'pending')
        with self.assertRaises(AccessError):
            api_a.payment_link_status(link_a['reference'], mark_paid=True)
        with self.assertRaises(AccessError):
            Gateway.with_user(self.admin_a).create_pay_link(5.0, company=self.company_b)
        # direct RPC-style call on the gateway cannot mark paid either
        with self.assertRaises(AccessError):
            Gateway.with_user(self.admin_a).link_status(link_a['reference'], mark_paid=True)

        res = Gateway.with_user(self.platform_admin).link_status(link_a['reference'], mark_paid=True)
        self.assertEqual(res['status'], 'paid')

    def test_feature_flags_isolation(self):
        Flag = self.env['flexerp.feature.flag'].with_user(self.admin_a)
        self.assertTrue(Flag.get_mobile_features(self.company_a.id)['pos'])
        with self.assertRaises(AccessError):
            Flag.get_mobile_features(self.company_b.id)
        with self.assertRaises(AccessError):
            Flag.set_mobile_features(self.company_b.id, {'pos': False})
        with self.assertRaises(AccessError):
            Flag.ensure_flags_for_company(self.company_b)
        # record rules: B's flags are invisible to A's users
        flags = Flag.search([])
        self.assertTrue(flags)
        self.assertEqual(flags.company_id, self.company_a)

    def test_private_service_methods(self):
        for model, name in (
            ('flexerp.whatsapp.service', '_send_text'),
            ('flexerp.live.event', '_emit'),
        ):
            with self.assertRaises(AccessError):
                get_public_method(self.env[model], name)
        for model, name in (
            ('flexerp.whatsapp.service', 'send_text'),
            ('flexerp.live.event', 'emit'),
        ):
            with self.assertRaises(AttributeError):
                get_public_method(self.env[model], name)

    def test_live_event_record_rules(self):
        self.env['flexerp.live.event']._emit(self.company_b.id, 'sale', {})
        mine = self.env['flexerp.live.event']._emit(self.company_a.id, 'sale', {})
        events = self.env['flexerp.live.event'].with_user(self.admin_a).search([])
        self.assertEqual(events, mine)

    # ------------------------------------------------------------------
    # POS
    # ------------------------------------------------------------------
    def _open_session(self, user):
        res = self._api(user).pos_open_session(self.basic_config.id)
        self.assertEqual(res['state'], 'opened')
        return res['session_id']

    def test_pos_push_order_server_totals_and_idempotency(self):
        session_id = self._open_session(self.cashier_a)
        api = self._api(self.cashier_a)
        payload = {
            'session_id': session_id,
            'uuid': 'mobile-test-uuid-0001',
            'payment_method': 'cash',
            # client tries to cheat: totals/prices are ignored by the server
            'amount_total': 1.0,
            'lines': [{'product_id': self.product_tea.id, 'qty': 2, 'discount': 10, 'price_unit': 0.5}],
        }
        res = api.pos_push_order(payload)
        # 2 x 100 - 10% = 180 + 7% tax = 192.6
        self.assertAlmostEqual(res['amount_total'], 192.6, places=2)
        self.assertAlmostEqual(res['amount_tax'], 12.6, places=2)
        self.assertEqual(res['uuid'], 'mobile-test-uuid-0001')
        self.assertEqual(res['state'], 'paid')
        self.assertFalse(res['idempotent'])
        self.assertEqual(res['id'], res['order_id'])
        order = self.env['pos.order'].browse(res['id'])
        self.assertAlmostEqual(order.amount_paid, 192.6, places=2)
        self.assertEqual(order.lines.price_unit, 100.0)
        self.assertEqual(order.lines.discount, 10.0)

        again = api.pos_push_order(dict(payload, lines=[{'product_id': self.product_tea.id, 'qty': 99}]))
        self.assertTrue(again['idempotent'])
        self.assertEqual(again['id'], res['id'])
        self.assertAlmostEqual(again['amount_total'], 192.6, places=2)
        self.assertEqual(self.env['pos.order'].search_count([('uuid', '=', 'mobile-test-uuid-0001')]), 1)

    def test_pos_push_order_validation(self):
        session_id = self._open_session(self.cashier_a)
        api = self._api(self.cashier_a)
        base = {'session_id': session_id, 'payment_method': 'cash'}
        with self.assertRaises(AccessError):
            api.pos_push_order(dict(base, partner_id=self.partner_b.id,
                                    lines=[{'product_id': self.product_tea.id, 'qty': 1}]))
        with self.assertRaises(AccessError):
            api.pos_push_order(dict(base, lines=[{'product_id': self.product_b.id, 'qty': 1}]))
        with self.assertRaises(ValidationError):
            api.pos_push_order(dict(base, lines=[{'product_id': self.product_tea.id, 'qty': 1, 'discount': 150}]))
        with self.assertRaises(UserError):
            # storable product without stock: oversell guard
            api.pos_push_order(dict(base, lines=[{'product_id': self.product_storable.id, 'qty': 1}]))
        res = api.pos_push_order(dict(base, partner_id=self.partner_a.id,
                                      lines=[{'product_id': self.product_tea.id, 'qty': 1}]))
        self.assertEqual(res['partner_id'], self.partner_a.id)
        self.assertTrue(res['uuid'])

    def test_pos_invoice_walk_in_partner_and_close(self):
        session_id = self._open_session(self.admin_a)
        api = self._api(self.admin_a)
        orders = [
            api.pos_push_order({
                'session_id': session_id,
                'payment_method': 'bank',
                'lines': [{'product_id': self.product_tea.id, 'qty': 1}],
            })
            for _i in range(2)
        ]
        partners = self.env['res.partner']
        for res in orders:
            inv = api.invoice_create_from_pos(res['id'])
            self.assertTrue(inv['invoice_id'])
            partners |= self.env['pos.order'].browse(res['id']).partner_id
        self.assertEqual(len(partners), 1, 'One shared walk-in partner per company')
        self.assertEqual(partners.company_id, self.company_a)

        receipt = api.pos_order_receipt(orders[0]['id'])
        self.assertIn('partner_phone', receipt)
        closed = api.pos_close_session(session_id)
        self.assertEqual(closed['state'], 'closed')
        again = api.pos_close_session(session_id)
        self.assertTrue(again['already_closed'])

    # ------------------------------------------------------------------
    # Live poll
    # ------------------------------------------------------------------
    def test_live_poll_since_id(self):
        Event = self.env['flexerp.live.event']
        e1 = Event._emit(self.company_a.id, 'sale', {'n': 1})
        Event._emit(self.company_b.id, 'sale', {'n': 'b'})
        api = self._api(self.admin_a)
        fresh = api.live_poll(since_id=0)
        self.assertEqual(fresh['events'], [])
        self.assertEqual(fresh['last_id'], e1.id)
        self.assertEqual(fresh['latest_id'], e1.id)
        self.assertEqual(api.live_poll(since_id=-5)['events'], [])

        e2 = Event._emit(self.company_a.id, 'stock', {'n': 2})
        Event._emit(self.company_b.id, 'stock', {'n': 'b2'})
        res = api.live_poll(since_id=fresh['last_id'])
        self.assertEqual([e['id'] for e in res['events']], [e2.id])
        self.assertEqual(res['last_id'], e2.id)
        empty = api.live_poll(since_id=e2.id)
        self.assertEqual(empty['events'], [])
        self.assertEqual(empty['last_id'], e2.id)

    def test_bus_channels_are_scoped(self):
        try:
            from odoo.addons.http_routing.tests.common import MockRequest  # noqa: PLC0415
        except ImportError:
            self.skipTest('http_routing not available')
        env = self.env(user=self.admin_a)
        with MockRequest(env):
            channels = env['ir.websocket']._build_bus_channel_list([
                f'flexerp_slot_{self.company_b.id}', 'flexerp_live',
            ])
        str_channels = [c for c in channels if isinstance(c, str)]
        self.assertNotIn(f'flexerp_slot_{self.company_b.id}', str_channels)
        self.assertNotIn('flexerp_live', str_channels)
        live = [c for c in channels if isinstance(c, tuple) and c[1:] == ('flexerp_live',)]
        self.assertEqual([c[0] for c in live], [self.company_a])

    # ------------------------------------------------------------------
    # Partners / invoices (no res.partner.mobile in Odoo 20)
    # ------------------------------------------------------------------
    def test_partners_and_invoice_detail(self):
        api = self._api(self.admin_a)
        partners = {p['id']: p for p in api.partners_list(search='Mobile Customer')}
        self.assertIn(self.partner_a.id, partners)
        self.assertNotIn(self.partner_b.id, partners)
        self.assertEqual(partners[self.partner_a.id]['phone'], '+94 77 123 4567')

        invoice = self.init_invoice('out_invoice', partner=self.partner_a, products=self.product_tea, post=True)
        detail = api.invoice_detail(invoice.id)
        self.assertEqual(detail['partner_phone'], '+94 77 123 4567')
        self.assertEqual(detail['state'], 'posted')

        invoice_b = self.init_invoice(
            'out_invoice', partner=self.partner_b, products=self.product_b, post=True,
            company=self.company_b,
        )
        with self.assertRaises(AccessError):
            api.invoice_detail(invoice_b.id)

    def test_whatsapp_invoice_share_url(self):
        invoice = self.init_invoice('out_invoice', partner=self.partner_a, products=self.product_tea, post=True)
        res = self._api(self.admin_a).whatsapp_send_invoice('0771234567', move_id=invoice.id)
        self.assertEqual(res['status'], 'not_configured')
        self.assertIn('access_token=', res['pdf_url'])
        self.assertIn('report_type=pdf', res['pdf_url'])
        self.assertIn('access_token', res['wa_me_url'], 'The share link is part of the message text')

    # ------------------------------------------------------------------
    # Stock picking validation
    # ------------------------------------------------------------------
    def test_stock_validate_picking_backorder(self):
        warehouse = self.env['stock.warehouse'].search([('company_id', '=', self.company_a.id)], limit=1)
        picking = self.env['stock.picking'].create({
            'picking_type_id': warehouse.in_type_id.id,
            'location_id': self.env.ref('stock.stock_location_suppliers').id,
            'location_dest_id': warehouse.lot_stock_id.id,
            'company_id': self.company_a.id,
            'move_ids': [(0, 0, {
                'product_id': self.product_storable.id,
                'product_uom_qty': 5,
                'location_id': self.env.ref('stock.stock_location_suppliers').id,
                'location_dest_id': warehouse.lot_stock_id.id,
            })],
        })
        picking.action_confirm()
        picking.move_ids.quantity = 3
        res = self._api(self.admin_a).stock_validate_picking(picking.id)
        self.assertEqual(res['state'], 'done')
        self.assertFalse(res['requires_action'])
        self.assertEqual(len(res['backorder_ids']), 1)

    # ------------------------------------------------------------------
    # HR attendance (optional module)
    # ------------------------------------------------------------------
    def test_attendance_timestamp(self):
        if 'hr.attendance' not in self.env:
            self.skipTest('hr_attendance not installed')
        self.env['hr.employee'].sudo().create({
            'name': 'Cashier A', 'user_id': self.cashier_a.id, 'company_id': self.company_a.id,
        })
        api = self._api(self.cashier_a)
        now = fields.Datetime.now().replace(microsecond=0)
        with self.assertRaises(ValidationError):
            api.hr_attendance_check(check_in=True, timestamp=fields.Datetime.to_string(now + timedelta(hours=1)))
        with self.assertRaises(ValidationError):
            api.hr_attendance_check(check_in=True, timestamp=fields.Datetime.to_string(now - timedelta(days=8)))
        with self.assertRaises(ValidationError):
            api.hr_attendance_check(check_in=True, timestamp='not a date')
        queued = now - timedelta(hours=3)
        res = api.hr_attendance_check(check_in=True, timestamp=fields.Datetime.to_string(queued))
        att = self.env['hr.attendance'].browse(res['id'])
        self.assertEqual(att.check_in, queued)
        self.assertFalse(att.in_latitude, 'No coordinates sent: no default location assumed')
        res = api.hr_attendance_check(check_in=False, latitude=6.9271, longitude=79.8612)
        self.assertEqual(res['status'], 'checked_out')
        self.assertAlmostEqual(att.out_latitude, 6.9271, places=4)

    # ------------------------------------------------------------------
    # Payment registration idempotency
    # ------------------------------------------------------------------
    def test_register_payment_uuid_idempotent(self):
        invoice = self.init_invoice('out_invoice', partner=self.partner_a, products=self.product_tea, post=True)
        api = self._api(self.admin_a)
        half = invoice.amount_total / 2
        first = api.register_invoice_payment(invoice.id, amount=half, uuid='pay-uuid-1')
        self.assertFalse(first['idempotent'])
        self.assertTrue(first['payment_id'])
        self.assertEqual(first['uuid'], 'pay-uuid-1')
        self.assertAlmostEqual(first['amount_residual'], invoice.amount_total - half, places=2)

        replay = api.register_invoice_payment(invoice.id, amount=half, uuid='pay-uuid-1')
        self.assertTrue(replay['idempotent'])
        self.assertEqual(replay['payment_id'], first['payment_id'])
        self.assertAlmostEqual(replay['amount_residual'], first['amount_residual'], places=2)
        self.assertEqual(
            self.env['account.payment'].search_count([('flexerp_client_uuid', '=', 'pay-uuid-1')]), 1,
        )

        other = self.init_invoice('out_invoice', partner=self.partner_a, products=self.product_tea, post=True)
        with self.assertRaises(ValidationError):
            api.register_invoice_payment(other.id, uuid='pay-uuid-1')

        second = api.register_invoice_payment(invoice.id, uuid='pay-uuid-2')
        self.assertFalse(second['idempotent'])
        self.assertNotEqual(second['payment_id'], first['payment_id'])
        self.assertEqual(second['payment_state'] in ('paid', 'in_payment'), True)
