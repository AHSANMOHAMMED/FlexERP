# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import json

from odoo import api, fields, models


class FlexerpLiveEvent(models.Model):
    _name = 'flexerp.live.event'
    _description = 'FlexERP Live Sync Event'
    _order = 'id desc'

    company_id = fields.Many2one('res.company', required=True, index=True, ondelete='cascade')
    event_type = fields.Selection(
        [
            ('sale', 'Sale'),
            ('stock', 'Stock'),
            ('invoice', 'Invoice'),
            ('payment', 'Payment'),
        ],
        required=True,
        index=True,
    )
    payload_json = fields.Text(default='{}')
    create_date = fields.Datetime(readonly=True)

    @api.model
    def emit(self, company_id, event_type, payload=None):
        event = self.sudo().create({
            'company_id': int(company_id),
            'event_type': event_type,
            'payload_json': json.dumps(payload or {}),
        })
        # Best-effort bus notify for web clients
        try:
            self.env['bus.bus']._sendone(
                f'flexerp_slot_{company_id}',
                'flexerp_live',
                {
                    'id': event.id,
                    'type': event_type,
                    'company_id': int(company_id),
                    'payload': payload or {},
                },
            )
        except Exception:
            pass
        # Trim old events (keep last 500 per company)
        old = self.sudo().search([
            ('company_id', '=', int(company_id)),
        ], offset=500, order='id desc')
        if old:
            old.unlink()
        return event

    def to_mobile_dict(self):
        self.ensure_one()
        try:
            payload = json.loads(self.payload_json or '{}')
        except Exception:
            payload = {}
        return {
            'id': self.id,
            'type': self.event_type,
            'company_id': self.company_id.id,
            'payload': payload,
            'ts': fields.Datetime.to_string(self.create_date) if self.create_date else None,
        }
