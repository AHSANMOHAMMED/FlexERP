import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/repositories/vendor_bill_repository.dart';

class VendorBillsScreen extends ConsumerStatefulWidget {
  const VendorBillsScreen({super.key});

  @override
  ConsumerState<VendorBillsScreen> createState() => _VendorBillsScreenState();
}

class _VendorBillsScreenState extends ConsumerState<VendorBillsScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vendorBillsProvider.notifier).syncFromOdoo());
  }

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(vendorBillsProvider);

    final filteredBills = bills.where((b) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Pending') return !b.isPaid;
      if (_selectedFilter == 'Overdue') return b.isOverdue;
      if (_selectedFilter == 'Paid') return b.isPaid;
      return true;
    }).toList();

    final totalPayable = bills
        .where((b) => !b.isPaid)
        .fold(0.0, (prev, b) => prev + b.amountDue);

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Vendor Bills (AP)',
        subtitle: 'account.move Supplier Invoices & WHT',
        showCompanySwitcher: false,
        onSync: () => ref.read(vendorBillsProvider.notifier).syncFromOdoo(),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(vendorBillsProvider.notifier).syncFromOdoo(),
        child: Column(
          children: [
            // Total Outstanding AP Summary Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FlexColors.surface,
                    FlexColors.primary.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FlexColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding Payable',
                        style: TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LkFormatters.formatLkr(totalPayable),
                        style: const TextStyle(
                          color: FlexColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlexColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long, color: FlexColors.primaryLight, size: 24),
                  ),
                ],
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Pending', 'Overdue', 'Paid'].map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = f);
                      },
                      selectedColor: FlexColors.primary.withValues(alpha: 0.25),
                      backgroundColor: FlexColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? FlexColors.primaryLight : FlexColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? FlexColors.primary : FlexColors.cardBorder,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Bills List
            Expanded(
              child: filteredBills.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline, color: FlexColors.textSecondary, size: 48),
                          SizedBox(height: 12),
                          Text('No vendor bills found', style: TextStyle(color: FlexColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredBills.length,
                      itemBuilder: (context, index) {
                        final bill = filteredBills[index];
                        final isOverdue = bill.isOverdue;
                        final isPaid = bill.isPaid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: FlexColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isOverdue
                                  ? FlexColors.error.withValues(alpha: 0.5)
                                  : FlexColors.cardBorder,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    bill.billNumber,
                                    style: const TextStyle(
                                      color: FlexColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? FlexColors.success.withValues(alpha: 0.15)
                                          : (isOverdue
                                              ? FlexColors.error.withValues(alpha: 0.15)
                                              : FlexColors.warning.withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isPaid
                                            ? FlexColors.success
                                            : (isOverdue ? FlexColors.error : FlexColors.warning),
                                      ),
                                    ),
                                    child: Text(
                                      isPaid ? 'PAID' : (isOverdue ? 'OVERDUE' : 'DUE SOON'),
                                      style: TextStyle(
                                        color: isPaid
                                            ? FlexColors.success
                                            : (isOverdue ? FlexColors.error : FlexColors.warning),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bill.vendorName,
                                style: const TextStyle(
                                  color: FlexColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'TIN: ${bill.vendorVatOrTin}',
                                style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 12),
                              // Tax & Due Breakdown
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: FlexColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('18% VAT: ${LkFormatters.formatLkr(bill.vatAmount)}',
                                            style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11)),
                                        if (bill.whtAmount > 0)
                                          Text('5% WHT Ded: ${LkFormatters.formatLkr(bill.whtAmount)}',
                                              style: const TextStyle(color: FlexColors.warning, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total Bill Amount:',
                                            style: TextStyle(color: FlexColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(LkFormatters.formatLkr(bill.totalAmount),
                                            style: const TextStyle(color: FlexColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Register Payment Button
                              if (!isPaid)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: FlexColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      ref.read(vendorBillsProvider.notifier).markAsPaid(bill.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Payment registered for ${bill.billNumber}')),
                                      );
                                    },
                                    icon: const Icon(Icons.payment, size: 16),
                                    label: const Text('Register Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
