import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/executive_repository.dart';
import '../../data/repositories/pos_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/stock_quant_repository.dart';
import '../../data/repositories/vendor_inventory_repository.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/repositories/vendor_repository.dart';

class LiveSyncState {
  final int latestId;
  final bool running;
  final bool foreground;
  final String? lastError;
  final int backoffSeconds;

  const LiveSyncState({
    this.latestId = 0,
    this.running = false,
    this.foreground = true,
    this.lastError,
    this.backoffSeconds = 0,
  });
}

/// Cursor maths for `/flexerp/mobile/live/poll`.
///
/// * The server reports the newest id as `latest_id` (or `last_id`).
/// * With `since_id == 0` the server returns no events, only the current
///   `last_id` — the client adopts it as its starting cursor and processes
///   nothing (avoids replaying history on first launch).
/// * The cursor never moves backwards.
({int nextId, List<Map<String, dynamic>> events}) computeLiveCursor(
  int sinceId,
  Map<String, dynamic> result,
) {
  final rawEvents = (result['events'] as List?) ?? const [];
  final events = <Map<String, dynamic>>[
    for (final e in rawEvents)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
  var next = parseOdooInt(result['latest_id']) ?? parseOdooInt(result['last_id']) ?? sinceId;
  for (final e in events) {
    final id = parseOdooInt(e['id']);
    if (id != null && id > next) next = id;
  }
  if (next < sinceId) next = sinceId;
  if (sinceId <= 0) {
    return (nextId: next, events: const <Map<String, dynamic>>[]);
  }
  return (nextId: next, events: events);
}

class LiveSyncNotifier extends Notifier<LiveSyncState> {
  Timer? _timer;
  bool _polling = false;
  final _rng = Random();

  static const _baseInterval = Duration(seconds: 6);

  @override
  LiveSyncState build() {
    ref.onDispose(() => _timer?.cancel());
    // Logout / tenant switch: stop polling and restart from the cursor the
    // new bootstrap reported.
    ref.listen(
      currentUserProvider.select((u) => (u?.uid, u?.companyId, u?.serverUrl, u?.isDemo)),
      (prev, next) {
        if (prev == next) return;
        if (next.$1 == null || next.$4 == true) {
          _timer?.cancel();
          state = LiveSyncState(running: false, foreground: state.foreground);
          return;
        }
        if (state.running) {
          start(fromEventId: ref.read(currentUserProvider.notifier).liveStartEventId, reset: true);
        }
      },
    );
    return const LiveSyncState();
  }

  void setForeground(bool foreground) {
    state = LiveSyncState(
      latestId: state.latestId,
      running: state.running,
      foreground: foreground,
      lastError: state.lastError,
      backoffSeconds: state.backoffSeconds,
    );
    if (foreground && state.running) {
      Future.microtask(poll);
    }
  }

  /// Starts polling. [fromEventId] is bootstrap's `live_last_event_id`;
  /// when unknown the first poll uses since_id=0 to fetch the cursor only.
  void start({int? fromEventId, bool reset = false}) {
    _timer?.cancel();
    final cursor = fromEventId ?? (reset ? 0 : state.latestId);
    state = LiveSyncState(
      latestId: cursor,
      running: true,
      foreground: state.foreground,
    );
    _scheduleNext(immediate: true);
  }

  void stop() {
    _timer?.cancel();
    state = LiveSyncState(
      latestId: state.latestId,
      running: false,
      foreground: state.foreground,
    );
  }

  void _scheduleNext({bool immediate = false}) {
    _timer?.cancel();
    if (!state.running) return;
    final backoff = state.backoffSeconds;
    final jitterMs = _rng.nextInt(800);
    final delay = immediate
        ? Duration.zero
        : Duration(
            milliseconds: (_baseInterval.inMilliseconds) +
                (backoff * 1000) +
                jitterMs,
          );
    _timer = Timer(delay, () async {
      await poll();
      _scheduleNext();
    });
  }

  Future<void> poll() async {
    if (_polling) return;
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    if (!state.foreground || !state.running) return;

    _polling = true;
    try {
      final features = ref.read(currentVendorFeaturesProvider);
      final sinceId = state.latestId;
      final result = await api.livePoll(sinceId: sinceId);
      final cursor = computeLiveCursor(sinceId, result);
      final latest = cursor.nextId;
      final events = cursor.events;
      if (events.isEmpty) {
        state = LiveSyncState(
          latestId: latest,
          running: state.running,
          foreground: state.foreground,
        );
        return;
      }

      var needStock = false;
      var needSales = false;
      var needInvoice = false;
      for (final raw in events) {
        final type = raw['type']?.toString();
        if (type == 'stock' || type == 'sale') needStock = true;
        if (type == 'sale') needSales = true;
        if (type == 'invoice' || type == 'payment') needInvoice = true;
      }

      final tasks = <Future<void>>[];
      if (needStock && (features.enableInventory || features.enablePos || features.enableWarehouse)) {
        tasks.add(ref.read(vendorInventoryProvider.notifier).syncFromServer());
        tasks.add(ref.read(stockQuantsProvider.notifier).syncFromOdoo());
        api.client.invalidateCachePrefix('pos/products');
        api.client.invalidateCachePrefix('products');
      }
      if (needSales && (features.enableSales || features.enablePos)) {
        if (features.enableSales) {
          tasks.add(ref.read(saleOrdersProvider.notifier).syncFromOdoo());
        }
        if (features.enablePos) {
          tasks.add(ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo());
        }
        if (features.enableExecutive) {
          tasks.add(ref.read(executiveKpisProvider.notifier).syncFromServer());
        }
      }
      if (needInvoice && (features.enableInvoicing || features.enablePayments)) {
        tasks.add(ref.read(invoicesProvider.notifier).syncFromOdoo());
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }

      state = LiveSyncState(
        latestId: latest,
        running: state.running,
        foreground: state.foreground,
      );
    } catch (e) {
      debugPrint('FlexERP: live poll failed: $e');
      final nextBackoff = (state.backoffSeconds == 0
              ? 4
              : (state.backoffSeconds * 2).clamp(4, 60))
          .toInt();
      state = LiveSyncState(
        latestId: state.latestId,
        running: state.running,
        foreground: state.foreground,
        lastError: e.toString(),
        backoffSeconds: nextBackoff,
      );
    } finally {
      _polling = false;
    }
  }

  void notifyLocal({required String type}) {
    Future.microtask(() async {
      final features = ref.read(currentVendorFeaturesProvider);
      final tasks = <Future<void>>[];
      if ((type == 'stock' || type == 'sale') &&
          (features.enableInventory || features.enablePos)) {
        tasks.add(ref.read(vendorInventoryProvider.notifier).syncFromServer());
      }
      if (type == 'sale' && features.enablePos) {
        tasks.add(ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo());
      }
      if (type == 'sale' && features.enableExecutive) {
        tasks.add(ref.read(executiveKpisProvider.notifier).syncFromServer());
      }
      if (type == 'invoice' && features.enableInvoicing) {
        tasks.add(ref.read(invoicesProvider.notifier).syncFromOdoo());
      }
      if (tasks.isEmpty) return;
      try {
        await Future.wait(tasks);
      } catch (e) {
        debugPrint('FlexERP: local refresh after $type failed: $e');
      }
    });
  }
}

final liveSyncProvider = NotifierProvider<LiveSyncNotifier, LiveSyncState>(LiveSyncNotifier.new);
