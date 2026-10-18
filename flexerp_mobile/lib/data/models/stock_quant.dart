class StockQuant {
  final int id;
  final int productId;
  final int? locationId;
  final String productName;
  final String productSku;
  final String locationName;
  final String warehouseCode;
  final double quantityOnHand;
  final double reservedQuantity;
  final String uom;
  final double costPrice;
  final String category;

  const StockQuant({
    required this.id,
    this.productId = 0,
    this.locationId,
    required this.productName,
    required this.productSku,
    required this.locationName,
    required this.warehouseCode,
    required this.quantityOnHand,
    this.reservedQuantity = 0.0,
    this.uom = 'Units',
    required this.costPrice,
    this.category = 'General',
  });

  double get availableQuantity => (quantityOnHand - reservedQuantity).clamp(0.0, double.infinity);
  double get totalValuation => quantityOnHand * costPrice;
  bool get isLowStock => availableQuantity <= 10.0;
}
