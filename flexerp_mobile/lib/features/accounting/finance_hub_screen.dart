import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/executive_repository.dart';
import '../../data/repositories/vendor_bill_repository.dart';

class FinanceHubScreen extends ConsumerStatefulWidget {
  const FinanceHubScreen({super.key});

  @override
  ConsumerState<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends ConsumerState<FinanceHubScreen> {
  String? _error;
  List<Map<String, dynamic>> _journals = [];

  bool get _isLive {
    final user = ref.read(currentUserProvider);
    return user != null && !user.isDemo;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      await Future.wait([
        ref.read(invoicesProvider.notifier).syncFromOdoo(),
        ref.read(vendorBillsProvider.notifier).syncFromOdoo(),
        ref.read(executiveKpisProvider.notifier).syncFromServer(),
      ]);
      if (_isLive) {
        final api = ref.read(flexerpApiProvider);
        if (api != null) {
          final journals = await api.accountingJournals();
          if (mounted) setState(() => _journals = journals);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final bills = ref.watch(vendorBillsProvider);
    final kpis = ref.watch(executiveKpisProvider);
    final isLive = ref.watch(currentUserProvider)?.isDemo == false;

    final totalReceivable = invoices
        .where((inv) => inv.isPosted && !inv.isPaid)
        .fold(0.0, (sum, inv) => sum + inv.amountResidual);
    final totalPayable = bills.fold(0.0, (sum, b) => sum + b.amountDue);
    final vatEstimate = invoices.fold(0.0, (sum, inv) => sum + inv.amountTax);

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Finance & Treasury',
        subtitle: isLive ? 'Live AR / AP from Odoo' : 'Demo cash journals & taxes',
        showCompanySwitcher: false,
        onSync: _refresh,
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FlexColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: FlexColors.danger, fontSize: 12)),
              ),
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
              child: Column(
                children: [
                  _buildMetricRow('Today revenue (exec KPI)', LkFormatters.formatLkr(kpis.todayRevenue)),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildMetricRow('Unpaid customer invoices', '${kpis.unpaidInvoices}'),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildMetricRow('Total receivables (AR)', LkFormatters.formatLkr(totalReceivable),
                      valueColor: FlexColors.primaryLight),
                  const Divider(color: FlexColors.cardBorder, height: 18),
                  _buildMetricRow('Total payables (AP)', LkFormatters.formatLkr(totalPayable),
                      valueColor: FlexColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isLive ? 'Payment Journals (from Odoo)' : 'Bank & Liquid Treasury Journals (demo)',
              style: const TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (isLive) ...[
              if (_journals.isEmpty)
                const Text(
                  'No bank/cash journals returned yet. Open payments feature or sync again.',
                  style: TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                )
              else
                ..._journals.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildBankJournalCard(
                        bankName: j['name']?.toString() ?? 'Journal',
                        accountNumber: 'Type: ${j['type'] ?? 'bank'} · ID ${j['id']}',
                        balance: null,
                        currency: 'LKR',
                        icon: j['type'] == 'cash' ? Icons.payments_outlined : Icons.account_balance,
                        color: FlexColors.primaryLight,
                      ),
                    )),
            ] else ...[
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
            ],
            const SizedBox(height: 20),
            Text(
              isLive ? 'Tax snapshot (from open invoices)' : 'Sri Lanka Tax Compliance (demo)',
              style: const TextStyle(
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
              child: isLive
                  ? Column(
                      children: [
                        _buildTaxRow(
                          'Tax on listed customer invoices',
                          LkFormatters.formatLkr(vatEstimate),
                          FlexColors.textPrimary,
                        ),
                        const Divider(color: FlexColors.cardBorder, height: 18),
                        const Text(
                          'IRD / RAMIS filing totals are not computed in-app — use Odoo Accounting reports.',
                          style: TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTaxRow(
                          '18% VAT Output (Sales)',
                          LkFormatters.formatLkr(2470250),
                          FlexColors.textPrimary,
                        ),
                        const Divider(color: FlexColors.cardBorder, height: 18),
                        _buildTaxRow(
                          'Net VAT Payable to IRD',
                          LkFormatters.formatLkr(1349850),
                          FlexColors.error,
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

  Widget _buildMetricRow(String label, String value, {Color valueColor = FlexColors.textPrimary}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBankJournalCard({
    required String bankName,
    required String accountNumber,
    required double? balance,
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
          if (balance != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  LkFormatters.formatLkr(balance),
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
