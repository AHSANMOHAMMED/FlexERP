import 'package:flutter/material.dart';
import '../theme/flex_colors.dart';
import '../../data/models/auth_user.dart';

class FlexNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FlexNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class FlexBottomNav extends StatelessWidget {
  final UserRole role;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FlexNavItem>? customItems;

  const FlexBottomNav({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.customItems,
  });

  List<FlexNavItem> _getItemsForRole() {
    switch (role) {
      case UserRole.superAdmin:
        return const [
          FlexNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Executive'),
          FlexNavItem(icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'Admin Hub'),
          FlexNavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Operations'),
          FlexNavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Finance'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
      case UserRole.vendorAdmin:
        return const [
          FlexNavItem(icon: Icons.store_outlined, activeIcon: Icons.store, label: 'My Vendor'),
          FlexNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Staff'),
          FlexNavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Stock'),
          FlexNavItem(icon: Icons.point_of_sale, activeIcon: Icons.point_of_sale, label: 'POS'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
      case UserRole.salesRep:
        return const [
          FlexNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
          FlexNavItem(icon: Icons.view_kanban_outlined, activeIcon: Icons.view_kanban, label: 'Pipeline'),
          FlexNavItem(icon: Icons.request_quote_outlined, activeIcon: Icons.request_quote, label: 'Quotations'),
          FlexNavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Customers'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
      case UserRole.warehouseOp:
        return const [
          FlexNavItem(icon: Icons.hub_outlined, activeIcon: Icons.hub, label: 'Ops Hub'),
          FlexNavItem(icon: Icons.qr_code_scanner, activeIcon: Icons.qr_code_scanner, label: 'Barcode'),
          FlexNavItem(icon: Icons.local_shipping_outlined, activeIcon: Icons.local_shipping, label: 'Pickings'),
          FlexNavItem(icon: Icons.inventory_outlined, activeIcon: Icons.inventory, label: 'Stock Search'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
      case UserRole.accountant:
        return const [
          FlexNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
          FlexNavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Invoices'),
          FlexNavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payments'),
          FlexNavItem(icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance, label: 'Ledger'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
      case UserRole.posCashier:
        return const [
          FlexNavItem(icon: Icons.point_of_sale, activeIcon: Icons.point_of_sale, label: 'Register'),
          FlexNavItem(icon: Icons.receipt_outlined, activeIcon: Icons.receipt, label: 'Orders'),
          FlexNavItem(icon: Icons.lock_clock_outlined, activeIcon: Icons.lock_clock, label: 'Shift Close'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
      case UserRole.employee:
        return const [
          FlexNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          FlexNavItem(icon: Icons.location_on_outlined, activeIcon: Icons.location_on, label: 'Attendance'),
          FlexNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Time Off'),
          FlexNavItem(icon: Icons.contacts_outlined, activeIcon: Icons.contacts, label: 'Directory'),
          FlexNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = customItems ?? _getItemsForRole();

    return Container(
      decoration: BoxDecoration(
        color: FlexColors.surfaceDark,
        border: const Border(
          top: BorderSide(color: FlexColors.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 12 : 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FlexColors.primary.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: FlexColors.primary.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected
                                ? FlexColors.primaryLight
                                : FlexColors.textSecondaryDark,
                            size: 22,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? FlexColors.primaryLight
                                  : FlexColors.textSecondaryDark,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
