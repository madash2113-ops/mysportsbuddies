import 'package:flutter/material.dart';

/// ── MySportsBuddies Design System v1.1 ────────────────────────────────────
/// Dark theme — "Void" green-black palette with "Flame" red brand accent

class AppColors {
  // Backgrounds
  static const Color background  = Color(0xFF000F08); // Void
  static const Color surface     = Color(0xFF060C05);
  static const Color card        = Color(0xFF161E15);

  // Brand
  static const Color primary     = Color(0xFFFB3640); // Flame
  static const Color textOnPrimary = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFFF0F5F0); // on-background
  static const Color textMuted   = Color(0xFFA8B5A7); // on-surface
  static const Color textHint    = Color(0xFF7A8A79); // placeholder / disabled

  // Borders / dividers
  static const Color border      = Color(0xFF5C6B5B); // outline

  // Semantic
  static const Color error       = Color(0xFFD42530);
  static const Color success     = Color(0xFF34C759);
  static const Color warning     = Color(0xFFFF9500);
  static const Color info        = Color(0xFF2196F3);

  // Nav / chrome
  static const Color navBar      = Color(0xFF060C05); // bottom nav bg
  static const Color navUnselected = Color(0x61FFFFFF); // white38 equivalent
}

/// ── Light theme palette ────────────────────────────────────────────────────
class AppColorsLight {
  // Backgrounds
  static const Color background  = Color(0xFFF4F4F5);
  static const Color card        = Color(0xFFFFFFFF);
  static const Color surface     = Color(0xFFFFFFFF);

  // Brand — same Flame red across both themes
  static const Color primary     = Color(0xFFFB3640);
  static const Color textOnPrimary = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textMuted   = Color(0xFF6B7280);
  static const Color textHint    = Color(0xFF9CA3AF); // placeholder / disabled

  // Borders / dividers
  static const Color border      = Color(0x14000000); // black 8%

  // Semantic
  static const Color error       = Color(0xFFD42530);
  static const Color success     = Color(0xFF34C759);
  static const Color warning     = Color(0xFFFF9500);
  static const Color info        = Color(0xFF1976D2);

  // Nav / chrome
  static const Color navBar      = Colors.white;
  static const Color navUnselected = Color(0x61000000); // black38 equivalent
}

/// Resolves the correct color set from the current [BuildContext] brightness.
class AppC {
  static Color bg(BuildContext ctx)           => _d(ctx) ? AppColors.background     : AppColorsLight.background;
  static Color card(BuildContext ctx)         => _d(ctx) ? AppColors.card           : AppColorsLight.card;
  static Color surface(BuildContext ctx)      => _d(ctx) ? AppColors.surface        : AppColorsLight.surface;
  static Color primary(BuildContext ctx)      => _d(ctx) ? AppColors.primary        : AppColorsLight.primary;
  static Color onPrimary(BuildContext ctx)    => _d(ctx) ? AppColors.textOnPrimary  : AppColorsLight.textOnPrimary;
  static Color text(BuildContext ctx)         => _d(ctx) ? AppColors.textPrimary    : AppColorsLight.textPrimary;
  static Color muted(BuildContext ctx)        => _d(ctx) ? AppColors.textMuted      : AppColorsLight.textMuted;
  static Color hint(BuildContext ctx)         => _d(ctx) ? AppColors.textHint       : AppColorsLight.textHint;
  static Color border(BuildContext ctx)       => _d(ctx) ? AppColors.border         : AppColorsLight.border;
  static Color error(BuildContext ctx)        => _d(ctx) ? AppColors.error          : AppColorsLight.error;
  static Color success(BuildContext ctx)      => _d(ctx) ? AppColors.success        : AppColorsLight.success;
  static Color warning(BuildContext ctx)      => _d(ctx) ? AppColors.warning        : AppColorsLight.warning;
  static Color info(BuildContext ctx)         => _d(ctx) ? AppColors.info           : AppColorsLight.info;
  static Color navBar(BuildContext ctx)       => _d(ctx) ? AppColors.navBar         : AppColorsLight.navBar;
  static Color navUnselected(BuildContext ctx)=> _d(ctx) ? AppColors.navUnselected  : AppColorsLight.navUnselected;

  static bool isDark(BuildContext ctx) => _d(ctx);

  static bool _d(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;
}
