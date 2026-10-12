# FlexERP Mobile / Desktop

Flutter client for FlexERP (`dev` branch Odoo + `flexerp_addons`).

## Roles

- **Platform Super Admin** — ops, tenants, global KPIs
- **Vendor Admin** — own slot staff / stock / sales
- **POS Cashier** — register, tender (Cash / Card / LankaQR), receipt, WhatsApp, tax invoice

## Desktop builds (Vendor Admin & Cashier)

```bash
cd flexerp_mobile
flutter pub get
flutter build windows
flutter build macos
flutter build linux
```

Desktop notes:

- Camera barcode scanning is disabled; use USB wedge / keyboard entry (POS + warehouse screens).
- Corrupt session cache is cleared automatically on boot.
- `ErrorWidget` / `FlutterError` handlers prevent blank white screens.

## Live sync

Authenticated sessions poll `/flexerp/mobile/live/poll` every ~6s and refresh stock, sales, invoices, and KPIs without a manual pull-to-refresh.
