class AccountInvoice {
  final int id;
  final String number; // e.g. "INV/2026/00341"
  final String partnerName;
  final String partnerVat; // Sri Lanka SVAT or VAT number
  final double amountUntaxed;
  final double amountTax; // VAT + SSCL
  final double amountTotal;
  final double amountResidual; // Balance due
  final String state; // 'draft', 'posted', 'cancel'
  final String paymentState; // 'not_paid', 'in_payment', 'paid', 'reversed'
  final DateTime invoiceDate;
  final DateTime invoiceDateDue;

  const AccountInvoice({
    required this.id,
    required this.number,
    required this.partnerName,
    required this.partnerVat,
    required this.amountUntaxed,
    required this.amountTax,
    required this.amountTotal,
    required this.amountResidual,
    required this.state,
    required this.paymentState,
    required this.invoiceDate,
    required this.invoiceDateDue,
  });

  bool get isPosted => state == 'posted';
  bool get isPaid => paymentState == 'paid';
  bool get isOverdue => !isPaid && DateTime.now().isAfter(invoiceDateDue);
  int get overdueDays => isOverdue ? DateTime.now().difference(invoiceDateDue).inDays : 0;
}
