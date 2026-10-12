import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/pos_repository.dart';

class PosTenderScreen extends ConsumerStatefulWidget {
  final double totalAmount;
  final VoidCallback onOrderComplete;

  const PosTenderScreen({
    super.key,
    required this.totalAmount,
    required this.onOrderComplete,
  });

  @override
  ConsumerState<PosTenderScreen> createState() => _PosTenderScreenState();
}

class _PosTenderScreenState extends ConsumerState<PosTenderScreen> {
  String _paymentMethod = 'Cash';
  late double _tenderedAmount;

  @override
  void initState() {
    super.initState();
    _tenderedAmount = widget.totalAmount;
  }

  double get _changeDue => (_tenderedAmount - widget.totalAmount).clamp(0.0, double.infinity);

  void _completeSale() {
    if (_paymentMethod == 'Cash') {
      ref.read(posSessionProvider.notifier).recordSale(cashAmount: widget.totalAmount, cardAmount: 0);
    } else {
      ref.read(posSessionProvider.notifier).recordSale(cashAmount: 0, cardAmount: widget.totalAmount);
    }

    ref.read(posCartProvider.notifier).completeCheckoutAndDeductStock();
    Navigator.pop(context);
    widget.onOrderComplete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FlexColors.success,
        content: Text('POS Order complete! Change Due: ${LkFormatters.formatLkr(_changeDue)}'),
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
            // Prominent Amount To Pay
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

            // Payment Method Selector
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
                  onTap: () => setState(() => _paymentMethod = 'LankaQR'),
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
                    label: 'Rs. 5,000',
                    onTap: () => setState(() => _tenderedAmount = 5000),
                  ),
                  _QuickAmountButton(
                    label: 'Rs. 10,000',
                    onTap: () => setState(() => _tenderedAmount = 10000),
                  ),
                  _QuickAmountButton(
                    label: 'Rs. 50,000',
                    onTap: () => setState(() => _tenderedAmount = 50000),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Change Due Card
              FlexCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change to Return', style: FlexTypography.labelLg),
                        Text('Tendered: ${LkFormatters.formatLkr(_tenderedAmount)}', style: FlexTypography.bodySm),
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

            // Receipt Options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('ESC/POS Print'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: FlexColors.borderDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('E-Receipt'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: FlexColors.borderDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Confirm Sale
            FlexButton(
              label: 'Complete & Print Receipt',
              icon: Icons.check,
              variant: FlexButtonVariant.primary,
              height: 50,
              onPressed: _completeSale,
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
