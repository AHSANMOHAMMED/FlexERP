# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP Vendor RBAC',
    'version': '20.0.1.0.0',
    'category': 'Hidden/Tools',
    'summary': 'Vendor slot provisioning, Vendor Admin/Cashier groups, company isolation',
    'depends': [
        'flexerp_tenant_features',
        'point_of_sale',
        'stock',
        'sale',
        'account',
    ],
    'data': [
        'security/flexerp_security.xml',
        'security/ir.model.access.csv',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
