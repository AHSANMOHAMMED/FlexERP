# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import api, fields, models

from .feature_flag import PRESETS


class ResCompany(models.Model):
    _inherit = 'res.company'

    flexerp_vendor_code = fields.Char(
        string='FlexERP Vendor Code',
        help='Stable tenant code used by the mobile app (e.g. VND-001).',
        copy=False,
        index=True,
    )
    flexerp_preset = fields.Selection(
        [
            ('small_shop', 'Small Shop'),
            ('mall', 'Mall / Multi-store'),
            ('custom', 'Custom'),
        ],
        default='small_shop',
        string='FlexERP Preset',
    )
    flexerp_feature_ids = fields.One2many(
        'flexerp.feature.flag',
        'company_id',
        string='Mobile Features',
    )
    flexerp_is_active_vendor = fields.Boolean(
        string='Active FlexERP Vendor',
        default=True,
    )

    @api.model_create_multi
    def create(self, vals_list):
        companies = super().create(vals_list)
        Flag = self.env['flexerp.feature.flag']
        for company in companies:
            if not company.flexerp_vendor_code:
                company.flexerp_vendor_code = f'VND-{company.id:03d}'
            preset = company.flexerp_preset if company.flexerp_preset != 'custom' else 'small_shop'
            Flag.ensure_flags_for_company(company, preset=preset)
        return companies

    def action_apply_flexerp_preset(self):
        Flag = self.env['flexerp.feature.flag']
        for company in self:
            preset = company.flexerp_preset if company.flexerp_preset in PRESETS else 'small_shop'
            Flag.apply_preset(company.id, preset)
        return True

    def get_flexerp_tenant_payload(self):
        self.ensure_one()
        features = self.env['flexerp.feature.flag'].get_mobile_features(self.id)
        return {
            'id': self.id,
            'vendor_id': self.flexerp_vendor_code or f'VND-{self.id:03d}',
            'name': self.name,
            'email': self.email or '',
            'phone': self.phone or '',
            'city': self.city or '',
            'address': self.street or '',
            'tax_tin': self.vat or '',
            'is_active': bool(self.flexerp_is_active_vendor),
            'preset': self.flexerp_preset or 'custom',
            'features': features,
            'cashier_count': self.env['res.users'].sudo().search_count([
                ('company_ids', 'in', self.id),
                ('share', '=', False),
            ]),
        }
