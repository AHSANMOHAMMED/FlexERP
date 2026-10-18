# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import fields, models


class AccountPayment(models.Model):
    _inherit = 'account.payment'

    flexerp_client_uuid = fields.Char(
        string='FlexERP Client UUID',
        index='btree_not_null',
        copy=False,
        readonly=True,
        help='Idempotency key sent by the FlexERP mobile app for offline/retried payments.',
    )

    _flexerp_client_uuid_company_uniq = models.Constraint(
        'unique(company_id, flexerp_client_uuid)',
        'A payment with this client UUID already exists for this company.',
    )
