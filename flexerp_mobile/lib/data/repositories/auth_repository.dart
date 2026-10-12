import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';
import '../models/vendor_model.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import '../../core/api/flexerp_mobile_api.dart';
import '../../core/storage/secure_session_store.dart';
import '../../core/widgets/company_switcher_sheet.dart';

class ServerConfig {
  final String serverUrl;
  final String database;
  final bool isConnected;
  final int? latencyMs;
  final String? serverVersion;
  final String? lastError;
  final bool enforceHttps;

  const ServerConfig({
    this.serverUrl = 'http://localhost:8069',
    this.database = 'flexerp_production_lk',
    this.isConnected = false,
    this.latencyMs,
    this.serverVersion,
    this.lastError,
    this.enforceHttps = false,
  });

  ServerConfig copyWith({
    String? serverUrl,
    String? database,
    bool? isConnected,
    int? latencyMs,
    String? serverVersion,
    String? lastError,
    bool? enforceHttps,
  }) {
    return ServerConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      isConnected: isConnected ?? this.isConnected,
      latencyMs: latencyMs ?? this.latencyMs,
      serverVersion: serverVersion ?? this.serverVersion,
      lastError: lastError ?? this.lastError,
      enforceHttps: enforceHttps ?? this.enforceHttps,
    );
  }
}

class ServerConfigNotifier extends Notifier<ServerConfig> {
  @override
  ServerConfig build() => const ServerConfig();

  void updateConfig({
    required String serverUrl,
    required String database,
    bool isConnected = false,
    int? latencyMs,
    String? serverVersion,
    String? lastError,
    bool? enforceHttps,
  }) {
    state = state.copyWith(
      serverUrl: serverUrl,
      database: database,
      isConnected: isConnected,
      latencyMs: latencyMs,
      serverVersion: serverVersion,
      lastError: lastError,
      enforceHttps: enforceHttps,
    );
  }

  void setConnected(bool connected, {int? latencyMs, String? serverVersion, String? error}) {
    state = state.copyWith(
      isConnected: connected,
      latencyMs: latencyMs,
      serverVersion: serverVersion,
      lastError: error,
    );
  }

  void setEnforceHttps(bool value) {
    state = state.copyWith(enforceHttps: value);
  }
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig>(ServerConfigNotifier.new);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final odooClientProvider = Provider<OdooClient?>((ref) {
  return ref.watch(authRepositoryProvider).activeClient;
});

final flexerpApiProvider = Provider<FlexerpMobileApi?>((ref) {
  final client = ref.watch(odooClientProvider);
  if (client == null || !client.isAuthenticated) return null;
  return FlexerpMobileApi(client);
});

final vendorFeaturesFromAuthProvider = Provider<VendorFeatures>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.features ?? const VendorFeatures();
});

UserRole mapRoleFromGroups(List<String> groups, {bool isAdmin = false, bool isSystem = false}) {
  if (isSystem ||
      isAdmin ||
      groups.contains('base.group_system') ||
      groups.contains('base.group_erp_manager') ||
      groups.any((g) => g.contains('flexerp_vendor_rbac.group_platform_super_admin'))) {
    return UserRole.superAdmin;
  }
  if (groups.any((g) => g.contains('flexerp_vendor_rbac.group_vendor_admin'))) {
    return UserRole.vendorAdmin;
  }
  if (groups.any((g) =>
      g.contains('flexerp_vendor_rbac.group_vendor_cashier') ||
      g.contains('point_of_sale.group_pos'))) {
    return UserRole.posCashier;
  }
  if (groups.any((g) => g.contains('stock.group_stock'))) {
    return UserRole.warehouseOp;
  }
  if (groups.any((g) => g.contains('account.group_account'))) {
    return UserRole.accountant;
  }
  if (groups.any((g) => g.contains('sales_team.group_sale') || g.contains('sale.group_sale'))) {
    return UserRole.salesRep;
  }
  return UserRole.employee;
}

UserRole roleFromString(String value) {
  return UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.employee,
  );
}

class CurrentUserNotifier extends Notifier<AuthUser?> {
  final SecureSessionStore _store = SecureSessionStore();

  @override
  AuthUser? build() => null;

  Future<bool> tryRestoreSession() async {
    final stored = await _store.readSession();
    if (stored == null) return false;
    final repo = ref.read(authRepositoryProvider);
    try {
      final client = repo.getClient(stored.serverUrl, sessionId: stored.sessionId);
      client.setCompanyContext(companyId: stored.companyId);
      // Validate session still alive
      final info = await client.getSessionInfo();
      if (info['uid'] == null || info['uid'] == false) {
        await _store.clearSession();
        return false;
      }
      Map<String, dynamic>? bootstrap;
      try {
        bootstrap = await FlexerpMobileApi(client).bootstrap(companyId: stored.companyId);
      } catch (_) {
        bootstrap = null;
      }
      final features = VendorFeatures.fromApiMap(
        (bootstrap?['features'] as Map?)?.cast<String, dynamic>() ?? stored.features,
      );
      final groups = bootstrap != null
          ? List<String>.from(bootstrap['groups'] as List? ?? stored.groups)
          : stored.groups;
      final role = bootstrap != null
          ? roleFromString(bootstrap['role'] as String? ?? stored.role)
          : roleFromString(stored.role);

      state = AuthUser(
        uid: stored.uid,
        name: bootstrap?['name'] as String? ?? stored.name,
        email: bootstrap?['email'] as String? ?? stored.email,
        role: role,
        serverUrl: stored.serverUrl,
        database: stored.database,
        companyId: bootstrap?['company_id'] as int? ?? stored.companyId,
        companyName: bootstrap?['company_name'] as String? ?? stored.companyName,
        groups: groups,
        isDemo: false,
        sessionId: stored.sessionId,
        vendorId: bootstrap?['vendor_id'] as String? ?? stored.vendorId,
        features: features,
        enforceHttps: stored.enforceHttps,
      );
      ref.read(serverConfigProvider.notifier).updateConfig(
            serverUrl: stored.serverUrl,
            database: stored.database,
            isConnected: true,
            enforceHttps: stored.enforceHttps,
          );
      return true;
    } catch (_) {
      await _store.clearSession();
      repo.activeClient?.clearSession();
      return false;
    }
  }

  Future<void> login({
    required String serverUrl,
    required String database,
    required String email,
    required String password,
    bool isDemo = false,
    bool enforceHttps = false,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.login(
      serverUrl: serverUrl,
      database: database,
      email: email,
      password: password,
      isDemo: isDemo,
      enforceHttps: enforceHttps,
    );
    state = user;
    if (!isDemo && user.sessionId != null) {
      await _store.saveSession(StoredSession(
        serverUrl: user.serverUrl,
        database: user.database,
        sessionId: user.sessionId!,
        uid: user.uid,
        name: user.name,
        email: user.email,
        companyId: user.companyId,
        companyName: user.companyName,
        vendorId: user.vendorId,
        role: user.role.name,
        groups: user.groups,
        features: user.features.toApiMap(),
        enforceHttps: user.enforceHttps,
      ));
    }
  }

  void switchRole(UserRole role) {
    final user = state;
    if (user == null || !user.isDemo) return;
    final matchingMock = MockSriLankaDataService.mockUsers.firstWhere(
      (u) => u.role == role,
      orElse: () => MockSriLankaDataService.mockUsers.first,
    );
    state = user.copyWith(
      role: role,
      name: matchingMock.name,
      email: matchingMock.email,
      groups: matchingMock.groups,
      features: matchingMock.features,
    );
  }

  Future<void> applyBootstrapFeatures(VendorFeatures features) async {
    if (state == null) return;
    state = state!.copyWith(features: features);
    if (!state!.isDemo && state!.sessionId != null) {
      await _store.saveSession(StoredSession(
        serverUrl: state!.serverUrl,
        database: state!.database,
        sessionId: state!.sessionId!,
        uid: state!.uid,
        name: state!.name,
        email: state!.email,
        companyId: state!.companyId,
        companyName: state!.companyName,
        vendorId: state!.vendorId,
        role: state!.role.name,
        groups: state!.groups,
        features: features.toApiMap(),
        enforceHttps: state!.enforceHttps,
      ));
    }
  }

  Future<void> switchCompany(int companyId) async {
    final user = state;
    if (user == null || user.isDemo) return;
    final api = ref.read(flexerpApiProvider);
    final client = ref.read(authRepositoryProvider).activeClient;
    if (api == null || client == null) return;
    final bootstrap = await api.switchCompany(companyId);
    client.setCompanyContext(
      companyId: bootstrap['company_id'] as int? ?? companyId,
      allowedIds: ((bootstrap['companies'] as List?) ?? [])
          .map((c) => (c as Map)['id'] as int)
          .toList(),
    );
    final features = VendorFeatures.fromApiMap(
      (bootstrap['features'] as Map?)?.cast<String, dynamic>(),
    );
    state = user.copyWith(
      companyId: bootstrap['company_id'] as int? ?? companyId,
      companyName: bootstrap['company_name'] as String? ?? user.companyName,
      vendorId: bootstrap['vendor_id'] as String? ?? user.vendorId,
      role: roleFromString(bootstrap['role'] as String? ?? user.role.name),
      groups: List<String>.from(bootstrap['groups'] as List? ?? user.groups),
      features: features,
    );
    await applyBootstrapFeatures(features);
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout(isDemo: state?.isDemo ?? true);
    await _store.clearSession();
    state = null;
  }
}

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, AuthUser?>(CurrentUserNotifier.new);

class CurrentBranchNotifier extends Notifier<CompanyBranch> {
  @override
  CompanyBranch build() => sriLankaBranches.first;

  void setBranch(CompanyBranch branch) => state = branch;
}

final currentBranchProvider =
    NotifierProvider<CurrentBranchNotifier, CompanyBranch>(CurrentBranchNotifier.new);

class AuthRepository {
  OdooClient? _client;

  OdooClient getClient(String serverUrl, {String? sessionId}) {
    if (_client == null || _client!.baseUrl != serverUrl) {
      _client = OdooClient(baseUrl: serverUrl, sessionId: sessionId);
    } else if (sessionId != null && _client!.sessionId != sessionId) {
      _client!.updateSession(sessionId);
    }
    return _client!;
  }

  OdooClient? get activeClient => _client;

  Future<AuthUser> login({
    required String serverUrl,
    required String database,
    required String email,
    required String password,
    bool isDemo = false,
    bool enforceHttps = false,
  }) async {
    if (isDemo) {
      final matched = MockSriLankaDataService.mockUsers.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => MockSriLankaDataService.mockUsers.first,
      );
      return matched.copyWith(
        serverUrl: serverUrl,
        database: database,
        isDemo: true,
        features: matched.features,
      );
    }

    final normalized = OdooClient.normalizeUrl(serverUrl, enforceHttps: enforceHttps);
    OdooClient.assertUrlAllowed(
      normalized,
      enforceHttps: enforceHttps,
      isRelease: kReleaseMode,
    );

    final client = getClient(normalized);
    final authResult = await client.authenticate(
      db: database,
      login: email,
      password: password,
    );

    final uid = authResult['uid'] as int;
    final name = authResult['name'] as String? ?? email;
    final companyId = (authResult['company_id'] is List)
        ? (authResult['company_id'] as List).first as int
        : authResult['company_id'] as int? ?? 1;
    final sessionId = authResult['session_id'] as String? ?? client.sessionId;
    final isSystem = authResult['is_system'] as bool? ?? false;
    final isAdmin = authResult['is_admin'] as bool? ?? false;

    List<String> groups = [];
    try {
      final sessionInfo = await client.getSessionInfo();
      // Odoo may expose user_context / is_system; groups via bootstrap preferred
      if (sessionInfo['is_system'] == true) {
        groups = ['base.group_system'];
      }
    } catch (_) {}

    Map<String, dynamic>? bootstrap;
    try {
      client.setCompanyContext(companyId: companyId);
      bootstrap = await FlexerpMobileApi(client).bootstrap(companyId: companyId);
    } catch (_) {
      bootstrap = null;
    }

    if (bootstrap != null) {
      groups = List<String>.from(bootstrap['groups'] as List? ?? groups);
    }

    final role = bootstrap != null
        ? roleFromString(bootstrap['role'] as String? ?? 'employee')
        : mapRoleFromGroups(groups, isAdmin: isAdmin, isSystem: isSystem);

    final features = VendorFeatures.fromApiMap(
      (bootstrap?['features'] as Map?)?.cast<String, dynamic>(),
    );

    return AuthUser(
      uid: uid,
      name: bootstrap?['name'] as String? ?? name,
      email: bootstrap?['email'] as String? ?? email,
      role: role,
      serverUrl: normalized,
      database: database,
      companyId: bootstrap?['company_id'] as int? ?? companyId,
      companyName: bootstrap?['company_name'] as String? ??
          (authResult['user_companies'] is Map
              ? ((authResult['user_companies'] as Map)['current_company'] as List?)?.last?.toString() ??
                  'Company'
              : 'Company'),
      groups: groups.isEmpty
          ? (role == UserRole.superAdmin ? ['base.group_system'] : [role.odooGroupKey])
          : groups,
      isDemo: false,
      sessionId: sessionId,
      vendorId: bootstrap?['vendor_id'] as String? ?? 'VND-${companyId.toString().padLeft(3, '0')}',
      features: features,
      enforceHttps: enforceHttps,
    );
  }

  Future<void> logout({bool isDemo = false}) async {
    if (!isDemo && _client != null) {
      try {
        await _client!.destroySession();
      } catch (_) {
        _client?.clearSession();
      }
    } else {
      _client?.clearSession();
    }
  }
}
