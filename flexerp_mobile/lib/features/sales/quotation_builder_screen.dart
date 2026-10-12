import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/sale_order.dart';
import '../../data/repositories/sales_repository.dart';

class QuotationBuilderScreen extends ConsumerStatefulWidget {
  final VoidCallback onOrderConfirmed;

  const QuotationBuilderScreen({super.key, required this.onOrderConfirmed});

  @override
  ConsumerState<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends ConsumerState<QuotationBuilderScreen> {
  final _customerController = TextEditingController(text: 'Lanka Industrial Supplies (Pvt) Ltd');
  final _phoneController = TextEditingController(text: '+94 11 268 9000');
  String _paymentTerms = '30 Days Net';
  double _creditLimit = 1500000.0;
  double _currentCreditUsed = 620000.0;
  double _globalDiscountPercent = 5.0;

  List<OrderLine> _lines = [
    const OrderLine(
      productId: 101,
      productName: 'Heavy Duty Industrial Pallet 1200x1000',
      sku: 'PLT-1200-HD',
      quantity: 50,
      unitPrice: 4500.0,
      discountPercent: 0.0,
    ),
    const OrderLine(
      productId: 102,
      productName: 'Hydraulic Hand Pallet Truck 3.0T',
      sku: 'HPT-3000-NY',
      quantity: 2,
      unitPrice: 185000.0,
      discountPercent: 0.0,
    ),
  ];

  double get _untaxedSubtotal {
    double sum = _lines.fold(0.0, (prev, line) => prev + line.subtotal);
    return sum * (1 - (_globalDiscountPercent / 100));
  }

  double get _vatAmount => _untaxedSubtotal * 0.18;
  double get _ssclAmount => _untaxedSubtotal * 0.025;
  double get _totalAmount => _untaxedSubtotal + _vatAmount + _ssclAmount;

  void _addProduct() {
    setState(() {
      _lines.add(
        const OrderLine(
          productId: 103,
          productName: 'Wireless Barcode Scanner 2D Bluetooth',
          sku: 'SCN-2D-BT',
          quantity: 5,
          unitPrice: 38500.0,
          discountPercent: 0.0,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  void _confirmOrder() {
    final newOrder = SaleOrder(
      id: DateTime.now().millisecondsSinceEpoch,
      name: 'SO/2026/0014${_lines.length + 5}',
      partnerName: _customerController.text,
      partnerPhone: _phoneController.text,
      paymentTerms: _paymentTerms,
      creditLimit: _creditLimit,
      currentCreditUsed: _currentCreditUsed,
      lines: List.from(_lines),
      globalDiscountPercent: _globalDiscountPercent,
      state: 'sale', // confirmed!
      dateOrder: DateTime.now(),
    );

    ref.read(saleOrdersProvider.notifier).addOrder(newOrder);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FlexColors.success,
        content: Text('Order ${newOrder.name} confirmed and submitted to ERP!'),
      ),
    );
    widget.onOrderConfirmed();
  }

  @override
  Widget build(BuildContext context) {
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
            // Section 1: Customer Details & Credit
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
                              LkFormatters.formatLkr(_creditLimit - _currentCreditUsed),
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

            // Section 2: Line Items Checklist
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Line Items (${_lines.length})', style: FlexTypography.headlineMd),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Product'),
                  onPressed: _addProduct,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                            Text('SKU: ${line.sku} • Qty: ${line.quantity.toInt()} x ${LkFormatters.formatLkr(line.unitPrice)}',
                                style: FlexTypography.bodySm),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            LkFormatters.formatLkr(line.subtotal),
                            style: FlexTypography.codeNum,
                          ),
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

            // Section 3: Sri Lankan Tax Calculation & Totals
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

            // Bottom Actions
            FlexButton(
              label: 'Confirm Order (action_confirm)',
              icon: Icons.check_circle_outline,
              variant: FlexButtonVariant.primary,
              height: 48,
              onPressed: _confirmOrder,
            ),
            const SizedBox(height: 8),
            FlexButton(
              label: 'Share PDF via WhatsApp / Email',
              icon: Icons.share,
              variant: FlexButtonVariant.secondary,
              height: 44,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating Sri Lanka Tax Invoice PDF...')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
