class PosProduct {
  final int id;
  final String name;
  final String category;
  final double price; // in LKR
  final String? imagePlaceholderColor;
  final int stockOnHand;
  final String barcode;
  final String sku;

  const PosProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.imagePlaceholderColor,
    required this.stockOnHand,
    this.barcode = '',
    this.sku = '',
  });
}

class PosCartItem {
  final PosProduct product;
  int quantity;
  double discountPercent;

  PosCartItem({
    required this.product,
    this.quantity = 1,
    this.discountPercent = 0.0,
  });

  double get subtotal => product.price * quantity * (1 - (discountPercent / 100));
}

class PosShiftSession {
  final int id;
  final String name; // e.g. "POS/0042 (Colombo Counter 1)"
  final String cashierName;
  final DateTime openingTime;
  final double openingBalance; // LKR Cash in drawer
  double cashSalesTotal;
  double cardSalesTotal;
  int transactionCount;
  final String state; // 'none', 'opened', 'opening_control', 'closing_control', 'closed'
  final int? configId;

  static const String stateNone = 'none';

  PosShiftSession({
    required this.id,
    required this.name,
    required this.cashierName,
    required this.openingTime,
    required this.openingBalance,
    this.cashSalesTotal = 0.0,
    this.cardSalesTotal = 0.0,
    this.transactionCount = 0,
    this.state = 'opened',
    this.configId,
  });

  /// A real server session that accepts orders.
  bool get isLiveOpen => id > 0 && (state == 'opened' || state == 'opening_control');

  double get totalExpectedDrawerCash => openingBalance + cashSalesTotal;
}

class PosOrderLine {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const PosOrderLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });
}

class PosPastOrder {
  final int id;
  final String receiptNumber;
  final DateTime orderDate;
  final String customerName;
  final double totalAmount;
  final String paymentMethod; // 'LANKAQR', 'Cash', 'Card'
  final String status; // 'paid', 'done', 'invoiced'
  final List<PosOrderLine> lines;

  const PosPastOrder({
    required this.id,
    required this.receiptNumber,
    required this.orderDate,
    required this.customerName,
    required this.totalAmount,
    required this.paymentMethod,
    this.status = 'paid',
    this.lines = const [],
  });
}

