# Part of FlexERP. See LICENSE file for full copyright and licensing details.

import json
import logging
from urllib import error as urlerror
from urllib import request as urlrequest

from odoo import api, fields, models
from odoo.exceptions import AccessError

_logger = logging.getLogger(__name__)


class FlexerpOpsService(models.AbstractModel):
    _name = 'flexerp.ops.service'
    _description = 'FlexERP Ops Control Service'

    @api.model
    def _assert_platform_admin(self):
        user = self.env.user
        if not (
            user.has_group('base.group_system')
            or user.has_group('flexerp_vendor_rbac.group_platform_super_admin')
        ):
            raise AccessError('Only platform Super Admin can control ops.')

    @api.model
    def _config(self):
        ICP = self.env['ir.config_parameter'].sudo()
        return {
            'provider_type': ICP.get_param('flexerp.ops.provider_type', 'docker') or 'docker',
            'endpoint': (ICP.get_param('flexerp.ops.endpoint') or '').strip(),
            'token': (ICP.get_param('flexerp.ops.token') or '').strip(),
            'workers': ICP.get_param('flexerp.ops.workers', '4'),
            'db_maxconn': ICP.get_param('flexerp.ops.db_maxconn', '64'),
        }

    @api.model
    def _call_provider(self, action, cfg=None):
        cfg = cfg or self._config()
        endpoint = cfg['endpoint']
        if not endpoint:
            return {
                'ok': False,
                'status': 'not_configured',
                'message': 'Ops endpoint not configured. Set flexerp.ops.endpoint after deployment.',
                'provider_type': cfg['provider_type'],
            }
        url = endpoint.rstrip('/') + f'/{action}'
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
        if cfg['token']:
            headers['Authorization'] = f'Bearer {cfg["token"]}'
        payload = json.dumps({
            'provider_type': cfg['provider_type'],
            'action': action,
            'timestamp': fields.Datetime.now().isoformat(),
        }).encode('utf-8')
        req = urlrequest.Request(url, data=payload, headers=headers, method='POST')
        try:
            with urlrequest.urlopen(req, timeout=12) as resp:
                body = resp.read().decode('utf-8')
                try:
                    data = json.loads(body)
                except Exception:
                    data = {'raw': body}
                return {
                    'ok': True,
                    'status': 'ok',
                    'provider_type': cfg['provider_type'],
                    'action': action,
                    'result': data,
                }
        except urlerror.HTTPError as e:
            _logger.warning('Ops provider HTTP error: %s', e)
            return {
                'ok': False,
                'status': 'error',
                'provider_type': cfg['provider_type'],
                'message': f'HTTP {e.code}: {e.reason}',
            }
        except Exception as e:
            _logger.warning('Ops provider call failed: %s', e)
            return {
                'ok': False,
                'status': 'unreachable',
                'provider_type': cfg['provider_type'],
                'message': str(e),
            }

    @api.model
    def overview(self):
        self._assert_platform_admin()
        cfg = self._config()
        db_name = self.env.cr.dbname
        company_count = self.env['res.company'].sudo().search_count([
            ('flexerp_is_active_vendor', '=', True),
        ])
        user_count = self.env['res.users'].sudo().search_count([
            ('share', '=', False),
            ('active', '=', True),
        ])
        provider = self._call_provider('health', cfg) if cfg['endpoint'] else {
            'ok': False,
            'status': 'not_configured',
            'provider_type': cfg['provider_type'],
            'message': 'Ops endpoint not configured.',
        }
        return {
            'server_time': fields.Datetime.now().isoformat(),
            'database': db_name,
            'active_vendor_slots': company_count,
            'active_users': user_count,
            'provider': provider,
            'pool': self.pool_stats(internal=True),
            'odoo_online': True,
        }

    @api.model
    def wake(self):
        self._assert_platform_admin()
        return self._call_provider('wake')

    @api.model
    def restart(self):
        self._assert_platform_admin()
        return self._call_provider('restart')

    @api.model
    def stop(self):
        self._assert_platform_admin()
        return self._call_provider('stop')

    @api.model
    def pool_stats(self, internal=False):
        if not internal:
            self._assert_platform_admin()
        cfg = self._config()
        return {
            'workers_configured': int(cfg['workers'] or 0),
            'db_maxconn_configured': int(cfg['db_maxconn'] or 0),
            'provider_type': cfg['provider_type'],
            'endpoint_configured': bool(cfg['endpoint']),
            'note': 'Wire PgBouncer + Odoo workers at deploy time; values come from ir.config_parameter.',
        }
