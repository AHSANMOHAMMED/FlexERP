enum UserRole {
  superAdmin,
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
        return 'Super Admin / C-Level';
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
        return 'base.group_system';
      case UserRole.salesRep:
        return 'sales_team.group_sale_salesman';
      case UserRole.warehouseOp:
        return 'stock.group_stock_user';
      case UserRole.accountant:
        return 'account.group_account_invoice';
      case UserRole.posCashier:
        return 'point_of_sale.group_pos_user';
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
    );
  }
}
