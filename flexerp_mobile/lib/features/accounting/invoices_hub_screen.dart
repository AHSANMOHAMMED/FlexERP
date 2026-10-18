import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../shared/whatsapp_number_sheet.dart';

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
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(invoicesProvider.notifier).syncFromOdoo();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice sync failed: $e'), backgroundColor: FlexColors.danger),
        );
      }
    });
  }

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
          try {
            await ref.read(invoicesProvider.notifier).syncFromOdoo();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sync failed: $e'), backgroundColor: FlexColors.danger),
            );
          }
        },
      ),
      body: Column(
        children: [
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

class _InvoiceCard extends ConsumerWidget {
  final AccountInvoice invoice;

  const _InvoiceCard({required this.invoice});

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    final api = ref.read(flexerpApiProvider);
    final user = ref.read(currentUserProvider);
    if (user == null || user.isDemo || api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo: PDF for ${invoice.number} not fetched from Odoo')),
      );
      return;
    }
    try {
      final pdf = await api.invoicePdf(invoice.id);
      final b64 = pdf['pdf_base64']?.toString();
      if (b64 == null || b64.isEmpty) throw Exception('Empty PDF');
      final bytes = base64Decode(b64);
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: 'PDF ${pdf['filename']} (${bytes.length} bytes)'));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF fetched (web — metadata copied)')),
        );
        return;
      }
      final file = File('${Directory.systemTemp.path}/${pdf['filename'] ?? 'invoice.pdf'}');
      await file.writeAsBytes(bytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ${file.path}'), backgroundColor: FlexColors.success),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF error: $e'), backgroundColor: FlexColors.danger),
      );
    }
  }

  Future<void> _sendWhatsApp(BuildContext context, WidgetRef ref) async {
    await showWhatsAppNumberSheet(
      context,
      ref,
      title: 'Send invoice',
      customerName: invoice.partnerName,
      storeName: ref.read(currentUserProvider)?.companyName,
      moveId: invoice.id,
      amountLabel: LkFormatters.formatLkr(
        invoice.amountResidual > 0 ? invoice.amountResidual : invoice.amountTotal,
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref) async {
    final api = ref.read(flexerpApiProvider);
    final user = ref.read(currentUserProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final detail = await api.invoiceDetail(invoice.id);
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: FlexColors.surfaceDark,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail['name']?.toString() ?? invoice.number, style: FlexTypography.headlineMd),
              const SizedBox(height: 8),
              Text('Partner: ${detail['partner_name'] ?? invoice.partnerName}', style: FlexTypography.bodyMd),
              Text('State: ${detail['state'] ?? invoice.state}', style: FlexTypography.bodySm),
              Text(
                'Total: ${LkFormatters.formatLkr((detail['amount_total'] as num?)?.toDouble() ?? invoice.amountTotal)}',
                style: FlexTypography.labelLg,
              ),
              Text(
                'Residual: ${LkFormatters.formatLkr((detail['amount_residual'] as num?)?.toDouble() ?? invoice.amountResidual)}',
                style: FlexTypography.bodySm,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detail failed: $e'), backgroundColor: FlexColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onTap: () => _openDetail(context, ref),
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
                onPressed: () => _downloadPdf(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined, color: FlexColors.info, size: 20),
                onPressed: () => _sendWhatsApp(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
