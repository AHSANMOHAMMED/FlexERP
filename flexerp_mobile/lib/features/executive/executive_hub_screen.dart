import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/executive_repository.dart';

class ExecutiveHubScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToBarcode;
  final VoidCallback? onNavigateToCreateOrder;
  final VoidCallback? onNavigateToStock;
  final VoidCallback? onNavigateToApprovals;

  const ExecutiveHubScreen({
    super.key,
    this.onNavigateToBarcode,
    this.onNavigateToCreateOrder,
    this.onNavigateToStock,
    this.onNavigateToApprovals,
  });

  @override
  ConsumerState<ExecutiveHubScreen> createState() => _ExecutiveHubScreenState();
}

class _ExecutiveHubScreenState extends ConsumerState<ExecutiveHubScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(executiveKpisProvider.notifier).syncFromServer());
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final pendingApprovals = ref.watch(pendingApprovalsProvider);
    final salesOrders = ref.watch(saleOrdersProvider);
    final kpis = ref.watch(executiveKpisProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Executive Master Hub',
        subtitle: currentBranch.name,
        currentBranch: currentBranch,
        onBranchChanged: (branch) {
          ref.read(currentBranchProvider.notifier).setBranch(branch);
        },
        onSync: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refreshing Executive KPIs & Orders from Odoo...')),
          );
          await ref.read(executiveKpisProvider.notifier).syncFromServer();
          await ref.read(saleOrdersProvider.notifier).syncFromOdoo();
          await ref.read(crmLeadsProvider.notifier).syncFromOdoo();
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Financial Carousel
            SizedBox(
              height: 154,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _KpiCard(
                    title: "TODAY'S REVENUE",
                    value: LkFormatters.formatLkr(kpis.todayRevenue),
                    delta: '${kpis.todayOrders} orders today',
                    deltaPositive: true,
                    icon: Icons.trending_up,
                    badgeText: 'LKR Gross',
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'UNPAID INVOICES',
                    value: '${kpis.unpaidInvoices}',
                    delta: 'Open AR documents',
                    deltaPositive: kpis.unpaidInvoices == 0,
                    icon: Icons.account_balance,
                    badgeText: 'AR',
                  ),
                  const SizedBox(width: 12),
                  _KpiCard(
                    title: 'PENDING SHIPMENTS',
                    value: '${kpis.pendingShipments} Orders',
                    delta: kpis.vendorId.isNotEmpty ? 'Slot ${kpis.vendorId}' : 'Warehouse',
                    deltaPositive: false,
                    icon: Icons.local_shipping,
                    badgeText: 'Outbound',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Quick Action Grid
            Text('Quick Operations', style: FlexTypography.headlineMd),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _ActionTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan Barcode',
                  subtitle: 'Stock Inquiry & Aisle',
                  onTap: widget.onNavigateToBarcode,
                ),
                _ActionTile(
                  icon: Icons.add_shopping_cart,
                  title: 'Create Order',
                  subtitle: 'Quotations & VAT/SSCL',
                  onTap: widget.onNavigateToCreateOrder,
                ),
                _ActionTile(
                  icon: Icons.warehouse,
                  title: 'Stock Levels',
                  subtitle: 'Multi-Branch Inventory',
                  onTap: widget.onNavigateToStock,
                ),
                _ActionTile(
                  icon: Icons.approval,
                  title: 'Approvals (${pendingApprovals.length})',
                  subtitle: 'Credit & PO Authorizations',
                  badgeCount: pendingApprovals.length,
                  onTap: widget.onNavigateToApprovals,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 3: Approvals Center Preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Urgent Authorizations', style: FlexTypography.headlineMd),
                if (pendingApprovals.isNotEmpty)
                  FlexBadge(
                    text: '${pendingApprovals.length} NEED SIGN-OFF',
                    variant: FlexBadgeVariant.warning,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (pendingApprovals.isEmpty)
              FlexCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('All pending requests are approved', style: FlexTypography.bodyMd),
                  ),
                ),
              )
            else
              ...pendingApprovals.take(2).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: FlexCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FlexBadge(text: item.type, variant: FlexBadgeVariant.warning),
                            Text(
                              LkFormatters.formatLkr(item.amount),
                              style: FlexTypography.codeNum.copyWith(
                                color: FlexColors.primaryLight,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(item.customerOrVendor, style: FlexTypography.labelLg),
                        const SizedBox(height: 4),
                        Text(item.reason, style: FlexTypography.bodySm),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FlexButton(
                                label: 'One-Tap Approve',
                                icon: Icons.check,
                                height: 36,
                                onPressed: () {
                                  ref.read(pendingApprovalsProvider.notifier).approve(item.id);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FlexButton(
                                label: 'Reject',
                                icon: Icons.close,
                                variant: FlexButtonVariant.danger,
                                height: 36,
                                onPressed: () {
                                  ref.read(pendingApprovalsProvider.notifier).reject(item.id);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),

            // Section 4: Recent Confirmed Orders
            Text('Recent Active Orders', style: FlexTypography.headlineMd),
            const SizedBox(height: 12),
            ...salesOrders.take(3).map((order) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: FlexCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: FlexColors.primaryLight, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.name, style: FlexTypography.labelLg),
                            Text(order.partnerName, style: FlexTypography.bodySm),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            LkFormatters.formatLkr(order.totalAmount),
                            style: FlexTypography.codeNum,
                          ),
                          const SizedBox(height: 4),
                          FlexBadge(
                            text: order.state.toUpperCase(),
                            variant: order.state == 'sale' ? FlexBadgeVariant.success : FlexBadgeVariant.neutral,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String delta;
  final bool deltaPositive;
  final IconData icon;
  final String badgeText;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.deltaPositive,
    required this.icon,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: FlexCard(
        backgroundColor: FlexColors.surfaceRaisedDark,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: FlexTypography.labelSm),
                FlexBadge(text: badgeText, variant: FlexBadgeVariant.info),
              ],
            ),
            Text(value, style: FlexTypography.headlineLg.copyWith(letterSpacing: -0.5)),
            Row(
              children: [
                Icon(
                  deltaPositive ? Icons.arrow_upward : Icons.info_outline,
                  color: deltaPositive ? FlexColors.success : FlexColors.warning,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  delta,
                  style: FlexTypography.bodySm.copyWith(
                    color: deltaPositive ? FlexColors.success : FlexColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badgeCount;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlexCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: FlexColors.primaryLight, size: 24),
              if (badgeCount != null && badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: FlexColors.warning,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: FlexTypography.labelLg, maxLines: 1),
          Text(subtitle, style: FlexTypography.bodySm, maxLines: 1),
        ],
      ),
    );
  }
}
