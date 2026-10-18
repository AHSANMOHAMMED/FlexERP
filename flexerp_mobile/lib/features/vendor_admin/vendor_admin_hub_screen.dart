import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/odoo_client.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/executive_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/vendor_repository.dart';
import '../sales/sale_order_detail_sheet.dart';
import 'vendor_staff_screen.dart';

/// Vendor-slot dashboard — distinct from platform Super Admin ops console.
class VendorAdminHubScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenStaff;
  final VoidCallback? onOpenStock;
  final VoidCallback? onOpenPos;
  final VoidCallback? onOpenPurchase;
  final VoidCallback? onOpenSales;
  final VoidCallback? onOpenCrm;
  final VoidCallback? onOpenWarehouse;
  final VoidCallback? onOpenFinance;
  final VoidCallback? onOpenBills;
  final VoidCallback? onOpenHr;
  final VoidCallback? onOpenShop;
  final VoidCallback? onOpenCustomers;
  final VoidCallback? onOpenPosOrders;

  const VendorAdminHubScreen({
    super.key,
    this.onOpenStaff,
    this.onOpenStock,
    this.onOpenPos,
    this.onOpenPurchase,
    this.onOpenSales,
    this.onOpenCrm,
    this.onOpenWarehouse,
    this.onOpenFinance,
    this.onOpenBills,
    this.onOpenHr,
    this.onOpenShop,
    this.onOpenCustomers,
    this.onOpenPosOrders,
  });

  @override
  ConsumerState<VendorAdminHubScreen> createState() => _VendorAdminHubScreenState();
}

class _VendorAdminHubScreenState extends ConsumerState<VendorAdminHubScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(executiveKpisProvider.notifier).syncFromServer();
        await ref.read(saleOrdersProvider.notifier).syncFromOdoo();
      } catch (e) {
        debugPrint('FlexERP: vendor admin hub sync failed: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${describeError(e)}'), backgroundColor: FlexColors.danger),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final branch = ref.watch(currentBranchProvider);
    final features = ref.watch(currentVendorFeaturesProvider);
    final kpis = ref.watch(executiveKpisProvider);
    final orders = ref.watch(saleOrdersProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Vendor Admin',
        subtitle: user?.companyName ?? 'Your vendor slot',
        currentBranch: branch,
        onSync: () async {
          await ref.read(executiveKpisProvider.notifier).syncFromServer();
          await ref.read(saleOrdersProvider.notifier).syncFromOdoo();
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FlexCard(
            backgroundColor: FlexColors.surfaceRaisedDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.store, color: FlexColors.primaryLight, size: 20),
                    const SizedBox(width: 8),
                    Text('YOUR VENDOR SLOT', style: FlexTypography.labelSm),
                    const Spacer(),
                    FlexBadge(text: user?.vendorId ?? 'SLOT', variant: FlexBadgeVariant.info),
                  ],
                ),
                const SizedBox(height: 10),
                Text(user?.companyName ?? 'Vendor', style: FlexTypography.headlineMd),
                const SizedBox(height: 4),
                Text(
                  'Manage staff, stock, and sales for this company only. '
                  'Platform ops and other vendors are not visible here.',
                  style: FlexTypography.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Local KPIs', style: FlexTypography.headlineMd),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  label: "Today's revenue",
                  value: LkFormatters.formatLkr(kpis.todayRevenue),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniKpi(
                  label: 'Orders today',
                  value: '${kpis.todayOrders}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  label: 'Unpaid invoices',
                  value: '${kpis.unpaidInvoices}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniKpi(
                  label: 'Pending ship',
                  value: '${kpis.pendingShipments}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Quick actions', style: FlexTypography.headlineMd),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.groups,
            title: 'Staff management',
            subtitle: 'Invite cashiers / admins for this slot',
            onTap: widget.onOpenStaff ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VendorStaffScreen()),
                  );
                },
          ),
          if (features.enableInventory)
            _ActionTile(
              icon: Icons.inventory_2,
              title: 'Live stock',
              subtitle: 'Adjust and review inventory',
              onTap: widget.onOpenStock,
            ),
          if (features.enablePos)
            _ActionTile(
              icon: Icons.point_of_sale,
              title: 'POS register',
              subtitle: 'Open cashier register',
              onTap: widget.onOpenPos,
            ),
          if (features.enablePos)
            _ActionTile(
              icon: Icons.receipt_long,
              title: 'POS orders',
              subtitle: 'Past register tickets',
              onTap: widget.onOpenPosOrders,
            ),
          if (features.enableSales)
            _ActionTile(
              icon: Icons.request_quote,
              title: 'New quotation',
              subtitle: 'Create sale order in Odoo',
              onTap: widget.onOpenSales,
            ),
          if (features.hasAnyCommerce)
            _ActionTile(
              icon: Icons.people,
              title: 'Customers',
              subtitle: 'Partner directory',
              onTap: widget.onOpenCustomers,
            ),
          if (features.enableCrm)
            _ActionTile(
              icon: Icons.view_kanban,
              title: 'CRM pipeline',
              subtitle: 'Leads and stages',
              onTap: widget.onOpenCrm,
            ),
          if (features.enableWarehouse)
            _ActionTile(
              icon: Icons.local_shipping,
              title: 'Warehouse ops',
              subtitle: 'Pickings and transfers',
              onTap: widget.onOpenWarehouse,
            ),
          if (features.enablePurchase)
            _ActionTile(
              icon: Icons.shopping_bag_outlined,
              title: 'Purchase orders',
              subtitle: 'Vendor POs (independent module)',
              onTap: widget.onOpenPurchase,
            ),
          if (features.enableInvoicing)
            _ActionTile(
              icon: Icons.payments_outlined,
              title: 'Vendor bills',
              subtitle: 'Supplier invoices / AP',
              onTap: widget.onOpenBills,
            ),
          if (features.enablePayments || features.enableInvoicing)
            _ActionTile(
              icon: Icons.account_balance,
              title: 'Finance hub',
              subtitle: 'AR / AP / journals snapshot',
              onTap: widget.onOpenFinance,
            ),
          if (features.enableHr)
            _ActionTile(
              icon: Icons.badge_outlined,
              title: 'HR attendance',
              subtitle: 'Check-in and time tracking',
              onTap: widget.onOpenHr,
            ),
          if (features.enableWebsite)
            _ActionTile(
              icon: Icons.storefront,
              title: 'Website shop',
              subtitle: 'Catalog / cart (website feature)',
              onTap: widget.onOpenShop,
            ),
          const SizedBox(height: 20),
          Text('Enabled modules', style: FlexTypography.headlineMd),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeatureChip('POS', features.enablePos),
              _FeatureChip('Inventory', features.enableInventory),
              _FeatureChip('Sales', features.enableSales),
              _FeatureChip('CRM', features.enableCrm),
              _FeatureChip('Purchase', features.enablePurchase),
              _FeatureChip('Invoicing', features.enableInvoicing),
              _FeatureChip('Warehouse', features.enableWarehouse),
              _FeatureChip('Website', features.enableWebsite),
              _FeatureChip('HR', features.enableHr),
            ],
          ),
          if (features.enableSales) ...[
            const SizedBox(height: 20),
            Text('Recent sales (${orders.length})', style: FlexTypography.headlineMd),
            const SizedBox(height: 10),
            ...orders.take(8).map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FlexCard(
                    onTap: () => showSaleOrderDetail(context, ref, o),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.name, style: FlexTypography.labelLg),
                              Text(o.partnerName, style: FlexTypography.bodySm),
                            ],
                          ),
                        ),
                        FlexBadge(text: o.state.toUpperCase(), variant: FlexBadgeVariant.info),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;

  const _MiniKpi({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return FlexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FlexTypography.labelSm),
          const SizedBox(height: 6),
          Text(value, style: FlexTypography.headlineSm),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FlexCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: FlexColors.primaryLight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlexTypography.labelLg),
                  Text(subtitle, style: FlexTypography.bodySm),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FlexColors.textDisabledDark),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final bool enabled;

  const _FeatureChip(this.label, this.enabled);

  @override
  Widget build(BuildContext context) {
    return FlexBadge(
      text: label,
      variant: enabled ? FlexBadgeVariant.success : FlexBadgeVariant.warning,
    );
  }
}
