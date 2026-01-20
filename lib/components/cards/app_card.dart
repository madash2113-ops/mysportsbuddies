import 'package:flutter/material.dart';

class AppColors {
  // ──────────────────────────
  // BACKGROUNDS
  // ──────────────────────────
  static const Color background = Color(0xFF000000); // App background
  static const Color surface = Color(0xFF0F0F0F);    // Scaffold / sheets
  static const Color card = Color(0xFF1A1A1A);       // Cards

  // ──────────────────────────
  // PRIMARY ACCENT
  // ──────────────────────────
  static const Color primary = Color(0xFFE10600);    // Red accent

  // ──────────────────────────
  // TEXT
  // ──────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color textMuted = Color(0xFF999999);

  // ──────────────────────────
  // BORDERS & DIVIDERS
  // ──────────────────────────
  static const Color border = Color.fromRGBO(255, 255, 255, 0.10);

  // ──────────────────────────
  // STATUS COLORS
  // ──────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F);
  static const Color error = Color(0xFFE74C3C);
}
