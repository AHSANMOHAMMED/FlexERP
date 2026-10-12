import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_card.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/auth_repository.dart';

/// Staff management scoped to the signed-in vendor slot only.
class VendorStaffScreen extends ConsumerStatefulWidget {
  const VendorStaffScreen({super.key});

  @override
  ConsumerState<VendorStaffScreen> createState() => _VendorStaffScreenState();
}

class _VendorStaffScreenState extends ConsumerState<VendorStaffScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final user = ref.read(currentUserProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (user != null && !user.isDemo) {
        await ref.read(managedUsersProvider.notifier).syncForCompany(user.companyId);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final branch = ref.watch(currentBranchProvider);
    final staff = ref.watch(managedUsersProvider);
    final slotStaff = staff
        .where((u) =>
            u.role == UserRole.vendorAdmin ||
            u.role == UserRole.posCashier ||
            u.role == UserRole.salesRep ||
            u.role == UserRole.warehouseOp ||
            u.role == UserRole.accountant ||
            u.role == UserRole.employee)
        .toList();

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Vendor Staff',
        subtitle: user?.companyName ?? 'Your slot',
        currentBranch: branch,
        onSync: _refresh,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FlexColors.primary,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite Staff'),
        onPressed: () => _showInviteDialog(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: FlexTypography.bodyMd, textAlign: TextAlign.center))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FlexCard(
                      backgroundColor: FlexColors.surfaceRaisedDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SLOT ISOLATION', style: FlexTypography.labelSm),
                          const SizedBox(height: 6),
                          Text(
                            'Staff can only access ${user?.companyName ?? 'this vendor'}. '
                            'Other vendors are invisible to this account.',
                            style: FlexTypography.bodySm,
                          ),
                          const SizedBox(height: 8),
                          FlexBadge(
                            text: 'VENDOR: ${user?.vendorId ?? '—'}',
                            variant: FlexBadgeVariant.info,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Team (${slotStaff.length})', style: FlexTypography.headlineMd),
                    const SizedBox(height: 12),
                    if (slotStaff.isEmpty)
                      FlexCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No staff yet — invite a cashier or admin',
                                style: FlexTypography.bodyMd),
                          ),
                        ),
                      )
                    else
                      ...slotStaff.map((member) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: FlexCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: FlexColors.surfaceRaisedDark,
                                  child: Text(
                                    member.name.isNotEmpty ? member.name[0] : '?',
                                    style: const TextStyle(color: FlexColors.primaryLight),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(member.name, style: FlexTypography.labelLg),
                                      Text(member.email, style: FlexTypography.bodySm),
                                      const SizedBox(height: 4),
                                      FlexBadge(
                                        text: member.role.displayName,
                                        variant: member.isActive
                                            ? FlexBadgeVariant.success
                                            : FlexBadgeVariant.warning,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: member.isActive,
                                  onChanged: (_) async {
                                    await ref
                                        .read(managedUsersProvider.notifier)
                                        .toggleUserActive(member.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 72),
                  ],
                ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final loginCtrl = TextEditingController();
    var role = 'posCashier';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: FlexColors.surfaceDark,
              title: Text('Invite Staff', style: FlexTypography.headlineSm),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: loginCtrl,
                    decoration: const InputDecoration(labelText: 'Login / email'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(value: 'posCashier', child: Text('POS Cashier')),
                      DropdownMenuItem(value: 'vendorAdmin', child: Text('Vendor Admin')),
                      DropdownMenuItem(value: 'salesRep', child: Text('Sales')),
                      DropdownMenuItem(value: 'warehouseOp', child: Text('Warehouse')),
                    ],
                    onChanged: (v) => setLocal(() => role = v ?? 'posCashier'),
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FlexButton(
                  label: 'Create',
                  height: 36,
                  onPressed: () async {
                    final user = ref.read(currentUserProvider);
                    if (user == null || nameCtrl.text.isEmpty || loginCtrl.text.isEmpty) return;
                    await ref.read(managedUsersProvider.notifier).createUser(
                          companyId: user.companyId,
                          name: nameCtrl.text.trim(),
                          login: loginCtrl.text.trim(),
                          role: role,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
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
