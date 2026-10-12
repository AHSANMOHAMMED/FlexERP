# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import api, fields, models

# Canonical keys consumed by flexerp_mobile + flexerp_mobile_api.
FEATURE_KEYS = (
    'pos',
    'inventory',
    'sales',
    'crm',
    'invoicing',
    'payments',
    'warehouse',
    'hr',
    'website',
    'executive',
)

PRESETS = {
    'small_shop': {
        'pos': True,
        'inventory': True,
        'sales': False,
        'crm': False,
        'invoicing': True,
        'payments': True,
        'warehouse': False,
        'hr': False,
        'website': False,
        'executive': False,
    },
    'mall': {
        'pos': True,
        'inventory': True,
        'sales': True,
        'crm': True,
        'invoicing': True,
        'payments': True,
        'warehouse': True,
        'hr': True,
        'website': False,
        'executive': True,
    },
}


class FlexerpFeatureFlag(models.Model):
    _name = 'flexerp.feature.flag'
    _description = 'FlexERP Mobile Feature Flag'
    _rec_name = 'key'
    _order = 'company_id, key'

    company_id = fields.Many2one(
        'res.company',
        required=True,
        ondelete='cascade',
        index=True,
    )
    key = fields.Selection(
        selection=[(k, k.replace('_', ' ').title()) for k in FEATURE_KEYS],
        required=True,
        index=True,
    )
    enabled = fields.Boolean(default=True)
    vendor_code = fields.Char(
        related='company_id.flexerp_vendor_code',
        store=True,
        readonly=True,
    )

    _sql_constraints = [
        (
            'company_key_uniq',
            'unique(company_id, key)',
            'Each company may only have one flag per feature key.',
        ),
    ]

    @api.model
    def ensure_flags_for_company(self, company, preset='small_shop'):
        """Create missing flags for a company using a named preset."""
        company = company or self.env.company
        defaults = PRESETS.get(preset) or PRESETS['small_shop']
        Flag = self.sudo()
        existing = {
            rec.key: rec
            for rec in Flag.search([('company_id', '=', company.id)])
        }
        for key in FEATURE_KEYS:
            if key in existing:
                continue
            Flag.create({
                'company_id': company.id,
                'key': key,
                'enabled': bool(defaults.get(key, False)),
            })
        return Flag.search([('company_id', '=', company.id)])

    @api.model
    def get_mobile_features(self, company_id=None):
        """Return {key: bool} for the given company (defaults to current)."""
        company = self.env['res.company'].browse(company_id) if company_id else self.env.company
        if not company:
            company = self.env.user.company_id
        self.ensure_flags_for_company(company)
        flags = self.sudo().search([('company_id', '=', company.id)])
        result = {key: False for key in FEATURE_KEYS}
        for flag in flags:
            result[flag.key] = bool(flag.enabled)
        return result

    @api.model
    def set_mobile_features(self, company_id, features):
        """Upsert feature map for one company only. Never touches other vendors."""
        company = self.env['res.company'].browse(int(company_id))
        if not company.exists():
            raise ValueError('Company / vendor slot not found.')
        # Platform Super Admin may write any slot; others need company write access.
        user = self.env.user
        is_platform = (
            user.has_group('base.group_system')
            or user.has_group('base.group_erp_manager')
            or user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
        )
        if not is_platform:
            company.check_access('write')
        self.ensure_flags_for_company(company)
        Flag = self.sudo()
        for key, enabled in (features or {}).items():
            if key not in FEATURE_KEYS:
                continue
            flag = Flag.search([
                ('company_id', '=', company.id),
                ('key', '=', key),
            ], limit=1)
            if flag:
                flag.enabled = bool(enabled)
            else:
                Flag.create({
                    'company_id': company.id,
                    'key': key,
                    'enabled': bool(enabled),
                })
        # Always re-read scoped to this company_id only.
        return self.get_mobile_features(company.id)

    @api.model
    def apply_preset(self, company_id, preset):
        if preset not in PRESETS:
            raise ValueError(f'Unknown preset: {preset}')
        return self.set_mobile_features(company_id, PRESETS[preset])
