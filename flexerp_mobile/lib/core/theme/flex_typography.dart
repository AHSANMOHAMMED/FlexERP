import 'package:flutter/material.dart';
import 'flex_colors.dart';

/// FlexERP Typography tokens grounded in the Stitch design system.
/// Uses Inter font with tabular figures for high-density enterprise numbers.
class FlexTypography {
  static const String? fontFamily = null;

  // Headlines
  static const TextStyle headlineXl = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    letterSpacing: -0.56,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
    letterSpacing: -0.33,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    letterSpacing: -0.18,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    letterSpacing: -0.08,
    color: FlexColors.textPrimaryDark,
  );

  // Body
  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    letterSpacing: 0,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0.12,
    color: FlexColors.textSecondaryDark,
  );

  // Labels
  static const TextStyle labelLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    letterSpacing: 0.14,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 16 / 13,
    letterSpacing: 0,
    color: FlexColors.textPrimaryDark,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.44,
    color: FlexColors.textSecondaryDark,
  );

  // High-density numeric code/money style with tabular figures
  static const TextStyle codeNum = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 16 / 13,
    letterSpacing: -0.13,
    color: FlexColors.textPrimaryDark,
  );
}
