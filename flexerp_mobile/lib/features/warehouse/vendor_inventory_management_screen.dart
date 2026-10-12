import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/vendor_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/vendor_repository.dart';
import '../../data/repositories/vendor_inventory_repository.dart';

class VendorInventoryManagementScreen extends ConsumerStatefulWidget {
  const VendorInventoryManagementScreen({super.key});

  @override
  ConsumerState<VendorInventoryManagementScreen> createState() =>
      _VendorInventoryManagementScreenState();
}

class _VendorInventoryManagementScreenState
    extends ConsumerState<VendorInventoryManagementScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Safety & PPE',
    'Hand Tools',
    'Power Tools',
    'Electrical',
    'Hardware',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddProductModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '20');
    String category = 'Hardware';

    showModalBottomSheet(
      context: context,
      backgroundColor: FlexColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add New Product to Catalog', style: FlexTypography.headlineSm),
                        IconButton(
                          icon: const Icon(Icons.close, color: FlexColors.textSecondaryDark),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        hintText: 'e.g. Stanley 8m Tape Measure',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: skuCtrl,
                            decoration: const InputDecoration(
                              labelText: 'SKU Code',
                              hintText: 'e.g. STN-TP-08',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            decoration: const InputDecoration(labelText: 'Category'),
                            dropdownColor: FlexColors.surfaceRaisedDark,
                            items: _categories
                                .where((c) => c != 'All')
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => category = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: barcodeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Barcode (EAN-13 / Code128)',
                              hintText: '4790012...',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.auto_awesome, color: FlexColors.primaryLight, size: 20),
                                tooltip: 'Auto-generate Barcode',
                                onPressed: () {
                                  final gen = '479${DateTime.now().millisecondsSinceEpoch.toString().substring(3, 13)}';
                                  setModalState(() => barcodeCtrl.text = gen);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cost Price (LKR)',
                              hintText: '1500.00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Selling Price (LKR)',
                              hintText: '2200.00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Initial Stock',
                              hintText: '25',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FlexButton(
                      label: 'Save & Publish to Vendor DB',
                      icon: Icons.cloud_upload_outlined,
                      height: 48,
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty ||
                            barcodeCtrl.text.trim().isEmpty ||
                            priceCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill Name, Barcode, and Selling Price'),
                              backgroundColor: FlexColors.danger,
                            ),
                          );
                          return;
                        }

                        final currentVendor = ref.read(currentVendorProvider);
                        final newProd = VendorProduct(
                          id: DateTime.now().millisecondsSinceEpoch,
                          vendorId: currentVendor.vendorId,
                          name: nameCtrl.text.trim(),
                          sku: skuCtrl.text.trim().isNotEmpty
                              ? skuCtrl.text.trim()
                              : 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                          barcode: barcodeCtrl.text.trim(),
                          category: category,
                          costPrice: double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          sellingPrice: double.tryParse(priceCtrl.text.trim()) ?? 0.0,
                          stockOnHand: int.tryParse(stockCtrl.text.trim()) ?? 0,
                          minStockAlert: 5,
                          updatedAt: DateTime.now(),
                        );

                        ref.read(vendorInventoryProvider.notifier).addProduct(newProd);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${newProd.name} to ${currentVendor.name} DB!'),
                            backgroundColor: FlexColors.success,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStockAdjustDialog(BuildContext context, VendorProduct product) {
    int delta = 5;
    String reason = 'Supplier Delivery (GRN)';
    final reasons = [
      'Supplier Delivery (GRN)',
      'Physical Inventory Audit',
      'Damaged / Write-Off',
      'Customer Return',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final newStock = product.stockOnHand + delta;
            return AlertDialog(
              backgroundColor: FlexColors.surfaceDark,
              title: Row(
                children: [
                  const Icon(Icons.tune, color: FlexColors.primaryLight, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Adjust Stock: ${product.name}', style: FlexTypography.headlineSm),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current On-Hand:', style: TextStyle(color: FlexColors.textSecondaryDark)),
                      Text('${product.stockOnHand} Units', style: FlexTypography.labelLg),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: FlexColors.danger, size: 32),
                        onPressed: () {
                          if (product.stockOnHand + (delta - 1) >= 0) {
                            setDialogState(() => delta--);
                          }
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: FlexColors.surfaceRaisedDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FlexColors.borderDark),
                        ),
                        child: Text(
                          delta >= 0 ? '+$delta' : '$delta',
                          style: FlexTypography.headlineMd.copyWith(
                            color: delta >= 0 ? FlexColors.success : FlexColors.danger,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: FlexColors.success, size: 32),
                        onPressed: () => setDialogState(() => delta++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Resulting Stock Level:', style: TextStyle(color: FlexColors.textSecondaryDark)),
                      Text(
                        '$newStock Units',
                        style: FlexTypography.labelLg.copyWith(
                          color: newStock <= 0 ? FlexColors.danger : FlexColors.primaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: 'Adjustment Reason'),
                    dropdownColor: FlexColors.surfaceRaisedDark,
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => reason = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: FlexColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: FlexColors.primary),
                  onPressed: () {
                    ref.read(vendorInventoryProvider.notifier).adjustStock(
                          product.id,
                          delta,
                          reason: reason,
                        );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Live Stock Sync: ${product.name} is now $newStock units!'),
                        backgroundColor: FlexColors.surfaceRaisedDark,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Broadcast Live Stock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBarcodeUpdateDialog(BuildContext context, VendorProduct product) {
    final barcodeCtrl = TextEditingController(text: product.barcode);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: FlexColors.surfaceDark,
          title: Text('Edit Barcode: ${product.name}', style: FlexTypography.headlineSm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: barcodeCtrl,
                decoration: InputDecoration(
                  labelText: 'New Barcode Number',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.auto_awesome, color: FlexColors.primaryLight),
                    tooltip: 'Generate new barcode',
                    onPressed: () {
                      barcodeCtrl.text = '479${DateTime.now().millisecondsSinceEpoch.toString().substring(3, 13)}';
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Updating the barcode will immediately update the POS high-speed scanner index.',
                style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: FlexColors.textSecondaryDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: FlexColors.primary),
              onPressed: () {
                if (barcodeCtrl.text.trim().isNotEmpty) {
                  ref.read(vendorInventoryProvider.notifier).updateBarcode(
                        product.id,
                        barcodeCtrl.text.trim(),
                      );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Barcode updated to ${barcodeCtrl.text.trim()}!'),
                      backgroundColor: FlexColors.success,
                    ),
                  );
                }
              },
              child: const Text('Save Barcode'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final currentVendor = ref.watch(currentVendorProvider);
    final inventory = ref.watch(vendorInventoryProvider);

    final filteredInventory = inventory.where((p) {
      final matchesCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.barcode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesQuery;
    }).toList();

    final totalStockUnits = inventory.fold<int>(0, (sum, item) => sum + item.stockOnHand);
    final totalValuation = inventory.fold<double>(0.0, (sum, item) => sum + (item.costPrice * item.stockOnHand));

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Vendor Inventory Manager',
        subtitle: '${currentVendor.name} • ${currentVendor.vendorId}',
        currentBranch: currentBranch,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FlexColors.primary,
        onPressed: () => _showAddProductModal(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // KPI Metric Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: FlexColors.surfaceDark,
              border: Border(bottom: BorderSide(color: FlexColors.borderDark)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL SKUs', style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${inventory.length}', style: FlexTypography.headlineMd),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: FlexColors.borderDark),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STOCK ON-HAND', style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('$totalStockUnits Units', style: FlexTypography.headlineMd.copyWith(color: FlexColors.primaryLight)),
                    ],
                  ),
                ),
                Container(height: 32, width: 1, color: FlexColors.borderDark),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STOCK VALUATION', style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(LkFormatters.formatLkr(totalValuation), style: FlexTypography.headlineSm.copyWith(color: FlexColors.success)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search SKU, product name, or barcode...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: FlexColors.primary,
                    backgroundColor: FlexColors.surfaceRaisedDark,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FlexColors.textSecondaryDark,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                    side: BorderSide(
                      color: isSelected ? FlexColors.primary : FlexColors.borderDark,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Product Inventory Cards List
          Expanded(
            child: filteredInventory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 48, color: FlexColors.textSecondaryDark),
                        const SizedBox(height: 12),
                        Text('No products found matching filters', style: FlexTypography.bodyMd),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProductModal(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Product to this Vendor'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: filteredInventory.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredInventory[index];
                      final isOutOfStock = item.isOutOfStock;
                      final isLowStock = item.isLowStock;

                      final statusColor = isOutOfStock
                          ? FlexColors.danger
                          : isLowStock
                              ? FlexColors.warning
                              : FlexColors.success;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FlexCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            FlexBadge(text: item.category, variant: FlexBadgeVariant.neutral),
                                            const SizedBox(width: 8),
                                            Text(
                                              item.sku,
                                              style: const TextStyle(
                                                color: FlexColors.primaryLight,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(item.name, style: FlexTypography.labelLg),
                                      ],
                                    ),
                                  ),
                                  // Stock Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      '${item.stockOnHand} Units',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Barcode & Price Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code, size: 14, color: FlexColors.textSecondaryDark),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.barcode,
                                        style: const TextStyle(
                                          color: FlexColors.textSecondaryDark,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 14, color: FlexColors.textSecondaryDark),
                                        tooltip: 'Edit Barcode',
                                        onPressed: () => _showBarcodeUpdateDialog(context, item),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        LkFormatters.formatLkr(item.sellingPrice),
                                        style: FlexTypography.codeNum.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Cost: ${LkFormatters.formatLkr(item.costPrice)}',
                                        style: const TextStyle(color: FlexColors.textSecondaryDark, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              // Quick Stock Action Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      side: const BorderSide(color: FlexColors.borderDark),
                                    ),
                                    onPressed: () => _showStockAdjustDialog(context, item),
                                    icon: const Icon(Icons.tune, size: 14, color: FlexColors.primaryLight),
                                    label: const Text('Adjust Live Stock', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
