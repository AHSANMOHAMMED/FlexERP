# Part of FlexERP. See LICENSE file for full copyright and licensing details.

from odoo import models

from .live_event import LIVE_CHANNEL


class IrWebsocket(models.AbstractModel):
    _inherit = 'ir.websocket'

    def _build_bus_channel_list(self, channels):
        # Never honour client-supplied FlexERP string channels (legacy
        # ``flexerp_slot_<id>``): anyone could subscribe to any vendor slot.
        channels = [
            c for c in channels
            if not (isinstance(c, str) and c.startswith(('flexerp_slot_', LIVE_CHANNEL)))
        ]
        channels = super()._build_bus_channel_list(channels)
        user = self.env.user
        if user and not user._is_public() and user._is_internal():
            # Live sync channel only for the vendor slots the user belongs to.
            channels.extend((company, LIVE_CHANNEL) for company in user.company_ids)
        return channels
