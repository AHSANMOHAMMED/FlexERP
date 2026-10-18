# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP Ops Control',
    'version': '20.0.1.0.0',
    'category': 'Hidden/Tools',
    'summary': 'Super Admin ops overview, wake/restart, pool stats (Docker + Cloud adapters)',
    'depends': [
        'flexerp_vendor_rbac',
        'flexerp_mobile_api',
    ],
    'data': [
        'data/ops_parameters.xml',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
