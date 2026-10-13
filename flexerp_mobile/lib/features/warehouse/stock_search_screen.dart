import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/repositories/stock_quant_repository.dart';

class StockSearchScreen extends ConsumerStatefulWidget {
  const StockSearchScreen({super.key});

  @override
  ConsumerState<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends ConsumerState<StockSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedWarehouse = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(stockQuantsProvider.notifier).syncFromOdoo());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quants = ref.watch(stockQuantsProvider);
    final query = _searchController.text.toLowerCase();

    final filteredQuants = quants.where((q) {
      final matchesSearch = q.productName.toLowerCase().contains(query) ||
          q.productSku.toLowerCase().contains(query) ||
          q.locationName.toLowerCase().contains(query);
      final matchesWh = _selectedWarehouse == 'All' || q.warehouseCode.contains(_selectedWarehouse);
      return matchesSearch && matchesWh;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Inventory & Bins',
        subtitle: 'stock.quant Multi-Warehouse Levels',
        showCompanySwitcher: false,
        onSync: () => ref.read(stockQuantsProvider.notifier).syncFromOdoo(),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(stockQuantsProvider.notifier).syncFromOdoo(),
        child: Column(
          children: [
            // Search & filter
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: FlexColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by SKU, item name or bin location...',
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
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        {'label': 'All Hubs', 'code': 'All'},
                        {'label': 'Kelaniya (WH1)', 'code': 'WH1'},
                        {'label': 'Colombo (WH2)', 'code': 'WH2'},
                        {'label': 'Kandy (WH3)', 'code': 'WH3'},
                        {'label': 'Galle (WH4)', 'code': 'WH4'},
                      ].map((wh) {
                        final isSelected = _selectedWarehouse == wh['code'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(wh['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedWarehouse = wh['code']!);
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
                ],
              ),
            ),

            // Quants List
            Expanded(
              child: filteredQuants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inventory_2_outlined, color: FlexColors.textSecondary, size: 48),
                          SizedBox(height: 12),
                          Text('No stock records found', style: TextStyle(color: FlexColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredQuants.length,
                      itemBuilder: (context, index) {
                        final q = filteredQuants[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: FlexColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: q.isLowStock
                                  ? FlexColors.warning.withValues(alpha: 0.5)
                                  : FlexColors.cardBorder,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: FlexColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.qr_code_2, color: FlexColors.primaryLight, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          q.productName,
                                          style: const TextStyle(
                                            color: FlexColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              q.productSku,
                                              style: const TextStyle(
                                                color: FlexColors.primaryLight,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '• ${q.category}',
                                              style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (q.isLowStock)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: FlexColors.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: FlexColors.warning),
                                      ),
                                      child: const Text(
                                        'LOW STOCK',
                                        style: TextStyle(
                                          color: FlexColors.warning,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Location tag
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: FlexColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warehouse_outlined, size: 14, color: FlexColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        q.locationName,
                                        style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Quantities row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQtyCard(
                                      label: 'On Hand',
                                      value: '${q.quantityOnHand.toStringAsFixed(0)} ${q.uom}',
                                      color: FlexColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildQtyCard(
                                      label: 'Reserved',
                                      value: '${q.reservedQuantity.toStringAsFixed(0)} ${q.uom}',
                                      color: FlexColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildQtyCard(
                                      label: 'Available',
                                      value: '${q.availableQuantity.toStringAsFixed(0)} ${q.uom}',
                                      color: FlexColors.success,
                                    ),
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

  Widget _buildQtyCard({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: FlexColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: FlexColors.textSecondary, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
