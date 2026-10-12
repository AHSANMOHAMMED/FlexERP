# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP WhatsApp',
    'version': '20.0.1.0.0',
    'category': 'Marketing',
    'summary': 'WhatsApp Cloud API adapter for invoice / receipt send',
    'depends': ['base', 'mail'],
    'data': [
        'data/whatsapp_parameters.xml',
        'security/ir.model.access.csv',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
