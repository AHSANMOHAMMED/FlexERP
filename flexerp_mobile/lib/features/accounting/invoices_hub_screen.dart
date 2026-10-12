import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/account_invoice.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/accounting_repository.dart';
import 'payment_register_screen.dart';

class InvoicesHubScreen extends ConsumerStatefulWidget {
  const InvoicesHubScreen({super.key});

  @override
  ConsumerState<InvoicesHubScreen> createState() => _InvoicesHubScreenState();
}

class _InvoicesHubScreenState extends ConsumerState<InvoicesHubScreen> {
  String _selectedTab = 'All';
  String _searchQuery = '';

  final List<String> _tabs = ['All', 'Unpaid', 'Overdue', 'Paid'];

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final allInvoices = ref.watch(invoicesProvider);

    final filteredInvoices = allInvoices.where((inv) {
      bool matchesTab = true;
      if (_selectedTab == 'Unpaid') {
        matchesTab = !inv.isPaid;
      } else if (_selectedTab == 'Overdue') {
        matchesTab = inv.isOverdue;
      } else if (_selectedTab == 'Paid') {
        matchesTab = inv.isPaid;
      }

      final matchesSearch = _searchQuery.isEmpty ||
          inv.number.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          inv.partnerName.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesTab && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Customer Invoices',
        subtitle: 'Financial Receivables',
        currentBranch: currentBranch,
        onSync: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Syncing Customer Invoices with Odoo...')),
          );
          await ref.read(invoicesProvider.notifier).syncFromOdoo();
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search invoice #, customer, SVAT...',
              ),
            ),
          ),

          // Segmented Tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = tab == _selectedTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tab),
                    selected: isSelected,
                    selectedColor: FlexColors.primary,
                    backgroundColor: FlexColors.surfaceRaisedDark,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FlexColors.textSecondaryDark,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? FlexColors.primary : FlexColors.borderDark,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedTab = tab);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Invoices List
          Expanded(
            child: filteredInvoices.isEmpty
                ? Center(
                    child: Text('No invoices found in $_selectedTab filter', style: FlexTypography.bodyMd),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final inv = filteredInvoices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: _InvoiceCard(invoice: inv),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final AccountInvoice invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    FlexBadgeVariant badgeVariant = FlexBadgeVariant.neutral;
    String badgeText = invoice.paymentState.toUpperCase();

    if (invoice.isPaid) {
      badgeVariant = FlexBadgeVariant.success;
      badgeText = 'PAID';
    } else if (invoice.isOverdue) {
      badgeVariant = FlexBadgeVariant.danger;
      badgeText = 'OVERDUE BY ${invoice.overdueDays} DAYS';
    } else {
      badgeVariant = FlexBadgeVariant.warning;
      badgeText = 'NOT PAID';
    }

    return FlexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(invoice.number, style: FlexTypography.headlineSm),
              FlexBadge(text: badgeText, variant: badgeVariant),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${invoice.partnerName} • SVAT: ${invoice.partnerVat}',
            style: FlexTypography.bodySm,
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice Date', style: FlexTypography.bodySm),
                  Text(LkFormatters.formatDate(invoice.invoiceDate), style: FlexTypography.labelMd),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due Date', style: FlexTypography.bodySm),
                  Text(
                    LkFormatters.formatDate(invoice.invoiceDateDue),
                    style: FlexTypography.labelMd.copyWith(
                      color: invoice.isOverdue ? FlexColors.danger : FlexColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Amount', style: FlexTypography.bodySm),
                  Text(
                    LkFormatters.formatLkr(invoice.amountTotal),
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
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            children: [
              if (!invoice.isPaid) ...[
                Expanded(
                  child: FlexButton(
                    label: 'Register Payment',
                    icon: Icons.payments_outlined,
                    variant: FlexButtonVariant.primary,
                    height: 36,
                    onPressed: () {
                      PaymentRegisterSheet.show(context, invoice: invoice);
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: FlexColors.primaryLight, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading Tax PDF for ${invoice.number}...')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined, color: FlexColors.info, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment reminder dispatched for ${invoice.number}')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
