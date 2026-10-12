import 'package:flutter/material.dart';
import '../theme/flex_colors.dart';
import '../theme/flex_typography.dart';

enum FlexBadgeVariant { neutral, success, warning, danger, info }

/// Stitch Status Pill Badge (9999px radius, uppercase label-sm, tinted backgrounds).
class FlexBadge extends StatelessWidget {
  final String text;
  final FlexBadgeVariant variant;
  final IconData? icon;

  const FlexBadge({
    super.key,
    required this.text,
    this.variant = FlexBadgeVariant.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (variant) {
      case FlexBadgeVariant.neutral:
        bg = FlexColors.surfaceContainerHighest;
        fg = FlexColors.textSecondaryDark;
        break;
      case FlexBadgeVariant.success:
        bg = FlexColors.successBg;
        fg = FlexColors.success;
        break;
      case FlexBadgeVariant.warning:
        bg = FlexColors.warningBg;
        fg = FlexColors.warning;
        break;
      case FlexBadgeVariant.danger:
        bg = FlexColors.dangerBg;
        fg = FlexColors.danger;
        break;
      case FlexBadgeVariant.info:
        bg = FlexColors.infoBg;
        fg = FlexColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: FlexTypography.labelSm.copyWith(
              color: fg,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
