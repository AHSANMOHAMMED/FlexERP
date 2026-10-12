class CustomerPartner {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String address;
  final String vatOrTin;
  final String svatNumber;
  final double creditLimit;
  final double totalReceivable;
  final String paymentTerms;
  final bool isCustomer;
  final bool isSupplier;

  const CustomerPartner({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.address,
    required this.vatOrTin,
    this.svatNumber = '',
    required this.creditLimit,
    required this.totalReceivable,
    this.paymentTerms = '30 Days Net',
    this.isCustomer = true,
    this.isSupplier = false,
  });

  bool get isOverCreditLimit => totalReceivable > creditLimit;
  double get availableCredit => (creditLimit - totalReceivable).clamp(0.0, creditLimit);
}
