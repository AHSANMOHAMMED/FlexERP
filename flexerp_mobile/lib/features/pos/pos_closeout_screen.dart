import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/pos_repository.dart';

class PosCloseoutScreen extends ConsumerStatefulWidget {
  const PosCloseoutScreen({super.key});

  @override
  ConsumerState<PosCloseoutScreen> createState() => _PosCloseoutScreenState();
}

class _PosCloseoutScreenState extends ConsumerState<PosCloseoutScreen> {
  late TextEditingController _countedCashCtrl;

  @override
  void initState() {
    super.initState();
    final session = ref.read(posSessionProvider);
    _countedCashCtrl = TextEditingController(text: session.totalExpectedDrawerCash.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final session = ref.watch(posSessionProvider);

    final countedCash = double.tryParse(_countedCashCtrl.text) ?? session.totalExpectedDrawerCash;
    final variance = countedCash - session.totalExpectedDrawerCash;

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Shift Closeout & Drawer',
        subtitle: session.name,
        currentBranch: currentBranch,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Overview Card
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('REGISTER SESSION STATUS', style: FlexTypography.labelSm),
                      FlexBadge(
                        text: session.state.toUpperCase(),
                        variant: session.state == 'opened' ? FlexBadgeVariant.success : FlexBadgeVariant.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(session.name, style: FlexTypography.headlineSm),
                  const SizedBox(height: 4),
                  Text(
                    'Cashier: ${session.cashierName} • Opened: ${LkFormatters.formatDateTime(session.openingTime)}',
                    style: FlexTypography.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Financial Summary Breakdown
            FlexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SHIFT CASHFLOW SUMMARY (LKR)', style: FlexTypography.labelSm),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Opening Float Balance', style: FlexTypography.bodyMd),
                      Text(LkFormatters.formatLkr(session.openingBalance), style: FlexTypography.codeNum),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cash Sales Collected', style: FlexTypography.bodyMd),
                      Text(
                        '+ ${LkFormatters.formatLkr(session.cashSalesTotal)}',
                        style: FlexTypography.codeNum.copyWith(color: FlexColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Card & QR Transactions (${session.transactionCount} orders)', style: FlexTypography.bodyMd),
                      Text(
                        LkFormatters.formatLkr(session.cardSalesTotal),
                        style: FlexTypography.codeNum.copyWith(color: FlexColors.info),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Expected Cash in Drawer', style: FlexTypography.labelLg),
                      Text(
                        LkFormatters.formatLkr(session.totalExpectedDrawerCash),
                        style: FlexTypography.codeNum.copyWith(
                          color: FlexColors.primaryLight,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Physical Drawer Reconciliation
            FlexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PHYSICAL CASH COUNT RECONCILIATION', style: FlexTypography.labelSm),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _countedCashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => setState(() {}),
                    style: FlexTypography.codeNum.copyWith(fontSize: 18),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.point_of_sale, size: 20),
                      labelText: 'Actual Counted Cash (LKR)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cash Variance / Difference:', style: FlexTypography.bodyMd),
                      Text(
                        variance == 0.0 ? 'Rs. 0.00 (Balanced)' : LkFormatters.formatLkr(variance),
                        style: FlexTypography.codeNum.copyWith(
                          color: variance == 0.0
                              ? FlexColors.success
                              : (variance > 0 ? FlexColors.info : FlexColors.danger),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (session.state == 'opened')
              FlexButton(
                label: 'Close Session & Lock Drawer',
                icon: Icons.lock_outline,
                variant: FlexButtonVariant.danger,
                height: 48,
                onPressed: () {
                  ref.read(posSessionProvider.notifier).closeSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: FlexColors.success,
                      content: Text('POS Shift successfully closed and synced to Odoo backend!'),
                    ),
                  );
                },
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Session is closed.', style: FlexTypography.labelMd),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
