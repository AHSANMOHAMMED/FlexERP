import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_picking.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import 'auth_repository.dart';

class StockPickingsNotifier extends Notifier<List<StockPicking>> {
  @override
  List<StockPicking> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.stockPickings);
  }

  /// Loads the picking list only (one request). Move lines are fetched on
  /// demand via [loadPickingDetail] — no N+1 detail calls per refresh.
  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo) return;
    if (api == null) throw OdooException('Not authenticated');

    final records = await api.stockPickings();
    final previous = {for (final p in state) p.id: p};
    state = [
      for (final rec in records)
        if (parseOdooInt(rec['id']) != null)
          () {
            final id = parseOdooInt(rec['id'])!;
            final prior = previous[id];
            final picking = StockPicking(
              id: id,
              name: rec['name']?.toString() ?? 'WH/OUT/000',
              partnerName: rec['partner']?.toString() ?? 'Warehouse Partner',
              origin: rec['origin']?.toString() ?? 'Manual',
              pickingType: rec['picking_type']?.toString() ?? 'Delivery Orders',
              state: rec['state']?.toString() ?? 'assigned',
              scheduledDate: rec['scheduled_date'] != null
                  ? DateTime.tryParse(rec['scheduled_date'].toString()) ?? DateTime.now()
                  : DateTime.now(),
              lines: const [],
              linesLoaded: false,
            );
            // Keep already-fetched lines (and local scan progress) if unchanged.
            if (prior != null && prior.linesLoaded && prior.state == picking.state) {
              return picking.copyWith(lines: prior.lines, linesLoaded: true);
            }
            return picking;
          }(),
    ];
  }

  /// Fetches move lines for one picking (when the user opens it).
  Future<void> loadPickingDetail(int pickingId, {bool force = false}) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo) return;
    if (api == null) throw OdooException('Not authenticated');
    final existing = state.where((p) => p.id == pickingId);
    if (!force && existing.isNotEmpty && existing.first.linesLoaded) return;
    final detail = await api.stockPicking(pickingId);
    final rawLines = detail['lines'] as List? ?? const [];
    final lines = rawLines.map((line) {
      final map = Map<String, dynamic>.from(line as Map);
      return PickingMoveLine(
        id: parseOdooInt(map['move_id']) ?? parseOdooInt(map['id']) ?? 0,
        productName: map['product_name']?.toString() ?? 'Product',
        barcode: map['barcode']?.toString() ?? '',
        sourceLocation: map['location_src']?.toString() ?? '',
        expectedQty: (map['product_uom_qty'] as num?)?.toDouble() ?? 0.0,
        scannedQty: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
    state = [
      for (final p in state)
        if (p.id == pickingId)
          p.copyWith(
            lines: lines,
            linesLoaded: true,
            state: detail['state']?.toString() ?? p.state,
          )
        else
          p
    ];
  }

  void incrementScannedQty(int pickingId, int lineId) {
    state = [
      for (final p in state)
        if (p.id == pickingId)
          StockPicking(
            id: p.id,
            name: p.name,
            partnerName: p.partnerName,
            origin: p.origin,
            pickingType: p.pickingType,
            state: p.state,
            scheduledDate: p.scheduledDate,
            lines: [
              for (final line in p.lines)
                if (line.id == lineId)
                  PickingMoveLine(
                    id: line.id,
                    productName: line.productName,
                    barcode: line.barcode,
                    sourceLocation: line.sourceLocation,
                    expectedQty: line.expectedQty,
                    scannedQty:
                        line.scannedQty < line.expectedQty ? line.scannedQty + 1 : line.scannedQty,
                  )
                else
                  line,
            ],
          )
        else
          p
    ];
  }

  Future<void> validatePicking(int pickingId) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      final result = await api.validatePicking(pickingId);
      final newState = result['state']?.toString() ?? 'done';
      state = [
        for (final p in state)
          if (p.id == pickingId)
            StockPicking(
              id: p.id,
              name: p.name,
              partnerName: p.partnerName,
              origin: p.origin,
              pickingType: p.pickingType,
              state: newState,
              scheduledDate: p.scheduledDate,
              lines: p.lines,
            )
          else
            p
      ];
      if (result['requires_action'] == true) {
        // e.g. lots/serials or zero-quantity confirmation: finish in Odoo.
        throw OdooException(result['message']?.toString() ??
            'Additional confirmation is required in the Odoo backend.');
      }
      return;
    }

    state = [
      for (final p in state)
        if (p.id == pickingId)
          StockPicking(
            id: p.id,
            name: p.name,
            partnerName: p.partnerName,
            origin: p.origin,
            pickingType: p.pickingType,
            state: 'done',
            scheduledDate: p.scheduledDate,
            lines: p.lines,
          )
        else
          p
    ];
  }
}

final stockPickingsProvider =
    NotifierProvider<StockPickingsNotifier, List<StockPicking>>(StockPickingsNotifier.new);
