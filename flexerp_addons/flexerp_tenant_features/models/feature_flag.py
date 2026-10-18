# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import api, fields, models
from odoo.exceptions import AccessError

# Canonical keys consumed by flexerp_mobile + flexerp_mobile_api.
# Each key is independently toggleable — no key requires another.
FEATURE_KEYS = (
    'pos',
    'inventory',
    'sales',
    'crm',
    'invoicing',
    'payments',
    'warehouse',
    'purchase',
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
        'purchase': False,
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
        'purchase': True,
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

    _company_key_uniq = models.Constraint(
        'unique(company_id, key)',
        'Each company may only have one flag per feature key.',
    )

    @api.model
    def _is_platform_admin(self):
        """Platform Super Admin (or system admin, implied by it).

        ``base.group_erp_manager`` is intentionally NOT a platform admin.
        """
        if self.env.su:
            return True
        user = self.env.user
        if user.has_group('base.group_system'):
            return True
        group = self.env.ref('flexerp_vendor_rbac.group_platform_super_admin', raise_if_not_found=False)
        return bool(group) and user.has_group('flexerp_vendor_rbac.group_platform_super_admin')

    @api.model
    def _check_company_allowed(self, company):
        """Only platform admins may read/write flags of companies they don't belong to."""
        if not company or not company.exists():
            raise AccessError(self.env._('Company / vendor slot not found.'))
        if self._is_platform_admin():
            return company
        if company.id not in self.env.user.company_ids.ids:
            raise AccessError(self.env._('You cannot access feature flags of this vendor slot.'))
        return company

    @api.model
    def ensure_flags_for_company(self, company, preset='small_shop'):
        """Create missing flags for a company using a named preset."""
        company = company or self.env.company
        self._check_company_allowed(company)
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
        company = self.env['res.company'].browse(int(company_id)) if company_id else self.env.company
        if not company:
            company = self.env.user.company_id
        self._check_company_allowed(company)
        # Read-only: missing flags fall back to the company preset defaults
        # (no write, so this is safe in readonly routes).
        preset = company.sudo().flexerp_preset
        defaults = PRESETS.get(preset) or PRESETS['small_shop']
        result = {key: bool(defaults.get(key, False)) for key in FEATURE_KEYS}
        flags = self.sudo().search([('company_id', '=', company.id)])
        for flag in flags:
            result[flag.key] = bool(flag.enabled)
        return result

    @api.model
    def set_mobile_features(self, company_id, features):
        """Upsert feature map for one company only. Never touches other vendors."""
        company = self.env['res.company'].browse(int(company_id))
        if not company.exists():
            raise ValueError(self.env._('Company / vendor slot not found.'))
        # Platform Super Admin may write any slot; others need membership + company write access.
        if not self._is_platform_admin():
            self._check_company_allowed(company)
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
