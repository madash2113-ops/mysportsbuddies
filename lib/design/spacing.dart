import 'package:flutter/material.dart';

class AppSpacing {
  // 4px base spacing system
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Standard border radius values — brand guideline: 12-16px default.
class AppRadius {
  static const double sm  = 8;   // chips, small badges, tags
  static const double md  = 12;  // buttons, inputs, standard cards
  static const double lg  = 16;  // large cards, sport pills, modals
  static const double xl  = 24;  // bottom sheets, full-width panels

  // Pre-built BorderRadius for convenience
  static final BorderRadius smAll  = BorderRadius.circular(sm);
  static final BorderRadius mdAll  = BorderRadius.circular(md);
  static final BorderRadius lgAll  = BorderRadius.circular(lg);
  static final BorderRadius xlAll  = BorderRadius.circular(xl);
}
