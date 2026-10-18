import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/account_invoice.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/repositories/auth_repository.dart';

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
  List<Map<String, dynamic>> _journals = [];
  int? _selectedJournalId;
  String _selectedJournalLabel = '';
  bool _loadingJournals = false;
  bool _submitting = false;

  final List<Map<String, dynamic>> _demoJournals = const [
    {'id': 0, 'name': 'Commercial Bank of Ceylon PLC'},
    {'id': 0, 'name': 'Sampath Bank Corporate Account'},
    {'id': 0, 'name': 'Hatton National Bank (HNB)'},
    {'id': 0, 'name': 'Petty Cash Colombo Drawer'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.invoice.amountResidual.toStringAsFixed(2));
    _memoController.text = 'Payment for ${widget.invoice.number}';
    Future.microtask(_loadJournals);
  }

  Future<void> _loadJournals() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) {
      setState(() {
        _journals = List.from(_demoJournals);
        _selectedJournalLabel = _journals.first['name']?.toString() ?? '';
      });
      return;
    }
    setState(() => _loadingJournals = true);
    try {
      final rows = await api.accountingJournals();
      if (!mounted) return;
      setState(() {
        _journals = rows;
        if (_journals.isNotEmpty) {
          _selectedJournalId = (_journals.first['id'] as num?)?.toInt();
          _selectedJournalLabel = _journals.first['name']?.toString() ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Journals failed: $e'), backgroundColor: FlexColors.danger),
      );
      setState(() {
        _journals = [];
        _selectedJournalId = null;
        _selectedJournalLabel = '';
      });
    } finally {
      if (mounted) setState(() => _loadingJournals = false);
    }
  }

  Future<void> _confirmPayment() async {
    final amount = double.tryParse(_amountController.text) ?? widget.invoice.amountResidual;
    setState(() => _submitting = true);
    try {
      await ref.read(invoicesProvider.notifier).registerPayment(
            widget.invoice.id,
            amount,
            memo: _memoController.text.trim(),
            journalId: (_selectedJournalId != null && _selectedJournalId! > 0)
                ? _selectedJournalId
                : null,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FlexColors.success,
          content: Text(
            'Registered ${LkFormatters.formatLkr(amount)}'
            '${_selectedJournalLabel.isNotEmpty ? ' via $_selectedJournalLabel' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed (queued if offline): $e'), backgroundColor: FlexColors.warning),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
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
          Text('Client: ${widget.invoice.partnerName}', style: FlexTypography.bodySm),
          const SizedBox(height: 16),
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
          Text('PAYMENT JOURNAL / BANK ACCOUNT', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          if (_loadingJournals)
            const LinearProgressIndicator()
          else if (_journals.isEmpty)
            Text(
              'No payment journals available. Fix the journal sync error before registering payment.',
              style: FlexTypography.bodySm.copyWith(color: FlexColors.danger),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedJournalLabel.isEmpty ? null : _selectedJournalLabel,
              dropdownColor: FlexColors.surfaceRaisedDark,
              decoration: const InputDecoration(),
              items: _journals.map((j) {
                final name = j['name']?.toString() ?? 'Journal';
                return DropdownMenuItem(value: name, child: Text(name, style: FlexTypography.bodyMd));
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final match = _journals.firstWhere(
                  (j) => j['name']?.toString() == val,
                  orElse: () => _journals.first,
                );
                setState(() {
                  _selectedJournalLabel = val;
                  _selectedJournalId = (match['id'] as num?)?.toInt();
                });
              },
            ),
          const SizedBox(height: 14),
          Text('MEMO / TRANSACTION REFERENCE', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            style: FlexTypography.bodyMd,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.notes, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          FlexButton(
            label: _submitting ? 'Posting…' : 'Confirm Payment',
            icon: Icons.check_circle,
            variant: FlexButtonVariant.primary,
            height: 48,
            onPressed: (_submitting || _journals.isEmpty) ? null : _confirmPayment,
          ),
        ],
      ),
    );
  }
}
