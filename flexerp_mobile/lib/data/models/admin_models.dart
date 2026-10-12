import 'auth_user.dart';

class SystemHealthMetric {
  final String metricName;
  final String value;
  final String status; // 'healthy', 'warning', 'danger'
  final String detail;

  const SystemHealthMetric({
    required this.metricName,
    required this.value,
    required this.status,
    required this.detail,
  });
}

class ManagedUser {
  final int id;
  final String name;
  final String email;
  final String nicOrId; // Sri Lanka NIC
  UserRole role;
  bool isActive;
  final String assignedBranch;
  final DateTime lastActive;

  ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.nicOrId,
    required this.role,
    this.isActive = true,
    required this.assignedBranch,
    required this.lastActive,
  });
}

class PendingApproval {
  final int id;
  final String type; // 'Credit Limit Override', 'High-Value PO Approval', 'Price Discount Override'
  final String reference; // e.g. "SO/2026/00142" or "PO/2026/00098"
  final String requestedBy;
  final String customerOrVendor;
  final double amount; // LKR
  final String reason;
  final DateTime requestedAt;

  const PendingApproval({
    required this.id,
    required this.type,
    required this.reference,
    required this.requestedBy,
    required this.customerOrVendor,
    required this.amount,
    required this.reason,
    required this.requestedAt,
  });
}
