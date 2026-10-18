# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP Invoice Branding',
    'version': '20.0.1.0.0',
    'category': 'Accounting',
    'summary': 'Vendor logo watermark + paid seal on FlexERP invoices',
    'depends': ['account'],
    'data': [
        'views/res_company_views.xml',
        'report/invoice_report.xml',
        'report/invoice_report_templates.xml',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
