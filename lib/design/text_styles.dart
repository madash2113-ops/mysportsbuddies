import 'package:flutter/material.dart';
import 'colors.dart';

class AppText {
  static const heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const muted = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );
}
