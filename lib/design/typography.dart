import 'package:flutter/material.dart';
import 'colors.dart';

/// Theme-aware text styles for MySportsBuddies.
///
/// Usage: `AppTextStyles.headingLg(context)` — returns a [TextStyle] that
/// automatically picks the correct color for the current brightness.
///
/// All sizes follow Work Sans (set globally in theme.dart).
class AppTextStyles {
  // ── Display ──────────────────────────────────────────────────────────────
  static TextStyle displayLg(BuildContext ctx) => TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800, color: AppC.text(ctx),
  );
  static TextStyle displayMd(BuildContext ctx) => TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppC.text(ctx),
  );

  // ── Headings ─────────────────────────────────────────────────────────────
  static TextStyle headingLg(BuildContext ctx) => TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppC.text(ctx),
  );
  static TextStyle headingMd(BuildContext ctx) => TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppC.text(ctx),
  );
  static TextStyle headingSm(BuildContext ctx) => TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppC.text(ctx),
  );

  // ── Body ─────────────────────────────────────────────────────────────────
  static TextStyle bodyLg(BuildContext ctx) => TextStyle(
    fontSize: 15, fontWeight: FontWeight.w500, color: AppC.text(ctx),
  );
  static TextStyle bodyMd(BuildContext ctx) => TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppC.text(ctx),
  );
  static TextStyle bodySm(BuildContext ctx) => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppC.text(ctx),
  );

  // ── Caption / Label ──────────────────────────────────────────────────────
  static TextStyle caption(BuildContext ctx) => TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppC.muted(ctx),
  );
  static TextStyle label(BuildContext ctx) => TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600, color: AppC.muted(ctx),
  );

  // ── Legacy static styles (dark-only, for backward compat) ───────────────
  static const TextStyle heading = TextStyle(
    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textPrimary,
  );
  static const TextStyle muted = TextStyle(
    fontSize: 12, color: AppColors.textMuted,
  );
}
