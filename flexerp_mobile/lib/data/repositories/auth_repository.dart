import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/api/odoo_client.dart';
import '../../core/widgets/company_switcher_sheet.dart';

class ServerConfig {
  final String serverUrl;
  final String database;
  final bool isConnected;
  final int? latencyMs;
  final String? serverVersion;
  final String? lastError;

  const ServerConfig({
    this.serverUrl = 'http://localhost:8069',
    this.database = 'flexerp_production_lk',
    this.isConnected = false,
    this.latencyMs,
    this.serverVersion,
    this.lastError,
  });

  ServerConfig copyWith({
    String? serverUrl,
    String? database,
    bool? isConnected,
    int? latencyMs,
    String? serverVersion,
    String? lastError,
  }) {
    return ServerConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      isConnected: isConnected ?? this.isConnected,
      latencyMs: latencyMs ?? this.latencyMs,
      serverVersion: serverVersion ?? this.serverVersion,
      lastError: lastError ?? this.lastError,
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
  }) {
    state = state.copyWith(
      serverUrl: serverUrl,
      database: database,
      isConnected: isConnected,
      latencyMs: latencyMs,
      serverVersion: serverVersion,
      lastError: lastError,
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
}

final serverConfigProvider = NotifierProvider<ServerConfigNotifier, ServerConfig>(ServerConfigNotifier.new);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final odooClientProvider = Provider<OdooClient?>((ref) {
  return ref.watch(authRepositoryProvider).activeClient;
});

class CurrentUserNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    return MockSriLankaDataService.mockUsers.first;
  }

  Future<void> login({
    required String serverUrl,
    required String database,
    required String email,
    required String password,
    bool isDemo = false,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.login(
      serverUrl: serverUrl,
      database: database,
      email: email,
      password: password,
      isDemo: isDemo,
    );
    state = user;
  }

  void switchRole(UserRole role) {
    if (state != null) {
      final matchingMock = MockSriLankaDataService.mockUsers.firstWhere(
        (u) => u.role == role,
        orElse: () => MockSriLankaDataService.mockUsers.first,
      );
      state = state!.copyWith(
        role: role,
        name: matchingMock.name,
        email: matchingMock.email,
        groups: matchingMock.groups,
      );
    }
  }

  void logout() {
    state = null;
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, AuthUser?>(CurrentUserNotifier.new);

class CurrentBranchNotifier extends Notifier<CompanyBranch> {
  @override
  CompanyBranch build() => sriLankaBranches.first;

  void setBranch(CompanyBranch branch) => state = branch;
}

final currentBranchProvider = NotifierProvider<CurrentBranchNotifier, CompanyBranch>(CurrentBranchNotifier.new);

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
      );
    }

    final client = getClient(serverUrl);
    final authResult = await client.authenticate(
      db: database,
      login: email,
      password: password,
    );

    final uid = authResult['uid'] as int;
    final name = authResult['name'] as String? ?? email;
    final companyId = authResult['company_id'] as int? ?? 1;
    final sessionId = authResult['session_id'] as String?;
    final isSystem = authResult['is_system'] as bool? ?? false;
    final isAdmin = authResult['is_admin'] as bool? ?? false;

    UserRole detectedRole = UserRole.salesRep;
    if (isSystem || isAdmin) {
      detectedRole = UserRole.superAdmin;
    }

    return AuthUser(
      uid: uid,
      name: name,
      email: email,
      role: detectedRole,
      serverUrl: serverUrl,
      database: database,
      companyId: companyId,
      companyName: 'FlexCorp Ceylon (Pvt) Ltd',
      groups: isSystem ? ['base.group_system'] : ['sales_team.group_sale_salesman'],
      isDemo: false,
      sessionId: sessionId,
    );
  }
}
