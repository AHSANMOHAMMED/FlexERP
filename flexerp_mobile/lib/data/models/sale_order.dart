class OrderLine {
  final int productId;
  final String productName;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double discountPercent;

  const OrderLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0.0,
  });

  double get subtotal => quantity * unitPrice * (1 - (discountPercent / 100));
}

class SaleOrder {
  final int id;
  final String name; // e.g. "SO/2026/00142"
  final String partnerName;
  final String partnerPhone;
  final String paymentTerms; // e.g. "30 Days Credit"
  final double creditLimit;
  final double currentCreditUsed;
  final List<OrderLine> lines;
  final double globalDiscountPercent;
  final String state; // 'draft', 'sent', 'sale', 'done', 'cancel'
  final DateTime dateOrder;

  const SaleOrder({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.partnerPhone,
    required this.paymentTerms,
    required this.creditLimit,
    required this.currentCreditUsed,
    required this.lines,
    this.globalDiscountPercent = 0.0,
    required this.state,
    required this.dateOrder,
  });

  double get untaxedAmount {
    double sum = lines.fold(0.0, (prev, line) => prev + line.subtotal);
    return sum * (1 - (globalDiscountPercent / 100));
  }

  // Sri Lanka 2.5% SSCL (levied first)
  double get ssclAmount => untaxedAmount * 0.025;

  // Sri Lanka standard 18% VAT charged on (value + SSCL)
  double get vatAmount => (untaxedAmount + ssclAmount) * 0.18;

  double get totalAmount => untaxedAmount + vatAmount + ssclAmount;
}
