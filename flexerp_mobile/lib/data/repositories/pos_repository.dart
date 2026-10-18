import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pos_order.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import '../../core/offline/offline_queue.dart';
import 'auth_repository.dart';
import 'vendor_inventory_repository.dart';

String _newPosOrderUuid() {
  final r = Random.secure();
  final hex = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-'
      '${(8 + r.nextInt(4)).toRadixString(16)}${hex.substring(17, 20)}-${hex.substring(20)}';
}

final posProductsProvider = Provider<List<PosProduct>>((ref) {
  final vendorProducts = ref.watch(vendorInventoryProvider);
  if (vendorProducts.isNotEmpty) {
    return vendorProducts.map((vp) => vp.toPosProduct()).toList();
  }
  final user = ref.watch(currentUserProvider);
  if (user != null && !user.isDemo) return const [];
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

  Future<Map<String, dynamic>> completeCheckoutAndPush({
    required String paymentMethod,
    required double cashAmount,
    required double cardAmount,
    int? partnerId,
    bool createInvoice = false,
  }) async {
    final user = ref.read(currentUserProvider);
    final session = ref.read(posSessionProvider);
    final lines = state
        .map((item) => {
              'product_id': item.product.id,
              'qty': item.quantity.toDouble(),
              'price_unit': item.product.price,
            })
        .toList();
    final total = totalAmount;
    if (session.id <= 0 && user != null && !user.isDemo) {
      throw OdooException('POS session is not open. Open a shift before selling.');
    }
    final orderUuid = _newPosOrderUuid();
    final payload = {
      'session_id': session.id,
      'uuid': orderUuid,
      'lines': lines,
      'amount_total': total,
      'payment_method': paymentMethod,
      if (partnerId != null) 'partner_id': partnerId,
      'create_invoice': createInvoice,
    };

    Map<String, dynamic> result = {'queued': false, 'local': true, 'uuid': orderUuid};

    if (user != null && !user.isDemo) {
      final api = ref.read(flexerpApiProvider);
      try {
        if (api == null) throw OdooException('Not authenticated');
        result = await api.posPushOrder(payload);
        result['queued'] = false;
        result['local'] = false;
      } catch (e) {
        // Queue with stable uuid so retries never double-post the sale.
        await ref.read(offlineQueueProvider.notifier).enqueue(
              type: 'pos_order',
              payload: payload,
            );
        result = {
          'queued': true,
          'local': false,
          'amount_total': total,
          'uuid': orderUuid,
          'error': e.toString(),
        };
      }
    }

    final soldMap = getSoldQuantities();
    if (soldMap.isNotEmpty) {
      ref.read(vendorInventoryProvider.notifier).deductSoldQuantities(soldMap);
    }
    ref.read(posSessionProvider.notifier).recordSale(
          cashAmount: cashAmount,
          cardAmount: cardAmount,
        );
    clear();
    return result;
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

  Future<void> openLiveSession() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    final configs = await api.posConfigs();
    if (configs.isEmpty) throw OdooException('No POS config found for this company');
    final configId = configs.first['id'] as int;
    final opened = await api.posOpenSession(configId);
    state = PosShiftSession(
      id: opened['session_id'] as int,
      name: opened['name']?.toString() ?? 'POS Session',
      cashierName: user.name,
      openingTime: DateTime.now(),
      openingBalance: state.openingBalance,
      cashSalesTotal: 0,
      cardSalesTotal: 0,
      transactionCount: 0,
      state: opened['state']?.toString() ?? 'opened',
    );
  }

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

  Future<void> closeSession() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null && state.id > 0) {
      final closed = await api.posCloseSession(state.id);
      state = PosShiftSession(
        id: state.id,
        name: state.name,
        cashierName: state.cashierName,
        openingTime: state.openingTime,
        openingBalance: state.openingBalance,
        cashSalesTotal: state.cashSalesTotal,
        cardSalesTotal: state.cardSalesTotal,
        transactionCount: state.transactionCount,
        state: closed['state']?.toString() ?? 'closed',
      );
      return;
    }
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
  List<PosPastOrder> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return MockSriLankaDataService.mockPastPosOrders;
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;

    final results = await api.posOrders();
    state = results.map((item) {
      final dateStr = item['date_order']?.toString();
      return PosPastOrder(
        id: (item['id'] as num?)?.toInt() ?? 0,
        receiptNumber: item['pos_reference']?.toString() ?? item['name']?.toString() ?? 'POS/RECEIPT',
        orderDate: dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
        customerName: item['partner_name']?.toString() ?? 'Walk-in Customer',
        totalAmount: (item['amount_total'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: item['payment_method']?.toString().isNotEmpty == true
            ? item['payment_method'].toString()
            : 'Cash',
        status: item['state']?.toString() ?? 'paid',
      );
    }).toList();
  }

  void addOrder(PosPastOrder order) {
    state = [order, ...state];
  }
}

final posOrdersHistoryProvider =
    NotifierProvider<PosOrdersHistoryNotifier, List<PosPastOrder>>(
  PosOrdersHistoryNotifier.new,
);
