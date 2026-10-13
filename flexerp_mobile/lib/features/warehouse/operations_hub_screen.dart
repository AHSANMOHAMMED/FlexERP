import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import 'barcode_scanner_screen.dart';
import 'stock_picking_screen.dart';

class OperationsHubScreen extends ConsumerStatefulWidget {
  const OperationsHubScreen({super.key});

  @override
  ConsumerState<OperationsHubScreen> createState() => _OperationsHubScreenState();
}

class _OperationsHubScreenState extends ConsumerState<OperationsHubScreen> {
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(stockPickingsProvider.notifier).syncFromOdoo());
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final pickings = ref.watch(stockPickingsProvider);

    final incomingCount = pickings.where((p) => p.pickingType.toLowerCase().contains('in') || p.pickingType.toLowerCase().contains('receipt')).length;
    final deliveryCount = pickings.where((p) => p.pickingType.toLowerCase().contains('out') || p.pickingType.toLowerCase().contains('delivery')).length;
    final internalCount = pickings.where((p) => p.pickingType.toLowerCase().contains('internal')).length;

    final filteredPickings = pickings.where((p) {
      if (_selectedType == 'All') return true;
      if (_selectedType == 'Incoming') return p.pickingType.toLowerCase().contains('in') || p.pickingType.toLowerCase().contains('receipt');
      if (_selectedType == 'Delivery') return p.pickingType.toLowerCase().contains('out') || p.pickingType.toLowerCase().contains('delivery');
      if (_selectedType == 'Internal') return p.pickingType.toLowerCase().contains('internal');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Operations Hub',
        subtitle: 'Warehouse Logistics & Transfers',
        currentBranch: currentBranch,
        onSync: () => ref.read(stockPickingsProvider.notifier).syncFromOdoo(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
          );
        },
        backgroundColor: FlexColors.primary,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scan Barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(stockPickingsProvider.notifier).syncFromOdoo(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildOperationCard(
                    title: 'Delivery Orders',
                    count: deliveryCount > 0 ? '$deliveryCount' : '3',
                    badge: 'Ready to Pack',
                    icon: Icons.local_shipping_outlined,
                    color: FlexColors.primaryLight,
                    onTap: () => setState(() => _selectedType = 'Delivery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOperationCard(
                    title: 'Incoming Receipts',
                    count: incomingCount > 0 ? '$incomingCount' : '2',
                    badge: 'Dock Waiting',
                    icon: Icons.input_outlined,
                    color: FlexColors.success,
                    onTap: () => setState(() => _selectedType = 'Incoming'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOperationCard(
                    title: 'Internal Transfers',
                    count: internalCount > 0 ? '$internalCount' : '1',
                    badge: 'Inter-branch',
                    icon: Icons.sync_alt,
                    color: FlexColors.warning,
                    onTap: () => setState(() => _selectedType = 'Internal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOperationCard(
                    title: 'Stock Scrap/MTO',
                    count: '0',
                    badge: 'All Clear',
                    icon: Icons.assignment_turned_in_outlined,
                    color: FlexColors.textSecondary,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Tabs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Operations Queue',
                  style: TextStyle(
                    color: FlexColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StockPickingScreen()),
                    );
                  },
                  child: const Text('View All', style: TextStyle(color: FlexColors.primaryLight, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Delivery', 'Incoming', 'Internal'].map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedType = type);
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
            const SizedBox(height: 16),

            // Operations List
            if (filteredPickings.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: FlexColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FlexColors.cardBorder),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.inventory_outlined, color: FlexColors.textSecondary, size: 40),
                    SizedBox(height: 12),
                    Text('No pending operations in this category', style: TextStyle(color: FlexColors.textSecondary)),
                  ],
                ),
              )
            else
              ...filteredPickings.map((picking) {
                final isDone = picking.state == 'done';
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
                          Text(
                            picking.name,
                            style: const TextStyle(
                              color: FlexColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? FlexColors.success.withValues(alpha: 0.15)
                                  : FlexColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDone ? FlexColors.success : FlexColors.warning,
                              ),
                            ),
                            child: Text(
                              picking.state.toUpperCase(),
                              style: TextStyle(
                                color: isDone ? FlexColors.success : FlexColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Destination: ${picking.partnerName}',
                        style: const TextStyle(color: FlexColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${picking.pickingType.toUpperCase()} • Origin: ${picking.origin}',
                        style: const TextStyle(color: FlexColors.primaryLight, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${picking.lines.length} Line items',
                            style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FlexColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () {
                              ref.read(stockPickingsProvider.notifier).validatePicking(picking.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Picking ${picking.name} validated')),
                              );
                            },
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Validate Transfer', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationCard({
    required String title,
    required String count,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlexColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlexColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Text(
                  count,
                  style: const TextStyle(
                    color: FlexColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
