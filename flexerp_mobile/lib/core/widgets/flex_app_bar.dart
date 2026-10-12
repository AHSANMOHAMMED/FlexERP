import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/flex_colors.dart';
import '../theme/flex_typography.dart';
import 'company_switcher_sheet.dart';
import '../../data/repositories/auth_repository.dart';

/// FlexERP Branded App Bar featuring live server status, company switcher pill,
/// and instant JSON-RPC synchronization.
class FlexAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final CompanyBranch currentBranch;
  final ValueChanged<CompanyBranch>? onBranchChanged;
  final List<Widget>? actions;
  final bool showCompanySwitcher;
  final Widget? leading;
  final VoidCallback? onSync;

  const FlexAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.currentBranch = const CompanyBranch(
      id: 1,
      name: 'FlexCorp Ceylon (Pvt) Ltd',
      code: 'HQ-COLOMBO',
      city: 'Colombo 03',
    ),
    this.onBranchChanged,
    this.actions,
    this.showCompanySwitcher = true,
    this.leading,
    this.onSync,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isLiveOdoo = user != null && !user.isDemo;

    return AppBar(
      backgroundColor: FlexColors.canvasDark,
      elevation: 0,
      centerTitle: false,
      leading: leading,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(title, style: FlexTypography.headlineMd),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLiveOdoo
                      ? FlexColors.success.withValues(alpha: 0.15)
                      : FlexColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isLiveOdoo ? FlexColors.success : FlexColors.info,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isLiveOdoo ? FlexColors.success : FlexColors.info,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLiveOdoo ? 'LIVE ODOO' : 'SANDBOX',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isLiveOdoo ? FlexColors.success : FlexColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: FlexTypography.bodySm),
          ],
        ],
      ),
      actions: [
        if (onSync != null) ...[
          IconButton(
            tooltip: 'Sync with Odoo Server',
            icon: const Icon(Icons.sync, size: 20, color: FlexColors.primaryLight),
            onPressed: onSync,
          ),
        ],
        if (showCompanySwitcher) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              onTap: onBranchChanged != null
                  ? () async {
                      final selected = await CompanySwitcherSheet.show(
                        context,
                        currentBranch: currentBranch,
                      );
                      if (selected != null) {
                        onBranchChanged!(selected);
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FlexColors.surfaceRaisedDark,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: FlexColors.borderDark),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business, size: 14, color: FlexColors.primaryLight),
                    const SizedBox(width: 6),
                    Text(
                      currentBranch.code,
                      style: FlexTypography.labelSm.copyWith(
                        color: FlexColors.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16, color: FlexColors.textSecondaryDark),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        ...?actions,
        const SizedBox(width: 12),
      ],
    );
  }
}
