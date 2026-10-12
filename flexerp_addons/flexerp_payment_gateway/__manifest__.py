# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP Payment Gateway',
    'version': '20.0.1.0.0',
    'category': 'Accounting',
    'summary': 'LankaQR / JustPay-style pay link create + status (connection-ready)',
    'depends': ['base'],
    'data': [
        'data/payment_parameters.xml',
        'security/ir.model.access.csv',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
