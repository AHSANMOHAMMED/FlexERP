# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import secrets
import string

from odoo import api, models
from odoo.exceptions import AccessError, UserError, ValidationError


class FlexerpVendorSlot(models.AbstractModel):
    _name = 'flexerp.vendor.slot'
    _description = 'FlexERP Vendor Slot Provisioning'

    @api.model
    def _assert_platform_admin(self):
        user = self.env.user
        if not (
            user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
            or user.has_group('base.group_system')
        ):
            raise AccessError(self.env._('Only platform Super Admin can manage vendor slots.'))

    @api.model
    def _assert_company_access(self, company):
        """Reject cross-slot access for non-platform users."""
        user = self.env.user
        if user.has_group('flexerp_vendor_rbac.group_platform_super_admin') or user.has_group('base.group_system'):
            return company
        if not company or company.id not in user.company_ids.ids:
            raise AccessError(self.env._('You cannot access this vendor slot.'))
        return company

    @api.model
    def _random_password(self, length=12):
        alphabet = string.ascii_letters + string.digits
        return ''.join(secrets.choice(alphabet) for _ in range(length))

    @api.model
    def provision_slot(self, vals):
        """Create a vendor company slot + Vendor Admin user.

        vals keys: name, vendor_code, email, phone, city, street, vat, preset,
                   admin_login, admin_name, admin_password (optional)
        """
        self._assert_platform_admin()
        name = (vals.get('name') or '').strip()
        if not name:
            raise ValidationError(self.env._('Vendor name is required.'))

        vendor_code = (vals.get('vendor_code') or '').strip().upper()
        Company = self.env['res.company'].sudo()
        if vendor_code:
            if Company.with_context(active_test=False).search_count([('flexerp_vendor_code', '=', vendor_code)]):
                raise ValidationError(f'Vendor code {vendor_code} already exists.')
        # Empty code: res.company.create assigns a unique VND-<id> code.

        preset = vals.get('preset') or 'small_shop'
        if preset not in ('small_shop', 'mall', 'custom'):
            preset = 'small_shop'

        company = Company.create({
            'name': name,
            'email': vals.get('email') or False,
            'phone': vals.get('phone') or False,
            'city': vals.get('city') or False,
            'street': vals.get('street') or vals.get('address') or False,
            'vat': vals.get('vat') or vals.get('tax_tin') or False,
            'flexerp_vendor_code': vendor_code or False,
            'flexerp_preset': preset if preset != 'custom' else 'small_shop',
            'flexerp_is_active_vendor': True,
        })
        if preset in ('small_shop', 'mall'):
            self.env['flexerp.feature.flag'].apply_preset(company.id, preset)
        else:
            self.env['flexerp.feature.flag'].ensure_flags_for_company(company, preset='small_shop')
            if vals.get('features'):
                self.env['flexerp.feature.flag'].set_mobile_features(company.id, vals['features'])

        vendor_code = company.flexerp_vendor_code
        admin_login = (vals.get('admin_login') or vals.get('email') or f'admin@{vendor_code.lower()}.lk').strip()
        admin_name = vals.get('admin_name') or f'{name} Admin'
        admin_password = vals.get('admin_password') or self._random_password()

        partner = self.env['res.partner'].sudo().create({
            'name': admin_name,
            'email': admin_login,
            'company_id': company.id,
        })
        user = self.env['res.users'].sudo().with_context(no_reset_password=True).create({
            'name': admin_name,
            'login': admin_login,
            'password': admin_password,
            'partner_id': partner.id,
            'company_id': company.id,
            'company_ids': [(6, 0, [company.id])],
            'group_ids': [(6, 0, [
                self.env.ref('flexerp_vendor_rbac.group_vendor_admin').id,
            ])],
        })

        return {
            'company': company.get_flexerp_tenant_payload(),
            'admin_user': {
                'id': user.id,
                'login': user.login,
                'name': user.name,
                'role': 'vendorAdmin',
                'temporary_password': admin_password if not vals.get('admin_password') else None,
            },
        }

    @api.model
    def deactivate_slot(self, company_id):
        self._assert_platform_admin()
        company = self.env['res.company'].sudo().browse(int(company_id))
        if not company.exists():
            raise UserError(self.env._('Vendor slot not found.'))
        company.flexerp_is_active_vendor = False
        return company.get_flexerp_tenant_payload()

    @api.model
    def list_slot_users(self, company_id):
        company = self.env['res.company'].browse(int(company_id))
        user = self.env.user
        is_platform = (
            user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
            or user.has_group('base.group_system')
        )
        is_vendor_admin = user.has_group('flexerp_vendor_rbac.group_vendor_admin')
        if not is_platform:
            if not is_vendor_admin:
                raise AccessError(self.env._('Not allowed to list users.'))
            self._assert_company_access(company)
        users = self.env['res.users'].sudo().search([
            ('company_ids', 'in', company.id),
            ('share', '=', False),
            ('active', '=', True),
        ])
        result = []
        for u in users:
            role = 'employee'
            if u.has_group('flexerp_vendor_rbac.group_platform_super_admin') or u.has_group('base.group_system'):
                if not is_platform:
                    # Platform operators are not part of a vendor's staff list.
                    continue
                role = 'superAdmin'
            elif u.has_group('flexerp_vendor_rbac.group_vendor_admin'):
                role = 'vendorAdmin'
            elif u.has_group('flexerp_vendor_rbac.group_vendor_cashier') or u.has_group('point_of_sale.group_pos_user'):
                role = 'posCashier'
            result.append({
                'id': u.id,
                'name': u.name,
                'login': u.login,
                'email': u.email or u.login,
                'role': role,
                'company_id': company.id,
                'active': u.active,
            })
        return result

    @api.model
    def create_slot_user(self, company_id, vals):
        """Create Vendor Admin or Cashier in a slot."""
        company = self.env['res.company'].browse(int(company_id))
        user = self.env.user
        is_platform = (
            user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
            or user.has_group('base.group_system')
        )
        is_vendor_admin = user.has_group('flexerp_vendor_rbac.group_vendor_admin')
        if not is_platform:
            if not is_vendor_admin:
                raise AccessError(self.env._('Not allowed to create users.'))
            self._assert_company_access(company)

        role = vals.get('role') or 'posCashier'
        login = (vals.get('login') or vals.get('email') or '').strip()
        name = (vals.get('name') or login).strip()
        if not login or not name:
            raise ValidationError(self.env._('login and name are required.'))
        password = vals.get('password') or self._random_password()

        if role == 'vendorAdmin':
            group = self.env.ref('flexerp_vendor_rbac.group_vendor_admin')
        else:
            group = self.env.ref('flexerp_vendor_rbac.group_vendor_cashier')
            role = 'posCashier'

        partner = self.env['res.partner'].sudo().create({
            'name': name,
            'email': login,
            'company_id': company.id,
        })
        new_user = self.env['res.users'].sudo().with_context(no_reset_password=True).create({
            'name': name,
            'login': login,
            'password': password,
            'partner_id': partner.id,
            'company_id': company.id,
            'company_ids': [(6, 0, [company.id])],
            'group_ids': [(6, 0, [group.id])],
        })
        return {
            'id': new_user.id,
            'name': new_user.name,
            'login': new_user.login,
            'role': role,
            'company_id': company.id,
            'temporary_password': password if not vals.get('password') else None,
        }

    @api.model
    def set_slot_user_active(self, user_id, active=True):
        target = self.env['res.users'].sudo().browse(int(user_id))
        if not target.exists():
            raise UserError(self.env._('User not found.'))
        company = target.company_id
        user = self.env.user
        is_platform = (
            user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
            or user.has_group('base.group_system')
        )
        if not is_platform:
            if not user.has_group('flexerp_vendor_rbac.group_vendor_admin'):
                raise AccessError(self.env._('Not allowed.'))
            self._assert_company_access(company)
        if target.has_group('base.group_system') and not is_platform:
            raise AccessError(self.env._('Cannot modify platform administrators.'))
        target.active = bool(active)
        return {'id': target.id, 'active': target.active}
