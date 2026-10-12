import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../models/stock_quant.dart';
import 'auth_repository.dart';

class StockQuantsNotifier extends Notifier<List<StockQuant>> {
  @override
  List<StockQuant> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return MockSriLankaDataService.mockStockQuants;
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final client = ref.read(odooClientProvider);
    if (user == null || user.isDemo) return;

    if (api != null) {
      final results = await api.stockQuants();
      state = results.map((item) {
        return StockQuant(
          id: (item['id'] as num?)?.toInt() ?? 0,
          productName: item['product_name']?.toString() ?? 'Product',
          productSku: item['sku']?.toString() ?? '',
          locationName: item['location']?.toString() ?? 'Internal',
          warehouseCode: 'WH',
          quantityOnHand: (item['quantity'] as num?)?.toDouble() ?? 0.0,
          reservedQuantity: (item['reserved'] as num?)?.toDouble() ?? 0.0,
          costPrice: 0,
        );
      }).toList();
      return;
    }

    if (client == null || !client.isAuthenticated) return;
    final results = await client.searchRead(
      model: 'stock.quant',
      domain: [
        ['quantity', '>', 0]
      ],
      fields: ['id', 'product_id', 'location_id', 'quantity', 'reserved_quantity'],
      limit: 50,
    );
    state = results.map((item) {
      final prod = item['product_id'] is List ? item['product_id'] as List : [0, 'Product'];
      final loc = item['location_id'] is List ? item['location_id'] as List : [0, 'Location'];
      return StockQuant(
        id: (item['id'] as num?)?.toInt() ?? 0,
        productName: prod.length > 1 ? prod[1].toString() : 'Product',
        productSku: 'SKU-${prod[0]}',
        locationName: loc.length > 1 ? loc[1].toString() : 'Internal Location',
        warehouseCode: 'WH-MAIN',
        quantityOnHand: (item['quantity'] as num?)?.toDouble() ?? 0.0,
        reservedQuantity: (item['reserved_quantity'] as num?)?.toDouble() ?? 0.0,
        costPrice: 2500.0,
      );
    }).toList();
  }

  void updateQuantity(int quantId, double newQty) {
    state = [
      for (final q in state)
        if (q.id == quantId)
          StockQuant(
            id: q.id,
            productName: q.productName,
            productSku: q.productSku,
            locationName: q.locationName,
            warehouseCode: q.warehouseCode,
            quantityOnHand: newQty,
            reservedQuantity: q.reservedQuantity,
            uom: q.uom,
            costPrice: q.costPrice,
            category: q.category,
          )
        else
          q,
    ];
  }
}

final stockQuantsProvider = NotifierProvider<StockQuantsNotifier, List<StockQuant>>(
  StockQuantsNotifier.new,
);
