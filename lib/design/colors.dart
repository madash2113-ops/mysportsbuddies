import 'package:flutter/material.dart';

/// ── Dark theme palette (Black + Red) ──────────────────────────────────────
class AppColors {
  // Backgrounds
  static const Color background  = Color(0xFF0A0A0A); // Warm near-black
  static const Color card        = Color(0xFF161616);
  static const Color surface     = Color(0xFF1E1E1E);

  // Brand
  static const Color primary     = Color(0xFFE10600); // Vivid red

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted   = Color(0xFF888888);

  // Borders / dividers
  static const Color border      = Color(0x1AFFFFFF); // white 10%
}

/// ── Light theme palette (Clean White + Red) ────────────────────────────────
class AppColorsLight {
  // Backgrounds
  static const Color background  = Color(0xFFF4F4F5); // Clean light gray
  static const Color card        = Color(0xFFFFFFFF); // Pure white cards
  static const Color surface     = Color(0xFFFFFFFF); // White

  // Brand
  static const Color primary     = Color(0xFFD32F2F); // Material Red 700

  // Text
  static const Color textPrimary = Color(0xFF111827); // Near-black
  static const Color textMuted   = Color(0xFF6B7280); // Cool gray

  // Borders / dividers
  static const Color border      = Color(0x14000000); // black 8%
}

/// Resolves the correct color set from the current [BuildContext] brightness.
class AppC {
  static Color bg(BuildContext ctx)      => _d(ctx) ? AppColors.background  : AppColorsLight.background;
  static Color card(BuildContext ctx)    => _d(ctx) ? AppColors.card        : AppColorsLight.card;
  static Color surface(BuildContext ctx) => _d(ctx) ? AppColors.surface     : AppColorsLight.surface;
  static Color primary(BuildContext ctx) => _d(ctx) ? AppColors.primary     : AppColorsLight.primary;
  static Color text(BuildContext ctx)    => _d(ctx) ? AppColors.textPrimary : AppColorsLight.textPrimary;
  static Color muted(BuildContext ctx)   => _d(ctx) ? AppColors.textMuted   : AppColorsLight.textMuted;
  static Color border(BuildContext ctx)  => _d(ctx) ? AppColors.border      : AppColorsLight.border;

  static bool _d(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;
}
