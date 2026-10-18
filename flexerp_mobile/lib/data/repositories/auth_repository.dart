import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/auth_user.dart';
import '../models/vendor_model.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import '../../core/api/flexerp_mobile_api.dart';
import '../../core/storage/secure_session_store.dart';
import '../../core/localization/lk_formatters.dart';
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
    this.enforceHttps = true,
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

/// Holds the live [OdooClient] for the authenticated session.
///
/// A *new* client instance is published on every login / session restore /
/// company context change and `null` on logout, so every provider that
/// watches [odooClientProvider] or [flexerpApiProvider] recomputes. When the
/// configured server URL changes the stale client is dropped.
class OdooClientNotifier extends Notifier<OdooClient?> {
  @override
  OdooClient? build() {
    ref.listen<String>(
      serverConfigProvider.select((c) => c.serverUrl),
      (previous, next) {
        final current = state;
        if (current == null) return;
        final normalized = OdooClient.normalizeUrl(next, enforceHttps: false);
        final currentHost = OdooClient.normalizeUrl(current.baseUrl, enforceHttps: false);
        if (normalized != currentHost) {
          state = null;
        }
      },
    );
    return null;
  }

  void setClient(OdooClient? client) => state = client;

  /// Re-publish the current client after an in-place mutation (company
  /// context) so dependents rebuild.
  void refresh() {
    final current = state;
    if (current == null) return;
    state = current.copy();
  }
}

final odooClientProvider =
    NotifierProvider<OdooClientNotifier, OdooClient?>(OdooClientNotifier.new);

final flexerpApiProvider = Provider<FlexerpMobileApi?>((ref) {
  final client = ref.watch(odooClientProvider);
  if (client == null || !client.isAuthenticated) return null;
  return FlexerpMobileApi(client);
});

final vendorFeaturesFromAuthProvider = Provider<VendorFeatures>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.features ?? VendorFeatures.none;
});

/// Company id/name from an Odoo `/web/session/authenticate` payload.
///
/// `user_companies.current_company` is an int on Odoo 17+ (name looked up in
/// `allowed_companies`) and a `[id, name]` pair on legacy versions.
({int? id, String? name}) parseSessionCompany(Map<String, dynamic> authResult) {
  int? id = parseOdooInt(authResult['company_id']);
  String? name;
  final userCompanies = authResult['user_companies'];
  if (userCompanies is Map) {
    final current = userCompanies['current_company'];
    if (current is List && current.isNotEmpty) {
      id ??= parseOdooInt(current.first);
      if (current.length > 1 && current[1] != false) name = current[1]?.toString();
    } else {
      final currentId = parseOdooInt(current);
      id ??= currentId;
      final allowed = userCompanies['allowed_companies'];
      if (currentId != null) {
        if (allowed is Map) {
          final entry = allowed['$currentId'] ?? allowed[currentId];
          if (entry is Map && entry['name'] != null) name = entry['name'].toString();
        } else if (allowed is List) {
          for (final c in allowed) {
            if (c is List && c.length > 1 && parseOdooInt(c.first) == currentId) {
              name = c[1]?.toString();
            } else if (c is Map && parseOdooInt(c['id']) == currentId) {
              name = c['name']?.toString();
            }
          }
        }
      }
    }
  }
  return (id: id, name: name);
}

/// `live_last_event_id` from bootstrap (0/absent → null).
int? parseLiveLastEventId(Map<String, dynamic>? bootstrap) {
  final id = parseOdooInt(bootstrap?['live_last_event_id']);
  return (id == null || id <= 0) ? null : id;
}

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

  /// Live event cursor reported by the latest bootstrap (`live_last_event_id`).
  int? liveStartEventId;

  @override
  AuthUser? build() => null;

  void _setUser(AuthUser? user) {
    state = user;
    if (user == null) {
      LkFormatters.resetCurrency();
    } else {
      LkFormatters.configureCurrency(symbol: user.currencySymbol, code: user.currencyName);
    }
  }

  Future<bool> tryRestoreSession() async {
    final stored = await _store.readSession();
    if (stored == null) return false;
    final repo = ref.read(authRepositoryProvider);
    OdooClient? client;
    try {
      client = repo.createClient(stored.serverUrl, sessionId: stored.sessionId);
      client.setCompanyContext(companyId: stored.companyId);
      // Validate session still alive
      final info = await client.getSessionInfo();
      if (parseOdooInt(info['uid']) == null) {
        await _store.clearSession();
        return false;
      }
      Map<String, dynamic>? bootstrap;
      try {
        bootstrap = await FlexerpMobileApi(client).bootstrap(companyId: stored.companyId);
      } catch (e) {
        debugPrint('FlexERP: bootstrap on restore failed, using cached profile: $e');
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
      final companyId = parseOdooInt(bootstrap?['company_id']) ?? stored.companyId;
      _applyCompanyContext(client, companyId, bootstrap);

      liveStartEventId = parseLiveLastEventId(bootstrap);
      ref.read(serverConfigProvider.notifier).updateConfig(
            serverUrl: stored.serverUrl,
            database: stored.database,
            isConnected: true,
            enforceHttps: stored.enforceHttps,
          );
      ref.read(odooClientProvider.notifier).setClient(client);
      _setUser(AuthUser(
        uid: stored.uid,
        name: bootstrap?['name'] as String? ?? stored.name,
        email: bootstrap?['email'] as String? ?? stored.email,
        role: role,
        serverUrl: stored.serverUrl,
        database: stored.database,
        companyId: companyId,
        companyName: bootstrap?['company_name'] as String? ?? stored.companyName,
        groups: groups,
        isDemo: false,
        sessionId: stored.sessionId,
        vendorId: bootstrap?['vendor_id'] as String? ?? stored.vendorId,
        features: features,
        enforceHttps: stored.enforceHttps,
        currencyName: bootstrap?['currency_name'] as String? ?? 'LKR',
        currencySymbol: bootstrap?['currency_symbol'] as String? ?? LkFormatters.defaultSymbol,
      ));
      return true;
    } catch (e) {
      debugPrint('FlexERP: session restore failed: $e');
      if (e is OdooException && e.isNetworkError) {
        // Offline at launch: keep the stored session so the user can retry,
        // but do not enter the shell without a validated session.
        return false;
      }
      await _store.clearSession();
      client?.clearSession();
      return false;
    }
  }

  Future<void> login({
    required String serverUrl,
    required String database,
    required String email,
    required String password,
    bool isDemo = false,
    bool enforceHttps = true,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.login(
      serverUrl: serverUrl,
      database: database,
      email: email,
      password: password,
      isDemo: isDemo,
      enforceHttps: enforceHttps,
    );
    final user = result.user;
    liveStartEventId = parseLiveLastEventId(result.bootstrap);
    ref.read(odooClientProvider.notifier).setClient(result.client);
    _setUser(user);
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
    _setUser(user.copyWith(
      role: role,
      name: matchingMock.name,
      email: matchingMock.email,
      groups: matchingMock.groups,
      features: matchingMock.features,
    ));
  }

  Future<void> applyBootstrapFeatures(VendorFeatures features) async {
    if (state == null) return;
    _setUser(state!.copyWith(features: features));
    await _persistCurrent();
  }

  Future<void> _persistCurrent() async {
    final user = state;
    if (user == null || user.isDemo || user.sessionId == null) return;
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

  void _applyCompanyContext(OdooClient client, int companyId, Map<String, dynamic>? bootstrap) {
    final allowed = <int>[
      for (final c in (bootstrap?['companies'] as List?) ?? const [])
        if (c is Map && parseOdooInt(c['id']) != null) parseOdooInt(c['id'])!,
    ];
    client.setCompanyContext(
      companyId: companyId,
      allowedIds: allowed.isEmpty ? null : allowed,
    );
  }

  Future<void> switchCompany(int companyId) async {
    final user = state;
    if (user == null || user.isDemo) return;
    final api = ref.read(flexerpApiProvider);
    final client = ref.read(odooClientProvider);
    if (api == null || client == null) return;
    final bootstrap = await api.switchCompany(companyId);
    final newCompanyId = parseOdooInt(bootstrap['company_id']) ?? companyId;
    final next = client.copy();
    _applyCompanyContext(next, newCompanyId, bootstrap);
    final features = VendorFeatures.fromApiMap(
      (bootstrap['features'] as Map?)?.cast<String, dynamic>(),
    );
    liveStartEventId = parseLiveLastEventId(bootstrap) ?? liveStartEventId;
    ref.read(odooClientProvider.notifier).setClient(next);
    _setUser(user.copyWith(
      companyId: newCompanyId,
      companyName: bootstrap['company_name'] as String? ?? user.companyName,
      vendorId: bootstrap['vendor_id'] as String? ?? user.vendorId,
      role: roleFromString(bootstrap['role'] as String? ?? user.role.name),
      groups: List<String>.from(bootstrap['groups'] as List? ?? user.groups),
      features: features,
      currencyName: bootstrap['currency_name'] as String? ?? user.currencyName,
      currencySymbol: bootstrap['currency_symbol'] as String? ?? user.currencySymbol,
    ));
    await _persistCurrent();
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    final client = ref.read(odooClientProvider);
    await repo.logout(client, isDemo: state?.isDemo ?? true);
    await _store.clearSession();
    liveStartEventId = null;
    ref.read(odooClientProvider.notifier).setClient(null);
    _setUser(null);
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

class AuthLoginResult {
  final AuthUser user;
  final OdooClient? client;
  final Map<String, dynamic>? bootstrap;

  const AuthLoginResult({required this.user, this.client, this.bootstrap});
}

class AuthRepository {
  /// Injectable transport (tests use `MockClient`).
  final http.Client? httpClient;

  AuthRepository({this.httpClient});

  /// Always returns a fresh client so session/server changes never reuse a
  /// stale instance.
  OdooClient createClient(String serverUrl, {String? sessionId}) {
    return OdooClient(baseUrl: serverUrl, sessionId: sessionId, httpClient: httpClient);
  }

  Future<AuthLoginResult> login({
    required String serverUrl,
    required String database,
    required String email,
    required String password,
    bool isDemo = false,
    bool enforceHttps = true,
  }) async {
    if (isDemo) {
      final matched = MockSriLankaDataService.mockUsers.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => MockSriLankaDataService.mockUsers.first,
      );
      return AuthLoginResult(
        user: matched.copyWith(
          serverUrl: serverUrl,
          database: database,
          isDemo: true,
          features: matched.features,
        ),
      );
    }

    final normalized = OdooClient.normalizeUrl(serverUrl, enforceHttps: enforceHttps);
    OdooClient.assertUrlAllowed(
      normalized,
      enforceHttps: enforceHttps,
      isRelease: kReleaseMode,
    );

    final client = createClient(normalized);
    final authResult = await client.authenticate(
      db: database,
      login: email,
      password: password,
    );

    final uid = parseOdooInt(authResult['uid']);
    if (uid == null) {
      throw OdooException('Invalid credentials');
    }
    final name = authResult['name'] as String? ?? email;
    final sessionCompany = parseSessionCompany(authResult);
    final companyId = sessionCompany.id ?? 1;
    final sessionId = authResult['session_id'] as String? ?? client.sessionId;
    final isSystem = authResult['is_system'] == true;
    final isAdmin = authResult['is_admin'] == true;

    List<String> groups = [];
    try {
      final sessionInfo = await client.getSessionInfo();
      // Odoo may expose user_context / is_system; groups via bootstrap preferred
      if (sessionInfo['is_system'] == true) {
        groups = ['base.group_system'];
      }
    } catch (e) {
      debugPrint('FlexERP: get_session_info failed after login: $e');
    }

    Map<String, dynamic>? bootstrap;
    try {
      client.setCompanyContext(companyId: companyId);
      bootstrap = await FlexerpMobileApi(client).bootstrap(companyId: companyId);
    } catch (e) {
      debugPrint('FlexERP: bootstrap failed after login: $e');
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
    final effectiveCompanyId = parseOdooInt(bootstrap?['company_id']) ?? companyId;
    final allowed = <int>[
      for (final c in (bootstrap?['companies'] as List?) ?? const [])
        if (c is Map && parseOdooInt(c['id']) != null) parseOdooInt(c['id'])!,
    ];
    client.setCompanyContext(
      companyId: effectiveCompanyId,
      allowedIds: allowed.isEmpty ? null : allowed,
    );

    final user = AuthUser(
      uid: uid,
      name: bootstrap?['name'] as String? ?? name,
      email: bootstrap?['email'] as String? ?? email,
      role: role,
      serverUrl: normalized,
      database: database,
      companyId: effectiveCompanyId,
      companyName: bootstrap?['company_name'] as String? ?? sessionCompany.name ?? 'Company',
      groups: groups.isEmpty
          ? (role == UserRole.superAdmin ? ['base.group_system'] : [role.odooGroupKey])
          : groups,
      isDemo: false,
      sessionId: sessionId,
      vendorId: bootstrap?['vendor_id'] as String? ??
          'VND-${effectiveCompanyId.toString().padLeft(3, '0')}',
      features: features,
      enforceHttps: enforceHttps,
      currencyName: bootstrap?['currency_name'] as String? ?? LkFormatters.defaultCurrencyCode,
      currencySymbol: bootstrap?['currency_symbol'] as String? ?? LkFormatters.defaultSymbol,
    );
    return AuthLoginResult(user: user, client: client, bootstrap: bootstrap);
  }

  Future<void> logout(OdooClient? client, {bool isDemo = false}) async {
    if (client == null) return;
    if (!isDemo) {
      try {
        await client.destroySession();
      } catch (e) {
        debugPrint('FlexERP: session destroy failed (clearing locally): $e');
        client.clearSession();
      }
    } else {
      client.clearSession();
    }
  }
}
