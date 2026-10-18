import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../models/vendor_bill.dart';
import 'auth_repository.dart';

class VendorBillsNotifier extends Notifier<List<VendorBill>> {
  @override
  List<VendorBill> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.mockVendorBills);
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;

    try {
      final results = await api.accountingInvoices(moveType: 'in_invoice');
      state = results.map((item) {
        final dateStr = item['invoice_date']?.toString();
        final dueStr = item['invoice_date_due']?.toString();
        return VendorBill(
          id: (item['id'] as num?)?.toInt() ?? 0,
          billNumber: item['name']?.toString() ?? 'BILL/NEW',
          vendorName: item['partner_name']?.toString() ?? 'Supplier',
          vendorVatOrTin: 'V-SUPPLIER-TIN',
          billDate: dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
          dueDate: dueStr != null ? DateTime.tryParse(dueStr) ?? DateTime.now() : DateTime.now(),
          subtotal: (item['amount_total'] as num?)?.toDouble() ?? 0.0,
          vatAmount: 0.0,
          totalAmount: (item['amount_total'] as num?)?.toDouble() ?? 0.0,
          amountDue: (item['amount_residual'] as num?)?.toDouble() ?? 0.0,
          state: item['state']?.toString() ?? 'posted',
          paymentReference: '',
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAsPaid(int billId) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final bill = state.firstWhere((b) => b.id == billId, orElse: () => state.first);
    if (user != null && !user.isDemo && api != null) {
      try {
        await api.registerPayment(moveId: billId, amount: bill.amountDue);
      } catch (e) {
        rethrow;
      }
    }
    state = [
      for (final b in state)
        if (b.id == billId)
          VendorBill(
            id: b.id,
            billNumber: b.billNumber,
            vendorName: b.vendorName,
            vendorVatOrTin: b.vendorVatOrTin,
            billDate: b.billDate,
            dueDate: b.dueDate,
            currency: b.currency,
            subtotal: b.subtotal,
            vatAmount: b.vatAmount,
            ssclAmount: b.ssclAmount,
            whtAmount: b.whtAmount,
            totalAmount: b.totalAmount,
            amountDue: 0.0,
            state: 'paid',
            paymentReference: b.paymentReference,
          )
        else
          b,
    ];
  }
}

final vendorBillsProvider = NotifierProvider<VendorBillsNotifier, List<VendorBill>>(
  VendorBillsNotifier.new,
);
