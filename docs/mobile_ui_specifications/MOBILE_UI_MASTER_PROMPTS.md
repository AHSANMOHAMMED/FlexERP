# FlexERP Mobile Application — Master UI Generation & Role-Based Specification

This specification documents the complete **Role-Based Access Control (RBAC)** model, data permissions, navigation hierarchy, and **production-grade AI UI generation prompts** for every mobile screen in the FlexERP ecosystem.

---

## 1. Role-Based Access Control (RBAC) Architecture

FlexERP maps mobile users to native Odoo security groups (`res.groups`) retrieved via `/web/session/get_session_info` during login.

| Role Name | Target User | Odoo Security Group Mapping | Primary Modules & Permissions |
| :--- | :--- | :--- | :--- |
| **System Admin / Executive** | C-Level, General Manager | `base.group_system`, `base.group_erp_manager` | Unrestricted read/write across all modules, multi-company switcher, executive KPI analytics. |
| **Sales Representative** | Field Sales, Account Managers | `sales_team.group_sale_salesman` | CRM leads, Opportunities, Quotations, Sales Orders (`sale.order`), Customer Directory (`res_partner`). |
| **Sales Manager** | Head of Sales | `sales_team.group_sale_manager` | All team quotations, price override approvals, commission reports, customer credit approvals. |
| **Warehouse Operator** | Storekeepers, Pickers | `stock.group_stock_user` | Receipts (`incoming`), Delivery Orders (`outgoing`), Internal Transfers, Barcode scanning, Stock counts. |
| **Warehouse Manager** | Inventory Director | `stock.group_stock_manager` | Scrap orders, inventory adjustments, reordering rules, warehouse routing configuration. |
| **Accountant / Billing Clerk** | Finance Team, Cashiers | `account.group_account_invoice`, `account.group_account_user` | Customer Invoices, Vendor Bills, Payment Registration, Bank Reconciliation. |
| **POS Cashier / Waiter** | Retail Staff, Floor Staff | `point_of_sale.group_pos_user` | POS Sessions, Order Entry, Cash drawer, Kitchen display, Split billing. |
| **Field Service Technician** | Maintenance Crew | `project.group_project_user`, `maintenance.group_equipment_manager` | Assigned tasks, work orders, timesheet logs, parts usage, equipment tickets. |
| **HR Employee** | All Organization Staff | `base.group_user` (Internal User) | Self-service attendance kiosk, time-off requests, personal profile, company directory. |

---

## 2. Dynamic Role-Based Bottom Navigation

When a user logs in, the app dynamically constructs the bottom tab bar according to their highest permission tier:

```mermaid
flowchart TD
    Login[User Authenticated via /web/session/authenticate] --> Session[Parse user_context & res.groups]
    Session --> RoleCheck{Role Check}
    RoleCheck -->|Sales Rep| NavSales[Tabs: Dashboard | Leads & CRM | Quotations | Customers | More]
    RoleCheck -->|Warehouse Op| NavStock[Tabs: Ops Hub | Barcode Scan | Pickings | Stock Search | More]
    RoleCheck -->|Accountant| NavAcc[Tabs: Dashboard | Invoices | Bills | Payments | More]
    RoleCheck -->|POS Cashier| NavPOS[Tabs: POS Register | Orders | Shift Summary | More]
    RoleCheck -->|Standard Employee| NavEmp[Tabs: Home | Attendance | Time Off | Directory | Profile]
```

---

## 3. Master UI Generation Prompts by Screen & Role

Use the following modular prompts in AI generators (v0.dev, Stitch MCP, Cursor, Lovable, Claude Artifacts) to generate each mobile UI screen.

---

### Module A: Authentication & Workspace Setup

#### Screen A.1: Server Connection & Discovery
```text
Role: All Users
Screen Name: Server Connection & Health Check
Device: Mobile (iOS / Android)
Framework: Flutter / React Native (Tailwind CSS)

Requirements:
- Visual Identity: Dark Slate/Indigo minimal enterprise theme with subtle radial gradient.
- Header: FlexERP geometric logo with "Connect to Instance" subtitle.
- Input Group 1: Server URL input field with pre-filled placeholder "https://erp.yourcompany.com", clear button, and an active "Ping / Verify" button.
- Status Indicator: Micro-badge showing latency (e.g. "Connected: 48ms", green dot) upon successful ping.
- Input Group 2 (Appears after successful ping): Database Selector Dropdown dynamically populated from /web/database/list.
- SSL Verification Toggle: "Enforce HTTPS & Validate Certificate" switch.
- Action: "Proceed to Login" primary action button with smooth fade-in animation.
- Footer: "Quick Demo Mode" pill button for sandbox testing.
```

#### Screen A.2: User Authentication & Biometrics
```text
Role: All Users
Screen Name: Multi-Factor Login Screen
Device: Mobile (iOS / Android)

Requirements:
- Top App Bar: Back arrow to change server URL, server badge showing "Connected to: erp.flexcorp.com".
- Form Fields:
  - Email / Username with auto-fill credentials support.
  - Password field with masked input and show/hide toggle.
  - "Remember Me" toggle.
- 2FA/TOTP Modal / Step: 6-digit one-time passcode box with auto-focus and resend countdown timer.
- Biometric Trigger: Prominent FaceID / Fingerprint circular button with label "Unlock with Biometrics".
- Primary Action: "Sign In" button with loading state.
- Error Handling: Inline error banner for invalid credentials or session timeouts with retry action.
```

---

### Module B: Executive & Management Dashboard

#### Screen B.1: Executive Master Hub
```text
Role: System Admin, Executive, General Manager
Screen Name: Executive KPI Hub & Company Switcher
Device: Mobile (iOS / Android)

Requirements:
- Top Bar:
  - User avatar with status indicator.
  - "Company Switcher" pill button showing current company (e.g., "FlexCorp US") that opens a bottom sheet to switch between multi-company entities.
  - Notification icon with unread count badge.
- Section 1: Financial & Sales Summary Carousel:
  - Card 1: Today's Revenue ($84,230, +14.2% vs target) with green sparkline.
  - Card 2: Cash Inflow vs Outflow ($120k / $45k).
  - Card 3: Pending Shipments (38 Orders requiring validation).
  - Card 4: Open Support / Maintenance Tickets (7 Urgent).
- Section 2: Quick Action Grid (4 rounded cards with icons):
  - "Scan Barcode"
  - "Create Order"
  - "Stock Levels"
  - "Approve Requests (5)"
- Section 3: Approvals Center:
  - Pending approval cards for Sales Orders over credit limit and Purchase Orders over budget with one-tap "Approve" and "Reject" buttons.
- Bottom Navigation: [Dashboard, Operations, CRM, Finance, Settings].
```

---

### Module C: CRM & Field Sales

#### Screen C.1: Sales Pipeline Kanban View
```text
Role: Sales Representative, Sales Manager
Screen Name: Opportunity Kanban Board
Device: Mobile (iOS / Android)

Requirements:
- Header: Title "Sales Pipeline", search bar, filter button ("My Leads", "This Month", "High Value"), and a "+" Floating Action Button (FAB).
- Column Carousel / Swipeable Stages:
  - Stages: "New" -> "Qualified" -> "Proposition" -> "Won".
  - Stage Header: Stage name, deal count, and total stage value (e.g., "Proposition (12) • $145,000").
- Deal Card Design:
  - Customer Name in bold.
  - Deal Title / Expected Revenue in accent color.
  - Priority Star Rating (1 to 3 stars).
  - Tag chips: e.g. "Enterprise", "Consulting".
  - Expected closing date badge with urgency color coding (e.g. Red if overdue).
  - Quick action icons: Call Customer, WhatsApp, Schedule Activity.
- Gestures: Drag-and-drop cards between stages or swipe left to mark Won / swipe right to mark Lost.
```

#### Screen C.2: Quotation & Sales Order Builder
```text
Role: Sales Representative
Screen Name: New Sales Quotation Form (sale.order)
Device: Mobile (iOS / Android)

Requirements:
- Header: "New Quotation", "Save Draft" header action, and Cancel button.
- Section 1: Customer Details:
  - Customer Search & Select field with auto-suggest.
  - Quick-view badge showing customer payment terms (e.g., "30 Days") and available credit limit.
- Section 2: Line Items:
  - List of added products showing thumbnail, name, variant attributes, quantity, unit price, and line subtotal.
  - Swipe-to-delete item action.
  - "Add Product" button that opens catalog modal or barcode scan sheet.
- Section 3: Pricing & Discounts:
  - Subtotal, global discount input (percent or fixed amount), taxes, and bold Total Amount ($).
- Bottom Sticky Action Bar:
  - "Confirm Order" primary button (calls action_confirm).
  - "Send by Email / WhatsApp" secondary button with PDF generator preview.
```

---

### Module D: Warehouse & Barcode Logistics

#### Screen D.1: Barcode Scanner & Rapid Inventory Inquiry
```text
Role: Warehouse Operator, Storekeeper
Screen Name: Real-Time Stock Barcode Inquiry
Device: Mobile (iOS / Android)

Requirements:
- Top Half (Live Scanner Viewport):
  - Camera view with centered barcode framing bracket.
  - Flashlight toggle button, front/rear camera toggle, and continuous scan mode toggle.
  - Visual beep / haptic feedback indicator on successful scan.
- Bottom Half (Product Detail Card - slides up on scan):
  - Product Image thumbnail, Name, SKU, and scanned Barcode.
  - Stock on Hand vs Forecasted Stock across locations (e.g., "WH/Stock: 142 Units", "WH/Shelf-B: 20 Units").
  - Cost & Sales Price info (hidden for Operator, visible for Manager).
- Quick Action Buttons:
  - "Transfer Stock"
  - "Adjust Count"
  - "Print Shelf Label" (via Bluetooth ESC/POS printer).
```

#### Screen D.2: Picking & Delivery Order Execution
```text
Role: Warehouse Operator
Screen Name: Stock Picking Execution (stock.picking)
Device: Mobile (iOS / Android)

Requirements:
- Header: Picking Reference (e.g., "WH/OUT/00142"), Partner Name, Source Document (e.g., "SO048"), Status ("Ready").
- Progress Indicator: Progress bar showing "4 of 6 Items Picked (66%)".
- Line Items Checklist:
  - Source Location (e.g. "LOC-A-12").
  - Product Name & Barcode.
  - Expected Qty vs Scanned Qty with stepper (+ / -).
  - Green checkmark icon when Scanned == Expected.
- Manual Input Trigger: "Enter Barcode Manually" for damaged packaging.
- Bottom Action:
  - "Validate Delivery" button (calls button_validate). Disabled until all items are scanned, with override dialog for partial shipments.
```

---

### Module E: Invoicing & Payment Collection

#### Screen E.1: Invoice Directory & Payment Status
```text
Role: Accountant, Billing Clerk, Sales Rep
Screen Name: Customer Invoices Hub (account.move)
Device: Mobile (iOS / Android)

Requirements:
- Top Bar: Search bar for invoice number / partner, date range filter, and tab pills: "All", "Draft", "Posted / Unpaid", "Overdue", "Paid".
- Invoice Cards:
  - Invoice Number (e.g., "INV/2026/00184") and Customer Name.
  - Invoice Date and Due Date.
  - Total Amount ($) in bold.
  - Status Badge: "Paid" (Green), "Not Paid" (Orange), "Overdue by 12 Days" (Red alert).
- Quick Actions on Card:
  - "Register Payment" button for unpaid invoices.
  - "Download PDF" icon.
  - "Send Reminder" SMS/Email action.
```

#### Screen E.2: Quick Payment Registration Modal
```text
Role: Accountant, Field Sales, Cashier
Screen Name: Register Payment Sheet (account.payment)
Device: Mobile (iOS / Android)

Requirements:
- Bottom Sheet Modal displaying:
  - Invoice Number & Balance Due ($1,450.00).
- Payment Amount input pre-filled with full balance, editable for partial payments.
- Payment Date picker (defaults to today).
- Journal Selector: Segmented pill tabs: [Cash, Bank Transfer, Stripe, POS Terminal].
- Memo / Reference note input field.
- Checkbox: "Send Payment Receipt to Customer via Email".
- Primary Action: "Confirm Payment" button.
```

---

### Module F: Mobile POS & Quick Retail

#### Screen F.1: Mobile POS Touch Register
```text
Role: POS Cashier, Waiter
Screen Name: Mobile POS Register (point_of_sale)
Device: Mobile (iOS / Android)

Requirements:
- Layout:
  - Category Carousel at top: [All, Hot Drinks, Cold Drinks, Bakery, Snacks, Combos].
  - 2-Column Product Grid with product photo, title, price tag ($), and stock indicator.
- Floating Cart Strip:
  - Bottom expandable bar showing "3 Items • $24.50" with arrow to open Cart Drawer.
- Cart Drawer (Expanded):
  - Item list with quantity steppers, discount percentage input, and customer note.
  - Customer selection button ("Select Customer or Walk-in").
- Checkout Button: Prominent green button triggering payment flow.
```

#### Screen F.2: POS Tender & Receipt Print
```text
Role: POS Cashier
Screen Name: POS Payment Tender & ESC-POS Print
Device: Mobile (iOS / Android)

Requirements:
- Header: Amount to Pay in large prominent typography (e.g. "$48.00").
- Payment Method Tiles: Cash, Credit Card, QR Payment.
- Cash Quick-Tender Buttons: "$50", "$100", "Exact Amount".
- Change Due calculation card (e.g., "Change Due: $2.00" in green).
- Receipt Options:
  - "Print Physical Receipt" (shows connected Bluetooth ESC/POS printer status).
  - "Email E-Receipt".
- Action: "New Order / Done" button to instantly reset register for next customer.
```

---

### Module G: HR Self-Service & Attendance

#### Screen G.1: Geofenced Attendance Kiosk
```text
Role: All Employees
Screen Name: Attendance Check-In / Check-Out (hr.attendance)
Device: Mobile (iOS / Android)

Requirements:
- Top Header: Current Date and live Digital Clock with seconds.
- Map Preview Card:
  - User's current GPS location on map with office geofence circle.
  - Badge: "Inside Office Geofence (HQ)" in green or "Outside Geofence" in orange.
- Central Status Display:
  - Status banner: "Currently Checked Out" or "Checked In since 09:15 AM (Worked: 4h 12m)".
- Check-In / Check-Out Action:
  - Large circular animated toggle button (Green "Check In" / Red "Check Out").
- Day Summary Card:
  - Check-in timestamp, expected break time, total hours logged.
```

---

## 4. UI Design System Tokens (For AI Styling)

```json
{
  "colors": {
    "primary": "#4F46E5",
    "primary_dark": "#3730A3",
    "secondary": "#0F172A",
    "background_light": "#F8FAFC",
    "background_dark": "#0B0F19",
    "surface_light": "#FFFFFF",
    "surface_dark": "#1E293B",
    "accent_success": "#10B981",
    "accent_warning": "#F59E0B",
    "accent_danger": "#EF4444"
  },
  "typography": {
    "font_family": "Inter, -apple-system, Roboto, sans-serif",
    "title_size": "24px",
    "subtitle_size": "18px",
    "body_size": "14px",
    "caption_size": "12px"
  },
  "radii": {
    "card": "16px",
    "button": "12px",
    "chip": "9999px"
  }
}
```

