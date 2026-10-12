import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/account_invoice.dart';
import '../../data/repositories/accounting_repository.dart';

class PaymentRegisterSheet extends ConsumerStatefulWidget {
  final AccountInvoice invoice;

  const PaymentRegisterSheet({super.key, required this.invoice});

  static Future<void> show(BuildContext context, {required AccountInvoice invoice}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: FlexColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PaymentRegisterSheet(invoice: invoice),
    );
  }

  @override
  ConsumerState<PaymentRegisterSheet> createState() => _PaymentRegisterSheetState();
}

class _PaymentRegisterSheetState extends ConsumerState<PaymentRegisterSheet> {
  late TextEditingController _amountController;
  final TextEditingController _memoController = TextEditingController();
  String _selectedJournal = 'Commercial Bank of Ceylon PLC';
  bool _sendReceiptEmail = true;

  final List<String> _lkJournals = [
    'Commercial Bank of Ceylon PLC',
    'Sampath Bank Corporate Account',
    'Hatton National Bank (HNB)',
    'Petty Cash Colombo Drawer',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.invoice.amountResidual.toStringAsFixed(2));
    _memoController.text = 'Payment for ${widget.invoice.number}';
  }

  void _confirmPayment() {
    final amount = double.tryParse(_amountController.text) ?? widget.invoice.amountResidual;
    ref.read(invoicesProvider.notifier).registerPayment(widget.invoice.id, amount);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FlexColors.success,
        content: Text('Registered payment of ${LkFormatters.formatLkr(amount)} to $_selectedJournal'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: FlexColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Register Payment', style: FlexTypography.headlineMd),
              Text(
                widget.invoice.number,
                style: FlexTypography.labelSm.copyWith(color: FlexColors.primaryLight),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Client: ${widget.invoice.partnerName}',
            style: FlexTypography.bodySm,
          ),
          const SizedBox(height: 16),

          // Balance Due Stat Block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlexColors.surfaceRaisedDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FlexColors.borderDark),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Balance Due:', style: FlexTypography.bodyMd),
                Text(
                  LkFormatters.formatLkr(widget.invoice.amountResidual),
                  style: FlexTypography.codeNum.copyWith(
                    color: FlexColors.warning,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment Amount
          Text('PAYMENT AMOUNT (LKR)', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: FlexTypography.codeNum.copyWith(fontSize: 16),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.payments_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 14),

          // Payment Journal Selector
          Text('PAYMENT JOURNAL / BANK ACCOUNT (SRI LANKA)', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedJournal,
            dropdownColor: FlexColors.surfaceRaisedDark,
            decoration: const InputDecoration(),
            items: _lkJournals.map((j) {
              return DropdownMenuItem(value: j, child: Text(j, style: FlexTypography.bodyMd));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedJournal = val);
            },
          ),
          const SizedBox(height: 14),

          // Memo Note
          Text('MEMO / TRANSACTION REFERENCE', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            style: FlexTypography.bodyMd,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.notes, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Email Receipt Checkbox
          Row(
            children: [
              Checkbox(
                value: _sendReceiptEmail,
                activeColor: FlexColors.primary,
                onChanged: (val) => setState(() => _sendReceiptEmail = val ?? true),
              ),
              Text('Send Payment Receipt to Client via Email/SMS', style: FlexTypography.bodySm),
            ],
          ),
          const SizedBox(height: 16),

          // Confirm Payment Button
          FlexButton(
            label: 'Confirm Payment (account.payment)',
            icon: Icons.check_circle,
            variant: FlexButtonVariant.primary,
            height: 48,
            onPressed: _confirmPayment,
          ),
        ],
      ),
    );
  }
}
