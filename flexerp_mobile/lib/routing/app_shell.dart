import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/flex_colors.dart';
import '../core/widgets/flex_bottom_nav.dart';
import '../data/models/auth_user.dart';
import '../data/models/vendor_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/vendor_repository.dart';

// Screens
import '../features/super_admin/admin_hub_screen.dart';
import '../features/super_admin/vendor_management_screen.dart';
import '../features/executive/executive_hub_screen.dart';
import '../features/sales/pipeline_kanban_screen.dart';
import '../features/sales/quotation_builder_screen.dart';
import '../features/sales/customer_directory_screen.dart';
import '../features/warehouse/operations_hub_screen.dart';
import '../features/warehouse/barcode_scanner_screen.dart';
import '../features/warehouse/stock_picking_screen.dart';
import '../features/warehouse/stock_search_screen.dart';
import '../features/warehouse/vendor_inventory_management_screen.dart';
import '../features/accounting/invoices_hub_screen.dart';
import '../features/accounting/vendor_bills_screen.dart';
import '../features/accounting/finance_hub_screen.dart';
import '../features/pos/pos_register_screen.dart';
import '../features/pos/pos_orders_screen.dart';
import '../features/pos/pos_closeout_screen.dart';
import '../features/hr/attendance_kiosk_screen.dart';
import '../features/hr/time_off_screen.dart';
import '../features/hr/employee_directory_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/website/shop_catalog_screen.dart';
import '../features/vendor_admin/vendor_admin_hub_screen.dart';
import '../features/vendor_admin/vendor_staff_screen.dart';
import '../features/purchase/purchase_orders_screen.dart';
import '../features/admin/approvals_screen.dart';
import '../core/offline/offline_queue.dart';
import '../core/live/live_sync.dart';

class _ShellTab {
  final FlexNavItem navItem;
  final Widget screen;

  const _ShellTab({required this.navItem, required this.screen});
}

class AppShell extends ConsumerStatefulWidget {
  final VoidCallback onLogout;

  const AppShell({super.key, required this.onLogout});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(offlineQueueProvider.notifier).flush();
      ref.read(liveSyncProvider.notifier).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sync = ref.read(liveSyncProvider.notifier);
    final foreground = state == AppLifecycleState.resumed;
    sync.setForeground(foreground);
    if (foreground) {
      // Replay queued POS/payments after connectivity returns.
      ref.read(offlineQueueProvider.notifier).flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // LiveSyncNotifier cancels its timer via ref.onDispose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final role = user?.role ?? UserRole.superAdmin;
    final features = ref.watch(currentVendorFeaturesProvider);

    // Build role & feature scoped tab set
    final tabs = _getTabsForRole(role, features);

    // Safeguard index if active tabs change dynamically
    if (_currentTabIndex >= tabs.length) {
      _currentTabIndex = 0;
    }

    final screens = tabs.map((t) => t.screen).toList();
    final navItems = tabs.map((t) => t.navItem).toList();

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      body: IndexedStack(
        index: _currentTabIndex,
        children: screens,
      ),
      bottomNavigationBar: FlexBottomNav(
        role: role,
        customItems: navItems,
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() => _currentTabIndex = index);
        },
      ),
    );
  }

  List<_ShellTab> _getTabsForRole(UserRole role, VendorFeatures features) {
    switch (role) {
      case UserRole.superAdmin:
        return [
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Executive',
            ),
            screen: ExecutiveHubScreen(
              onNavigateToBarcode: () => _openBarcodeScanner(context),
              onNavigateToCreateOrder: () => _openNewQuotation(context),
              onNavigateToStock: features.enableInventory
                  ? () => _pushScreen(context, const VendorInventoryManagementScreen())
                  : null,
              onNavigateToApprovals: () => setState(() => _currentTabIndex = 1),
            ),
          ),
          const _ShellTab(
            navItem: FlexNavItem(
              icon: Icons.admin_panel_settings_outlined,
              activeIcon: Icons.admin_panel_settings,
              label: 'Admin Hub',
            ),
            screen: AdminHubScreen(),
          ),
          const _ShellTab(
            navItem: FlexNavItem(
              icon: Icons.business_outlined,
              activeIcon: Icons.business,
              label: 'Tenants',
            ),
            screen: VendorManagementScreen(),
          ),
          if (features.enableInventory)
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2,
                label: 'Live Stock',
              ),
              screen: VendorInventoryManagementScreen(),
            ),
          if (features.enableWebsite)
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: 'Shop',
              ),
              screen: ShopCatalogScreen(),
            ),
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        ];

      case UserRole.vendorAdmin:
        // Keep bottom nav lean: Hub, Staff, primary modules; secondary via hub push.
        var nextIndex = 2;
        final stockIndex = features.enableInventory ? nextIndex++ : -1;
        final posIndex = features.enablePos ? nextIndex++ : -1;
        if (features.enableSales) nextIndex++;
        if (features.enableCrm) nextIndex++;
        if (features.enableInvoicing) nextIndex++;
        final purchaseIndex = features.enablePurchase ? nextIndex++ : -1;
        final tabs = <_ShellTab>[
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.store_outlined,
              activeIcon: Icons.store,
              label: 'My Vendor',
            ),
            screen: VendorAdminHubScreen(
              onOpenStaff: () => setState(() => _currentTabIndex = 1),
              onOpenStock: stockIndex >= 0
                  ? () => setState(() => _currentTabIndex = stockIndex)
                  : null,
              onOpenPos:
                  posIndex >= 0 ? () => setState(() => _currentTabIndex = posIndex) : null,
              onOpenPurchase: purchaseIndex >= 0
                  ? () => setState(() => _currentTabIndex = purchaseIndex)
                  : null,
              onOpenSales: features.enableSales
                  ? () => _openNewQuotation(context)
                  : null,
              onOpenCrm: features.enableCrm
                  ? () => _pushScreen(
                        context,
                        PipelineKanbanScreen(
                          onNewQuotation: features.enableSales
                              ? () => _openNewQuotation(context)
                              : null,
                        ),
                      )
                  : null,
              onOpenWarehouse: features.enableWarehouse
                  ? () => _pushScreen(context, const OperationsHubScreen())
                  : null,
              onOpenFinance: (features.enablePayments || features.enableInvoicing)
                  ? () => _pushScreen(context, const FinanceHubScreen())
                  : null,
              onOpenBills: features.enableInvoicing
                  ? () => _pushScreen(context, const VendorBillsScreen())
                  : null,
              onOpenHr: features.enableHr
                  ? () => _pushScreen(context, const AttendanceKioskScreen())
                  : null,
              onOpenShop: features.enableWebsite
                  ? () => _pushScreen(context, const ShopCatalogScreen())
                  : null,
              onOpenCustomers: features.hasAnyCommerce
                  ? () => _pushScreen(context, const CustomerDirectoryScreen())
                  : null,
              onOpenPosOrders: features.enablePos
                  ? () => _pushScreen(context, const PosOrdersScreen())
                  : null,
            ),
          ),
          const _ShellTab(
            navItem: FlexNavItem(
              icon: Icons.groups_outlined,
              activeIcon: Icons.groups,
              label: 'Staff',
            ),
            screen: VendorStaffScreen(),
          ),
        ];
        if (features.enableInventory) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2,
                label: 'Stock',
              ),
              screen: VendorInventoryManagementScreen(),
            ),
          );
        }
        if (features.enablePos) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.point_of_sale,
                activeIcon: Icons.point_of_sale,
                label: 'POS',
              ),
              screen: PosRegisterScreen(),
            ),
          );
        }
        if (features.enableSales) {
          tabs.add(
            _ShellTab(
              navItem: const FlexNavItem(
                icon: Icons.request_quote_outlined,
                activeIcon: Icons.request_quote,
                label: 'Sales',
              ),
              screen: QuotationBuilderScreen(
                onOrderConfirmed: () {},
              ),
            ),
          );
        }
        if (features.enableCrm) {
          tabs.add(
            _ShellTab(
              navItem: const FlexNavItem(
                icon: Icons.view_kanban_outlined,
                activeIcon: Icons.view_kanban,
                label: 'CRM',
              ),
              screen: PipelineKanbanScreen(
                onNewQuotation: features.enableSales
                    ? () => _openNewQuotation(context)
                    : null,
              ),
            ),
          );
        }
        if (features.enableInvoicing) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Invoices',
              ),
              screen: InvoicesHubScreen(),
            ),
          );
        }
        if (features.enablePurchase) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Purchase',
              ),
              screen: PurchaseOrdersScreen(),
            ),
          );
        }
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        );
        return tabs;

      case UserRole.posCashier:
        final tabs = <_ShellTab>[];
        if (features.enablePos) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.point_of_sale,
                activeIcon: Icons.point_of_sale,
                label: 'Register',
              ),
              screen: PosRegisterScreen(),
            ),
          );
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.receipt_outlined,
                activeIcon: Icons.receipt,
                label: 'Orders',
              ),
              screen: PosOrdersScreen(),
            ),
          );
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.lock_clock_outlined,
                activeIcon: Icons.lock_clock,
                label: 'Shift Close',
              ),
              screen: PosCloseoutScreen(),
            ),
          );
        }
        if (features.enableInventory) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.search,
                activeIcon: Icons.search,
                label: 'Stock Lookup',
              ),
              screen: StockSearchScreen(),
            ),
          );
        }
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        );
        return tabs;

      case UserRole.warehouseOp:
        final tabs = <_ShellTab>[
          const _ShellTab(
            navItem: FlexNavItem(
              icon: Icons.hub_outlined,
              activeIcon: Icons.hub,
              label: 'Ops Hub',
            ),
            screen: OperationsHubScreen(),
          ),
        ];
        if (features.enableInventory) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.qr_code_scanner,
                activeIcon: Icons.qr_code_scanner,
                label: 'Barcode',
              ),
              screen: BarcodeScannerScreen(),
            ),
          );
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.inventory_outlined,
                activeIcon: Icons.inventory,
                label: 'Live Stock',
              ),
              screen: VendorInventoryManagementScreen(),
            ),
          );
        }
        if (features.enableWarehouse) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.local_shipping_outlined,
                activeIcon: Icons.local_shipping,
                label: 'Pickings',
              ),
              screen: StockPickingScreen(),
            ),
          );
        }
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        );
        return tabs;

      case UserRole.salesRep:
        final tabs = <_ShellTab>[];
        if (features.enableExecutive) {
          tabs.add(
            _ShellTab(
              navItem: const FlexNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
              ),
              screen: ExecutiveHubScreen(
                onNavigateToBarcode: features.enableInventory
                    ? () => _openBarcodeScanner(context)
                    : null,
                onNavigateToCreateOrder: features.enableSales
                    ? () => _openNewQuotation(context)
                    : null,
                onNavigateToStock: features.enableInventory
                    ? () => _pushScreen(context, const StockSearchScreen())
                    : null,
                onNavigateToApprovals: () => _openApprovals(context),
              ),
            ),
          );
        }
        if (features.enableCrm) {
          tabs.add(
            _ShellTab(
              navItem: const FlexNavItem(
                icon: Icons.view_kanban_outlined,
                activeIcon: Icons.view_kanban,
                label: 'Pipeline',
              ),
              screen: PipelineKanbanScreen(
                onNewQuotation: features.enableSales
                    ? () => _openNewQuotation(context)
                    : null,
              ),
            ),
          );
        }
        if (features.enableSales) {
          tabs.add(
            _ShellTab(
              navItem: const FlexNavItem(
                icon: Icons.request_quote_outlined,
                activeIcon: Icons.request_quote,
                label: 'Quotations',
              ),
              screen: QuotationBuilderScreen(onOrderConfirmed: () {}),
            ),
          );
        }
        if (features.hasAnyCommerce) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Customers',
              ),
              screen: CustomerDirectoryScreen(),
            ),
          );
        }
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        );
        return tabs;

      case UserRole.accountant:
        final tabs = <_ShellTab>[];
        if (features.enableExecutive) {
          tabs.add(
            _ShellTab(
              navItem: const FlexNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
              ),
              screen: ExecutiveHubScreen(
                onNavigateToApprovals: () => _openApprovals(context),
                onNavigateToCreateOrder: features.enableSales
                    ? () => _openNewQuotation(context)
                    : null,
                onNavigateToBarcode: features.enableInventory
                    ? () => _openBarcodeScanner(context)
                    : null,
                onNavigateToStock: features.enableInventory
                    ? () => _pushScreen(context, const StockSearchScreen())
                    : null,
              ),
            ),
          );
        }
        if (features.enableInvoicing) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Invoices',
              ),
              screen: InvoicesHubScreen(),
            ),
          );
        }
        if (features.enableInvoicing) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.payments_outlined,
                activeIcon: Icons.payments,
                label: 'Bills',
              ),
              screen: VendorBillsScreen(),
            ),
          );
        }
        if (features.enablePayments) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.account_balance_outlined,
                activeIcon: Icons.account_balance,
                label: 'Ledger',
              ),
              screen: FinanceHubScreen(),
            ),
          );
        }
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        );
        return tabs;

      case UserRole.employee:
        final tabs = <_ShellTab>[];
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
            ),
            screen: ExecutiveHubScreen(
              onNavigateToApprovals: () => _openApprovals(context),
              onNavigateToBarcode: features.enableInventory
                  ? () => _openBarcodeScanner(context)
                  : null,
              onNavigateToStock: features.enableInventory
                  ? () => _pushScreen(context, const StockSearchScreen())
                  : null,
            ),
          ),
        );
        if (features.enableHr) {
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.location_on_outlined,
                activeIcon: Icons.location_on,
                label: 'Attendance',
              ),
              screen: AttendanceKioskScreen(),
            ),
          );
          tabs.add(
            const _ShellTab(
              navItem: FlexNavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Time Off',
              ),
              screen: TimeOffScreen(),
            ),
          );
        }
        tabs.add(
          const _ShellTab(
            navItem: FlexNavItem(
              icon: Icons.contacts_outlined,
              activeIcon: Icons.contacts,
              label: 'Directory',
            ),
            screen: EmployeeDirectoryScreen(),
          ),
        );
        tabs.add(
          _ShellTab(
            navItem: const FlexNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
            ),
            screen: ProfileScreen(onLogout: widget.onLogout),
          ),
        );
        return tabs;
    }
  }

  void _openNewQuotation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuotationBuilderScreen(
          onOrderConfirmed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openApprovals(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ApprovalsScreen()),
    );
  }

  void _openBarcodeScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  void _pushScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
