import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pos_order.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

import 'vendor_inventory_repository.dart';

final posProductsProvider = Provider<List<PosProduct>>((ref) {
  final vendorProducts = ref.watch(vendorInventoryProvider);
  if (vendorProducts.isNotEmpty) {
    return vendorProducts.map((vp) => vp.toPosProduct()).toList();
  }
  return MockSriLankaDataService.posProducts;
});

final posCartProvider = NotifierProvider<PosCartNotifier, List<PosCartItem>>(
  PosCartNotifier.new,
);

final posSessionProvider = NotifierProvider<PosSessionNotifier, PosShiftSession>(
  PosSessionNotifier.new,
);

class PosCartNotifier extends Notifier<List<PosCartItem>> {
  @override
  List<PosCartItem> build() => [];

  Map<int, int> getSoldQuantities() {
    final map = <int, int>{};
    for (final item in state) {
      map[item.product.id] = (map[item.product.id] ?? 0) + item.quantity;
    }
    return map;
  }

  void completeCheckoutAndDeductStock() {
    final soldMap = getSoldQuantities();
    if (soldMap.isNotEmpty) {
      ref.read(vendorInventoryProvider.notifier).deductSoldQuantities(soldMap);
    }
    clear();
  }

  void addProduct(PosProduct product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            PosCartItem(
              product: existing.product,
              quantity: existing.quantity + 1,
              discountPercent: existing.discountPercent,
            )
          else
            state[i]
      ];
    } else {
      state = [...state, PosCartItem(product: product, quantity: 1)];
    }
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      state = state.where((item) => item.product.id != productId).toList();
    } else {
      state = [
        for (final item in state)
          if (item.product.id == productId)
            PosCartItem(
              product: item.product,
              quantity: quantity,
              discountPercent: item.discountPercent,
            )
          else
            item
      ];
    }
  }

  void clear() {
    state = [];
  }

  double get totalAmount => state.fold(0.0, (prev, item) => prev + item.subtotal);
  int get totalItemCount => state.fold(0, (prev, item) => prev + item.quantity);
}

class PosSessionNotifier extends Notifier<PosShiftSession> {
  @override
  PosShiftSession build() => MockSriLankaDataService.activePosSession;

  void recordSale({required double cashAmount, required double cardAmount}) {
    state = PosShiftSession(
      id: state.id,
      name: state.name,
      cashierName: state.cashierName,
      openingTime: state.openingTime,
      openingBalance: state.openingBalance,
      cashSalesTotal: state.cashSalesTotal + cashAmount,
      cardSalesTotal: state.cardSalesTotal + cardAmount,
      transactionCount: state.transactionCount + 1,
      state: state.state,
    );
  }

  void closeSession() {
    state = PosShiftSession(
      id: state.id,
      name: state.name,
      cashierName: state.cashierName,
      openingTime: state.openingTime,
      openingBalance: state.openingBalance,
      cashSalesTotal: state.cashSalesTotal,
      cardSalesTotal: state.cardSalesTotal,
      transactionCount: state.transactionCount,
      state: 'closed',
    );
  }
}

class PosOrdersHistoryNotifier extends Notifier<List<PosPastOrder>> {
  @override
  List<PosPastOrder> build() => MockSriLankaDataService.mockPastPosOrders;

  Future<void> syncFromOdoo() async {
    final client = ref.read(odooClientProvider);
    if (client == null || !client.isAuthenticated) return;

    try {
      final results = await client.searchRead(
        model: 'pos.order',
        fields: [
          'id',
          'pos_reference',
          'partner_id',
          'amount_total',
          'date_order',
          'state',
        ],
        limit: 40,
      );

      if (results.isNotEmpty) {
        final orders = results.map((item) {
          final partner = item['partner_id'] is List ? item['partner_id'] as List : [0, 'Walk-in Customer'];
          final dateStr = item['date_order']?.toString();

          return PosPastOrder(
            id: (item['id'] as num?)?.toInt() ?? 0,
            receiptNumber: item['pos_reference']?.toString() ?? 'POS/RECEIPT',
            orderDate: dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
            customerName: partner.length > 1 ? partner[1].toString() : 'Walk-in Customer',
            totalAmount: (item['amount_total'] as num?)?.toDouble() ?? 0.0,
            paymentMethod: 'LANKAQR / Cash',
            status: item['state']?.toString() ?? 'paid',
          );
        }).toList();

        state = orders;
      }
    } catch (_) {
      // Fallback
    }
  }

  void addOrder(PosPastOrder order) {
    state = [order, ...state];
  }
}

final posOrdersHistoryProvider = NotifierProvider<PosOrdersHistoryNotifier, List<PosPastOrder>>(
  PosOrdersHistoryNotifier.new,
);
