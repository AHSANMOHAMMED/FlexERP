import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/customer_partner.dart';
import '../../data/models/sale_order.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/sales_repository.dart';

class QuotationBuilderScreen extends ConsumerStatefulWidget {
  final VoidCallback onOrderConfirmed;

  const QuotationBuilderScreen({super.key, required this.onOrderConfirmed});

  @override
  ConsumerState<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends ConsumerState<QuotationBuilderScreen> {
  final _customerController = TextEditingController();
  final _phoneController = TextEditingController();
  String _paymentTerms = '30 Days Net';
  double _creditLimit = 0;
  double _currentCreditUsed = 0;
  double _globalDiscountPercent = 0;
  int? _partnerId;
  List<OrderLine> _lines = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  bool _loadingCatalog = false;
  bool _submitting = false;

  double get _untaxedSubtotal {
    final sum = _lines.fold(0.0, (prev, line) => prev + line.subtotal);
    return sum * (1 - (_globalDiscountPercent / 100));
  }

  double get _vatAmount => LkFormatters.calculateVat(_untaxedSubtotal);
  double get _ssclAmount => LkFormatters.calculateSscl(_untaxedSubtotal);
  double get _totalAmount => _untaxedSubtotal + _vatAmount + _ssclAmount;

  bool get _isLive {
    final user = ref.read(currentUserProvider);
    return user != null && !user.isDemo;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(partnersProvider.notifier).syncFromOdoo();
    if (!_isLive) {
      setState(() {
        _customerController.text = 'Lanka Industrial Supplies (Pvt) Ltd';
        _phoneController.text = '+94 11 268 9000';
        _creditLimit = 1500000;
        _currentCreditUsed = 620000;
        _globalDiscountPercent = 5;
        _lines = [
          const OrderLine(
            productId: 101,
            productName: 'Heavy Duty Industrial Pallet 1200x1000',
            sku: 'PLT-1200-HD',
            quantity: 50,
            unitPrice: 4500.0,
          ),
        ];
      });
      return;
    }
    setState(() => _loadingCatalog = true);
    try {
      final api = ref.read(flexerpApiProvider);
      if (api != null) {
        final categories = await api.productCategories();
        final products = await api.products(limit: 120);
        if (mounted) {
          setState(() {
            _categories = categories;
            _products = products;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load products: $e'), backgroundColor: FlexColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  void _selectPartner(CustomerPartner partner) {
    setState(() {
      _partnerId = partner.id;
      _customerController.text = partner.name;
      _phoneController.text = partner.phone;
      _creditLimit = partner.creditLimit;
      _currentCreditUsed = partner.totalReceivable;
      _paymentTerms = partner.paymentTerms;
    });
  }

  Future<void> _addProduct() async {
    if (_isLive) {
      if (_products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products available from Odoo yet.')),
        );
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: FlexColors.surfaceDark,
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final visible = _categoryId == null
                  ? _products
                  : _products
                      .where((p) => (p['categ_id'] as num?)?.toInt() == _categoryId)
                      .toList();
              return SafeArea(
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.7,
                  child: Column(
                    children: [
                      if (_categories.isNotEmpty)
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected: _categoryId == null,
                                onSelected: (_) {
                                  setState(() => _categoryId = null);
                                  setSheetState(() {});
                                },
                              ),
                              ..._categories.take(20).map((c) {
                                final id = (c['id'] as num?)?.toInt();
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(c['name']?.toString() ?? 'Cat'),
                                    selected: _categoryId == id,
                                    onSelected: (_) {
                                      setState(() => _categoryId = id);
                                      setSheetState(() {});
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (_, i) {
                            final p = visible[i];
                            final name = p['name']?.toString() ?? 'Product';
                            final price = (p['list_price'] as num?)?.toDouble() ?? 0.0;
                            return ListTile(
                              title: Text(name, style: FlexTypography.labelMd),
                              subtitle: Text(
                                '${p['default_code'] ?? p['sku'] ?? ''} · ${LkFormatters.formatLkr(price)}',
                                style: FlexTypography.bodySm,
                              ),
                              onTap: () => Navigator.pop(ctx, p),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      if (selected == null) return;
      final id = (selected['id'] as num?)?.toInt() ?? 0;
      final price = (selected['list_price'] as num?)?.toDouble() ??
          (selected['lst_price'] as num?)?.toDouble() ??
          (selected['selling_price'] as num?)?.toDouble() ??
          0.0;
      setState(() {
        _lines = [
          ..._lines,
          OrderLine(
            productId: id,
            productName: selected['name']?.toString() ?? 'Product',
            sku: selected['default_code']?.toString() ?? selected['sku']?.toString() ?? '',
            quantity: 1,
            unitPrice: price,
          ),
        ];
      });
      return;
    }

    setState(() {
      _lines.add(
        const OrderLine(
          productId: 103,
          productName: 'Wireless Barcode Scanner 2D Bluetooth',
          sku: 'SCN-2D-BT',
          quantity: 5,
          unitPrice: 38500.0,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  Future<void> _confirmOrder() async {
    if (_customerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required'), backgroundColor: FlexColors.danger),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product'), backgroundColor: FlexColors.danger),
      );
      return;
    }

    final draft = SaleOrder(
      id: DateTime.now().millisecondsSinceEpoch,
      name: 'SO/DRAFT',
      partnerName: _customerController.text.trim(),
      partnerPhone: _phoneController.text.trim(),
      paymentTerms: _paymentTerms,
      creditLimit: _creditLimit,
      currentCreditUsed: _currentCreditUsed,
      lines: List.from(_lines),
      globalDiscountPercent: _globalDiscountPercent,
      state: 'sale',
      dateOrder: DateTime.now(),
    );

    setState(() => _submitting = true);
    try {
      final saved = await ref.read(saleOrdersProvider.notifier).addOrder(
            draft,
            partnerId: _partnerId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FlexColors.success,
          content: Text('Order ${saved.name} submitted to ERP'),
        ),
      );
      widget.onOrderConfirmed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: $e'), backgroundColor: FlexColors.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(partnersProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: AppBar(
        title: Text('New Sales Quotation', style: FlexTypography.headlineMd),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUSTOMER & CREDIT TERMS', style: FlexTypography.labelSm),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerController,
                    style: FlexTypography.bodyMd,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.business, size: 20),
                      labelText: 'Customer / Corporate Client',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    style: FlexTypography.bodyMd,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.phone, size: 20),
                      labelText: 'Phone',
                    ),
                  ),
                  if (_isLive && partners.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Pick existing partner', style: FlexTypography.bodySm),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: partners.take(12).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final p = partners[i];
                          final selected = _partnerId == p.id;
                          return ChoiceChip(
                            label: Text(p.name, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (_) => _selectPartner(p),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Terms', style: FlexTypography.bodySm),
                            const SizedBox(height: 4),
                            Text(_paymentTerms, style: FlexTypography.labelLg),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Credit Available', style: FlexTypography.bodySm),
                            const SizedBox(height: 4),
                            Text(
                              LkFormatters.formatLkr((_creditLimit - _currentCreditUsed).clamp(0, double.infinity)),
                              style: FlexTypography.codeNum.copyWith(color: FlexColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Line Items (${_lines.length})', style: FlexTypography.headlineMd),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(_loadingCatalog ? 'Loading…' : 'Add Product'),
                  onPressed: _loadingCatalog ? null : _addProduct,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _isLive ? 'Add products from your Odoo catalog.' : 'Add demo product lines.',
                  style: FlexTypography.bodySm,
                ),
              ),
            ..._lines.asMap().entries.map((entry) {
              final idx = entry.key;
              final line = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: FlexCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: FlexColors.surfaceRaisedDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, color: FlexColors.primaryLight, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.productName, style: FlexTypography.labelMd, maxLines: 1),
                            const SizedBox(height: 2),
                            Text(
                              'SKU: ${line.sku} • Qty: ${line.quantity.toInt()} x ${LkFormatters.formatLkr(line.unitPrice)}',
                              style: FlexTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(LkFormatters.formatLkr(line.subtotal), style: FlexTypography.codeNum),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: FlexColors.danger),
                            onPressed: () => _removeLine(idx),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRICE SUMMARY & STATUTORY TAXES (l10n_lk)', style: FlexTypography.labelSm),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Untaxed Subtotal', style: FlexTypography.bodyMd),
                      Text(LkFormatters.formatLkr(_untaxedSubtotal), style: FlexTypography.codeNum),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sri Lanka VAT (18.0%)', style: FlexTypography.bodySm.copyWith(color: FlexColors.textSecondaryDark)),
                      Text(LkFormatters.formatLkr(_vatAmount), style: FlexTypography.codeNum.copyWith(color: FlexColors.textSecondaryDark)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Social Security Contribution (SSCL 2.5%)', style: FlexTypography.bodySm.copyWith(color: FlexColors.textSecondaryDark)),
                      Text(LkFormatters.formatLkr(_ssclAmount), style: FlexTypography.codeNum.copyWith(color: FlexColors.textSecondaryDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount (LKR)', style: FlexTypography.headlineSm),
                      Text(
                        LkFormatters.formatLkr(_totalAmount),
                        style: FlexTypography.headlineMd.copyWith(
                          color: FlexColors.primaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FlexButton(
              label: _submitting ? 'Submitting…' : 'Confirm Order',
              icon: Icons.check_circle_outline,
              variant: FlexButtonVariant.primary,
              height: 48,
              onPressed: _submitting ? null : _confirmOrder,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
