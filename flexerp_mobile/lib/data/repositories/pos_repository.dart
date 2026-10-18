import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pos_order.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import '../../core/offline/offline_queue.dart';
import 'auth_repository.dart';
import 'vendor_inventory_repository.dart';

/// RFC 4122 v4 uuid — generated once per checkout and reused on retries.
String newPosOrderUuid() {
  final r = Random.secure();
  final hex = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-'
      '${(8 + r.nextInt(4)).toRadixString(16)}${hex.substring(17, 20)}-${hex.substring(20)}';
}

/// Normalises the `/pos/order` response (new contract returns `id`,
/// legacy returned `order_id`).
Map<String, dynamic> normalizePosOrderResult(
  Map<String, dynamic> server, {
  required String fallbackUuid,
}) {
  final result = Map<String, dynamic>.from(server);
  final id = parseOdooInt(server['id']) ?? parseOdooInt(server['order_id']);
  result['order_id'] = id;
  result['id'] = id;
  result['uuid'] = server['uuid']?.toString() ?? fallbackUuid;
  result['queued'] = false;
  result['local'] = false;
  return result;
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

  /// Payload lines: product, qty, list price and per-line discount (%).
  /// The server recomputes prices / taxes / totals from these.
  List<Map<String, dynamic>> buildOrderLines() {
    return state
        .map((item) => {
              'product_id': item.product.id,
              'qty': item.quantity.toDouble(),
              'price_unit': item.product.price,
              'discount': item.discountPercent,
            })
        .toList();
  }

  /// Completes the sale.
  ///
  /// Live mode:
  /// * requires a real open POS session (never a mock id);
  /// * server accepted → stock deducted locally, receipt uses the server's
  ///   `amount_total` / `amount_tax`;
  /// * network failure → queued offline with the same `uuid`
  ///   (`queued: true`, shown as "pending sync"); no local stock deduction;
  /// * Odoo business error (UserError/ValidationError/AccessError) → thrown,
  ///   nothing queued, cart kept.
  ///
  /// [orderUuid] must be generated once per checkout (see [newPosOrderUuid])
  /// so a re-submit of the same checkout is deduplicated by the server.
  Future<Map<String, dynamic>> completeCheckoutAndPush({
    required String paymentMethod,
    required double cashAmount,
    required double cardAmount,
    required String orderUuid,
    int? partnerId,
    bool createInvoice = false,
  }) async {
    final user = ref.read(currentUserProvider);
    final session = ref.read(posSessionProvider);
    if (state.isEmpty) {
      throw OdooException('Cart is empty');
    }
    final isLive = user != null && !user.isDemo;
    final lines = buildOrderLines();
    final estimatedTotal = totalAmount;

    if (!isLive) {
      final soldMap = getSoldQuantities();
      if (soldMap.isNotEmpty) {
        ref.read(vendorInventoryProvider.notifier).deductSoldQuantities(soldMap);
      }
      ref.read(posSessionProvider.notifier).recordSale(
            cashAmount: cashAmount,
            cardAmount: cardAmount,
          );
      clear();
      return {
        'queued': false,
        'local': true,
        'uuid': orderUuid,
        'amount_total': estimatedTotal,
      };
    }

    if (!session.isLiveOpen) {
      throw OdooException(
        'No open POS session. Open the register session before selling.',
      );
    }
    final payload = <String, dynamic>{
      'session_id': session.id,
      'uuid': orderUuid,
      'lines': lines,
      // Client estimate only; the server computes the authoritative total.
      'amount_total': estimatedTotal,
      'payment_method': paymentMethod,
      if (partnerId != null) 'partner_id': partnerId,
      'create_invoice': createInvoice,
    };

    final api = ref.read(flexerpApiProvider);
    if (api == null) {
      throw OdooException('Not signed in to Odoo. Sign in again to sell.');
    }

    Map<String, dynamic> result;
    try {
      final server = await api.posPushOrder(payload);
      result = normalizePosOrderResult(server, fallbackUuid: orderUuid);
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow; // business error → surface, never queue
      await ref.read(offlineQueueProvider.notifier).enqueue(
            type: 'pos_order',
            payload: payload,
          );
      final queued = {
        'queued': true,
        'local': false,
        'uuid': orderUuid,
        'name': 'PENDING SYNC',
        'amount_total': estimatedTotal,
        'error': describeError(e),
      };
      clear();
      return queued;
    }

    final soldMap = getSoldQuantities();
    if (soldMap.isNotEmpty) {
      ref.read(vendorInventoryProvider.notifier).deductSoldQuantities(soldMap);
    }
    final serverTotal = (result['amount_total'] as num?)?.toDouble() ?? estimatedTotal;
    final paid = cashAmount + cardAmount;
    final ratio = paid > 0 ? serverTotal / paid : 1.0;
    ref.read(posSessionProvider.notifier).recordSale(
          cashAmount: cashAmount * ratio,
          cardAmount: cardAmount * ratio,
        );
    clear();
    return result;
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
  PosShiftSession build() {
    final ctx = ref.watch(currentUserProvider.select(
      (u) => (u?.isDemo, u?.uid, u?.companyId, u?.serverUrl, u?.name),
    ));
    final isDemo = ctx.$1;
    if (isDemo == null || isDemo) return MockSriLankaDataService.activePosSession;
    // Live: no session until the register opens/fetches a real one.
    return PosShiftSession(
      id: 0,
      name: 'No POS session',
      cashierName: ctx.$5 ?? '',
      openingTime: DateTime.now(),
      openingBalance: 0,
      state: PosShiftSession.stateNone,
    );
  }

  /// Fetches the company's POS configs and opens (or re-attaches to) the
  /// config's current session via `pos/session/open`.
  Future<void> openLiveSession({int? configId}) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo) return;
    if (api == null) throw OdooException('Not signed in to Odoo');
    var targetConfigId = configId;
    if (targetConfigId == null) {
      final configs = await api.posConfigs();
      if (configs.isEmpty) {
        throw OdooException('No Point of Sale configured for this company. '
            'Create one in Odoo → Point of Sale → Configuration.');
      }
      final withSession = configs.where((c) {
        final st = c['current_session_state']?.toString();
        return parseOdooInt(c['current_session_id']) != null &&
            (st == 'opened' || st == 'opening_control');
      });
      final chosen = withSession.isNotEmpty ? withSession.first : configs.first;
      targetConfigId = parseOdooInt(chosen['id']);
    }
    if (targetConfigId == null) throw OdooException('Invalid POS config from server');
    final opened = await api.posOpenSession(targetConfigId);
    final sessionId = parseOdooInt(opened['session_id']) ?? parseOdooInt(opened['id']);
    if (sessionId == null || sessionId <= 0) {
      throw OdooException('Server did not return an open POS session');
    }
    state = PosShiftSession(
      id: sessionId,
      name: opened['name']?.toString() ?? 'POS Session',
      cashierName: user.name,
      openingTime: DateTime.now(),
      openingBalance: (opened['cash_register_balance_start'] as num?)?.toDouble() ?? 0,
      cashSalesTotal: 0,
      cardSalesTotal: 0,
      transactionCount: 0,
      state: opened['state']?.toString() ?? 'opened',
      configId: targetConfigId,
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
      configId: state.configId,
    );
  }

  Future<void> closeSession() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo) {
      if (api == null) throw OdooException('Not signed in to Odoo');
      if (state.id <= 0) throw OdooException('No open POS session to close');
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
        configId: state.configId,
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
