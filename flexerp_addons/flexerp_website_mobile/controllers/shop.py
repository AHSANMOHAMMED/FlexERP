# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import http
from odoo.exceptions import AccessError
from odoo.http import request, route


class FlexerpWebsiteMobileController(http.Controller):

    def _require_website_feature(self):
        features = request.env['flexerp.feature.flag'].get_mobile_features(request.env.company.id)
        if not features.get('website'):
            raise AccessError('Website feature is disabled for this vendor.')

    @route('/flexerp/mobile/shop/catalog', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def catalog(self, limit=40, search=None, category_id=None, **kwargs):
        self._require_website_feature()
        Product = request.env['product.template']
        domain = [('is_published', '=', True), ('sale_ok', '=', True)]
        if search:
            domain.append(('name', 'ilike', search))
        if category_id:
            domain.append(('public_categ_ids', 'in', [int(category_id)]))
        products = Product.search(domain, limit=int(limit or 40))
        return [{
            'id': p.id,
            'name': p.name,
            'list_price': p.list_price,
            'description': p.description_sale or '',
            'website_url': p.website_url,
        } for p in products]

    @route('/flexerp/mobile/shop/cart', type='jsonrpc', auth='user', methods=['POST'])
    def cart_state(self, **kwargs):
        self._require_website_feature()
        order = request.website.sale_get_order()
        if not order:
            return {'order_id': False, 'lines': [], 'amount_total': 0.0}
        return {
            'order_id': order.id,
            'amount_total': order.amount_total,
            'lines': [{
                'id': line.id,
                'product_id': line.product_id.id,
                'name': line.name,
                'qty': line.product_uom_qty,
                'price_unit': line.price_unit,
                'price_subtotal': line.price_subtotal,
            } for line in order.order_line],
        }

    @route('/flexerp/mobile/shop/cart/add', type='jsonrpc', auth='user', methods=['POST'])
    def cart_add(self, product_id=None, qty=1.0, **kwargs):
        self._require_website_feature()
        order = request.website.sale_get_order(force_create=True)
        product = request.env['product.product'].browse(int(product_id))
        if not product.exists():
            product = request.env['product.template'].browse(int(product_id)).product_variant_id
        order._cart_update(product_id=product.id, add_qty=float(qty or 1.0))
        return self.cart_state()

    @route('/flexerp/mobile/shop/cart/update', type='jsonrpc', auth='user', methods=['POST'])
    def cart_update(self, line_id=None, qty=1.0, **kwargs):
        self._require_website_feature()
        order = request.website.sale_get_order()
        if not order:
            return {'order_id': False, 'lines': [], 'amount_total': 0.0}
        line = order.order_line.filtered(lambda l: l.id == int(line_id))
        if line:
            order._cart_update(product_id=line.product_id.id, line_id=line.id, set_qty=float(qty or 0.0))
        return self.cart_state()

    @route('/flexerp/mobile/shop/checkout', type='jsonrpc', auth='user', methods=['POST'])
    def checkout(self, **kwargs):
        self._require_website_feature()
        order = request.website.sale_get_order()
        if not order or not order.order_line:
            return {'success': False, 'error': 'Cart is empty'}
        # Confirm as quotation; payment gateway flows stay on website for now
        if order.state in ('draft', 'sent'):
            order.action_confirm()
        return {
            'success': True,
            'order_id': order.id,
            'name': order.name,
            'state': order.state,
            'amount_total': order.amount_total,
        }
