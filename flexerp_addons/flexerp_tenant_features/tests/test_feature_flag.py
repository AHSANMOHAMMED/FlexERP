# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from psycopg2.errors import UniqueViolation

from odoo.tests import TransactionCase, tagged
from odoo.tools import mute_logger

from odoo.addons.flexerp_tenant_features.models.feature_flag import (
    FEATURE_KEYS,
    PRESETS,
)


@tagged('post_install', '-at_install')
class TestFeatureFlag(TransactionCase):

    def test_company_create_seeds_flags_and_code(self):
        company = self.env['res.company'].create({'name': 'Flag Shop', 'flexerp_preset': 'mall'})
        flags = self.env['flexerp.feature.flag'].search([('company_id', '=', company.id)])
        self.assertEqual(set(flags.mapped('key')), set(FEATURE_KEYS))
        self.assertEqual(self.env['flexerp.feature.flag'].get_mobile_features(company.id), PRESETS['mall'])
        self.assertTrue(company.flexerp_vendor_code.startswith('VND-'))

    def test_get_mobile_features_is_read_only(self):
        company = self.env['res.company'].create({'name': 'No Flags Yet'})
        Flag = self.env['flexerp.feature.flag']
        Flag.search([('company_id', '=', company.id)]).unlink()
        features = Flag.get_mobile_features(company.id)
        self.assertEqual(features, PRESETS['small_shop'])
        self.assertFalse(Flag.search_count([('company_id', '=', company.id)]), 'No write on read')

    def test_unique_flag_per_company(self):
        company = self.env['res.company'].create({'name': 'Dup Flags'})
        with mute_logger('odoo.sql_db'), self.assertRaises(UniqueViolation), self.cr.savepoint():
            self.env['flexerp.feature.flag'].create({'company_id': company.id, 'key': 'pos'})
