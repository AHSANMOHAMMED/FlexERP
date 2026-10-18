import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/models/pos_order.dart';
import '../../data/repositories/pos_repository.dart';

class PosOrdersScreen extends ConsumerStatefulWidget {
  const PosOrdersScreen({super.key});

  @override
  ConsumerState<PosOrdersScreen> createState() => _PosOrdersScreenState();
}

class _PosOrdersScreenState extends ConsumerState<PosOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(posOrdersHistoryProvider);
    final query = _searchController.text.toLowerCase();

    final filteredOrders = orders.where((o) {
      return o.receiptNumber.toLowerCase().contains(query) ||
          o.customerName.toLowerCase().contains(query) ||
          o.paymentMethod.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'POS Orders & Receipts',
        subtitle: 'pos.order Transaction History & Reprints',
        showCompanySwitcher: false,
        onSync: () => ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo(),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(posOrdersHistoryProvider.notifier).syncFromOdoo(),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: FlexColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by receipt number or payment type...',
                  hintStyle: const TextStyle(color: FlexColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: FlexColors.primary, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: FlexColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: FlexColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: FlexColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: FlexColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: FlexColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Orders list
            Expanded(
              child: filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.receipt_long_outlined, color: FlexColors.textSecondary, size: 48),
                          SizedBox(height: 12),
                          Text('No past POS orders found', style: TextStyle(color: FlexColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: FlexColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: FlexColors.cardBorder),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt, color: FlexColors.primaryLight, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        order.receiptNumber,
                                        style: const TextStyle(
                                          color: FlexColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: FlexColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: FlexColors.primary),
                                    ),
                                    child: Text(
                                      order.paymentMethod,
                                      style: const TextStyle(
                                        color: FlexColors.primaryLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                order.customerName,
                                style: const TextStyle(color: FlexColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Time: ${order.orderDate.hour}:${order.orderDate.minute.toString().padLeft(2, '0')} • Today',
                                style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    LkFormatters.formatLkr(order.totalAmount),
                                    style: const TextStyle(
                                      color: FlexColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: FlexColors.primaryLight,
                                      side: const BorderSide(color: FlexColors.cardBorder),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                    onPressed: () => _showReceiptModal(context, order),
                                    icon: const Icon(Icons.print_outlined, size: 14),
                                    label: const Text('View & Print', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
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

  void _showReceiptModal(BuildContext context, PosPastOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlexColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.receiptNumber,
                    style: const TextStyle(
                      color: FlexColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlexColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PAID', style: TextStyle(color: FlexColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Customer: ${order.customerName}', style: const TextStyle(color: FlexColors.textSecondary, fontSize: 13)),
              Text('Payment Mode: ${order.paymentMethod}', style: const TextStyle(color: FlexColors.primaryLight, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Items Purchased:', style: TextStyle(color: FlexColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              if (order.lines.isEmpty)
                const Text('Retail items bundle (Consolidated)', style: TextStyle(color: FlexColors.textSecondary, fontSize: 12))
              else
                ...order.lines.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${l.quantity}x ${l.productName}',
                              style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                            ),
                          ),
                          Text(LkFormatters.formatLkr(l.subtotal), style: const TextStyle(color: FlexColors.textPrimary, fontSize: 12)),
                        ],
                      ),
                    )),
              const Divider(color: FlexColors.cardBorder, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Paid:', style: TextStyle(color: FlexColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(LkFormatters.formatLkr(order.totalAmount), style: const TextStyle(color: FlexColors.primaryLight, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlexColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reprint sent to 80mm ESC/POS printer for ${order.receiptNumber}')),
                    );
                  },
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Reprint ESC/POS Thermal Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
