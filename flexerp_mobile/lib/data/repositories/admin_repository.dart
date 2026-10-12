import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_models.dart';
import '../models/auth_user.dart';
import '../mock/mock_sri_lanka_data.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

class PendingApprovalsNotifier extends Notifier<List<PendingApproval>> {
  @override
  List<PendingApproval> build() {
    return List.from(MockSriLankaDataService.pendingApprovals);
  }

  void approve(int id) {
    state = state.where((item) => item.id != id).toList();
  }

  void reject(int id) {
    state = state.where((item) => item.id != id).toList();
  }
}

final pendingApprovalsProvider = NotifierProvider<PendingApprovalsNotifier, List<PendingApproval>>(PendingApprovalsNotifier.new);

class ManagedUsersNotifier extends Notifier<List<ManagedUser>> {
  @override
  List<ManagedUser> build() {
    return List.from(MockSriLankaDataService.managedUsers);
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

  void toggleUserActive(int id) {
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

final managedUsersProvider = NotifierProvider<ManagedUsersNotifier, List<ManagedUser>>(ManagedUsersNotifier.new);

class AdminRepository {
  List<SystemHealthMetric> getHealthMetrics() {
    return MockSriLankaDataService.healthMetrics;
  }
}
