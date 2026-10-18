# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo.exceptions import AccessError, ValidationError
from odoo.tests import TransactionCase, new_test_user, tagged


@tagged('post_install', '-at_install')
class TestVendorSlot(TransactionCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.platform_admin = new_test_user(
            cls.env, login='flex_platform', groups='flexerp_vendor_rbac.group_platform_super_admin',
        )
        cls.Slot = cls.env['flexerp.vendor.slot'].with_user(cls.platform_admin)

    def test_provision_slots_unique_codes(self):
        first = self.Slot.provision_slot({'name': 'Kandy Spices', 'admin_login': 'kandy@example.lk'})
        second = self.Slot.provision_slot({'name': 'Galle Fabrics', 'admin_login': 'galle@example.lk'})
        codes = {first['company']['vendor_id'], second['company']['vendor_id']}
        self.assertEqual(len(codes), 2, 'Auto vendor codes must not collide')
        self.assertTrue(all(code.startswith('VND-') for code in codes))

        admin = self.env['res.users'].browse(first['admin_user']['id'])
        self.assertTrue(admin.has_group('flexerp_vendor_rbac.group_vendor_admin'))
        self.assertEqual(admin.company_ids.ids, [first['company']['id']])
        self.assertTrue(first['admin_user']['temporary_password'])

        with self.assertRaises(ValidationError):
            self.Slot.provision_slot({
                'name': 'Duplicate', 'vendor_code': first['company']['vendor_id'],
                'admin_login': 'dup@example.lk',
            })

    def test_vendor_code_db_uniqueness(self):
        company = self.env['res.company'].create({'name': 'Code Owner', 'flexerp_vendor_code': 'VND-UNIQ'})
        self.assertEqual(company.flexerp_vendor_code, 'VND-UNIQ')
        # A company whose id-based code is already taken still gets a unique one.
        nxt = self.env['res.company'].create({'name': 'Next'})
        clash = self.env['res.company'].create({'name': 'Clash', 'flexerp_vendor_code': f'VND-{nxt.id + 1:03d}'})
        auto = self.env['res.company'].create({'name': 'Auto'})
        self.assertNotEqual(auto.flexerp_vendor_code, clash.flexerp_vendor_code)

    def test_vendor_admin_scope(self):
        res = self.Slot.provision_slot({'name': 'Jaffna Books', 'admin_login': 'jaffna@example.lk'})
        vendor_admin = self.env['res.users'].browse(res['admin_user']['id'])
        Slot = self.env['flexerp.vendor.slot'].with_user(vendor_admin)
        with self.assertRaises(AccessError):
            Slot.provision_slot({'name': 'Rogue'})
        other = self.Slot.provision_slot({'name': 'Matara Fish', 'admin_login': 'matara@example.lk'})
        with self.assertRaises(AccessError):
            Slot.list_slot_users(other['company']['id'])
        with self.assertRaises(AccessError):
            Slot.create_slot_user(other['company']['id'], {'login': 'x@example.lk', 'name': 'X'})
        cashier = Slot.create_slot_user(res['company']['id'], {'login': 'cash@example.lk', 'name': 'Cash'})
        self.assertEqual(cashier['role'], 'posCashier')
        users = Slot.list_slot_users(res['company']['id'])
        self.assertEqual({u['role'] for u in users}, {'vendorAdmin', 'posCashier'})
