import 'package:flutter/material.dart';
import '../theme/flex_colors.dart';
import '../theme/flex_typography.dart';

enum FlexButtonVariant { primary, secondary, danger, outline }

/// Stitch enterprise action button with 12px radius, micro-animations, and loading spinners.
class FlexButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FlexButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;

  const FlexButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FlexButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.height = 44,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;
    Gradient? gradient;
    List<BoxShadow>? shadows;

    switch (variant) {
      case FlexButtonVariant.primary:
        bgColor = FlexColors.primary;
        textColor = Colors.white;
        gradient = FlexColors.primaryGradient;
        shadows = [
          BoxShadow(
            color: FlexColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case FlexButtonVariant.secondary:
        bgColor = FlexColors.surfaceRaisedDark;
        textColor = FlexColors.textPrimaryDark;
        border = Border.all(color: FlexColors.cardBorder);
        break;
      case FlexButtonVariant.danger:
        bgColor = FlexColors.dangerBg;
        textColor = FlexColors.danger;
        border = Border.all(color: FlexColors.danger.withValues(alpha: 0.3));
        break;
      case FlexButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = FlexColors.primaryLight;
        border = Border.all(color: FlexColors.primary, width: 1.2);
        break;
    }

    final isEnabled = onPressed != null && !isLoading;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isEnabled ? shadows : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: gradient == null ? (isEnabled ? bgColor : bgColor.withValues(alpha: 0.4)) : null,
              gradient: isEnabled ? gradient : null,
              border: border,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: textColor),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: FlexTypography.labelLg.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
