import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

class ExecutiveKpis {
  final double todayRevenue;
  final int todayOrders;
  final int unpaidInvoices;
  final int pendingShipments;
  final String vendorId;

  const ExecutiveKpis({
    this.todayRevenue = 0,
    this.todayOrders = 0,
    this.unpaidInvoices = 0,
    this.pendingShipments = 0,
    this.vendorId = '',
  });
}

class ExecutiveKpisNotifier extends Notifier<ExecutiveKpis> {
  @override
  ExecutiveKpis build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) {
      return ExecutiveKpis(vendorId: user.vendorId);
    }
    return const ExecutiveKpis(
      todayRevenue: 4850000,
      todayOrders: 12,
      unpaidInvoices: 8,
      pendingShipments: 38,
      vendorId: 'DEMO',
    );
  }

  Future<void> syncFromServer() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final data = await api.executiveKpis();
      state = ExecutiveKpis(
        todayRevenue: (data['today_revenue'] as num?)?.toDouble() ?? 0,
        todayOrders: (data['today_orders'] as num?)?.toInt() ?? 0,
        unpaidInvoices: (data['unpaid_invoices'] as num?)?.toInt() ?? 0,
        pendingShipments: (data['pending_shipments'] as num?)?.toInt() ?? 0,
        vendorId: data['vendor_id']?.toString() ?? user.vendorId,
      );
    } catch (_) {
      // Keep last good / zero state — never reinject demo numbers in live mode.
    }
  }
}

final executiveKpisProvider =
    NotifierProvider<ExecutiveKpisNotifier, ExecutiveKpis>(ExecutiveKpisNotifier.new);
