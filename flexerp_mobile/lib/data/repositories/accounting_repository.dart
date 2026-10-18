import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account_invoice.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import '../../core/offline/offline_queue.dart';
import 'auth_repository.dart';
import 'pos_repository.dart' show newPosOrderUuid;

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
        final untaxed = (rec['amount_untaxed'] as num?)?.toDouble() ?? total;
        final tax = (rec['amount_tax'] as num?)?.toDouble() ?? 0.0;
        return AccountInvoice(
          id: rec['id'] as int? ?? 0,
          number: rec['name']?.toString() ?? 'INV/2026/000',
          partnerName: rec['partner_name']?.toString() ?? 'Client',
          partnerVat: rec['partner_vat']?.toString() ?? '',
          amountUntaxed: untaxed,
          amountTax: tax,
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
    } catch (e) {
      debugPrint('FlexERP: invoice sync failed: $e');
      rethrow;
    }
  }

  /// Registers a payment. Returns `true` when the payment was queued
  /// offline (network failure) instead of being accepted by the server.
  /// Odoo business errors are rethrown and never queued.
  Future<bool> registerPayment(
    int invoiceId,
    double paymentAmount, {
    String? memo,
    int? journalId,
  }) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo) {
      if (api == null) throw OdooException('Not signed in to Odoo');
      // Server dedups on this uuid, so retries and offline replays are safe.
      final paymentUuid = newPosOrderUuid();
      try {
        final result = await api.registerPayment(
          moveId: invoiceId,
          amount: paymentAmount,
          journalId: journalId,
          memo: memo,
          uuid: paymentUuid,
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
        return false;
      } catch (e) {
        if (!isNetworkFailure(e)) rethrow;
        await ref.read(offlineQueueProvider.notifier).enqueue(
              type: 'payment_register',
              payload: {
                'move_id': invoiceId,
                'uuid': paymentUuid,
                'amount': paymentAmount,
                'memo': memo,
                if (journalId != null) 'journal_id': journalId,
              },
            );
        // Invoice residual is NOT changed locally until the server accepts it.
        return true;
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
    return false;
  }
}

final invoicesProvider = NotifierProvider<InvoicesNotifier, List<AccountInvoice>>(InvoicesNotifier.new);
