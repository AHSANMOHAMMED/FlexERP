import 'pos_order.dart';

class VendorFeatures {
  final bool enablePos;
  final bool enableInventory;
  final bool enableSales;
  final bool enableInvoicing;
  final bool enableHr;

  const VendorFeatures({
    this.enablePos = true,
    this.enableInventory = true,
    this.enableSales = true,
    this.enableInvoicing = true,
    this.enableHr = true,
  });

  VendorFeatures copyWith({
    bool? enablePos,
    bool? enableInventory,
    bool? enableSales,
    bool? enableInvoicing,
    bool? enableHr,
  }) {
    return VendorFeatures(
      enablePos: enablePos ?? this.enablePos,
      enableInventory: enableInventory ?? this.enableInventory,
      enableSales: enableSales ?? this.enableSales,
      enableInvoicing: enableInvoicing ?? this.enableInvoicing,
      enableHr: enableHr ?? this.enableHr,
    );
  }

  int get activeCount {
    int count = 0;
    if (enablePos) count++;
    if (enableInventory) count++;
    if (enableSales) count++;
    if (enableInvoicing) count++;
    if (enableHr) count++;
    return count;
  }

  String get summary {
    final list = <String>[];
    if (enablePos) list.add('POS');
    if (enableInventory) list.add('Inventory');
    if (enableSales) list.add('Sales/CRM');
    if (enableInvoicing) list.add('Finance');
    if (enableHr) list.add('HR');
    return list.join(', ');
  }
}

class VendorTenant {
  final int id;
  final String vendorId; // Unique code e.g. "VND-001", "VND-KANDY"
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
  });

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
  final double sellingPrice; // in LKR
  final double costPrice; // in LKR
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
