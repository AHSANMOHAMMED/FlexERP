# Part of FlexERP. See LICENSE file for full copyright and licensing details.
{
    'name': 'FlexERP Mobile API',
    'version': '20.0.1.4.0',
    'category': 'Hidden/Tools',
    'summary': 'JSON-RPC facades for FlexERP mobile: bootstrap, POS, stock, sales, purchase, HR, payments, admin',
    'depends': [
        'flexerp_tenant_features',
        'flexerp_vendor_rbac',
        'flexerp_whatsapp',
        'flexerp_invoice_branding',
        'flexerp_payment_gateway',
        'point_of_sale',
        'stock',
        'account',
        'sale',
        'mail',
        'bus',
        'product',
    ],
    # Optional (soft): purchase, crm, hr, hr_attendance, hr_holidays —
    # routes return module_not_installed when model registry lacks them.
    'data': [
        'security/ir.access.csv',
    ],
    'installable': True,
    'application': False,
    'license': 'LGPL-3',
    'author': 'FlexERP',
}
