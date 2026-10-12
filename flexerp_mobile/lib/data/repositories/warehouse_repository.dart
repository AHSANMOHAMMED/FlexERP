import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_picking.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

class StockPickingsNotifier extends Notifier<List<StockPicking>> {
  @override
  List<StockPicking> build() {
    return List.from(MockSriLankaDataService.stockPickings);
  }

  Future<void> syncFromOdoo() async {
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client == null) return;
    try {
      final records = await client.searchRead(
        model: 'stock.picking',
        domain: [],
        fields: ['id', 'name', 'partner_id', 'origin', 'picking_type_id', 'state', 'scheduled_date'],
        limit: 50,
      );
      if (records.isNotEmpty) {
        state = records.map((rec) {
          final partner = rec['partner_id'];
          final partnerName = partner is List && partner.length > 1 ? partner[1].toString() : 'Warehouse Partner';
          final pickType = rec['picking_type_id'];
          final pickTypeName = pickType is List && pickType.length > 1 ? pickType[1].toString() : 'Delivery Orders';
          return StockPicking(
            id: rec['id'] as int,
            name: rec['name'] as String? ?? 'WH/OUT/000',
            partnerName: partnerName,
            origin: rec['origin']?.toString() ?? 'Manual',
            pickingType: pickTypeName,
            state: rec['state']?.toString() ?? 'assigned',
            scheduledDate: rec['scheduled_date'] != null
                ? DateTime.tryParse(rec['scheduled_date'].toString()) ?? DateTime.now()
                : DateTime.now(),
            lines: [
              PickingMoveLine(
                id: 1,
                productName: 'Sample Logistic SKU Item',
                barcode: '4792001928312',
                sourceLocation: 'WH/Kelaniya/Stock',
                expectedQty: 10,
                scannedQty: 10,
              ),
            ],
          );
        }).toList();
      }
    } catch (_) {
      // Gracefully maintain offline state
    }
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
                    scannedQty: line.scannedQty < line.expectedQty ? line.scannedQty + 1 : line.scannedQty,
                  )
                else
                  line,
            ],
          )
        else
          p
    ];
  }

  void validatePicking(int pickingId) {
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
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client != null) {
      client.callButton(model: 'stock.picking', method: 'button_validate', ids: [pickingId]).catchError((_) => null);
    }
  }
}

final stockPickingsProvider = NotifierProvider<StockPickingsNotifier, List<StockPicking>>(StockPickingsNotifier.new);
