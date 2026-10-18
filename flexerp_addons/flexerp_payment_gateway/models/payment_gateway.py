# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import json
import logging
import uuid
from urllib import error as urlerror
from urllib import request as urlrequest

from odoo import api, fields, models

_logger = logging.getLogger(__name__)


class FlexerpPaymentLink(models.Model):
    _name = 'flexerp.payment.link'
    _description = 'FlexERP Pay Link'
    _order = 'id desc'

    name = fields.Char(required=True, index=True)
    company_id = fields.Many2one('res.company', required=True, index=True)
    amount = fields.Float(required=True)
    currency_name = fields.Char(default='LKR')
    order_ref = fields.Char(index=True)
    pay_url = fields.Char()
    status = fields.Selection(
        [
            ('pending', 'Pending'),
            ('paid', 'Paid'),
            ('failed', 'Failed'),
            ('expired', 'Expired'),
        ],
        default='pending',
        index=True,
    )
    provider = fields.Char(default='lankaqr_stub')
    external_ref = fields.Char()


class FlexerpPaymentGateway(models.AbstractModel):
    _name = 'flexerp.payment.gateway'
    _description = 'FlexERP LankaQR / JustPay Gateway'

    @api.model
    def _config(self):
        ICP = self.env['ir.config_parameter'].sudo()
        return {
            'provider': ICP.get_param('flexerp.payment.provider', 'lankaqr_stub') or 'lankaqr_stub',
            'endpoint': (ICP.get_param('flexerp.payment.endpoint') or '').strip(),
            'merchant_id': (ICP.get_param('flexerp.payment.merchant_id') or '').strip(),
            'secret': (ICP.get_param('flexerp.payment.secret') or '').strip(),
        }

    @api.model
    def create_pay_link(self, amount, order_ref=None, return_url=None, company=None):
        company = company or self.env.company
        cfg = self._config()
        reference = f'FLX-{uuid.uuid4().hex[:12].upper()}'
        if not cfg['endpoint'] and cfg['provider'] in ('justpay', 'lankaqr'):
            return {
                'ok': False,
                'status': 'not_configured',
                'message': 'Payment gateway endpoint not configured.',
                'reference': reference,
            }

        # Stub / local link when endpoint empty (demo-safe)
        if not cfg['endpoint']:
            pay_url = f'flexerp://pay/{reference}?amount={amount}&ref={order_ref or ""}'
            link = self.env['flexerp.payment.link'].sudo().create({
                'name': reference,
                'company_id': company.id,
                'amount': float(amount),
                'order_ref': order_ref or '',
                'pay_url': pay_url,
                'status': 'pending',
                'provider': cfg['provider'],
                'external_ref': reference,
            })
            return {
                'ok': True,
                'status': 'pending',
                'reference': link.name,
                'pay_url': pay_url,
                'amount': link.amount,
                'currency': link.currency_name or company.currency_id.name or 'LKR',
                'provider': cfg['provider'],
                'mode': 'stub',
                'message': 'Stub pay link (configure endpoint for live LankaQR/JustPay).',
            }

        payload = {
            'merchant_id': cfg['merchant_id'],
            'amount': float(amount),
            'currency': 'LKR',
            'order_ref': order_ref or reference,
            'return_url': return_url or '',
            'reference': reference,
        }
        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Merchant-Secret': cfg['secret'],
        }
        url = cfg['endpoint'].rstrip('/') + '/paylinks'
        req = urlrequest.Request(
            url, data=json.dumps(payload).encode('utf-8'), headers=headers, method='POST',
        )
        try:
            with urlrequest.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode('utf-8'))
            pay_url = data.get('pay_url') or data.get('url') or ''
            link = self.env['flexerp.payment.link'].sudo().create({
                'name': data.get('reference') or reference,
                'company_id': company.id,
                'amount': float(amount),
                'order_ref': order_ref or '',
                'pay_url': pay_url,
                'status': 'pending',
                'provider': cfg['provider'],
                'external_ref': data.get('external_ref') or reference,
            })
            return {
                'ok': True,
                'status': 'pending',
                'reference': link.name,
                'pay_url': pay_url,
                'amount': link.amount,
                'currency': link.currency_name or company.currency_id.name or 'LKR',
                'provider': cfg['provider'],
                'mode': 'live',
            }
        except Exception as e:
            _logger.warning('Pay link create failed: %s', e)
            return {
                'ok': False,
                'status': 'error',
                'message': str(e),
                'reference': reference,
            }

    @api.model
    def link_status(self, reference, mark_paid=False):
        cfg = self._config()
        link = self.env['flexerp.payment.link'].sudo().search([('name', '=', reference)], limit=1)
        if not link:
            return {'ok': False, 'status': 'not_found', 'reference': reference}

        if mark_paid and link.status == 'pending':
            link.status = 'paid'

        if cfg['endpoint'] and link.status == 'pending':
            url = cfg['endpoint'].rstrip('/') + f'/paylinks/{link.external_ref or link.name}'
            headers = {'Accept': 'application/json', 'X-Merchant-Secret': cfg['secret']}
            req = urlrequest.Request(url, headers=headers, method='GET')
            try:
                with urlrequest.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read().decode('utf-8'))
                remote = (data.get('status') or '').lower()
                if remote in ('paid', 'success', 'completed'):
                    link.status = 'paid'
                elif remote in ('failed', 'cancelled'):
                    link.status = 'failed'
            except urlerror.HTTPError:
                pass
            except Exception as e:
                _logger.debug('Pay status poll: %s', e)

        return {
            'ok': True,
            'status': link.status,
            'reference': link.name,
            'pay_url': link.pay_url,
            'amount': link.amount,
            'currency': link.currency_name or (link.company_id.currency_id.name if link.company_id.currency_id else 'LKR'),
            'provider': link.provider,
            'endpoint_configured': bool(cfg['endpoint']),
        }
