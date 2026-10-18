import '../../core/api/odoo_client.dart';
import 'pos_order.dart';

class VendorFeatures {
  final bool enablePos;
  final bool enableInventory;
  final bool enableSales;
  final bool enableCrm;
  final bool enableInvoicing;
  final bool enablePayments;
  final bool enableWarehouse;
  final bool enablePurchase;
  final bool enableHr;
  final bool enableWebsite;
  final bool enableExecutive;

  /// Fail-closed: missing/unknown bootstrap must not unlock modules.
  const VendorFeatures({
    this.enablePos = false,
    this.enableInventory = false,
    this.enableSales = false,
    this.enableCrm = false,
    this.enableInvoicing = false,
    this.enablePayments = false,
    this.enableWarehouse = false,
    this.enablePurchase = false,
    this.enableHr = false,
    this.enableWebsite = false,
    this.enableExecutive = false,
  });

  static const none = VendorFeatures();

  static const allEnabled = VendorFeatures(
    enablePos: true,
    enableInventory: true,
    enableSales: true,
    enableCrm: true,
    enableInvoicing: true,
    enablePayments: true,
    enableWarehouse: true,
    enablePurchase: true,
    enableHr: true,
    enableWebsite: true,
    enableExecutive: true,
  );

  static const smallShop = VendorFeatures(
    enablePos: true,
    enableInventory: true,
    enableSales: false,
    enableCrm: false,
    enableInvoicing: true,
    enablePayments: true,
    enableWarehouse: false,
    enablePurchase: false,
    enableHr: false,
    enableWebsite: false,
    enableExecutive: false,
  );

  static const mall = VendorFeatures(
    enablePos: true,
    enableInventory: true,
    enableSales: true,
    enableCrm: true,
    enableInvoicing: true,
    enablePayments: true,
    enableWarehouse: true,
    enablePurchase: true,
    enableHr: true,
    enableWebsite: false,
    enableExecutive: true,
  );

  factory VendorFeatures.fromApiMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return VendorFeatures.none;
    bool flag(String key) {
      if (!map.containsKey(key)) return false;
      final v = map[key];
      return v == true || v == 1;
    }

    return VendorFeatures(
      enablePos: flag('pos'),
      enableInventory: flag('inventory'),
      enableSales: flag('sales'),
      enableCrm: flag('crm'),
      enableInvoicing: flag('invoicing'),
      enablePayments: flag('payments'),
      enableWarehouse: flag('warehouse'),
      enablePurchase: flag('purchase'),
      enableHr: flag('hr'),
      enableWebsite: flag('website'),
      enableExecutive: flag('executive'),
    );
  }

  Map<String, bool> toApiMap() => {
        'pos': enablePos,
        'inventory': enableInventory,
        'sales': enableSales,
        'crm': enableCrm,
        'invoicing': enableInvoicing,
        'payments': enablePayments,
        'warehouse': enableWarehouse,
        'purchase': enablePurchase,
        'hr': enableHr,
        'website': enableWebsite,
        'executive': enableExecutive,
      };

  VendorFeatures copyWith({
    bool? enablePos,
    bool? enableInventory,
    bool? enableSales,
    bool? enableCrm,
    bool? enableInvoicing,
    bool? enablePayments,
    bool? enableWarehouse,
    bool? enablePurchase,
    bool? enableHr,
    bool? enableWebsite,
    bool? enableExecutive,
  }) {
    return VendorFeatures(
      enablePos: enablePos ?? this.enablePos,
      enableInventory: enableInventory ?? this.enableInventory,
      enableSales: enableSales ?? this.enableSales,
      enableCrm: enableCrm ?? this.enableCrm,
      enableInvoicing: enableInvoicing ?? this.enableInvoicing,
      enablePayments: enablePayments ?? this.enablePayments,
      enableWarehouse: enableWarehouse ?? this.enableWarehouse,
      enablePurchase: enablePurchase ?? this.enablePurchase,
      enableHr: enableHr ?? this.enableHr,
      enableWebsite: enableWebsite ?? this.enableWebsite,
      enableExecutive: enableExecutive ?? this.enableExecutive,
    );
  }

  int get activeCount => toApiMap().values.where((v) => v).length;

  bool get hasAnyCommerce =>
      enablePos || enableSales || enableCrm || enableInventory || enablePurchase;

  String get summary {
    final list = <String>[];
    if (enablePos) list.add('POS');
    if (enableInventory) list.add('Inventory');
    if (enableSales) list.add('Sales');
    if (enableCrm) list.add('CRM');
    if (enableInvoicing) list.add('Invoicing');
    if (enablePayments) list.add('Payments');
    if (enableWarehouse) list.add('Warehouse');
    if (enablePurchase) list.add('Purchase');
    if (enableHr) list.add('HR');
    if (enableWebsite) list.add('Website');
    if (enableExecutive) list.add('Executive');
    return list.isEmpty ? 'None' : list.join(', ');
  }

  static const featureLabels = <String, String>{
    'pos': 'POS / Register',
    'inventory': 'Inventory & Barcode',
    'sales': 'Sales / Quotations',
    'crm': 'CRM Pipeline',
    'invoicing': 'Customer Invoices',
    'payments': 'Payment Registration',
    'warehouse': 'Warehouse Pickings',
    'purchase': 'Purchase Orders',
    'hr': 'HR Self-Service',
    'website': 'Website / Shop API',
    'executive': 'Executive KPIs',
  };
}

class VendorTenant {
  final int id;
  final String vendorId;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String address;
  final String taxTin;
  final VendorFeatures features;
  final bool isActive;
  final DateTime createdAt;
  final String? assignedAdminName;
  final int cashierCount;
  final String preset;

  const VendorTenant({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.address,
    required this.taxTin,
    this.features = const VendorFeatures(),
    this.isActive = true,
    required this.createdAt,
    this.assignedAdminName,
    this.cashierCount = 1,
    this.preset = 'custom',
  });

  factory VendorTenant.fromApi(Map<String, dynamic> json) {
    return VendorTenant(
      id: parseOdooInt(json['id']) ?? 0,
      vendorId: json['vendor_id'] as String? ?? 'VND-${json['id']}',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
      taxTin: json['tax_tin'] as String? ?? '',
      features: VendorFeatures.fromApiMap(
        (json['features'] as Map?)?.cast<String, dynamic>(),
      ),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.now(),
      cashierCount: json['cashier_count'] as int? ?? 1,
      preset: json['preset'] as String? ?? 'custom',
    );
  }

  VendorTenant copyWith({
    int? id,
    String? vendorId,
    String? name,
    String? email,
    String? phone,
    String? city,
    String? address,
    String? taxTin,
    VendorFeatures? features,
    bool? isActive,
    DateTime? createdAt,
    String? assignedAdminName,
    int? cashierCount,
    String? preset,
  }) {
    return VendorTenant(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      taxTin: taxTin ?? this.taxTin,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      assignedAdminName: assignedAdminName ?? this.assignedAdminName,
      cashierCount: cashierCount ?? this.cashierCount,
      preset: preset ?? this.preset,
    );
  }
}

class VendorProduct {
  final int id;
  final String vendorId;
  final String name;
  final String barcode;
  final String sku;
  final String category;
  final double sellingPrice;
  final double costPrice;
  int stockOnHand;
  final int minStockAlert;
  final String? imagePlaceholderColor;
  final DateTime updatedAt;

  VendorProduct({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.barcode,
    required this.sku,
    required this.category,
    required this.sellingPrice,
    required this.costPrice,
    required this.stockOnHand,
    this.minStockAlert = 5,
    this.imagePlaceholderColor,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory VendorProduct.fromApi(Map<String, dynamic> json) {
    return VendorProduct(
      id: parseOdooInt(json['id']) ?? 0,
      vendorId: json['vendor_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      sku: json['sku'] as String? ?? json['default_code'] as String? ?? '',
      category: json['category'] as String? ?? json['categ_name'] as String? ?? '',
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ??
          (json['list_price'] as num?)?.toDouble() ??
          0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ??
          (json['standard_price'] as num?)?.toDouble() ??
          0,
      stockOnHand: ((json['stock_on_hand'] as num?)?.toInt() ??
          (json['qty_available'] as num?)?.toInt() ??
          0),
    );
  }

  bool get isLowStock => stockOnHand <= minStockAlert;
  bool get isOutOfStock => stockOnHand <= 0;

  VendorProduct copyWith({
    int? id,
    String? vendorId,
    String? name,
    String? barcode,
    String? sku,
    String? category,
    double? sellingPrice,
    double? costPrice,
    int? stockOnHand,
    int? minStockAlert,
    String? imagePlaceholderColor,
    DateTime? updatedAt,
  }) {
    return VendorProduct(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      stockOnHand: stockOnHand ?? this.stockOnHand,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      imagePlaceholderColor: imagePlaceholderColor ?? this.imagePlaceholderColor,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  PosProduct toPosProduct() {
    return PosProduct(
      id: id,
      name: name,
      category: category,
      price: sellingPrice,
      imagePlaceholderColor: imagePlaceholderColor,
      stockOnHand: stockOnHand,
      barcode: barcode,
      sku: sku,
    );
  }
}

class VendorStockUpdateEvent {
  final String vendorId;
  final int productId;
  final String productName;
  final int newStock;
  final int delta;
  final String updatedBy;
  final String? reason;
  final DateTime timestamp;

  const VendorStockUpdateEvent({
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.newStock,
    required this.delta,
    required this.updatedBy,
    this.reason,
    required this.timestamp,
  });
}
