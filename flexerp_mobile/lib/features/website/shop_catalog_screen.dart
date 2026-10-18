import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';

class ShopCatalogScreen extends ConsumerStatefulWidget {
  const ShopCatalogScreen({super.key});

  @override
  ConsumerState<ShopCatalogScreen> createState() => _ShopCatalogScreenState();
}

class _ShopCatalogScreenState extends ConsumerState<ShopCatalogScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _cart;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final api = ref.read(flexerpApiProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (api == null) {
        setState(() {
          _loading = false;
          _error = 'Website API requires a live Odoo session with website feature enabled.';
        });
        return;
      }
      final catalog = await api.shopCatalog();
      final cart = await api.shopCart();
      setState(() {
        _products = catalog;
        _cart = cart;
        _loading = false;
      });
    } catch (e) {
      debugPrint('FlexERP: shop catalog load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = describeError(e);
      });
    }
  }

  Future<void> _refreshCart() async {
    final api = ref.read(flexerpApiProvider);
    if (api == null) return;
    try {
      final cart = await api.shopCart();
      if (mounted) setState(() => _cart = cart);
    } catch (e) {
      _showError('Cart refresh', e);
    }
  }

  void _showError(String action, Object e) {
    debugPrint('FlexERP: shop $action failed: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action failed: ${describeError(e)}'), backgroundColor: FlexColors.danger),
    );
  }

  Future<void> _addToCart(int productId) async {
    final api = ref.read(flexerpApiProvider);
    if (api == null || productId <= 0) return;
    final Map<String, dynamic> cart;
    try {
      cart = await api.shopCartAdd(productId: productId);
    } catch (e) {
      _showError('Add to cart', e);
      return;
    }
    if (!mounted) return;
    setState(() => _cart = cart);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart'), backgroundColor: FlexColors.success),
    );
  }

  Future<void> _updateLineQty(int lineId, double qty) async {
    final api = ref.read(flexerpApiProvider);
    if (api == null) return;
    try {
      final cart = await api.shopCartUpdate(lineId: lineId, qty: qty);
      if (mounted) setState(() => _cart = cart);
    } catch (e) {
      _showError('Cart update', e);
    }
  }

  Future<void> _checkout() async {
    final api = ref.read(flexerpApiProvider);
    if (api == null) return;
    final Map<String, dynamic> result;
    try {
      result = await api.shopCheckout();
    } catch (e) {
      _showError('Checkout', e);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['success'] == true
            ? 'Order ${result['name']} confirmed'
            : result['error']?.toString() ?? 'Checkout failed'),
        backgroundColor: result['success'] == true ? FlexColors.success : FlexColors.danger,
      ),
    );
    if (result['success'] == true) {
      await _refreshCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(currentBranchProvider);
    final lines = (_cart?['lines'] as List?) ?? const [];
    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Website Shop',
        subtitle: 'Mobile eCommerce facade',
        currentBranch: branch,
        onSync: _load,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: FlexTypography.bodyMd, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FlexCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Cart total: ${LkFormatters.formatLkr((_cart?['amount_total'] as num?)?.toDouble() ?? 0)}',
                                    style: FlexTypography.labelLg,
                                  ),
                                ),
                                FlexButton(
                                  label: 'Checkout',
                                  height: 36,
                                  onPressed: lines.isEmpty ? null : _checkout,
                                ),
                              ],
                            ),
                            if (lines.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ...lines.map((raw) {
                                final line = Map<String, dynamic>.from(raw as Map);
                                final lineId = line['id'] as int? ?? 0;
                                final qty = (line['qty'] as num?)?.toDouble() ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          line['name']?.toString() ?? 'Line',
                                          style: FlexTypography.bodySm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                                        onPressed: () => _updateLineQty(lineId, (qty - 1).clamp(0, 999)),
                                      ),
                                      Text(qty.toStringAsFixed(0), style: FlexTypography.labelMd),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 18),
                                        onPressed: () => _updateLineQty(lineId, qty + 1),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          return FlexCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name']?.toString() ?? 'Product', style: FlexTypography.labelLg),
                                      Text(
                                        LkFormatters.formatLkr((p['list_price'] as num?)?.toDouble() ?? 0),
                                        style: FlexTypography.bodySm.copyWith(color: FlexColors.primaryLight),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_shopping_cart, color: FlexColors.primaryLight),
                                  onPressed: () => _addToCart(parseOdooInt(p['product_id']) ?? 0),
                                ),
                              ],
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
