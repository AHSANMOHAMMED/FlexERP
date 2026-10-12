import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/executive_repository.dart';
import '../../data/repositories/pos_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/stock_quant_repository.dart';
import '../../data/repositories/vendor_inventory_repository.dart';
import '../../data/repositories/accounting_repository.dart';

class LiveSyncState {
  final int latestId;
  final bool running;
  final String? lastError;

  const LiveSyncState({this.latestId = 0, this.running = false, this.lastError});
}

class LiveSyncNotifier extends Notifier<LiveSyncState> {
  Timer? _timer;

  @override
  LiveSyncState build() {
    ref.onDispose(() => _timer?.cancel());
    return const LiveSyncState();
  }

  void start() {
    _timer?.cancel();
    state = LiveSyncState(latestId: state.latestId, running: true);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => poll());
    Future.microtask(poll);
  }

  void stop() {
    _timer?.cancel();
    state = LiveSyncState(latestId: state.latestId, running: false);
  }

  Future<void> poll() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final result = await api.livePoll(sinceId: state.latestId);
      final events = (result['events'] as List?) ?? const [];
      final latest = result['latest_id'] as int? ?? state.latestId;
      if (events.isEmpty) {
        state = LiveSyncState(latestId: latest, running: state.running);
        return;
      }
      var needStock = false;
      var needSales = false;
      var needInvoice = false;
      for (final raw in events) {
        final type = (raw as Map)['type']?.toString();
        if (type == 'stock' || type == 'sale') needStock = true;
        if (type == 'sale') needSales = true;
        if (type == 'invoice' || type == 'payment') needInvoice = true;
      }
      if (needStock) {
        await ref.read(vendorInventoryProvider.notifier).syncFromServer();
        await ref.read(stockQuantsProvider.notifier).syncFromOdoo();
      }
      if (needSales) {
        await ref.read(saleOrdersProvider.notifier).syncFromOdoo();
        await ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo();
        await ref.read(executiveKpisProvider.notifier).syncFromServer();
      }
      if (needInvoice) {
        await ref.read(invoicesProvider.notifier).syncFromOdoo();
      }
      state = LiveSyncState(latestId: latest, running: state.running);
    } catch (e) {
      state = LiveSyncState(latestId: state.latestId, running: state.running, lastError: e.toString());
    }
  }

  void notifyLocal({required String type}) {
    // Immediate local refresh after own write (no wait for poll).
    Future.microtask(() async {
      if (type == 'stock' || type == 'sale') {
        await ref.read(vendorInventoryProvider.notifier).syncFromServer();
      }
      if (type == 'sale') {
        await ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo();
        await ref.read(executiveKpisProvider.notifier).syncFromServer();
      }
      if (type == 'invoice') {
        await ref.read(invoicesProvider.notifier).syncFromOdoo();
      }
    });
  }
}

final liveSyncProvider = NotifierProvider<LiveSyncNotifier, LiveSyncState>(LiveSyncNotifier.new);
