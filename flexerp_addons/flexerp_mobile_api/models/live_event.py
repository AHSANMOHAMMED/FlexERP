# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import json
import logging

from odoo import api, fields, models

_logger = logging.getLogger(__name__)

# Bus notification type; the channel is the (res.company, LIVE_CHANNEL) record
# channel so clients cannot subscribe to other vendor slots by guessing a string.
LIVE_CHANNEL = 'flexerp_live'


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
    def _emit(self, company_id, event_type, payload=None):
        """Record a live event for one vendor slot and notify its bus channel.

        Private: only server-side facades (after their own access checks) emit.
        """
        company = self.env['res.company'].browse(int(company_id))
        event = self.sudo().create({
            'company_id': company.id,
            'event_type': event_type,
            'payload_json': json.dumps(payload or {}),
        })
        # Best-effort bus notify for web clients subscribed to this company.
        try:
            self.env['bus.bus'].sudo()._sendone(
                (company, LIVE_CHANNEL),
                LIVE_CHANNEL,
                {
                    'id': event.id,
                    'type': event_type,
                    'company_id': company.id,
                    'payload': payload or {},
                },
            )
        except Exception:  # noqa: BLE001
            _logger.debug('FlexERP live bus notify failed', exc_info=True)
        # Trim old events (keep last 500 per company)
        old = self.sudo().search([
            ('company_id', '=', company.id),
        ], offset=500, order='id desc')
        if old:
            old.unlink()
        return event

    @api.model
    def _max_event_id(self, company_ids):
        """Highest event id for the given companies (0 when none)."""
        if not company_ids:
            return 0
        last = self.sudo().search([('company_id', 'in', list(company_ids))], limit=1, order='id desc')
        return last.id or 0

    def to_mobile_dict(self):
        self.ensure_one()
        try:
            payload = json.loads(self.payload_json or '{}')
        except ValueError:
            payload = {}
        return {
            'id': self.id,
            'type': self.event_type,
            'company_id': self.company_id.id,
            'payload': payload,
            'ts': fields.Datetime.to_string(self.create_date) if self.create_date else None,
        }
