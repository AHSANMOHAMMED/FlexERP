# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP Tenant Features',
    'version': '20.0.1.0.0',
    'category': 'Hidden/Tools',
    'summary': 'Per-company mobile feature flags and vendor phase presets',
    'depends': ['base', 'web'],
    'data': [
        'security/ir.model.access.csv',
        'data/feature_flag_data.xml',
        'views/feature_flag_views.xml',
        'views/res_company_views.xml',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
