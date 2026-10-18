import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/purchase_repository.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_sync);
  }

  Future<void> _sync() async {
    setState(() => _error = null);
    try {
      await ref.read(purchaseOrdersProvider.notifier).syncFromServer();
      await ref.read(partnersProvider.notifier).syncFromOdoo(partnerType: 'supplier');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: FlexColors.danger,
        ),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('not installed')) {
      return 'Purchase module is not installed on this Odoo database.';
    }
    if (msg.contains('disabled') || msg.contains('Feature')) {
      return 'Purchase is disabled for this vendor.';
    }
    return 'Could not load purchase orders.';
  }

  Future<void> _showCreateDialog() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final partners = ref.read(partnersProvider);
    if (user != null && !user.isDemo && api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to Odoo'), backgroundColor: FlexColors.danger),
      );
      return;
    }

    List<Map<String, dynamic>> products = [];
    List<Map<String, dynamic>> categories = [];
    if (user != null && !user.isDemo && api != null) {
      try {
        products = await api.products(limit: 120);
        categories = await api.productCategories();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Products failed: $e'), backgroundColor: FlexColors.danger),
        );
        return;
      }
    }

    if (!mounted) return;
    int? partnerId = partners.isNotEmpty ? partners.first.id : null;
    int? categoryId;
    Map<String, dynamic>? product = products.isNotEmpty ? products.first : null;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(
      text: ((product?['list_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final visibleProducts = categoryId == null
                ? products
                : products
                    .where((p) => (p['categ_id'] as num?)?.toInt() == categoryId)
                    .toList();
            return AlertDialog(
              backgroundColor: FlexColors.surfaceDark,
              title: const Text('New Purchase Order'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user?.isDemo == true)
                      const Text(
                        'Demo mode: create is live-Odoo only. Connect a server to provision POs.',
                        style: TextStyle(fontSize: 12, color: FlexColors.textSecondaryDark),
                      )
                    else ...[
                      DropdownButtonFormField<int>(
                        value: partnerId,
                        dropdownColor: FlexColors.surfaceRaisedDark,
                        decoration: const InputDecoration(labelText: 'Vendor partner'),
                        items: partners
                            .map(
                              (p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                            )
                            .toList(),
                        onChanged: (v) => setModal(() => partnerId = v),
                      ),
                      if (categories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          value: categoryId,
                          dropdownColor: FlexColors.surfaceRaisedDark,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                            ...categories.take(30).map(
                                  (c) => DropdownMenuItem<int?>(
                                    value: (c['id'] as num?)?.toInt(),
                                    child: Text(c['name']?.toString() ?? 'Category', overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                          ],
                          onChanged: (v) {
                            setModal(() {
                              categoryId = v;
                              if (visibleProducts.isEmpty ||
                                  !visibleProducts.any((p) => (p['id'] as num?)?.toInt() == (product?['id'] as num?)?.toInt())) {
                                final next = (v == null
                                        ? products
                                        : products.where((p) => (p['categ_id'] as num?)?.toInt() == v))
                                    .toList();
                                product = next.isNotEmpty ? next.first : null;
                                priceCtrl.text =
                                    ((product?['list_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                              }
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: (product?['id'] as num?)?.toInt(),
                        dropdownColor: FlexColors.surfaceRaisedDark,
                        decoration: const InputDecoration(labelText: 'Product'),
                        items: visibleProducts
                            .map(
                              (p) => DropdownMenuItem(
                                value: (p['id'] as num?)?.toInt(),
                                child: Text(p['name']?.toString() ?? 'Product', overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          final match = visibleProducts.firstWhere(
                            (p) => (p['id'] as num?)?.toInt() == id,
                            orElse: () => visibleProducts.first,
                          );
                          setModal(() {
                            product = match;
                            priceCtrl.text =
                                ((match['list_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Unit price (LKR)'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: user?.isDemo == true
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true || partnerId == null || product == null) return;
    final productId = (product!['id'] as num?)?.toInt() ?? 0;
    final qty = double.tryParse(qtyCtrl.text) ?? 1;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    if (productId <= 0) return;

    try {
      final result = await ref.read(purchaseOrdersProvider.notifier).createOrder(
            partnerId: partnerId!,
            lines: [
              {
                'product_id': productId,
                'qty': qty,
                'price_unit': price,
                'name': product!['name']?.toString() ?? 'Line',
              },
            ],
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created ${result?['name'] ?? 'PO'}'),
          backgroundColor: FlexColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e)), backgroundColor: FlexColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Purchase Orders',
        subtitle: 'Independent purchase module',
        showCompanySwitcher: false,
        onSync: _sync,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: FlexColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New PO'),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: _sync,
        child: orders.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: FlexColors.textSecondaryDark.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error != null ? 'Sync failed' : 'No purchase orders yet',
                    textAlign: TextAlign.center,
                    style: FlexTypography.bodyMd.copyWith(color: FlexColors.textSecondaryDark),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _friendlyError(_error!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FlexColors.danger, fontSize: 12),
                      ),
                    ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final o = orders[index];
                  return FlexCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.name, style: FlexTypography.labelLg),
                              const SizedBox(height: 4),
                              Text(o.partnerName, style: FlexTypography.bodySm),
                              Text(
                                o.state.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FlexColors.textSecondaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          LkFormatters.formatLkr(o.amountTotal),
                          style: FlexTypography.labelLg.copyWith(color: FlexColors.primaryLight),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
