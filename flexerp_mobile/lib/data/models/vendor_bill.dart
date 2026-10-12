class VendorBill {
  final int id;
  final String billNumber;
  final String vendorName;
  final String vendorVatOrTin;
  final DateTime billDate;
  final DateTime dueDate;
  final String currency;
  final double subtotal;
  final double vatAmount;
  final double ssclAmount;
  final double whtAmount;
  final double totalAmount;
  final double amountDue;
  final String state;
  final String paymentReference;

  const VendorBill({
    required this.id,
    required this.billNumber,
    required this.vendorName,
    required this.vendorVatOrTin,
    required this.billDate,
    required this.dueDate,
    this.currency = 'LKR',
    required this.subtotal,
    required this.vatAmount,
    this.ssclAmount = 0.0,
    this.whtAmount = 0.0,
    required this.totalAmount,
    required this.amountDue,
    required this.state,
    this.paymentReference = '',
  });

  bool get isPaid => state == 'paid' || amountDue <= 0.0;
  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);
}
