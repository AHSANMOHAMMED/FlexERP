import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/live/live_sync.dart';
import '../../core/api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/pos_repository.dart';
import '../../data/repositories/vendor_repository.dart';
import 'pos_receipt_screen.dart';

class PosTenderScreen extends ConsumerStatefulWidget {
  final double totalAmount;
  final VoidCallback onOrderComplete;
  final int? partnerId;
  final bool createInvoice;

  const PosTenderScreen({
    super.key,
    required this.totalAmount,
    required this.onOrderComplete,
    this.partnerId,
    this.createInvoice = false,
  });

  @override
  ConsumerState<PosTenderScreen> createState() => _PosTenderScreenState();
}

class _PosTenderScreenState extends ConsumerState<PosTenderScreen> {
  String _paymentMethod = 'Cash';
  late double _tenderedAmount;
  bool _busy = false;
  String? _payRef;
  String? _payUrl;
  String? _payStatus;
  Timer? _pollTimer;

  /// One uuid per checkout: re-submitting after an error reuses it so the
  /// server never records the sale twice.
  late final String _orderUuid;

  @override
  void initState() {
    super.initState();
    _tenderedAmount = widget.totalAmount;
    _orderUuid = newPosOrderUuid();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  double get _changeDue => (_tenderedAmount - widget.totalAmount).clamp(0.0, double.infinity);

  Future<void> _startLankaQr() async {
    final api = ref.read(flexerpApiProvider);
    final features = ref.read(currentVendorFeaturesProvider);
    if (!features.enablePayments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments feature disabled for this vendor')),
      );
      return;
    }
    if (api == null) {
      setState(() {
        _payStatus = 'not_configured';
        _payUrl = 'flexerp://demo-pay';
        _payRef = 'DEMO-PAY';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final link = await api.paymentLinkCreate(
        amount: widget.totalAmount,
        orderRef: 'POS-${DateTime.now().millisecondsSinceEpoch}',
      );
      setState(() {
        _payRef = link['reference']?.toString();
        _payUrl = link['pay_url']?.toString();
        _payStatus = link['status']?.toString() ?? 'pending';
        _busy = false;
      });
      if (_payStatus == 'not_configured') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(link['message']?.toString() ?? 'Gateway not configured — use Cash'),
            backgroundColor: FlexColors.warning,
          ),
        );
        return;
      }
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollPayStatus());
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pay link failed: $e'), backgroundColor: FlexColors.danger),
      );
    }
  }

  Future<void> _pollPayStatus() async {
    final api = ref.read(flexerpApiProvider);
    final refCode = _payRef;
    if (api == null || refCode == null) return;
    final Map<String, dynamic> status;
    try {
      status = await api.paymentLinkStatus(refCode);
    } catch (e) {
      debugPrint('FlexERP: LankaQR status poll failed: $e');
      return;
    }
    final st = status['status']?.toString();
    if (!mounted) return;
    setState(() => _payStatus = st);
    if (st == 'paid') {
      _pollTimer?.cancel();
      await _completeSale(forceQrPaid: true);
    }
  }

  Future<void> _markStubPaid() async {
    final api = ref.read(flexerpApiProvider);
    if (api != null && _payRef != null) {
      await api.paymentLinkStatus(_payRef!, markPaid: true);
    }
    setState(() => _payStatus = 'paid');
    await _completeSale(forceQrPaid: true);
  }

  Future<void> _completeSale({bool forceQrPaid = false}) async {
    if (_busy) return;
    if (_paymentMethod == 'LankaQR' && !forceQrPaid && _payStatus != 'paid') {
      await _startLankaQr();
      return;
    }

    setState(() => _busy = true);
    final methodKey = _paymentMethod == 'Cash'
        ? 'cash'
        : _paymentMethod == 'LankaQR'
            ? 'qr'
            : 'card';
    final cash = _paymentMethod == 'Cash' ? widget.totalAmount : 0.0;
    final card = _paymentMethod == 'Cash' ? 0.0 : widget.totalAmount;

    final features = ref.read(currentVendorFeaturesProvider);
    final Map<String, dynamic> result;
    try {
      result = await ref.read(posCartProvider.notifier).completeCheckoutAndPush(
            paymentMethod: methodKey,
            cashAmount: cash,
            cardAmount: card,
            orderUuid: _orderUuid,
            partnerId: widget.partnerId,
            createInvoice: widget.createInvoice && features.enableInvoicing,
          );
    } catch (e) {
      debugPrint('FlexERP: POS checkout rejected: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sale not completed'),
          content: Text(
            '${describeError(e)}\n\nThe sale was NOT recorded and stock was not changed. '
            'Fix the issue and try again.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (result['queued'] != true) {
      ref.read(liveSyncProvider.notifier).notifyLocal(type: 'sale');
    }

    if (!mounted) return;
    setState(() => _busy = false);
    widget.onOrderComplete();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PosReceiptScreen(
          checkoutResult: Map<String, dynamic>.from(result),
          changeDue: _changeDue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: AppBar(
        title: Text('POS Payment Tender', style: FlexTypography.headlineMd),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Column(
                children: [
                  Text('TOTAL AMOUNT PAYABLE', style: FlexTypography.labelSm),
                  const SizedBox(height: 6),
                  Text(
                    LkFormatters.formatLkr(widget.totalAmount),
                    style: FlexTypography.headlineXl.copyWith(
                      color: FlexColors.primaryLight,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('PAYMENT METHOD', style: FlexTypography.labelSm),
            const SizedBox(height: 8),
            Row(
              children: [
                _TenderTile(
                  icon: Icons.money,
                  label: 'Cash (LKR)',
                  isSelected: _paymentMethod == 'Cash',
                  onTap: () => setState(() => _paymentMethod = 'Cash'),
                ),
                const SizedBox(width: 8),
                _TenderTile(
                  icon: Icons.credit_card,
                  label: 'Visa / Master',
                  isSelected: _paymentMethod == 'Card',
                  onTap: () => setState(() => _paymentMethod = 'Card'),
                ),
                const SizedBox(width: 8),
                _TenderTile(
                  icon: Icons.qr_code_2,
                  label: 'LankaQR',
                  isSelected: _paymentMethod == 'LankaQR',
                  onTap: () async {
                    setState(() => _paymentMethod = 'LankaQR');
                    await _startLankaQr();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_paymentMethod == 'Cash') ...[
              Text('CASH QUICK-TENDER BUTTONS', style: FlexTypography.labelSm),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickAmountButton(
                    label: 'Exact (${LkFormatters.formatLkrCompact(widget.totalAmount)})',
                    onTap: () => setState(() => _tenderedAmount = widget.totalAmount),
                  ),
                  _QuickAmountButton(
                    label: '${LkFormatters.currencySymbol} 5,000',
                    onTap: () => setState(() => _tenderedAmount = 5000),
                  ),
                  _QuickAmountButton(
                    label: '${LkFormatters.currencySymbol} 10,000',
                    onTap: () => setState(() => _tenderedAmount = 10000),
                  ),
                  _QuickAmountButton(
                    label: '${LkFormatters.currencySymbol} 50,000',
                    onTap: () => setState(() => _tenderedAmount = 50000),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FlexCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change to Return', style: FlexTypography.labelLg),
                        Text('Tendered: ${LkFormatters.formatLkr(_tenderedAmount)}',
                            style: FlexTypography.bodySm),
                      ],
                    ),
                    Text(
                      LkFormatters.formatLkr(_changeDue),
                      style: FlexTypography.headlineMd.copyWith(color: FlexColors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_paymentMethod == 'LankaQR') ...[
              FlexCard(
                child: Column(
                  children: [
                    Text('LankaQR / JustPay link', style: FlexTypography.labelLg),
                    const SizedBox(height: 8),
                    Text('Status: ${_payStatus ?? 'idle'}', style: FlexTypography.bodySm),
                    if (_payUrl != null && _payUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      QrImageView(
                        data: _payUrl!,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(_payRef ?? '', style: FlexTypography.bodySm),
                    ],
                    if (_payStatus == 'pending' || _payStatus == 'not_configured') ...[
                      const SizedBox(height: 12),
                      Text(
                        _payStatus == 'not_configured'
                            ? 'Gateway not configured — use Cash, or mark stub paid for testing.'
                            : 'Waiting for payment… polling every 3s',
                        style: FlexTypography.bodySm,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _markStubPaid,
                        child: const Text('Mark paid (test / stub)'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            FlexButton(
              label: _busy
                  ? 'Processing…'
                  : _paymentMethod == 'LankaQR' && _payStatus != 'paid'
                      ? 'Generate / Await LankaQR'
                      : 'Complete & Show Receipt',
              icon: Icons.check,
              variant: FlexButtonVariant.primary,
              height: 50,
              onPressed: _busy ? null : () => _completeSale(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TenderTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? FlexColors.surfaceRaisedDark : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? FlexColors.primary : FlexColors.borderDark,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? FlexColors.primaryLight : FlexColors.textDisabledDark),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? FlexColors.primaryLight : FlexColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: FlexTypography.labelSm),
      backgroundColor: FlexColors.surfaceRaisedDark,
      side: const BorderSide(color: FlexColors.borderDark),
      onPressed: onTap,
    );
  }
}
