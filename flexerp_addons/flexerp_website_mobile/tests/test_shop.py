# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo.exceptions import AccessError
from odoo.tests import new_test_user, tagged

from odoo.addons.flexerp_website_mobile.controllers.shop import (
    FlexerpWebsiteMobileController,
)
from odoo.addons.website_sale.tests.common import WebsiteSaleCommon


@tagged('post_install', '-at_install')
class TestFlexerpShop(WebsiteSaleCommon):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.company = cls.website.company_id
        cls.shop_user = new_test_user(
            cls.env, login='flex_shop_user', groups='base.group_user',
            company_id=cls.company.id, company_ids=[(6, 0, cls.company.ids)],
        )
        cls.env['flexerp.feature.flag'].sudo().set_mobile_features(cls.company.id, {'website': True})
        cls.controller = FlexerpWebsiteMobileController()

    def test_catalog_and_cart_flow(self):
        with self.mock_request(user=self.shop_user):
            catalog = self.controller.catalog(limit=100)
            self.assertIn(self.product.product_tmpl_id.id, [p['id'] for p in catalog])

            empty = self.controller.cart_state()
            self.assertFalse(empty['order_id'])

            cart = self.controller.cart_add(product_id=self.product.id, qty=2)
            self.assertTrue(cart['order_id'])
            self.assertEqual(len(cart['lines']), 1)
            self.assertEqual(cart['lines'][0]['qty'], 2)

            # adding again (by template id) merges into the same line
            cart = self.controller.cart_add(product_template_id=self.product.product_tmpl_id.id, qty=1)
            self.assertEqual(cart['lines'][0]['qty'], 3)

            line_id = cart['lines'][0]['id']
            cart = self.controller.cart_update(line_id=line_id, qty=1)
            self.assertEqual(cart['lines'][0]['qty'], 1)
            self.assertGreater(cart['amount_total'], 0)

            done = self.controller.checkout()
            self.assertTrue(done['success'])
            self.assertEqual(done['state'], 'sale')

    def test_feature_disabled(self):
        self.env['flexerp.feature.flag'].sudo().set_mobile_features(self.company.id, {'website': False})
        with self.mock_request(user=self.shop_user), self.assertRaises(AccessError):
            self.controller.catalog()
