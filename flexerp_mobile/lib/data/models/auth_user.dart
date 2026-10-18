import 'vendor_model.dart';

enum UserRole {
  superAdmin,
  vendorAdmin,
  salesRep,
  warehouseOp,
  accountant,
  posCashier,
  employee,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Platform Super Admin';
      case UserRole.vendorAdmin:
        return 'Vendor Admin';
      case UserRole.salesRep:
        return 'Sales Representative';
      case UserRole.warehouseOp:
        return 'Warehouse Operator';
      case UserRole.accountant:
        return 'Accountant / Cashier';
      case UserRole.posCashier:
        return 'POS Cashier / Staff';
      case UserRole.employee:
        return 'General Employee (HR)';
    }
  }

  String get odooGroupKey {
    switch (this) {
      case UserRole.superAdmin:
        return 'flexerp_vendor_rbac.group_platform_super_admin';
      case UserRole.vendorAdmin:
        return 'flexerp_vendor_rbac.group_vendor_admin';
      case UserRole.salesRep:
        return 'sales_team.group_sale_salesman';
      case UserRole.warehouseOp:
        return 'stock.group_stock_user';
      case UserRole.accountant:
        return 'account.group_account_invoice';
      case UserRole.posCashier:
        return 'flexerp_vendor_rbac.group_vendor_cashier';
      case UserRole.employee:
        return 'base.group_user';
    }
  }
}

class AuthUser {
  final int uid;
  final String name;
  final String email;
  final UserRole role;
  final String serverUrl;
  final String database;
  final int companyId;
  final String companyName;
  final List<String> groups;
  final bool isDemo;
  final String? sessionId;
  final String vendorId;
  final VendorFeatures features;
  final bool enforceHttps;
  /// Company currency from bootstrap (Sri Lanka tenants: LKR).
  final String currencyName;
  final String currencySymbol;

  const AuthUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.serverUrl,
    required this.database,
    required this.companyId,
    required this.companyName,
    required this.groups,
    this.isDemo = false,
    this.sessionId,
    this.vendorId = 'VND-001',
    this.features = const VendorFeatures(),
    this.enforceHttps = false,
    this.currencyName = 'LKR',
    this.currencySymbol = 'Rs.',
  });

  AuthUser copyWith({
    int? uid,
    String? name,
    String? email,
    UserRole? role,
    String? serverUrl,
    String? database,
    int? companyId,
    String? companyName,
    List<String>? groups,
    bool? isDemo,
    String? sessionId,
    String? vendorId,
    VendorFeatures? features,
    bool? enforceHttps,
    String? currencyName,
    String? currencySymbol,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      groups: groups ?? this.groups,
      isDemo: isDemo ?? this.isDemo,
      sessionId: sessionId ?? this.sessionId,
      vendorId: vendorId ?? this.vendorId,
      features: features ?? this.features,
      enforceHttps: enforceHttps ?? this.enforceHttps,
      currencyName: currencyName ?? this.currencyName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}
