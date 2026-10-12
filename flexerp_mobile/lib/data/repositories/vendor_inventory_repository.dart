import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor_model.dart';
import 'vendor_repository.dart';

final vendorStockEventStreamProvider = StreamProvider<VendorStockUpdateEvent>((ref) {
  final notifier = ref.watch(vendorInventoryProvider.notifier);
  return notifier.stockEventStream;
});

final vendorInventoryProvider = NotifierProvider<VendorInventoryNotifier, List<VendorProduct>>(
  VendorInventoryNotifier.new,
);

class VendorInventoryNotifier extends Notifier<List<VendorProduct>> {
  final StreamController<VendorStockUpdateEvent> _stockEventController =
      StreamController<VendorStockUpdateEvent>.broadcast();

  Stream<VendorStockUpdateEvent> get stockEventStream => _stockEventController.stream;

  // In-memory isolated databases keyed by unique vendorId
  static final Map<String, List<VendorProduct>> _isolatedVendorDbs = {
    'VND-001': [
      VendorProduct(
        id: 101,
        vendorId: 'VND-001',
        name: 'Industrial Safety Helmet - Ratchet Yellow',
        barcode: '4792019001018',
        sku: 'PPE-HLM-YEL',
        category: 'Safety & PPE',
        sellingPrice: 4250.00,
        costPrice: 2800.00,
        stockOnHand: 48,
        minStockAlert: 10,
        imagePlaceholderColor: '0xFFF59E0B',
      ),
      VendorProduct(
        id: 102,
        vendorId: 'VND-001',
        name: 'Heavy Duty Nitrile Coated Gloves (Pair)',
        barcode: '4792019001025',
        sku: 'PPE-GLV-NIT',
        category: 'Safety & PPE',
        sellingPrice: 850.00,
        costPrice: 520.00,
        stockOnHand: 140,
        minStockAlert: 25,
        imagePlaceholderColor: '0xFF10B981',
      ),
      VendorProduct(
        id: 103,
        vendorId: 'VND-001',
        name: 'Makita 750W Rotary Hammer Drill',
        barcode: '4792019001032',
        sku: 'PWR-DRL-750',
        category: 'Power Tools',
        sellingPrice: 38500.00,
        costPrice: 29000.00,
        stockOnHand: 14,
        minStockAlert: 4,
        imagePlaceholderColor: '0xFF3B82F6',
      ),
      VendorProduct(
        id: 104,
        vendorId: 'VND-001',
        name: 'Orange Conical Traffic Safety Cone 750mm',
        barcode: '4792019001049',
        sku: 'RSD-CON-750',
        category: 'Safety & PPE',
        sellingPrice: 3100.00,
        costPrice: 2100.00,
        stockOnHand: 30,
        minStockAlert: 8,
        imagePlaceholderColor: '0xFFF97316',
      ),
      VendorProduct(
        id: 105,
        vendorId: 'VND-001',
        name: 'Stanley Chrome Steel Claw Hammer 16oz',
        barcode: '4792019001056',
        sku: 'HND-HMR-16Z',
        category: 'Hand Tools',
        sellingPrice: 3800.00,
        costPrice: 2500.00,
        stockOnHand: 55,
        minStockAlert: 12,
        imagePlaceholderColor: '0xFF64748B',
      ),
    ],
    'VND-002': [
      VendorProduct(
        id: 201,
        vendorId: 'VND-002',
        name: 'Premium Ceylon Keells Keeri Samba 5kg',
        barcode: '4792029002012',
        sku: 'GRO-SAM-05K',
        category: 'Groceries',
        sellingPrice: 1450.00,
        costPrice: 1220.00,
        stockOnHand: 85,
        minStockAlert: 15,
        imagePlaceholderColor: '0xFF10B981',
      ),
      VendorProduct(
        id: 202,
        vendorId: 'VND-002',
        name: 'Anchor Full Cream Milk Powder 400g',
        barcode: '4792029002029',
        sku: 'DRY-MLK-400',
        category: 'Dairy',
        sellingPrice: 1120.00,
        costPrice: 990.00,
        stockOnHand: 60,
        minStockAlert: 20,
        imagePlaceholderColor: '0xFF38BDF8',
      ),
      VendorProduct(
        id: 203,
        vendorId: 'VND-002',
        name: 'Dilmah Premium Ceylon BOPF Tea 200g',
        barcode: '4792029002036',
        sku: 'BEV-TEA-200',
        category: 'Beverages',
        sellingPrice: 680.00,
        costPrice: 530.00,
        stockOnHand: 110,
        minStockAlert: 30,
        imagePlaceholderColor: '0xFFEF4444',
      ),
      VendorProduct(
        id: 204,
        vendorId: 'VND-002',
        name: 'Munchee Super Cream Cracker 500g',
        barcode: '4792029002043',
        sku: 'SNK-CRK-500',
        category: 'Snacks',
        sellingPrice: 520.00,
        costPrice: 420.00,
        stockOnHand: 95,
        minStockAlert: 20,
        imagePlaceholderColor: '0xFFF59E0B',
      ),
    ],
    'VND-003': [
      VendorProduct(
        id: 301,
        vendorId: 'VND-003',
        name: 'BOSCH 12V Cordless Driver / Screwdriver',
        barcode: '4792039003016',
        sku: 'BOS-DRV-12V',
        category: 'Power Tools',
        sellingPrice: 28500.00,
        costPrice: 21500.00,
        stockOnHand: 18,
        minStockAlert: 5,
        imagePlaceholderColor: '0xFF3B82F6',
      ),
      VendorProduct(
        id: 302,
        vendorId: 'VND-003',
        name: 'Galvanized Hex Bolts & Nuts 100pk M8x40',
        barcode: '4792039003023',
        sku: 'FAS-BLT-M8X',
        category: 'Fasteners',
        sellingPrice: 3200.00,
        costPrice: 2100.00,
        stockOnHand: 45,
        minStockAlert: 10,
        imagePlaceholderColor: '0xFF64748B',
      ),
    ],
    'VND-004': [
      VendorProduct(
        id: 401,
        vendorId: 'VND-004',
        name: 'Pure Ceylon Alba Cinnamon Quills 100g',
        barcode: '4792049004010',
        sku: 'SPC-CIN-100',
        category: 'Spices',
        sellingPrice: 1850.00,
        costPrice: 1100.00,
        stockOnHand: 75,
        minStockAlert: 15,
        imagePlaceholderColor: '0xFFD97706',
      ),
      VendorProduct(
        id: 402,
        vendorId: 'VND-004',
        name: 'Single Estate Silver Tips White Tea 50g',
        barcode: '4792049004027',
        sku: 'TEA-SLV-050',
        category: 'Tea',
        sellingPrice: 4500.00,
        costPrice: 2800.00,
        stockOnHand: 25,
        minStockAlert: 5,
        imagePlaceholderColor: '0xFFE2E8F0',
      ),
    ],
  };

  // Fast O(1) in-memory barcode index
  final Map<String, VendorProduct> _barcodeIndex = {};

  @override
  List<VendorProduct> build() {
    final currentVendor = ref.watch(currentVendorProvider);
    final vendorId = currentVendor.vendorId;

    final products = _isolatedVendorDbs[vendorId] ?? [];
    _rebuildBarcodeIndex(products);
    return products;
  }

  void _rebuildBarcodeIndex(List<VendorProduct> products) {
    _barcodeIndex.clear();
    for (final p in products) {
      if (p.barcode.isNotEmpty) {
        _barcodeIndex[p.barcode] = p;
      }
    }
  }

  /// Instant O(1) lookup by barcode for high-speed POS scanning
  VendorProduct? findByBarcode(String barcode) {
    return _barcodeIndex[barcode.trim()];
  }

  /// Add new product to current vendor's isolated database
  void addProduct(VendorProduct product) {
    final currentVendor = ref.read(currentVendorProvider);
    final vendorId = currentVendor.vendorId;

    final currentList = _isolatedVendorDbs[vendorId] ?? [];
    final updatedList = [...currentList, product];
    _isolatedVendorDbs[vendorId] = updatedList;

    _rebuildBarcodeIndex(updatedList);
    state = updatedList;

    // Broadcast live event
    _stockEventController.add(VendorStockUpdateEvent(
      vendorId: vendorId,
      productId: product.id,
      productName: product.name,
      newStock: product.stockOnHand,
      delta: product.stockOnHand,
      updatedBy: 'Admin Added SKU',
      timestamp: DateTime.now(),
    ));
  }

  /// Update existing product
  void updateProduct(VendorProduct updated) {
    final currentVendor = ref.read(currentVendorProvider);
    final vendorId = currentVendor.vendorId;

    final currentList = _isolatedVendorDbs[vendorId] ?? [];
    final updatedList = [
      for (final p in currentList)
        if (p.id == updated.id) updated else p
    ];
    _isolatedVendorDbs[vendorId] = updatedList;

    _rebuildBarcodeIndex(updatedList);
    state = updatedList;
  }

  /// Fast barcode overwrite/assignment
  void updateBarcode(int productId, String newBarcode) {
    final currentVendor = ref.read(currentVendorProvider);
    final vendorId = currentVendor.vendorId;

    final currentList = _isolatedVendorDbs[vendorId] ?? [];
    final updatedList = [
      for (final p in currentList)
        if (p.id == productId)
          p.copyWith(barcode: newBarcode.trim())
        else
          p
    ];
    _isolatedVendorDbs[vendorId] = updatedList;

    _rebuildBarcodeIndex(updatedList);
    state = updatedList;
  }

  /// Instant real-time stock adjustment (+ or -) with live broadcasting
  void adjustStock(int productId, int delta, {String reason = 'Admin Stock Adjustment'}) {
    final currentVendor = ref.read(currentVendorProvider);
    final vendorId = currentVendor.vendorId;

    VendorProduct? modifiedProduct;
    final currentList = _isolatedVendorDbs[vendorId] ?? [];
    final updatedList = [
      for (final p in currentList)
        if (p.id == productId) ...[
          () {
            final newQty = (p.stockOnHand + delta).clamp(0, 999999);
            final updated = p.copyWith(stockOnHand: newQty);
            modifiedProduct = updated;
            return updated;
          }()
        ] else
          p
    ];

    _isolatedVendorDbs[vendorId] = updatedList;
    _rebuildBarcodeIndex(updatedList);
    state = updatedList;

    if (modifiedProduct != null) {
      _stockEventController.add(VendorStockUpdateEvent(
        vendorId: vendorId,
        productId: productId,
        productName: modifiedProduct!.name,
        newStock: modifiedProduct!.stockOnHand,
        delta: delta,
        updatedBy: reason,
        reason: reason,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Real-time inventory deduction when Cashier tenders POS order
  void deductSoldQuantities(Map<int, int> itemsSold) {
    final currentVendor = ref.read(currentVendorProvider);
    final vendorId = currentVendor.vendorId;

    final currentList = _isolatedVendorDbs[vendorId] ?? [];
    final updatedList = [
      for (final p in currentList)
        if (itemsSold.containsKey(p.id)) ...[
          () {
            final soldQty = itemsSold[p.id]!;
            final newQty = (p.stockOnHand - soldQty).clamp(0, 999999);
            final updated = p.copyWith(stockOnHand: newQty);
            _stockEventController.add(VendorStockUpdateEvent(
              vendorId: vendorId,
              productId: p.id,
              productName: p.name,
              newStock: newQty,
              delta: -soldQty,
              updatedBy: 'POS Sale Checkout',
              timestamp: DateTime.now(),
            ));
            return updated;
          }()
        ] else
          p
    ];

    _isolatedVendorDbs[vendorId] = updatedList;
    _rebuildBarcodeIndex(updatedList);
    state = updatedList;
  }
}
