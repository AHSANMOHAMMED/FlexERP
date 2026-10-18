import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/stock_quant_repository.dart';
import '../../core/widgets/flex_app_bar.dart';

class StockSearchScreen extends ConsumerStatefulWidget {
  const StockSearchScreen({super.key});

  @override
  ConsumerState<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends ConsumerState<StockSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLocation = 'All';
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(stockQuantsProvider.notifier).syncFromOdoo();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock sync failed: $e'), backgroundColor: FlexColors.danger),
        );
      }
      await _loadLocations();
    });
  }

  Future<void> _loadLocations() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) {
      setState(() {
        _locations = [
          {'id': 0, 'name': 'All'},
          {'id': 0, 'name': 'WH1'},
          {'id': 0, 'name': 'WH2'},
        ];
      });
      return;
    }
    try {
      final rows = await api.stockLocations();
      if (!mounted) return;
      setState(() {
        _locations = [
          {'id': 0, 'name': 'All'},
          ...rows,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locations failed: $e'), backgroundColor: FlexColors.danger),
      );
    }
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
      final matchesLoc = _selectedLocation == 'All' ||
          q.locationName.toLowerCase().contains(_selectedLocation.toLowerCase()) ||
          q.warehouseCode.contains(_selectedLocation);
      return matchesSearch && matchesLoc;
    }).toList();

    final chips = _locations.isEmpty
        ? [
            {'name': 'All'},
          ]
        : _locations;

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Inventory & Bins',
        subtitle: 'stock.quant Multi-Warehouse Levels',
        showCompanySwitcher: false,
        onSync: () async {
          try {
            await ref.read(stockQuantsProvider.notifier).syncFromOdoo();
            await _loadLocations();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sync failed: $e'), backgroundColor: FlexColors.danger),
            );
          }
        },
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () async {
          await ref.read(stockQuantsProvider.notifier).syncFromOdoo();
          await _loadLocations();
        },
        child: Column(
          children: [
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
                      children: chips.map((loc) {
                        final name = loc['name']?.toString() ?? 'All';
                        final code = name == 'All' ? 'All' : name;
                        final isSelected = _selectedLocation == code ||
                            (_selectedLocation != 'All' && name.contains(_selectedLocation));
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(name.length > 28 ? '${name.substring(0, 28)}…' : name),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedLocation = code);
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
            Expanded(
              child: filteredQuants.isEmpty
                  ? const Center(
                      child: Text('No stock quants match filters', style: TextStyle(color: FlexColors.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredQuants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final q = filteredQuants[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: FlexColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: FlexColors.cardBorder),
                          ),
                          child: Row(
                            children: [
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '${q.productSku} · ${q.locationName}',
                                      style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                q.quantityOnHand.toStringAsFixed(1),
                                style: TextStyle(
                                  color: q.isLowStock ? FlexColors.warning : FlexColors.primaryLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
