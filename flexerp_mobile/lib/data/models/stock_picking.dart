class PickingMoveLine {
  final int id;
  final String productName;
  final String barcode;
  final String sourceLocation;
  final double expectedQty;
  double scannedQty;

  PickingMoveLine({
    required this.id,
    required this.productName,
    required this.barcode,
    required this.sourceLocation,
    required this.expectedQty,
    this.scannedQty = 0.0,
  });

  bool get isFulfilled => scannedQty >= expectedQty;
}

class StockPicking {
  final int id;
  final String name; // e.g. "WH/OUT/00189"
  final String partnerName;
  final String origin; // e.g. "SO/2026/00142"
  final String pickingType; // 'outgoing', 'incoming', 'internal'
  final String state; // 'draft', 'waiting', 'confirmed', 'assigned' (Ready), 'done'
  final List<PickingMoveLine> lines;
  final DateTime scheduledDate;

  /// False for live list rows whose move lines have not been fetched yet
  /// (details are loaded on demand when the picking is opened).
  final bool linesLoaded;

  StockPicking({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.origin,
    required this.pickingType,
    required this.state,
    required this.lines,
    required this.scheduledDate,
    this.linesLoaded = true,
  });

  StockPicking copyWith({String? state, List<PickingMoveLine>? lines, bool? linesLoaded}) {
    return StockPicking(
      id: id,
      name: name,
      partnerName: partnerName,
      origin: origin,
      pickingType: pickingType,
      state: state ?? this.state,
      lines: lines ?? this.lines,
      scheduledDate: scheduledDate,
      linesLoaded: linesLoaded ?? this.linesLoaded,
    );
  }

  int get totalItems => lines.length;
  int get completedItems => lines.where((l) => l.isFulfilled).length;
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;
  bool get canValidate => lines.isNotEmpty && lines.every((l) => l.isFulfilled);
}
