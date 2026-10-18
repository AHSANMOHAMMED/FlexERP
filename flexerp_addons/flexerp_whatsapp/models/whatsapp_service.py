# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import json
import logging
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

from odoo import api, models

_logger = logging.getLogger(__name__)


class FlexerpWhatsappService(models.AbstractModel):
    _name = 'flexerp.whatsapp.service'
    _description = 'FlexERP WhatsApp Cloud API Service'

    @api.model
    def _config(self):
        ICP = self.env['ir.config_parameter'].sudo()
        return {
            'provider': ICP.get_str('flexerp.whatsapp.provider', 'meta') or 'meta',
            'endpoint': (ICP.get_str('flexerp.whatsapp.endpoint') or 'https://graph.facebook.com/v19.0').strip(),
            'phone_number_id': (ICP.get_str('flexerp.whatsapp.phone_number_id') or '').strip(),
            'token': (ICP.get_str('flexerp.whatsapp.token') or '').strip(),
        }

    @api.model
    def build_wa_me_link(self, phone, message):
        digits = ''.join(c for c in (phone or '') if c.isdigit())
        if digits.startswith('0'):
            digits = '94' + digits[1:]
        text = urlparse.quote(message or '')
        return f'https://wa.me/{digits}?text={text}' if digits else False

    @api.model
    def _send_text(self, phone, message, media_url=None):
        """Send via WhatsApp Cloud API. Private: callers must check access first."""
        cfg = self._config()
        wa_me = self.build_wa_me_link(phone, message)
        if not cfg['phone_number_id'] or not cfg['token']:
            return {
                'ok': False,
                'status': 'not_configured',
                'message': 'WhatsApp Cloud API not configured. Set phone_number_id and token.',
                'wa_me_url': wa_me,
            }
        url = f"{cfg['endpoint'].rstrip('/')}/{cfg['phone_number_id']}/messages"
        digits = ''.join(c for c in (phone or '') if c.isdigit())
        if digits.startswith('0'):
            digits = '94' + digits[1:]
        body = {
            'messaging_product': 'whatsapp',
            'to': digits,
            'type': 'text',
            'text': {'body': message or ''},
        }
        if media_url:
            body = {
                'messaging_product': 'whatsapp',
                'to': digits,
                'type': 'document',
                'document': {'link': media_url, 'caption': message or 'Invoice'},
            }
        headers = {
            'Authorization': f"Bearer {cfg['token']}",
            'Content-Type': 'application/json',
        }
        req = urlrequest.Request(
            url, data=json.dumps(body).encode('utf-8'), headers=headers, method='POST',
        )
        try:
            with urlrequest.urlopen(req, timeout=15) as resp:
                raw = resp.read().decode('utf-8')
                try:
                    data = json.loads(raw)
                except ValueError:
                    data = {'raw': raw}
                return {
                    'ok': True,
                    'status': 'sent',
                    'result': data,
                    'wa_me_url': wa_me,
                }
        except urlerror.HTTPError as e:
            _logger.warning('WhatsApp HTTP error: %s', e)
            return {
                'ok': False,
                'status': 'error',
                'message': f'HTTP {e.code}: {e.reason}',
                'wa_me_url': wa_me,
            }
        except Exception as e:  # noqa: BLE001 - network adapter must never crash the API
            _logger.warning('WhatsApp send failed: %s', e)
            return {
                'ok': False,
                'status': 'unreachable',
                'message': str(e),
                'wa_me_url': wa_me,
            }
