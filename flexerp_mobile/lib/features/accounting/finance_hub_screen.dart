import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/repositories/accounting_repository.dart';

class FinanceHubScreen extends ConsumerWidget {
  const FinanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);

    final totalReceivable = invoices
        .where((inv) => inv.isPosted && !inv.isPaid)
        .fold(0.0, (sum, inv) => sum + inv.amountResidual);

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Finance & Treasury',
        subtitle: 'Cash Journals, IRD Taxes & Liquidity',
        showCompanySwitcher: false,
        onSync: () => ref.read(invoicesProvider.notifier).syncFromOdoo(),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(invoicesProvider.notifier).syncFromOdoo(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bank Accounts Overview
            const Text(
              'Bank & Liquid Treasury Journals',
              style: TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildBankJournalCard(
              bankName: 'Bank of Ceylon (BOC)',
              accountNumber: 'CA-0092182901 (Corporate Main)',
              balance: 18450000.0,
              currency: 'LKR',
              icon: Icons.account_balance,
              color: FlexColors.primaryLight,
            ),
            const SizedBox(height: 10),
            _buildBankJournalCard(
              bankName: 'Commercial Bank of Ceylon',
              accountNumber: 'CA-8839210044 (Operational & POS)',
              balance: 7240000.0,
              currency: 'LKR',
              icon: Icons.credit_card,
              color: FlexColors.success,
            ),
            const SizedBox(height: 10),
            _buildBankJournalCard(
              bankName: 'Sampath Bank PLC',
              accountNumber: 'CA-1029384722 (Payroll & EPF)',
              balance: 3110000.0,
              currency: 'LKR',
              icon: Icons.payments_outlined,
              color: FlexColors.warning,
            ),
            const SizedBox(height: 20),

            // Sri Lanka Tax Authority (IRD / RAMIS)
            const Text(
              'Sri Lanka Tax Compliance (IRD / RAMIS)',
              style: TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlexColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlexColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildTaxRow('18% VAT Output (Sales)', 'Rs. 2,470,250', FlexColors.textPrimary),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildTaxRow('18% VAT Input (Purchases)', '- Rs. 1,120,400', FlexColors.warning),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildTaxRow('Net VAT Payable to IRD', 'Rs. 1,349,850', FlexColors.error),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildTaxRow('2.5% Social Security Contribution (SSCL)', 'Rs. 343,000', FlexColors.textPrimary),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildTaxRow('Withholding Tax (WHT) Remittance', 'Rs. 94,500', FlexColors.textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Liquidity & Receivables Summary
            const Text(
              'Working Capital Position',
              style: TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlexColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlexColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Receivables (AR)', style: TextStyle(color: FlexColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${totalReceivable.toStringAsFixed(0)}',
                          style: const TextStyle(color: FlexColors.primaryLight, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 36, width: 1, color: FlexColors.cardBorder),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Total Payables (AP)', style: TextStyle(color: FlexColors.textSecondary, fontSize: 11)),
                        SizedBox(height: 4),
                        Text(
                          'Rs. 2,012,350',
                          style: TextStyle(color: FlexColors.warning, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBankJournalCard({
    required String bankName,
    required String accountNumber,
    required double balance,
    required String currency,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlexColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlexColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bankName,
                  style: const TextStyle(
                    color: FlexColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  accountNumber,
                  style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${balance.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: FlexColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(currency, style: const TextStyle(color: FlexColors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRow(String label, String amount, Color amountColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12)),
        Text(
          amount,
          style: TextStyle(color: amountColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
