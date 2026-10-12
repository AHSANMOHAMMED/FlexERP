import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/models/stock_picking.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/warehouse_repository.dart';

class StockPickingScreen extends ConsumerWidget {
  const StockPickingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = ref.watch(currentBranchProvider);
    final pickings = ref.watch(stockPickingsProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Picking Execution',
        subtitle: 'Delivery Orders & Shipments',
        currentBranch: currentBranch,
        onSync: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Syncing Stock Pickings with Odoo...')),
          );
          await ref.read(stockPickingsProvider.notifier).syncFromOdoo();
        },
      ),
      body: pickings.isEmpty
          ? Center(
              child: Text('No active picking orders', style: FlexTypography.bodyMd),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: pickings.length,
              itemBuilder: (context, index) {
                final picking = pickings[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _PickingOrderCard(picking: picking),
                );
              },
            ),
    );
  }
}

class _PickingOrderCard extends ConsumerWidget {
  final StockPicking picking;

  const _PickingOrderCard({required this.picking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = picking.state == 'done';

    return FlexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(picking.name, style: FlexTypography.headlineSm),
              FlexBadge(
                text: picking.state.toUpperCase(),
                variant: isDone ? FlexBadgeVariant.success : FlexBadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Partner: ${picking.partnerName} • Source: ${picking.origin}',
            style: FlexTypography.bodySm,
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${picking.completedItems} of ${picking.totalItems} Items Picked (${(picking.progress * 100).toInt()}%)',
                style: FlexTypography.labelSm.copyWith(color: FlexColors.primaryLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: picking.progress,
              backgroundColor: FlexColors.surfaceRaisedDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                picking.canValidate ? FlexColors.success : FlexColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // Line Items Checklist
          Text('Pick Checklist', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          ...picking.lines.map((line) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlexColors.surfaceRaisedDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: line.isFulfilled ? FlexColors.success.withOpacity(0.3) : FlexColors.borderDark,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    line.isFulfilled ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: line.isFulfilled ? FlexColors.success : FlexColors.textDisabledDark,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.productName, style: FlexTypography.labelMd, maxLines: 1),
                        const SizedBox(height: 2),
                        Text(
                          'Loc: ${line.sourceLocation} • Barcode: ${line.barcode}',
                          style: FlexTypography.bodySm.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${line.scannedQty.toInt()} / ${line.expectedQty.toInt()}',
                        style: FlexTypography.codeNum.copyWith(
                          color: line.isFulfilled ? FlexColors.success : FlexColors.textPrimaryDark,
                        ),
                      ),
                      if (!isDone) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: FlexColors.primaryLight, size: 22),
                          onPressed: () {
                            ref
                                .read(stockPickingsProvider.notifier)
                                .incrementScannedQty(picking.id, line.id);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),

          // Validate Delivery Action
          if (!isDone)
            FlexButton(
              label: 'Validate Delivery (button_validate)',
              icon: Icons.verified,
              variant: picking.canValidate ? FlexButtonVariant.primary : FlexButtonVariant.secondary,
              height: 42,
              onPressed: picking.canValidate
                  ? () {
                      ref.read(stockPickingsProvider.notifier).validatePicking(picking.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: FlexColors.success,
                          content: Text('${picking.name} successfully validated and shipped!'),
                        ),
                      );
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please scan and fulfill all required quantities first.'),
                        ),
                      );
                    },
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FlexColors.successBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, color: FlexColors.success, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Order Fully Picked & Validated',
                    style: FlexTypography.labelSm.copyWith(color: FlexColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
