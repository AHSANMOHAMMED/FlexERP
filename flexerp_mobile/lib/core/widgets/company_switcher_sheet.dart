import 'package:flutter/material.dart';
import '../theme/flex_colors.dart';
import '../theme/flex_typography.dart';
import 'flex_badge.dart';

class CompanyBranch {
  final int id;
  final String name;
  final String code;
  final String city;
  final bool isDefault;

  const CompanyBranch({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    this.isDefault = false,
  });
}

const List<CompanyBranch> sriLankaBranches = [
  CompanyBranch(
    id: 1,
    name: 'FlexCorp Ceylon (Pvt) Ltd',
    code: 'HQ-COLOMBO',
    city: 'Colombo 03',
    isDefault: true,
  ),
  CompanyBranch(
    id: 2,
    name: 'FlexCorp Logistics & Fulfillment Hub',
    code: 'WH-KELANIYA',
    city: 'Peliyagoda / Kelaniya',
  ),
  CompanyBranch(
    id: 3,
    name: 'FlexCorp Central Regional Branch',
    code: 'BR-KANDY',
    city: 'Kandy City Centre',
  ),
  CompanyBranch(
    id: 4,
    name: 'FlexCorp Southern Distribution Depot',
    code: 'DP-GALLE',
    city: 'Galle Fort Road',
  ),
];

/// Modal Bottom Sheet allowing Super Admin or executives to switch active company/branch.
class CompanySwitcherSheet extends StatelessWidget {
  final CompanyBranch currentBranch;
  final ValueChanged<CompanyBranch> onBranchSelected;

  const CompanySwitcherSheet({
    super.key,
    required this.currentBranch,
    required this.onBranchSelected,
  });

  static Future<CompanyBranch?> show(
    BuildContext context, {
    required CompanyBranch currentBranch,
  }) {
    return showModalBottomSheet<CompanyBranch>(
      context: context,
      backgroundColor: FlexColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CompanySwitcherSheet(
        currentBranch: currentBranch,
        onBranchSelected: (branch) => Navigator.pop(context, branch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: FlexColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.corporate_fare, color: FlexColors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Switch Branch / Entity',
                  style: FlexTypography.headlineMd,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select an active multi-company subsidiary in Sri Lanka. Data scopes and permissions will adjust immediately.',
              style: FlexTypography.bodySm,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...sriLankaBranches.map((branch) {
              final isSelected = branch.id == currentBranch.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? FlexColors.surfaceRaisedDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? FlexColors.primary : FlexColors.borderDark,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    branch.name,
                    style: FlexTypography.labelLg.copyWith(
                      color: isSelected ? FlexColors.primaryLight : FlexColors.textPrimaryDark,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          branch.city,
                          style: FlexTypography.bodySm,
                        ),
                        const SizedBox(width: 8),
                        FlexBadge(
                          text: branch.code,
                          variant: isSelected ? FlexBadgeVariant.info : FlexBadgeVariant.neutral,
                        ),
                      ],
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: FlexColors.primary)
                      : null,
                  onTap: () => onBranchSelected(branch),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
