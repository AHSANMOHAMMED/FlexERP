# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import http
from odoo.http import request, route


class FlexerpOpsController(http.Controller):

    def _ops(self):
        return request.env['flexerp.ops.service']

    @route('/flexerp/mobile/ops/overview', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def overview(self, **kwargs):
        return self._ops().overview()

    @route('/flexerp/mobile/ops/wake', type='jsonrpc', auth='user', methods=['POST'])
    def wake(self, **kwargs):
        return self._ops().wake()

    @route('/flexerp/mobile/ops/restart', type='jsonrpc', auth='user', methods=['POST'])
    def restart(self, **kwargs):
        return self._ops().restart()

    @route('/flexerp/mobile/ops/stop', type='jsonrpc', auth='user', methods=['POST'])
    def stop(self, **kwargs):
        return self._ops().stop()

    @route('/flexerp/mobile/ops/pool', type='jsonrpc', auth='user', readonly=True, methods=['POST'])
    def pool(self, **kwargs):
        return self._ops().pool_stats()
