import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

class PurchaseOrderSummary {
  final int id;
  final String name;
  final String partnerName;
  final double amountTotal;
  final String state;
  final DateTime dateOrder;

  const PurchaseOrderSummary({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.amountTotal,
    required this.state,
    required this.dateOrder,
  });
}

class PurchaseOrdersNotifier extends Notifier<List<PurchaseOrderSummary>> {
  @override
  List<PurchaseOrderSummary> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return const [];
  }

  Future<void> syncFromServer() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final rows = await api.purchaseOrders();
      state = rows.map((r) {
        return PurchaseOrderSummary(
          id: r['id'] as int? ?? 0,
          name: r['name']?.toString() ?? 'PO',
          partnerName: r['partner_name']?.toString() ?? 'Vendor',
          amountTotal: (r['amount_total'] as num?)?.toDouble() ?? 0,
          state: r['state']?.toString() ?? 'draft',
          dateOrder: DateTime.tryParse(r['date_order']?.toString() ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (_) {
      rethrow; // surface module_not_installed / feature-disabled to UI
    }
  }

  Future<Map<String, dynamic>?> createOrder({
    required int partnerId,
    required List<Map<String, dynamic>> lines,
    bool confirm = false,
  }) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return null;
    final created = await api.purchaseCreateOrder(
      partnerId: partnerId,
      lines: lines,
      confirm: confirm,
    );
    await syncFromServer();
    return created;
  }
}

final purchaseOrdersProvider =
    NotifierProvider<PurchaseOrdersNotifier, List<PurchaseOrderSummary>>(
  PurchaseOrdersNotifier.new,
);
