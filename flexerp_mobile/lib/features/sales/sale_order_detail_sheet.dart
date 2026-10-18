import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/sale_order.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/sales_repository.dart';

Future<void> showSaleOrderDetail(BuildContext context, WidgetRef ref, SaleOrder order) async {
  final user = ref.read(currentUserProvider);
  final api = ref.read(flexerpApiProvider);
  Map<String, dynamic>? detail;
  String? error;

  if (user != null && !user.isDemo && api != null && order.id > 0) {
    try {
      detail = await api.salesOrderDetail(order.id);
    } catch (e) {
      error = e.toString();
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: FlexColors.surfaceDark,
    isScrollControlled: true,
    builder: (ctx) {
      final name = detail?['name']?.toString() ?? order.name;
      final state = detail?['state']?.toString() ?? order.state;
      final partner = detail?['partner_name']?.toString() ?? order.partnerName;
      final total = (detail?['amount_total'] as num?)?.toDouble() ?? order.totalAmount;
      final lines = (detail?['lines'] as List?) ?? const [];
      final canConfirm = state == 'draft' || state == 'sent';

      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: FlexTypography.headlineMd),
            const SizedBox(height: 6),
            Text('$partner · ${state.toUpperCase()}', style: FlexTypography.bodySm),
            const SizedBox(height: 8),
            Text(LkFormatters.formatLkr(total), style: FlexTypography.headlineSm.copyWith(color: FlexColors.primaryLight)),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: FlexColors.danger, fontSize: 12)),
            ],
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Lines', style: FlexTypography.labelSm),
              const SizedBox(height: 6),
              ...lines.take(8).map((raw) {
                final line = Map<String, dynamic>.from(raw as Map);
                final qty = line['qty'] ?? line['product_uom_qty'] ?? 1;
                final priceUnit = (line['price_unit'] as num?)?.toDouble();
                final subtotal = (line['price_subtotal'] as num?)?.toDouble() ??
                    (line['price_total'] as num?)?.toDouble();
                final moneyBits = <String>[
                  if (priceUnit != null) '@ ${LkFormatters.formatLkr(priceUnit)}',
                  if (subtotal != null) LkFormatters.formatLkr(subtotal),
                ];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${line['name'] ?? line['product_name'] ?? 'Line'} × $qty'
                    '${moneyBits.isEmpty ? '' : ' · ${moneyBits.join(' · ')}'}',
                    style: FlexTypography.bodySm,
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            if (canConfirm && user != null && !user.isDemo)
              FlexButton(
                label: 'Confirm order',
                icon: Icons.check_circle_outline,
                height: 44,
                onPressed: () async {
                  try {
                    await ref.read(saleOrdersProvider.notifier).confirmOrder(order.id);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name confirmed'), backgroundColor: FlexColors.success),
                    );
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Confirm failed: $e'), backgroundColor: FlexColors.danger),
                    );
                  }
                },
              ),
          ],
        ),
      );
    },
  );
}
