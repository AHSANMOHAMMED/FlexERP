import '../models/auth_user.dart';
import '../models/crm_lead.dart';
import '../models/sale_order.dart';
import '../models/stock_picking.dart';
import '../models/account_invoice.dart';
import '../models/pos_order.dart';
import '../models/attendance_record.dart';
import '../models/admin_models.dart';
import '../models/customer_partner.dart';
import '../models/stock_quant.dart';
import '../models/vendor_bill.dart';
import '../models/hr_models.dart';

/// Rich in-memory dataset tailored for Sri Lankan enterprise operations (l10n_lk).
/// Includes Colombo HQ, Kelaniya Warehouse, Kandy & Galle operations.
class MockSriLankaDataService {
  // Pre-configured default users for instant role switching & testing
  static final List<AuthUser> mockUsers = [
    const AuthUser(
      uid: 1,
      name: 'Kasun Jayawardena (Director & Super Admin)',
      email: 'admin@flexcorp.lk',
      role: UserRole.superAdmin,
      serverUrl: 'https://erp.flexcorp.lk',
      database: 'flexerp_production_lk',
      companyId: 1,
      companyName: 'FlexCorp Ceylon (Pvt) Ltd',
      groups: ['base.group_system', 'base.group_erp_manager'],
      isDemo: true,
    ),
    const AuthUser(
      uid: 2,
      name: 'Nimal Perera (Field Sales Exec)',
      email: 'sales@flexcorp.lk',
      role: UserRole.salesRep,
      serverUrl: 'https://erp.flexcorp.lk',
      database: 'flexerp_production_lk',
      companyId: 1,
      companyName: 'FlexCorp Ceylon (Pvt) Ltd',
      groups: ['sales_team.group_sale_salesman'],
      isDemo: true,
    ),
    const AuthUser(
      uid: 3,
      name: 'Tharindu Silva (Warehouse Lead)',
      email: 'warehouse@flexcorp.lk',
      role: UserRole.warehouseOp,
      serverUrl: 'https://erp.flexcorp.lk',
      database: 'flexerp_production_lk',
      companyId: 2,
      companyName: 'FlexCorp Logistics & Fulfillment Hub',
      groups: ['stock.group_stock_user'],
      isDemo: true,
    ),
    const AuthUser(
      uid: 4,
      name: 'Dilini Fernando (Senior Accountant)',
      email: 'accounts@flexcorp.lk',
      role: UserRole.accountant,
      serverUrl: 'https://erp.flexcorp.lk',
      database: 'flexerp_production_lk',
      companyId: 1,
      companyName: 'FlexCorp Ceylon (Pvt) Ltd',
      groups: ['account.group_account_invoice', 'account.group_account_user'],
      isDemo: true,
    ),
    const AuthUser(
      uid: 5,
      name: 'Chamara Bandara (Store Cashier)',
      email: 'pos@flexcorp.lk',
      role: UserRole.posCashier,
      serverUrl: 'https://erp.flexcorp.lk',
      database: 'flexerp_production_lk',
      companyId: 3,
      companyName: 'FlexCorp Central Regional Branch',
      groups: ['point_of_sale.group_pos_user'],
      isDemo: true,
    ),
    const AuthUser(
      uid: 6,
      name: 'Anushka Wickramasinghe (Field Staff)',
      email: 'anushka@flexcorp.lk',
      role: UserRole.employee,
      serverUrl: 'https://erp.flexcorp.lk',
      database: 'flexerp_production_lk',
      companyId: 1,
      companyName: 'FlexCorp Ceylon (Pvt) Ltd',
      groups: ['base.group_user'],
      isDemo: true,
    ),
  ];

  // System Health Metrics for Super Admin
  static final List<SystemHealthMetric> healthMetrics = [
    const SystemHealthMetric(
      metricName: 'PostgreSQL DB Cluster',
      value: 'Primary Online (99.98% SLA)',
      status: 'healthy',
      detail: 'Latency: 18ms | Connections: 42/200 | Size: 14.2 GB',
    ),
    const SystemHealthMetric(
      metricName: 'Odoo Gevent Workers',
      value: '8 Active Workers',
      status: 'healthy',
      detail: 'CPU Load: 24% | Memory: 3.4 GB / 8 GB',
    ),
    const SystemHealthMetric(
      metricName: 'SMS Twilio & Dialog Gateway',
      value: '99.4% Delivery Rate',
      status: 'healthy',
      detail: 'Sri Lanka OTP & Quotation SMS Queue: 0 pending',
    ),
    const SystemHealthMetric(
      metricName: 'Branch Synchronization',
      value: '4 Branches Synchronized',
      status: 'healthy',
      detail: 'Last sync: 2 minutes ago across Colombo, Kandy, Galle, Kelaniya',
    ),
  ];

  // Super Admin Managed Users
  static final List<ManagedUser> managedUsers = [
    ManagedUser(
      id: 101,
      name: 'Nimal Perera',
      email: 'nimal.p@flexcorp.lk',
      nicOrId: '198824501234',
      role: UserRole.salesRep,
      isActive: true,
      assignedBranch: 'Colombo HQ',
      lastActive: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    ManagedUser(
      id: 102,
      name: 'Tharindu Silva',
      email: 'tharindu.s@flexcorp.lk',
      nicOrId: '199215809876',
      role: UserRole.warehouseOp,
      isActive: true,
      assignedBranch: 'Kelaniya Logistics',
      lastActive: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
    ManagedUser(
      id: 103,
      name: 'Dilini Fernando',
      email: 'dilini.f@flexcorp.lk',
      nicOrId: '199071203456',
      role: UserRole.accountant,
      isActive: true,
      assignedBranch: 'Colombo HQ',
      lastActive: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    ManagedUser(
      id: 104,
      name: 'Chamara Bandara',
      email: 'chamara.b@flexcorp.lk',
      nicOrId: '199532104321',
      role: UserRole.posCashier,
      isActive: true,
      assignedBranch: 'Kandy Regional',
      lastActive: DateTime.now().subtract(const Duration(minutes: 32)),
    ),
    ManagedUser(
      id: 105,
      name: 'Sanjeewa Alwis',
      email: 'sanjeewa.a@flexcorp.lk',
      nicOrId: '198511209988',
      role: UserRole.salesRep,
      isActive: true,
      assignedBranch: 'Galle Depot',
      lastActive: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // Pending Executive Approvals (Credit limit overrides, purchase approvals)
  static final List<PendingApproval> pendingApprovals = [
    PendingApproval(
      id: 1,
      type: 'Credit Limit Override',
      reference: 'SO/2026/00142',
      requestedBy: 'Nimal Perera (Field Sales)',
      customerOrVendor: 'Lanka Industrial Supplies (Pvt) Ltd',
      amount: 1450000.0,
      reason: 'Customer credit limit is Rs. 1,000,000. Order exceeds by Rs. 450,000. Customer promised payment in 14 days.',
      requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    PendingApproval(
      id: 2,
      type: 'Price Discount Override',
      reference: 'SO/2026/00145',
      requestedBy: 'Sanjeewa Alwis (Galle Branch)',
      customerOrVendor: 'Ruhunu Hardware Stores',
      amount: 680000.0,
      reason: 'Requested special project discount of 15% (standard rep limit is 8%). Bulk cement order.',
      requestedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    PendingApproval(
      id: 3,
      type: 'High-Value PO Approval',
      reference: 'PO/2026/00089',
      requestedBy: 'Procurement Department',
      customerOrVendor: 'Tokyo Cement Company PLC',
      amount: 8750000.0,
      reason: 'Monthly replenishment for Kelaniya Central Warehouse. Requires C-level sign-off.',
      requestedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // CRM Leads / Pipeline
  static final List<CrmLead> crmLeads = [
    const CrmLead(
      id: 1,
      name: 'Colombo Port Logistics Expansion Equipment',
      partnerName: 'South Asia Gateway Terminals (Pvt) Ltd',
      expectedRevenue: 3850000.0,
      stage: 'Proposition',
      priority: 3,
      tags: ['Enterprise', 'Port / Marine'],
      phone: '+94 11 245 8000',
      expectedClosing: '2026-10-25',
    ),
    const CrmLead(
      id: 2,
      name: 'Hospitality Solar Inverter & Battery Supply',
      partnerName: 'Cinnamon Grand Colombo',
      expectedRevenue: 1950000.0,
      stage: 'Qualified',
      priority: 2,
      tags: ['Solar', 'Commercial'],
      phone: '+94 11 249 7200',
      expectedClosing: '2026-10-30',
    ),
    const CrmLead(
      id: 3,
      name: 'Warehouse Automation RFID Scanner Package',
      partnerName: 'John Keells Logistics PLC',
      expectedRevenue: 5200000.0,
      stage: 'New',
      priority: 3,
      tags: ['Logistics', 'High Value'],
      phone: '+94 11 230 6000',
      expectedClosing: '2026-11-15',
    ),
    const CrmLead(
      id: 4,
      name: 'Apparel Factory Air Handling Units',
      partnerName: 'MAS Holdings (Slimline)',
      expectedRevenue: 4400000.0,
      stage: 'Won',
      priority: 3,
      tags: ['Industrial', 'HVAC'],
      phone: '+94 32 224 8000',
      expectedClosing: '2026-10-10',
    ),
    const CrmLead(
      id: 5,
      name: 'Retail Point-of-Sale Hardware Bundle',
      partnerName: 'Singer Sri Lanka PLC',
      expectedRevenue: 1250000.0,
      stage: 'Qualified',
      priority: 1,
      tags: ['Retail', 'POS'],
      phone: '+94 11 540 0400',
      expectedClosing: '2026-11-02',
    ),
  ];

  // Sales Orders & Quotations
  static final List<SaleOrder> saleOrders = [
    SaleOrder(
      id: 1,
      name: 'SO/2026/00142',
      partnerName: 'Lanka Industrial Supplies (Pvt) Ltd',
      partnerPhone: '+94 11 268 9000',
      paymentTerms: '30 Days Net',
      creditLimit: 1000000.0,
      currentCreditUsed: 850000.0,
      state: 'draft',
      dateOrder: DateTime.now().subtract(const Duration(hours: 3)),
      lines: [
        const OrderLine(
          productId: 101,
          productName: 'Heavy Duty Industrial Pallet 1200x1000',
          sku: 'PLT-1200-HD',
          quantity: 120,
          unitPrice: 4500.0,
          discountPercent: 5.0,
        ),
        const OrderLine(
          productId: 102,
          productName: 'Hydraulic Hand Pallet Truck 3.0T',
          sku: 'HPT-3000-NY',
          quantity: 4,
          unitPrice: 185000.0,
          discountPercent: 0.0,
        ),
      ],
    ),
    SaleOrder(
      id: 2,
      name: 'SO/2026/00141',
      partnerName: 'Access Engineering PLC',
      partnerPhone: '+94 11 760 6600',
      paymentTerms: '14 Days Net',
      creditLimit: 5000000.0,
      currentCreditUsed: 1200000.0,
      state: 'sale',
      dateOrder: DateTime.now().subtract(const Duration(days: 1)),
      lines: [
        const OrderLine(
          productId: 103,
          productName: 'Wireless Barcode Scanner 2D Bluetooth',
          sku: 'SCN-2D-BT',
          quantity: 25,
          unitPrice: 38500.0,
          discountPercent: 10.0,
        ),
      ],
    ),
  ];

  // Stock Pickings for Warehouse
  static final List<StockPicking> stockPickings = [
    StockPicking(
      id: 1,
      name: 'WH/OUT/00189',
      partnerName: 'Lanka Industrial Supplies (Pvt) Ltd',
      origin: 'SO/2026/00142',
      pickingType: 'outgoing',
      state: 'assigned', // Ready to pick
      scheduledDate: DateTime.now().add(const Duration(hours: 4)),
      lines: [
        PickingMoveLine(
          id: 201,
          productName: 'Heavy Duty Industrial Pallet 1200x1000',
          barcode: '4792001928312',
          sourceLocation: 'WH/Stock/Aisle-A-04',
          expectedQty: 120,
          scannedQty: 120,
        ),
        PickingMoveLine(
          id: 202,
          productName: 'Hydraulic Hand Pallet Truck 3.0T',
          barcode: '4792001928428',
          sourceLocation: 'WH/Stock/Bay-Heavy-02',
          expectedQty: 4,
          scannedQty: 3, // 3 of 4 picked
        ),
      ],
    ),
    StockPicking(
      id: 2,
      name: 'WH/IN/00094',
      partnerName: 'Tokyo Cement Company PLC',
      origin: 'PO/2026/00089',
      pickingType: 'incoming',
      state: 'assigned',
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      lines: [
        PickingMoveLine(
          id: 203,
          productName: 'Portland Composite Cement 50kg Bags',
          barcode: '4791002348123',
          sourceLocation: 'WH/Receiving-Dock-1',
          expectedQty: 500,
          scannedQty: 500,
        ),
      ],
    ),
  ];

  // Customer Invoices (account.move)
  static final List<AccountInvoice> invoices = [
    AccountInvoice(
      id: 1,
      number: 'INV/2026/00341',
      partnerName: 'South Asia Gateway Terminals (Pvt) Ltd',
      partnerVat: 'V-102938475-7000',
      amountUntaxed: 1200000.0,
      amountTax: 246000.0, // 18% VAT + 2.5% SSCL
      amountTotal: 1446000.0,
      amountResidual: 1446000.0,
      state: 'posted',
      paymentState: 'not_paid',
      invoiceDate: DateTime.now().subtract(const Duration(days: 12)),
      invoiceDateDue: DateTime.now().add(const Duration(days: 18)),
    ),
    AccountInvoice(
      id: 2,
      number: 'INV/2026/00338',
      partnerName: 'Kelani Cables PLC',
      partnerVat: 'V-203948576-9000',
      amountUntaxed: 850000.0,
      amountTax: 174250.0,
      amountTotal: 1024250.0,
      amountResidual: 1024250.0,
      state: 'posted',
      paymentState: 'not_paid',
      invoiceDate: DateTime.now().subtract(const Duration(days: 35)),
      invoiceDateDue: DateTime.now().subtract(const Duration(days: 5)), // Overdue!
    ),
    AccountInvoice(
      id: 3,
      number: 'INV/2026/00330',
      partnerName: 'Dialog Axiata PLC',
      partnerVat: 'V-394857612-4000',
      amountUntaxed: 2400000.0,
      amountTax: 492000.0,
      amountTotal: 2892000.0,
      amountResidual: 0.0,
      state: 'posted',
      paymentState: 'paid',
      invoiceDate: DateTime.now().subtract(const Duration(days: 45)),
      invoiceDateDue: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  // POS Catalog (Retail / Walk-in)
  static final List<PosProduct> posProducts = [
    const PosProduct(
      id: 301,
      name: 'Safety Helmet - Heavy Duty (White)',
      category: 'Safety & PPE',
      price: 2450.0,
      stockOnHand: 48,
    ),
    const PosProduct(
      id: 302,
      name: 'High-Visibility Reflector Vest (Orange)',
      category: 'Safety & PPE',
      price: 950.0,
      stockOnHand: 110,
    ),
    const PosProduct(
      id: 303,
      name: 'Heavy Duty Thermal Gloves (L)',
      category: 'Safety & PPE',
      price: 1850.0,
      stockOnHand: 65,
    ),
    const PosProduct(
      id: 304,
      name: 'Industrial Measuring Tape 10M',
      category: 'Hand Tools',
      price: 2200.0,
      stockOnHand: 32,
    ),
    const PosProduct(
      id: 305,
      name: 'Cordless Impact Drill 18V Brushless',
      category: 'Power Tools',
      price: 34500.0,
      stockOnHand: 14,
    ),
    const PosProduct(
      id: 306,
      name: 'Heavy Duty Extension Cable 20M (13A)',
      category: 'Electrical',
      price: 8900.0,
      stockOnHand: 22,
    ),
  ];

  // Active POS Shift
  static PosShiftSession activePosSession = PosShiftSession(
    id: 42,
    name: 'POS/0042 (Kandy Central Counter)',
    cashierName: 'Chamara Bandara',
    openingTime: DateTime.now().subtract(const Duration(hours: 4, minutes: 20)),
    openingBalance: 25000.0, // Rs. 25,000 opening float
    cashSalesTotal: 78500.0,
    cardSalesTotal: 142000.0,
    transactionCount: 28,
  );

  // Active Attendance Record
  static AttendanceRecord currentAttendance = AttendanceRecord(
    id: 1,
    employeeName: 'Anushka Wickramasinghe',
    checkIn: DateTime.now().subtract(const Duration(hours: 3, minutes: 42)),
    checkInLat: 6.9271, // Colombo HQ GPS coordinates
    checkInLon: 79.8612,
    geofenceLocationName: 'Colombo HQ Office (Radius 100m)',
    isInsideGeofence: true,
  );

  // Sri Lankan Corporate & Retail Partners (res.partner)
  static final List<CustomerPartner> mockPartners = [
    const CustomerPartner(
      id: 101,
      name: 'John Keells Logistics (Pvt) Ltd',
      email: 'procurement@jkh.lk',
      phone: '+94 11 230 6000',
      city: 'Colombo 02',
      address: '117 Sir Chittampalam A. Gardiner Mawatha',
      vatOrTin: 'V-102938475-7000',
      svatNumber: 'SVAT-004921',
      creditLimit: 5000000.0,
      totalReceivable: 1446000.0,
      paymentTerms: '30 Days Net',
      isCustomer: true,
    ),
    const CustomerPartner(
      id: 102,
      name: 'Hayleys Fabric PLC',
      email: 'purchasing@hayleysfabric.com',
      phone: '+94 34 229 7100',
      city: 'Horana',
      address: 'Narthupana Estate, Neboda',
      vatOrTin: 'V-485920183-8000',
      svatNumber: 'SVAT-008129',
      creditLimit: 3000000.0,
      totalReceivable: 2850000.0,
      paymentTerms: '45 Days Net',
      isCustomer: true,
    ),
    const CustomerPartner(
      id: 103,
      name: 'Dialog Axiata PLC',
      email: 'enterprise@dialog.lk',
      phone: '+94 77 767 8700',
      city: 'Colombo 02',
      address: '475 Union Place',
      vatOrTin: 'V-394857612-4000',
      svatNumber: 'SVAT-001004',
      creditLimit: 10000000.0,
      totalReceivable: 0.0,
      paymentTerms: '15 Days Net',
      isCustomer: true,
    ),
    const CustomerPartner(
      id: 104,
      name: 'Dilmah Ceylon Tea Company PLC',
      email: 'orders@dilmahtea.com',
      phone: '+94 11 482 2000',
      city: 'Peliyagoda',
      address: '111 Negombo Road',
      vatOrTin: 'V-583920194-2000',
      svatNumber: 'SVAT-003310',
      creditLimit: 4000000.0,
      totalReceivable: 780000.0,
      paymentTerms: '30 Days Net',
      isCustomer: true,
    ),
    const CustomerPartner(
      id: 105,
      name: 'Lanka IOC PLC',
      email: 'supplies@lioc.lk',
      phone: '+94 11 247 5720',
      city: 'Colombo 01',
      address: 'Level 20, West Tower, WTC, Echelon Square',
      vatOrTin: 'V-993847562-1000',
      svatNumber: 'SVAT-002288',
      creditLimit: 8000000.0,
      totalReceivable: 4200000.0,
      paymentTerms: '30 Days Net',
      isCustomer: true,
      isSupplier: true,
    ),
    const CustomerPartner(
      id: 106,
      name: 'DIMO (Diesel & Motor Engineering PLC)',
      email: 'industrial@dimolanka.com',
      phone: '+94 11 244 9797',
      city: 'Colombo 14',
      address: '65 Jetawana Road',
      vatOrTin: 'V-112233445-5000',
      svatNumber: 'SVAT-005670',
      creditLimit: 2500000.0,
      totalReceivable: 2650000.0, // Over credit limit!
      paymentTerms: 'Immediate Payment',
      isCustomer: true,
    ),
  ];

  // Multi-Warehouse Stock Quants (stock.quant)
  static final List<StockQuant> mockStockQuants = [
    const StockQuant(
      id: 501,
      productName: 'Heavy Duty Thermal Gloves (L)',
      productSku: 'PPE-GLV-01',
      locationName: 'Kelaniya Central / Zone A / Bin 12',
      warehouseCode: 'WH1-KLN',
      quantityOnHand: 280.0,
      reservedQuantity: 65.0,
      uom: 'Pairs',
      costPrice: 1200.0,
      category: 'Safety & PPE',
    ),
    const StockQuant(
      id: 502,
      productName: 'Safety Helmet - Heavy Duty (White)',
      productSku: 'PPE-HLM-W',
      locationName: 'Kelaniya Central / Zone B / Bin 04',
      warehouseCode: 'WH1-KLN',
      quantityOnHand: 140.0,
      reservedQuantity: 48.0,
      uom: 'Units',
      costPrice: 1650.0,
      category: 'Safety & PPE',
    ),
    const StockQuant(
      id: 503,
      productName: 'Cordless Impact Drill 18V Brushless',
      productSku: 'PWR-DRL-18',
      locationName: 'Colombo Bonded WH / Secure Cage 01',
      warehouseCode: 'WH2-CMB',
      quantityOnHand: 24.0,
      reservedQuantity: 14.0,
      uom: 'Units',
      costPrice: 24500.0,
      category: 'Power Tools',
    ),
    const StockQuant(
      id: 504,
      productName: 'High-Visibility Reflector Vest (Orange)',
      productSku: 'PPE-VST-ORG',
      locationName: 'Kandy Transit Hub / Shelf C2',
      warehouseCode: 'WH3-KDY',
      quantityOnHand: 85.0,
      reservedQuantity: 10.0,
      uom: 'Units',
      costPrice: 620.0,
      category: 'Safety & PPE',
    ),
    const StockQuant(
      id: 505,
      productName: 'Industrial Measuring Tape 10M',
      productSku: 'HND-MTR-10',
      locationName: 'Galle Distribution Depot / Rack 01',
      warehouseCode: 'WH4-GLE',
      quantityOnHand: 8.0, // Low stock!
      reservedQuantity: 0.0,
      uom: 'Units',
      costPrice: 1450.0,
      category: 'Hand Tools',
    ),
    const StockQuant(
      id: 506,
      productName: 'Heavy Duty Extension Cable 20M (13A)',
      productSku: 'ELC-CBL-20M',
      locationName: 'Kelaniya Central / Zone C / Bin 28',
      warehouseCode: 'WH1-KLN',
      quantityOnHand: 55.0,
      reservedQuantity: 22.0,
      uom: 'Units',
      costPrice: 5800.0,
      category: 'Electrical',
    ),
  ];

  // Supplier Vendor Bills (account.move - in_invoice)
  static final List<VendorBill> mockVendorBills = [
    VendorBill(
      id: 701,
      billNumber: 'BILL/2026/0018',
      vendorName: 'Lanka IOC PLC',
      vendorVatOrTin: 'V-993847562-1000',
      billDate: DateTime.now().subtract(const Duration(days: 8)),
      dueDate: DateTime.now().add(const Duration(days: 22)),
      subtotal: 1250000.0,
      vatAmount: 225000.0, // 18% VAT
      ssclAmount: 31250.0, // 2.5% SSCL
      whtAmount: 62500.0,  // 5% WHT
      totalAmount: 1506250.0,
      amountDue: 1506250.0,
      state: 'posted',
      paymentReference: 'INV-LIOC-9921',
    ),
    VendorBill(
      id: 702,
      billNumber: 'BILL/2026/0014',
      vendorName: 'Printcare PLC',
      vendorVatOrTin: 'V-442299113-6000',
      billDate: DateTime.now().subtract(const Duration(days: 34)),
      dueDate: DateTime.now().subtract(const Duration(days: 4)), // Overdue
      subtotal: 420000.0,
      vatAmount: 75600.0,
      ssclAmount: 10500.0,
      whtAmount: 0.0,
      totalAmount: 506100.0,
      amountDue: 506100.0,
      state: 'posted',
      paymentReference: 'PC-2026-FEB-44',
    ),
    VendorBill(
      id: 703,
      billNumber: 'BILL/2026/0009',
      vendorName: 'Ceylon Electricity Board (CEB)',
      vendorVatOrTin: 'V-000011223-9000',
      billDate: DateTime.now().subtract(const Duration(days: 20)),
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      subtotal: 340000.0,
      vatAmount: 61200.0,
      ssclAmount: 0.0,
      whtAmount: 0.0,
      totalAmount: 401200.0,
      amountDue: 0.0,
      state: 'paid',
      paymentReference: 'CEB-ACC-883921',
    ),
  ];

  // Employee Directory Profiles (hr.employee)
  static final List<EmployeeProfile> mockEmployees = [
    const EmployeeProfile(
      id: 801,
      name: 'Kasun Jayawardena',
      jobTitle: 'Chief Executive & Director',
      department: 'Executive Management',
      workEmail: 'admin@flexcorp.lk',
      workPhone: '+94 77 123 4567',
      epfNumber: 'EPF/00142',
      location: 'Colombo HQ (Level 12)',
      status: 'active',
    ),
    const EmployeeProfile(
      id: 802,
      name: 'Nimal Perera',
      jobTitle: 'Senior Field Sales Executive',
      department: 'Sales & Business Development',
      workEmail: 'sales@flexcorp.lk',
      workPhone: '+94 71 889 2233',
      epfNumber: 'EPF/00489',
      location: 'Western Province Field Hub',
      status: 'active',
    ),
    const EmployeeProfile(
      id: 803,
      name: 'Tharindu Silva',
      jobTitle: 'Warehouse & Logistics Manager',
      department: 'Supply Chain Operations',
      workEmail: 'warehouse@flexcorp.lk',
      workPhone: '+94 76 554 1122',
      epfNumber: 'EPF/00512',
      location: 'Kelaniya Fulfillment Complex',
      status: 'active',
    ),
    const EmployeeProfile(
      id: 804,
      name: 'Dilini Fernando',
      jobTitle: 'Lead Financial Controller',
      department: 'Finance & Treasury',
      workEmail: 'accounts@flexcorp.lk',
      workPhone: '+94 70 334 9911',
      epfNumber: 'EPF/00398',
      location: 'Colombo HQ (Finance Wing)',
      status: 'active',
    ),
    const EmployeeProfile(
      id: 805,
      name: 'Chamara Bandara',
      jobTitle: 'Senior Retail Cashier',
      department: 'Retail Point of Sale',
      workEmail: 'pos@flexcorp.lk',
      workPhone: '+94 78 442 7788',
      epfNumber: 'EPF/00645',
      location: 'Kandy Central Store',
      status: 'active',
    ),
    const EmployeeProfile(
      id: 806,
      name: 'Anushka Wickramasinghe',
      jobTitle: 'Field Service Engineer',
      department: 'Technical Operations',
      workEmail: 'anushka@flexcorp.lk',
      workPhone: '+94 72 990 4411',
      epfNumber: 'EPF/00718',
      location: 'Western Region Mobile Unit',
      status: 'active',
    ),
  ];

  // Leave Requests (hr.leave)
  static final List<LeaveRequest> mockLeaveRequests = [
    LeaveRequest(
      id: 901,
      employeeName: 'Anushka Wickramasinghe',
      employeeId: 806,
      leaveType: 'Annual Leave',
      dateFrom: DateTime.now().add(const Duration(days: 4)),
      dateTo: DateTime.now().add(const Duration(days: 6)),
      numberOfDays: 3.0,
      status: 'confirm',
      reason: 'Family trip to Nuwara Eliya',
    ),
    LeaveRequest(
      id: 902,
      employeeName: 'Anushka Wickramasinghe',
      employeeId: 806,
      leaveType: 'Casual Leave',
      dateFrom: DateTime.now().subtract(const Duration(days: 14)),
      dateTo: DateTime.now().subtract(const Duration(days: 14)),
      numberOfDays: 1.0,
      status: 'validate',
      reason: 'Personal banking matters',
    ),
    LeaveRequest(
      id: 903,
      employeeName: 'Tharindu Silva',
      employeeId: 803,
      leaveType: 'Medical Leave',
      dateFrom: DateTime.now().subtract(const Duration(days: 28)),
      dateTo: DateTime.now().subtract(const Duration(days: 26)),
      numberOfDays: 2.0,
      status: 'validate',
      reason: 'Viral fever rest certified by doctor',
    ),
  ];

  // Completed POS Order History (pos.order)
  static final List<PosPastOrder> mockPastPosOrders = [
    PosPastOrder(
      id: 1001,
      receiptNumber: 'POS/2026/0491',
      orderDate: DateTime.now().subtract(const Duration(minutes: 32)),
      customerName: 'Walk-in Customer (Kandy Store)',
      totalAmount: 4900.0,
      paymentMethod: 'LANKAQR',
      lines: const [
        PosOrderLine(
          productName: 'Safety Helmet - Heavy Duty (White)',
          quantity: 2,
          unitPrice: 2450.0,
          subtotal: 4900.0,
        ),
      ],
    ),
    PosPastOrder(
      id: 1002,
      receiptNumber: 'POS/2026/0490',
      orderDate: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
      customerName: 'Kandy Construction Works',
      totalAmount: 45250.0,
      paymentMethod: 'Card (Commercial Bank)',
      lines: const [
        PosOrderLine(
          productName: 'Cordless Impact Drill 18V Brushless',
          quantity: 1,
          unitPrice: 34500.0,
          subtotal: 34500.0,
        ),
        PosOrderLine(
          productName: 'Heavy Duty Extension Cable 20M (13A)',
          quantity: 1,
          unitPrice: 8900.0,
          subtotal: 8900.0,
        ),
        PosOrderLine(
          productName: 'High-Visibility Reflector Vest (Orange)',
          quantity: 2,
          unitPrice: 950.0,
          subtotal: 1900.0,
        ),
      ],
    ),
    PosPastOrder(
      id: 1003,
      receiptNumber: 'POS/2026/0489',
      orderDate: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      customerName: 'Walk-in Retail',
      totalAmount: 7350.0,
      paymentMethod: 'Cash',
      lines: const [
        PosOrderLine(
          productName: 'Heavy Duty Thermal Gloves (L)',
          quantity: 3,
          unitPrice: 1850.0,
          subtotal: 5550.0,
        ),
        PosOrderLine(
          productName: 'High-Visibility Reflector Vest (Orange)',
          quantity: 1,
          unitPrice: 950.0,
          subtotal: 950.0,
        ),
      ],
    ),
  ];
}

