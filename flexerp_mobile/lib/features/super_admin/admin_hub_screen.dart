import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/company_switcher_sheet.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/admin_repository.dart';
import 'vendor_management_screen.dart';
import '../warehouse/vendor_inventory_management_screen.dart';

class AdminHubScreen extends ConsumerStatefulWidget {
  const AdminHubScreen({super.key});

  @override
  ConsumerState<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends ConsumerState<AdminHubScreen> {
  bool _opsBusy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(opsOverviewProvider.notifier).refresh();
      await ref.read(pendingApprovalsProvider.notifier).syncFromServer();
      final user = ref.read(currentUserProvider);
      if (user != null) {
        await ref.read(managedUsersProvider.notifier).syncForCompany(user.companyId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final pendingApprovals = ref.watch(pendingApprovalsProvider);
    final managedUsers = ref.watch(managedUsersProvider);
    final adminRepo = ref.watch(adminRepositoryProvider);
    final healthMetrics = adminRepo.getHealthMetrics();
    final opsState = ref.watch(opsOverviewProvider);
    final providerStatus =
        (opsState.overview?['provider'] as Map?)?['status']?.toString() ?? 'unknown';

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Super Admin Console',
        subtitle: 'Centralized Sri Lanka Operations',
        currentBranch: currentBranch,
        onBranchChanged: (branch) {
          ref.read(currentBranchProvider.notifier).setBranch(branch);
        },
        onSync: () async {
          await ref.read(opsOverviewProvider.notifier).refresh();
          await ref.read(pendingApprovalsProvider.notifier).syncFromServer();
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: FlexColors.primaryLight, size: 20),
                      const SizedBox(width: 8),
                      Text('OPS CONTROL', style: FlexTypography.labelSm),
                      const Spacer(),
                      FlexBadge(
                        text: providerStatus.toUpperCase(),
                        variant: providerStatus == 'ok'
                            ? FlexBadgeVariant.success
                            : FlexBadgeVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Instance wake & pool', style: FlexTypography.headlineSm),
                  const SizedBox(height: 4),
                  Text(
                    providerStatus == 'not_configured'
                        ? 'Provider endpoints not set yet — configure Docker/Cloud later. Wake returns not_configured until then.'
                        : (opsState.overview?['provider'] as Map?)?['message']?.toString() ??
                            'Live ops provider connected.',
                    style: FlexTypography.bodySm,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FlexButton(
                          label: _opsBusy ? 'Working…' : 'Wake',
                          icon: Icons.power_settings_new,
                          height: 40,
                          onPressed: _opsBusy
                              ? null
                              : () async {
                                  setState(() => _opsBusy = true);
                                  try {
                                    final result =
                                        await ref.read(opsOverviewProvider.notifier).wake();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Wake: ${result['status'] ?? result}',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _opsBusy = false);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _opsBusy
                              ? null
                              : () async {
                                  setState(() => _opsBusy = true);
                                  try {
                                    final result =
                                        await ref.read(opsOverviewProvider.notifier).restart();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Restart: ${result['status'] ?? result}',
                                        ),
                                      ),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _opsBusy = false);
                                  }
                                },
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('Restart'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Top Multi-Company Summary Card
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield, color: FlexColors.primaryLight, size: 20),
                          const SizedBox(width: 8),
                          Text('CENTRALIZED GOVERNANCE', style: FlexTypography.labelSm),
                        ],
                      ),
                      const FlexBadge(
                        text: 'ROOT PRIVILEGE',
                        variant: FlexBadgeVariant.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentBranch.name,
                    style: FlexTypography.headlineMd,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Entity Code: ${currentBranch.code}', style: FlexTypography.bodySm),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: FlexColors.textDisabledDark)),
                      const SizedBox(width: 8),
                      Text('Location: ${currentBranch.city}', style: FlexTypography.bodySm),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('4 Regional Subsidiaries Online', style: FlexTypography.bodySm),
                      TextButton.icon(
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Switch Branch'),
                        onPressed: () async {
                          final selected = await CompanySwitcherSheet.show(
                            context,
                            currentBranch: currentBranch,
                          );
                          if (selected != null) {
                            ref.read(currentBranchProvider.notifier).setBranch(selected);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Multi-Vendor Architecture & Real-Time Stock Suite Card
            FlexCard(
              backgroundColor: FlexColors.surfaceDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hub, color: FlexColors.primaryLight, size: 20),
                          const SizedBox(width: 8),
                          Text('MULTI-VENDOR ARCHITECTURE', style: FlexTypography.labelSm),
                        ],
                      ),
                      const FlexBadge(text: 'LIVE SYNC', variant: FlexBadgeVariant.success),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Vendor Tenant Isolation & Stock Engine', style: FlexTypography.headlineSm),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage vendor company slots (one shared DB), provision cashiers, toggle modular features, and adjust stock in real-time.',
                    style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: FlexColors.primaryLight),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VendorManagementScreen()),
                            );
                          },
                          icon: const Icon(Icons.business_outlined, size: 16, color: FlexColors.primaryLight),
                          label: const Text('Vendor Tenants', style: TextStyle(color: FlexColors.primaryLight, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlexColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VendorInventoryManagementScreen()),
                            );
                          },
                          icon: const Icon(Icons.inventory_2, size: 16, color: Colors.white),
                          label: const Text('Live Stock Sync', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Pending Approvals Center
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Global Approvals Center', style: FlexTypography.headlineMd),
                FlexBadge(
                  text: '${pendingApprovals.length} PENDING',
                  variant: pendingApprovals.isNotEmpty ? FlexBadgeVariant.warning : FlexBadgeVariant.success,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pendingApprovals.isEmpty)
              FlexCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.verified, color: FlexColors.success, size: 36),
                        const SizedBox(height: 8),
                        Text('All requests approved or clear', style: FlexTypography.bodyMd),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...pendingApprovals.map((approval) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: FlexCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FlexBadge(
                              text: approval.type,
                              variant: FlexBadgeVariant.warning,
                            ),
                            Text(
                              LkFormatters.formatLkr(approval.amount),
                              style: FlexTypography.codeNum.copyWith(
                                color: FlexColors.primaryLight,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${approval.reference} • ${approval.customerOrVendor}',
                          style: FlexTypography.labelLg,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          approval.reason,
                          style: FlexTypography.bodySm,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Requested by: ${approval.requestedBy}',
                          style: FlexTypography.bodySm.copyWith(color: FlexColors.textDisabledDark),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FlexButton(
                                label: 'Approve',
                                icon: Icons.check,
                                variant: FlexButtonVariant.primary,
                                height: 36,
                                onPressed: () {
                                  ref.read(pendingApprovalsProvider.notifier).approve(approval.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Approved ${approval.reference}')),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FlexButton(
                                label: 'Reject',
                                icon: Icons.close,
                                variant: FlexButtonVariant.danger,
                                height: 36,
                                onPressed: () {
                                  ref.read(pendingApprovalsProvider.notifier).reject(approval.id);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 20),

            // Section 2: User Role Provisioning Center
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('User Management & Roles', style: FlexTypography.headlineMd),
                TextButton.icon(
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Provision User'),
                  onPressed: () => _showAddUserDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...managedUsers.map((user) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: FlexCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: FlexColors.surfaceRaisedDark,
                        child: Text(
                          user.name.substring(0, 1),
                          style: const TextStyle(color: FlexColors.primaryLight, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: FlexTypography.labelLg),
                            const SizedBox(height: 2),
                            Text(
                              '${user.email} • ${user.assignedBranch}',
                              style: FlexTypography.bodySm,
                            ),
                            const SizedBox(height: 4),
                            FlexBadge(
                              text: user.role.displayName,
                              variant: FlexBadgeVariant.info,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showEditRoleDialog(context, ref, user),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Section 3: System Health & Infrastructure Telemetry
            Text('Server & Cluster Telemetry', style: FlexTypography.headlineMd),
            const SizedBox(height: 12),
            ...healthMetrics.map((metric) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: FlexCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.dns, color: FlexColors.success, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metric.metricName, style: FlexTypography.labelMd),
                            Text(metric.value, style: FlexTypography.bodySm.copyWith(color: FlexColors.success)),
                            Text(metric.detail, style: FlexTypography.bodySm.copyWith(color: FlexColors.textDisabledDark)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, WidgetRef ref, ManagedUser user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FlexColors.surfaceDark,
          title: Text('Edit Role for ${user.name}', style: FlexTypography.headlineSm),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: UserRole.values.map((role) {
              return RadioListTile<UserRole>(
                value: role,
                groupValue: user.role,
                title: Text(role.displayName, style: FlexTypography.bodyMd),
                onChanged: (newRole) {
                  if (newRole != null) {
                    ref.read(managedUsersProvider.notifier).updateUserRole(user.id, newRole);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final nicCtrl = TextEditingController();
    UserRole selectedRole = UserRole.salesRep;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: FlexColors.surfaceDark,
              title: Text('Provision New User', style: FlexTypography.headlineSm),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nicCtrl,
                      decoration: const InputDecoration(labelText: 'Sri Lanka NIC Number'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UserRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Assigned Role'),
                      dropdownColor: FlexColors.surfaceRaisedDark,
                      items: UserRole.values.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r.displayName));
                      }).toList(),
                      onChanged: (r) {
                        if (r != null) setState(() => selectedRole = r);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                FlexButton(
                  label: 'Provision',
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                    final user = ref.read(currentUserProvider);
                    await ref.read(managedUsersProvider.notifier).createUser(
                          companyId: user?.companyId ?? 1,
                          name: nameCtrl.text.trim(),
                          login: emailCtrl.text.trim(),
                          role: selectedRole.name,
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
