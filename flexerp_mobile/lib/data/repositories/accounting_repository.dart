import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_invoice.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/offline/offline_queue.dart';
import 'auth_repository.dart';

class InvoicesNotifier extends Notifier<List<AccountInvoice>> {
  @override
  List<AccountInvoice> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.invoices);
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final records = await api.accountingInvoices(moveType: 'out_invoice');
      state = records.map((rec) {
        final total = (rec['amount_total'] as num?)?.toDouble() ?? 0.0;
        final residual = (rec['amount_residual'] as num?)?.toDouble() ?? total;
        return AccountInvoice(
          id: rec['id'] as int? ?? 0,
          number: rec['name']?.toString() ?? 'INV/2026/000',
          partnerName: rec['partner_name']?.toString() ?? 'Client',
          partnerVat: '102938475-7000',
          amountUntaxed: total * 0.8,
          amountTax: total * 0.2,
          amountTotal: total,
          amountResidual: residual,
          state: rec['state']?.toString() ?? 'posted',
          paymentState: rec['payment_state']?.toString() ?? (residual == 0 ? 'paid' : 'not_paid'),
          invoiceDate: rec['invoice_date'] != null
              ? DateTime.tryParse(rec['invoice_date'].toString()) ?? DateTime.now()
              : DateTime.now(),
          invoiceDateDue: rec['invoice_date_due'] != null
              ? DateTime.tryParse(rec['invoice_date_due'].toString()) ??
                  DateTime.now().add(const Duration(days: 30))
              : DateTime.now().add(const Duration(days: 30)),
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> registerPayment(int invoiceId, double paymentAmount, {String? memo}) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      try {
        final result = await api.registerPayment(
          moveId: invoiceId,
          amount: paymentAmount,
          memo: memo,
        );
        final residual = (result['amount_residual'] as num?)?.toDouble();
        final paymentState = result['payment_state']?.toString();
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
                amountResidual: residual ?? (inv.amountResidual - paymentAmount).clamp(0.0, inv.amountTotal),
                state: inv.state,
                paymentState: paymentState ??
                    ((inv.amountResidual - paymentAmount) <= 0.0 ? 'paid' : 'in_payment'),
                invoiceDate: inv.invoiceDate,
                invoiceDateDue: inv.invoiceDateDue,
              )
            else
              inv
        ];
        return;
      } catch (_) {
        await ref.read(offlineQueueProvider.notifier).enqueue(
              type: 'payment_register',
              payload: {'move_id': invoiceId, 'amount': paymentAmount, 'memo': memo},
            );
      }
    }

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
