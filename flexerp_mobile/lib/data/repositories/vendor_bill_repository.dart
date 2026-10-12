import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../models/vendor_bill.dart';
import 'auth_repository.dart';

class VendorBillsNotifier extends Notifier<List<VendorBill>> {
  @override
  List<VendorBill> build() {
    return MockSriLankaDataService.mockVendorBills;
  }

  Future<void> syncFromOdoo() async {
    final client = ref.read(odooClientProvider);
    if (client == null || !client.isAuthenticated) return;

    try {
      final results = await client.searchRead(
        model: 'account.move',
        domain: [
          ['move_type', '=', 'in_invoice']
        ],
        fields: [
          'id',
          'name',
          'partner_id',
          'invoice_date',
          'invoice_date_due',
          'amount_untaxed',
          'amount_tax',
          'amount_total',
          'amount_residual',
          'state',
          'payment_reference',
        ],
        limit: 50,
      );

      if (results.isNotEmpty) {
        final bills = results.map((item) {
          final partner = item['partner_id'] is List ? item['partner_id'] as List : [0, 'Supplier'];
          final dateStr = item['invoice_date']?.toString();
          final dueStr = item['invoice_date_due']?.toString();

          return VendorBill(
            id: (item['id'] as num?)?.toInt() ?? 0,
            billNumber: item['name']?.toString() ?? 'BILL/NEW',
            vendorName: partner.length > 1 ? partner[1].toString() : 'Supplier',
            vendorVatOrTin: 'V-SUPPLIER-TIN',
            billDate: dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
            dueDate: dueStr != null ? DateTime.tryParse(dueStr) ?? DateTime.now() : DateTime.now(),
            subtotal: (item['amount_untaxed'] as num?)?.toDouble() ?? 0.0,
            vatAmount: (item['amount_tax'] as num?)?.toDouble() ?? 0.0,
            totalAmount: (item['amount_total'] as num?)?.toDouble() ?? 0.0,
            amountDue: (item['amount_residual'] as num?)?.toDouble() ?? 0.0,
            state: item['state']?.toString() ?? 'posted',
            paymentReference: item['payment_reference']?.toString() ?? '',
          );
        }).toList();

        state = bills;
      }
    } catch (_) {
      // Fallback
    }
  }

  void markAsPaid(int billId) {
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
