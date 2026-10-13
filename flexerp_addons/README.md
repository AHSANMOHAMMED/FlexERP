# FlexERP Custom Addons (`dev` only)

These modules must **never** be merged onto branch `20.0`. Install only when running Odoo from the `dev` branch.

## Addons path

Add this directory to your Odoo config:

```ini
addons_path = /path/to/FlexERP/addons,/path/to/FlexERP/odoo/addons,/path/to/FlexERP/flexerp_addons
```

## Modules

| Module | Purpose |
|--------|---------|
| `flexerp_tenant_features` | Per-company feature flags + small_shop / mall presets |
| `flexerp_vendor_rbac` | Vendor Admin / Cashier groups, company-slot provision, isolation helpers |
| `flexerp_whatsapp` | Meta Cloud API adapter for invoice/receipt WhatsApp send |
| `flexerp_invoice_branding` | Logo watermark + paid seal QWeb PDF |
| `flexerp_payment_gateway` | LankaQR / JustPay-style pay link create + status |
| `flexerp_mobile_api` | JSON-RPC facades for mobile bootstrap, POS, stock, live poll, payments, admin |
| `flexerp_ops_control` | Super Admin ops overview / wake / restart / stop / pool |
| `flexerp_website_mobile` | JSON catalog/cart/checkout wrapping website_sale |

## Install order

1. `flexerp_tenant_features`
2. `flexerp_vendor_rbac`
3. `flexerp_whatsapp`
4. `flexerp_invoice_branding`
5. `flexerp_payment_gateway`
6. `flexerp_mobile_api`
7. `flexerp_ops_control`
8. `flexerp_website_mobile` (optional; needs Website + eCommerce)

## Tenancy model (single DB)

FlexERP uses **one Odoo database** and one **vendor slot** per `res.company` (`flexerp_vendor_code`).  
Do not create one database per cashier or per vendor for the default product path.

- Vendor Admin / Cashier: `company_ids` = their slot only; mobile RPC sets `allowed_company_ids` and rejects cross-slot IDs.
- Platform Super Admin: sees all slots, provisions users, toggles features, ops console.

## Mobile API map (Odoo → app)

All routes are JSON-RPC under `/flexerp/mobile/*`, company-slot scoped, feature-gated where noted.

| Area | Routes |
|------|--------|
| Auth / tenancy | `bootstrap`, `company/switch` |
| Admin | `admin/tenants`, `tenant/features`, `tenant/provision`, `users`, `approvals` |
| POS | `pos/configs`, `session/open\|close`, `products`, `order`, `order/receipt`, `orders` |
| Partners / catalog | `partners`, `partners/create`, `products`, `products/categories` |
| Sales / CRM | `sales/orders`, `sales/order/create\|confirm\|detail`, `crm/leads`, `crm/lead/create\|stage`, `crm/stages` |
| Purchase | `purchase/orders`, `purchase/order/create` (feature `purchase`; soft-optional Odoo `purchase` app) |
| Stock | `stock/barcode`, `quants`, `pickings`, `picking`, `validate`, `adjust`, `locations` |
| Accounting | `accounting/invoices`, `invoice/detail`, `journals`, `payment/register`, `invoice/pdf`, WhatsApp send |
| Payments | `payment/link/create`, `payment/link/status` |
| HR | `hr/employees`, `leaves`, `leave/types`, `leave/submit`, `attendance` |
| Ops / live | `ops/*`, `live/poll`, `executive/kpis` |
| Website | via `flexerp_website_mobile`: `shop/catalog`, `cart`, `cart/add\|update`, `checkout` |

Live path rule in the Flutter app: when `!isDemo`, repositories call these facades only (no silent mock success).

**Feature independence:** each key in `flexerp.feature.flag` (pos, inventory, sales, crm, invoicing, payments, warehouse, purchase, hr, website, executive) is independently toggleable per vendor company. No feature requires another. Soft-optional Odoo apps (`purchase`, `crm`, `hr*`) return a clear error when not installed.

### WhatsApp parameters

| Parameter | Notes |
|-----------|-------|
| `flexerp.whatsapp.phone_number_id` | Meta phone number id |
| `flexerp.whatsapp.token` | Cloud API token |
| `flexerp.whatsapp.endpoint` | Default Graph API URL |

Until configured → `status: not_configured` + `wa_me_url` fallback.

### Payment gateway parameters

| Parameter | Notes |
|-----------|-------|
| `flexerp.payment.provider` | `lankaqr_stub` / `justpay` / `lankaqr` |
| `flexerp.payment.endpoint` | Gateway base URL |
| `flexerp.payment.merchant_id` | Merchant id |
| `flexerp.payment.secret` | Server-side only |

- Empty endpoint + `lankaqr_stub` (default) → `ok: true`, `mode: stub` (demo-safe local links).
- Empty endpoint + `justpay` / `lankaqr` → `status: not_configured`.

### Invoice branding

- Company logo → faint watermark when `flexerp_watermark_enabled`
- `flexerp_seal` binary → stamp on paid invoices
- Report: **FlexERP Branded Invoice**

## Ops provider (connection-ready)

| Parameter | Example |
|-----------|---------|
| `flexerp.ops.provider_type` | `docker` or `cloud` |
| `flexerp.ops.endpoint` | `https://ops-agent.example.com` |
| `flexerp.ops.token` | agent token |
| `flexerp.ops.workers` | Telemetry mirror of process `workers` (not the source of truth) |
| `flexerp.ops.db_maxconn` | Telemetry mirror of process `db_maxconn` |

Until the endpoint is set, `/flexerp/mobile/ops/*` returns `status: not_configured`.

## Connection checklist (deploy later)

1. **Odoo workers** — set `workers` > 0 in [`odoo.conf.example`](odoo.conf.example) / real conf (process source of truth).
2. **`db_maxconn`** — keep below Postgres `max_connections`; mirror into ICP only for ops UI.
3. **PgBouncer** — transaction pooling in front of Postgres.
4. **Reverse proxy / LB** — TLS + `proxy_mode = True`.
5. **Ops agent** — Docker/Cloud wake-restart endpoint.
6. **WhatsApp / pay gateway** — set tokens/endpoints when ready; stub pay links are explicit `mode: stub`.

## Desktop app (Vendor Admin / Cashier)

From `flexerp_mobile/`:

```bash
flutter pub get
flutter build windows   # Windows installer/exe
flutter build macos     # macOS .app
flutter build linux     # Linux bundle
```

Desktop uses keyboard / USB barcode wedge (camera scanner disabled) so missing camera never blanks the app. Session restore uses secure storage with corrupt-cache recovery on boot (`tryRestoreSession`). Error boundaries in `main.dart` prevent white screens on widget failures.
