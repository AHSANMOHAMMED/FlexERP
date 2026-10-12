import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_invoice.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

class InvoicesNotifier extends Notifier<List<AccountInvoice>> {
  @override
  List<AccountInvoice> build() {
    return List.from(MockSriLankaDataService.invoices);
  }

  Future<void> syncFromOdoo() async {
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client == null) return;
    try {
      final records = await client.searchRead(
        model: 'account.move',
        domain: [
          ['move_type', '=', 'out_invoice']
        ],
        fields: ['id', 'name', 'partner_id', 'amount_untaxed', 'amount_tax', 'amount_total', 'amount_residual', 'state', 'payment_state', 'invoice_date', 'invoice_date_due'],
        limit: 50,
      );
      if (records.isNotEmpty) {
        state = records.map((rec) {
          final partner = rec['partner_id'];
          final partnerName = partner is List && partner.length > 1 ? partner[1].toString() : 'Client';
          final total = (rec['amount_total'] as num?)?.toDouble() ?? 0.0;
          final residual = (rec['amount_residual'] as num?)?.toDouble() ?? total;
          return AccountInvoice(
            id: rec['id'] as int,
            number: rec['name'] as String? ?? 'INV/2026/000',
            partnerName: partnerName,
            partnerVat: '102938475-7000',
            amountUntaxed: (rec['amount_untaxed'] as num?)?.toDouble() ?? (total * 0.8),
            amountTax: (rec['amount_tax'] as num?)?.toDouble() ?? (total * 0.2),
            amountTotal: total,
            amountResidual: residual,
            state: rec['state']?.toString() ?? 'posted',
            paymentState: rec['payment_state']?.toString() ?? (residual == 0 ? 'paid' : 'not_paid'),
            invoiceDate: rec['invoice_date'] != null
                ? DateTime.tryParse(rec['invoice_date'].toString()) ?? DateTime.now()
                : DateTime.now(),
            invoiceDateDue: rec['invoice_date_due'] != null
                ? DateTime.tryParse(rec['invoice_date_due'].toString()) ?? DateTime.now().add(const Duration(days: 30))
                : DateTime.now().add(const Duration(days: 30)),
          );
        }).toList();
      }
    } catch (_) {
      // Gracefully maintain offline state
    }
  }

  void registerPayment(int invoiceId, double paymentAmount) {
    state = [
      for (final inv in state)
        if (inv.id == invoiceId)
          AccountInvoice(
            id: inv.id,
            number: inv.number,
            partnerName: inv.partnerName,
            partnerVat: inv.partnerVat,
            amountUntaxed: inv.amountUntaxed,
            amountTax: inv.amountTax,
            amountTotal: inv.amountTotal,
            amountResidual: (inv.amountResidual - paymentAmount).clamp(0.0, inv.amountTotal),
            state: inv.state,
            paymentState: (inv.amountResidual - paymentAmount) <= 0.0 ? 'paid' : 'in_payment',
            invoiceDate: inv.invoiceDate,
            invoiceDateDue: inv.invoiceDateDue,
          )
        else
          inv
    ];
  }
}

final invoicesProvider = NotifierProvider<InvoicesNotifier, List<AccountInvoice>>(InvoicesNotifier.new);
