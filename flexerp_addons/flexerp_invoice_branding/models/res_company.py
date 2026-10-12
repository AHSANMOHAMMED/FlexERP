# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import fields, models


class ResCompany(models.Model):
    _inherit = 'res.company'

    flexerp_seal = fields.Binary(
        string='Shop Seal / Stamp',
        help='Optional seal image stamped on paid invoices.',
        attachment=True,
    )
    flexerp_watermark_enabled = fields.Boolean(
        string='Logo Watermark on Invoices',
        default=True,
    )
