import 'package:flutter/material.dart';
import '../theme/flex_colors.dart';

/// Stitch Level 1 Card container with 16px corner radius and hairline border.
class FlexCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final double radius;
  final bool hasShadow;

  const FlexCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.radius = 16,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final cardDecoration = BoxDecoration(
      color: gradient != null ? null : (backgroundColor ?? FlexColors.surfaceDark),
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: FlexColors.cardBorder, width: 1),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: FlexColors.primary.withValues(alpha: 0.15),
          highlightColor: FlexColors.primary.withValues(alpha: 0.08),
          child: Container(
            padding: padding,
            decoration: cardDecoration,
            child: child,
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: cardDecoration,
      child: child,
    );
  }
}
