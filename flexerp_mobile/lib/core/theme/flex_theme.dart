import 'package:flutter/material.dart';
import 'flex_colors.dart';
import 'flex_typography.dart';

/// FlexERP ThemeData builder for Material 3.
/// Configured with Stitch Dark Canvas as the primary enterprise aesthetic.
class FlexTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FlexColors.canvasDark,
      primaryColor: FlexColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: FlexColors.primary,
        onPrimary: Colors.white,
        primaryContainer: FlexColors.primaryContainer,
        secondary: FlexColors.secondary,
        onSecondary: Colors.white,
        surface: FlexColors.surfaceDark,
        onSurface: FlexColors.textPrimaryDark,
        error: FlexColors.danger,
        onError: Colors.white,
        outline: FlexColors.cardBorder,
      ),
      fontFamily: FlexTypography.fontFamily,
      cardTheme: CardThemeData(
        color: FlexColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FlexColors.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FlexColors.canvasDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: FlexTypography.headlineMd,
        iconTheme: IconThemeData(color: FlexColors.textPrimaryDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FlexColors.surfaceDark,
        selectedItemColor: FlexColors.primaryLight,
        unselectedItemColor: FlexColors.textDisabledDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FlexColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlexColors.cardBorder, width: 1),
        ),
        elevation: 16,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FlexColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: FlexColors.cardBorder, width: 1),
        ),
        showDragHandle: true,
        dragHandleColor: FlexColors.cardBorder,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FlexColors.surfaceRaisedDark,
        contentTextStyle: const TextStyle(color: FlexColors.textPrimaryDark, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FlexColors.cardBorder, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FlexColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FlexColors.surfaceRaisedDark,
        selectedColor: FlexColors.primaryContainer,
        side: const BorderSide(color: FlexColors.cardBorder, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 12, color: FlexColors.textSecondaryDark),
      ),
      dividerTheme: const DividerThemeData(
        color: FlexColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FlexColors.surfaceRaisedDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: FlexTypography.bodyMd.copyWith(color: FlexColors.textDisabledDark),
        labelStyle: FlexTypography.labelMd.copyWith(color: FlexColors.textSecondaryDark),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlexColors.cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlexColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlexColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlexColors.danger, width: 1.5),
        ),
      ),
    );
  }
}
