import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = ref.watch(currentBranchProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'User Profile & Roles',
        subtitle: 'Enterprise Security Context',
        currentBranch: currentBranch,
        showCompanySwitcher: true,
        onBranchChanged: (branch) {
          ref.read(currentBranchProvider.notifier).setBranch(branch);
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: FlexColors.primary,
                    child: Text(
                      user != null ? user.name.substring(0, 1) : 'U',
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Enterprise User', style: FlexTypography.headlineSm),
                        const SizedBox(height: 2),
                        Text(user?.email ?? 'user@flexcorp.lk', style: FlexTypography.bodySm),
                        const SizedBox(height: 6),
                        FlexBadge(
                          text: user?.role.displayName ?? 'SUPER ADMIN',
                          variant: FlexBadgeVariant.info,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Role Switcher for Pair-Programming & Multi-Role Testing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Switch Active Role', style: FlexTypography.headlineMd),
                const FlexBadge(text: 'DYNAMIC RBAC', variant: FlexBadgeVariant.success),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Switch between enterprise roles to test distinct navigation, feature scopes, and data permissions immediately.',
              style: FlexTypography.bodySm,
            ),
            const SizedBox(height: 12),

            ...UserRole.values.map((role) {
              final isCurrent = user?.role == role;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? FlexColors.surfaceRaisedDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? FlexColors.primary : FlexColors.borderDark,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(
                    role == UserRole.superAdmin
                        ? Icons.shield
                        : role == UserRole.salesRep
                            ? Icons.trending_up
                            : role == UserRole.warehouseOp
                                ? Icons.inventory_2
                                : role == UserRole.accountant
                                    ? Icons.receipt_long
                                    : role == UserRole.posCashier
                                        ? Icons.point_of_sale
                                        : Icons.badge,
                    color: isCurrent ? FlexColors.primaryLight : FlexColors.textDisabledDark,
                  ),
                  title: Text(
                    role.displayName,
                    style: FlexTypography.labelLg.copyWith(
                      color: isCurrent ? FlexColors.primaryLight : FlexColors.textPrimaryDark,
                    ),
                  ),
                  subtitle: Text(
                    'Odoo Group: ${role.odooGroupKey}',
                    style: FlexTypography.bodySm.copyWith(fontSize: 11),
                  ),
                  trailing: isCurrent ? const Icon(Icons.check_circle, color: FlexColors.primary) : null,
                  onTap: () {
                    ref.read(currentUserProvider.notifier).switchRole(role);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Switched to ${role.displayName} navigation!')),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 20),

            // Security & Instance Details
            FlexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INSTANCE DETAILS', style: FlexTypography.labelSm),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Server Endpoint:', style: FlexTypography.bodySm),
                      Text(user?.serverUrl ?? 'https://erp.flexcorp.lk', style: FlexTypography.codeNum),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Database:', style: FlexTypography.bodySm),
                      Text(user?.database ?? 'flexerp_production_lk', style: FlexTypography.codeNum),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Subsidiary:', style: FlexTypography.bodySm),
                      Text(currentBranch.name, style: FlexTypography.labelSm.copyWith(color: FlexColors.primaryLight)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            FlexButton(
              label: 'Sign Out of Workspace',
              icon: Icons.logout,
              variant: FlexButtonVariant.danger,
              height: 48,
              onPressed: () {
                ref.read(currentUserProvider.notifier).logout();
                onLogout();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
