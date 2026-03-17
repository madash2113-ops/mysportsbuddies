import 'package:flutter/material.dart';

/// ── MySportsBuddies Design System v1.0 ────────────────────────────────────
/// Dark theme — "Void" green-black palette with "Flame" red brand accent

class AppColors {
  // Backgrounds
  static const Color background  = Color(0xFF000F08); // Void
  static const Color surface     = Color(0xFF060C05);
  static const Color card        = Color(0xFF161E15);

  // Brand
  static const Color primary     = Color(0xFFFB3640); // Flame

  // Text
  static const Color textPrimary = Color(0xFFF0F5F0); // on-background
  static const Color textMuted   = Color(0xFFA8B5A7); // on-surface

  // Borders / dividers
  static const Color border      = Color(0xFF5C6B5B); // outline

  // Semantic
  static const Color error       = Color(0xFFD42530);
  static const Color success     = Color(0xFF34C759);
  static const Color warning     = Color(0xFFFF9500);
}

/// ── Light theme palette ────────────────────────────────────────────────────
class AppColorsLight {
  // Backgrounds
  static const Color background  = Color(0xFFF4F4F5);
  static const Color card        = Color(0xFFFFFFFF);
  static const Color surface     = Color(0xFFFFFFFF);

  // Brand — same Flame red across both themes
  static const Color primary     = Color(0xFFFB3640);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textMuted   = Color(0xFF6B7280);

  // Borders / dividers
  static const Color border      = Color(0x14000000); // black 8%

  // Semantic
  static const Color error       = Color(0xFFD42530);
  static const Color success     = Color(0xFF34C759);
  static const Color warning     = Color(0xFFFF9500);
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
