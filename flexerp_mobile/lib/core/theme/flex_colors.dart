import 'package:flutter/material.dart';

/// FlexERP Design System Colors (grounded in Stitch Enterprise tokens & modern dark aesthetics)
class FlexColors {
  // Canvas & Backgrounds (Dark Mode Default - Deep Obsidian / Midnight Slate)
  static const Color canvasDark = Color(0xFF0A0F1D);
  static const Color surfaceDark = Color(0xFF131D2E);
  static const Color surfaceRaisedDark = Color(0xFF1A263D);
  static const Color surfaceContainerHigh = Color(0xFF22314C);
  static const Color surfaceContainerHighest = Color(0xFF2C3E5E);
  
  // Canvas & Backgrounds (Light Mode)
  static const Color canvasLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF1F5F9);
  
  // Brand & Primaries (Electric Indigo / Violet)
  static const Color primary = Color(0xFF6366F1); // Luminous Electric Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryContainer = Color(0xFF312E81);
  static const Color primaryGlow = Color(0x336366F1);
  
  // Secondary & Accents
  static const Color secondary = Color(0xFF0F172A); // Slate Core
  static const Color secondaryMuted = Color(0xFF94A3B8);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentViolet = Color(0xFF8B5CF6);
  
  // Semantic Feedback
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successBg = Color(0x1F10B981);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningBg = Color(0x1FF59E0B);
  static const Color danger = Color(0xFFEF4444); // Coral Red
  static const Color dangerBg = Color(0x1FEF4444);
  static const Color info = Color(0xFF38BDF8); // Sky Blue
  static const Color infoBg = Color(0x1F38BDF8);

  // Borders & Dividers
  static const Color borderDark = Color(0x1AFFFFFF); // Crisp 10% translucent white hairline
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFF464555);

  // Typography Colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // Pure white high-contrast
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Cool Slate
  static const Color textDisabledDark = Color(0xFF64748B); // Charcoal Slate
  
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Modern Theme Aliases
  static const Color background = canvasDark;
  static const Color surface = surfaceDark;
  static const Color cardBorder = borderDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color error = danger;
  static const Color dangerLight = Color(0xFFFCA5A5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF16233B), Color(0xFF111A2B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient executiveGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

