import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../models/stock_quant.dart';
import 'auth_repository.dart';

final stockQuantsErrorProvider = NotifierProvider<_StringErrorNotifier, String?>(
  _StringErrorNotifier.new,
);

class _StringErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setError(String? v) => state = v;
}

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
      try {
        final results = await api.stockQuants();
        state = results.map((item) {
          return StockQuant(
            id: (item['id'] as num?)?.toInt() ?? 0,
            productId: (item['product_id'] as num?)?.toInt() ?? 0,
            productName: item['product_name']?.toString() ?? 'Product',
            productSku: item['sku']?.toString() ?? '',
            locationName: item['location']?.toString() ?? 'Internal',
            warehouseCode: 'WH',
            quantityOnHand: (item['quantity'] as num?)?.toDouble() ?? 0.0,
            reservedQuantity: (item['reserved'] as num?)?.toDouble() ?? 0.0,
            costPrice: 0,
          );
        }).toList();
        ref.read(stockQuantsErrorProvider.notifier).setError(null);
      } catch (e) {
        ref.read(stockQuantsErrorProvider.notifier).setError(e.toString());
        rethrow;
      }
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
        productId: prod.isNotEmpty ? (prod[0] as num?)?.toInt() ?? 0 : 0,
        locationId: loc.isNotEmpty ? (loc[0] as num?)?.toInt() : null,
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

  /// Set absolute quantity; live mode posts a delta via stockAdjust.
  Future<void> updateQuantity(int quantId, double newQty) async {
    StockQuant? quant;
    for (final q in state) {
      if (q.id == quantId) {
        quant = q;
        break;
      }
    }
    if (quant == null) return;

    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final delta = newQty - quant.quantityOnHand;

    if (user != null && !user.isDemo && api != null && quant.productId > 0 && delta != 0) {
      try {
        await api.stockAdjust(
          productId: quant.productId,
          quantityDelta: delta,
          locationId: quant.locationId,
          reason: 'Mobile quant update',
        );
        await syncFromOdoo();
      } catch (e) {
        ref.read(stockQuantsErrorProvider.notifier).setError(e.toString());
        rethrow;
      }
      return;
    }

    state = [
      for (final q in state)
        if (q.id == quantId)
          StockQuant(
            id: q.id,
            productId: q.productId,
            locationId: q.locationId,
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
