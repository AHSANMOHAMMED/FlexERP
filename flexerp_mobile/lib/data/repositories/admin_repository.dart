import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_models.dart';
import '../models/auth_user.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref);
});

class PendingApprovalsNotifier extends Notifier<List<PendingApproval>> {
  @override
  List<PendingApproval> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.pendingApprovals);
  }

  Future<void> syncFromServer() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    final rows = await api.listApprovals();
    state = rows.map((r) {
      return PendingApproval(
        id: r['id'] as int? ?? 0,
        type: r['summary']?.toString() ?? 'Activity',
        reference: '${r['res_model'] ?? 'mail.activity'}/${r['res_id'] ?? r['id']}',
        requestedBy: r['user_name']?.toString() ?? 'User',
        customerOrVendor: r['note']?.toString().isNotEmpty == true
            ? r['note'].toString()
            : 'Activity',
        amount: 0,
        reason: r['note']?.toString() ?? '',
        requestedAt: DateTime.tryParse(r['date_deadline']?.toString() ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  void approve(int id) {
    state = state.where((item) => item.id != id).toList();
  }

  void reject(int id) {
    state = state.where((item) => item.id != id).toList();
  }
}

final pendingApprovalsProvider =
    NotifierProvider<PendingApprovalsNotifier, List<PendingApproval>>(PendingApprovalsNotifier.new);

class ManagedUsersNotifier extends Notifier<List<ManagedUser>> {
  @override
  List<ManagedUser> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.managedUsers);
  }

  Future<void> syncForCompany(int companyId) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    final rows = await api.listTenantUsers(companyId);
    state = rows.map((r) {
      final roleName = r['role']?.toString() ?? 'employee';
      final role = UserRole.values.firstWhere(
        (e) => e.name == roleName,
        orElse: () => UserRole.employee,
      );
      return ManagedUser(
        id: r['id'] as int? ?? 0,
        name: r['name']?.toString() ?? '',
        email: r['email']?.toString() ?? r['login']?.toString() ?? '',
        nicOrId: 'UID-${r['id']}',
        role: role,
        isActive: r['active'] as bool? ?? true,
        assignedBranch: user.companyName,
        lastActive: DateTime.now(),
      );
    }).toList();
  }

  Future<void> createUser({
    required int companyId,
    required String name,
    required String login,
    required String role,
  }) async {
    final api = ref.read(flexerpApiProvider);
    final user = ref.read(currentUserProvider);
    if (user != null && !user.isDemo && api != null) {
      await api.createTenantUser(
        companyId: companyId,
        name: name,
        login: login,
        role: role,
      );
      await syncForCompany(companyId);
      return;
    }
    addUser(ManagedUser(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      email: login,
      nicOrId: 'DEMO',
      role: UserRole.values.firstWhere((e) => e.name == role, orElse: () => UserRole.posCashier),
      isActive: true,
      assignedBranch: 'Demo',
      lastActive: DateTime.now(),
    ));
  }

  void updateUserRole(int id, UserRole newRole) {
    state = [
      for (final u in state)
        if (u.id == id)
          ManagedUser(
            id: u.id,
            name: u.name,
            email: u.email,
            nicOrId: u.nicOrId,
            role: newRole,
            isActive: u.isActive,
            assignedBranch: u.assignedBranch,
            lastActive: u.lastActive,
          )
        else
          u
    ];
  }

  Future<void> toggleUserActive(int id) async {
    final api = ref.read(flexerpApiProvider);
    final user = ref.read(currentUserProvider);
    final current = state.firstWhere((u) => u.id == id, orElse: () => state.first);
    if (user != null && !user.isDemo && api != null) {
      await api.setTenantUserActive(id, active: !current.isActive);
      await syncForCompany(user.companyId);
      return;
    }
    state = [
      for (final u in state)
        if (u.id == id)
          ManagedUser(
            id: u.id,
            name: u.name,
            email: u.email,
            nicOrId: u.nicOrId,
            role: u.role,
            isActive: !u.isActive,
            assignedBranch: u.assignedBranch,
            lastActive: u.lastActive,
          )
        else
          u
    ];
  }

  void addUser(ManagedUser newUser) {
    state = [newUser, ...state];
  }
}

final managedUsersProvider =
    NotifierProvider<ManagedUsersNotifier, List<ManagedUser>>(ManagedUsersNotifier.new);

class OpsOverviewState {
  final Map<String, dynamic>? overview;
  final bool loading;
  final String? error;

  const OpsOverviewState({this.overview, this.loading = false, this.error});
}

class OpsOverviewNotifier extends Notifier<OpsOverviewState> {
  @override
  OpsOverviewState build() => const OpsOverviewState();

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) {
      state = OpsOverviewState(
        overview: {
          'odoo_online': true,
          'database': 'demo',
          'active_vendor_slots': 4,
          'active_users': 6,
          'provider': {'status': 'not_configured', 'message': 'Demo sandbox'},
          'pool': {
            'workers_configured': 2,
            'db_maxconn_configured': 32,
            'endpoint_configured': false,
          },
        },
      );
      return;
    }
    state = const OpsOverviewState(loading: true);
    try {
      final overview = await api.opsOverview();
      state = OpsOverviewState(overview: overview);
    } catch (e) {
      state = OpsOverviewState(error: e.toString());
    }
  }

  Future<Map<String, dynamic>> wake() async {
    final api = ref.read(flexerpApiProvider);
    if (api == null) return {'status': 'not_configured'};
    final result = await api.opsWake();
    await refresh();
    return result;
  }

  Future<Map<String, dynamic>> restart() async {
    final api = ref.read(flexerpApiProvider);
    if (api == null) return {'status': 'not_configured'};
    final result = await api.opsRestart();
    await refresh();
    return result;
  }
}

final opsOverviewProvider =
    NotifierProvider<OpsOverviewNotifier, OpsOverviewState>(OpsOverviewNotifier.new);

class AdminRepository {
  final Ref ref;
  AdminRepository(this.ref);

  List<SystemHealthMetric> getHealthMetrics() {
    final ops = ref.read(opsOverviewProvider).overview;
    if (ops == null) return MockSriLankaDataService.healthMetrics;
    final provider = ops['provider'] as Map? ?? {};
    final pool = ops['pool'] as Map? ?? {};
    return [
      SystemHealthMetric(
        metricName: 'Odoo Instance',
        value: ops['odoo_online'] == true ? 'Online' : 'Offline',
        status: ops['odoo_online'] == true ? 'healthy' : 'critical',
        detail: 'DB: ${ops['database']} | Vendors: ${ops['active_vendor_slots']}',
      ),
      SystemHealthMetric(
        metricName: 'Ops Provider',
        value: provider['status']?.toString() ?? 'unknown',
        status: provider['status'] == 'ok'
            ? 'healthy'
            : provider['status'] == 'not_configured'
                ? 'warning'
                : 'critical',
        detail: provider['message']?.toString() ?? provider['provider_type']?.toString() ?? '',
      ),
      SystemHealthMetric(
        metricName: 'Worker / DB Pool',
        value: 'workers=${pool['workers_configured']} maxconn=${pool['db_maxconn_configured']}',
        status: pool['endpoint_configured'] == true ? 'healthy' : 'warning',
        detail: pool['note']?.toString() ?? 'Configure PgBouncer at deploy time',
      ),
      SystemHealthMetric(
        metricName: 'Active Users',
        value: '${ops['active_users'] ?? 0}',
        status: 'healthy',
        detail: 'Internal users across vendor slots',
      ),
    ];
  }
}
