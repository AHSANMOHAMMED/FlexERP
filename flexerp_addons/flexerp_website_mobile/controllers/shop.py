# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import http
from odoo.exceptions import AccessError, UserError
from odoo.fields import Domain
from odoo.http import request, route


class FlexerpWebsiteMobileController(http.Controller):
    """JSON storefront facade on top of the website_sale cart API.

    All routes run in the website context (``website=True``) so that
    ``request.env.website`` / ``request.cart`` are resolved by website_sale.
    """

    def _require_website_feature(self):
        company = request.env.website.company_id
        # get_mobile_features also rejects companies the user does not belong to.
        features = request.env['flexerp.feature.flag'].get_mobile_features(company.id)
        if not features.get('website'):
            raise AccessError(request.env._('Website feature is disabled for this vendor.'))

    @staticmethod
    def _cart_payload(order_sudo):
        if not order_sudo:
            return {'order_id': False, 'name': False, 'lines': [], 'amount_total': 0.0, 'amount_tax': 0.0}
        return {
            'order_id': order_sudo.id,
            'name': order_sudo.name,
            'amount_untaxed': order_sudo.amount_untaxed,
            'amount_tax': order_sudo.amount_tax,
            'amount_total': order_sudo.amount_total,
            'currency': order_sudo.currency_id.name,
            'lines': [{
                'id': line.id,
                'product_id': line.product_id.id,
                'name': line.name,
                'qty': line.product_uom_qty,
                'price_unit': line.price_unit,
                'price_subtotal': line.price_subtotal,
                'price_total': line.price_total,
            } for line in order_sudo.order_line],
        }

    @route('/flexerp/mobile/shop/catalog', type='jsonrpc', auth='user', website=True, readonly=True, methods=['POST'])
    def catalog(self, limit=40, search=None, category_id=None, **kwargs):
        self._require_website_feature()
        website = request.env.website
        domain = Domain.AND([
            website.sale_product_domain(),
            [('is_published', '=', True), ('sale_ok', '=', True)],
        ])
        if search:
            domain &= Domain('name', 'ilike', search)
        if category_id:
            domain &= Domain('public_categ_ids', 'child_of', int(category_id))
        products = request.env['product.template'].search(domain, limit=int(limit or 40))
        return [{
            'id': p.id,
            'product_id': p.product_variant_id.id,
            'name': p.name,
            'list_price': p.list_price,
            'description': p.description_sale or '',
            'website_url': p.website_url,
        } for p in products]

    @route('/flexerp/mobile/shop/cart', type='jsonrpc', auth='user', website=True, methods=['POST'])
    def cart_state(self, **kwargs):
        self._require_website_feature()
        return self._cart_payload(request.cart)

    @route('/flexerp/mobile/shop/cart/add', type='jsonrpc', auth='user', website=True, methods=['POST'])
    def cart_add(self, product_id=None, qty=1.0, product_template_id=None, **kwargs):
        """Add to cart. ``product_id`` is a product.product id (catalog ``product_id``);
        alternatively pass ``product_template_id`` (catalog ``id``).
        """
        self._require_website_feature()
        if product_template_id:
            product = request.env['product.template'].browse(int(product_template_id)).exists().product_variant_id
        else:
            product = request.env['product.product'].browse(int(product_id or 0)).exists()
        if not product or not product._is_add_to_cart_allowed():
            raise UserError(request.env._('This product cannot be added to the cart.'))
        quantity = float(qty or 1.0)
        if quantity <= 0:
            raise UserError(request.env._('Quantity must be positive.'))
        order_sudo = request.cart or request.env.website._create_cart()
        values = order_sudo._cart_add(product_id=product.id, quantity=quantity)
        result = self._cart_payload(order_sudo)
        result['warning'] = values.get('warning') or False
        return result

    @route('/flexerp/mobile/shop/cart/update', type='jsonrpc', auth='user', website=True, methods=['POST'])
    def cart_update(self, line_id=None, qty=1.0, **kwargs):
        self._require_website_feature()
        order_sudo = request.cart
        if not order_sudo:
            return self._cart_payload(order_sudo)
        # 0 (or less) removes the line, like the website cart page.
        values = order_sudo._cart_update_line_quantity(int(line_id or 0), max(float(qty or 0.0), 0.0))
        result = self._cart_payload(order_sudo)
        result['warning'] = values.get('warning') or False
        return result

    @route('/flexerp/mobile/shop/checkout', type='jsonrpc', auth='user', website=True, methods=['POST'])
    def checkout(self, **kwargs):
        self._require_website_feature()
        order_sudo = request.cart
        if not order_sudo or not order_sudo.order_line:
            return {'success': False, 'error': 'Cart is empty'}
        # Confirm the order; online payment flows stay on the website for now.
        if order_sudo.state in ('draft', 'sent'):
            order_sudo.action_confirm()
        request.env.website.sale_reset()
        return {
            'success': True,
            'order_id': order_sudo.id,
            'name': order_sudo.name,
            'state': order_sudo.state,
            'amount_total': order_sudo.amount_total,
        }
