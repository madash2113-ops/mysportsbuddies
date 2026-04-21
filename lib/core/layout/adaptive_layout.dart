import 'package:flutter/material.dart';

// Switch between mobile and web layouts at this width.
const double kWebBreakpoint = 800;

class AdaptiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget web;

  const AdaptiveLayout({super.key, required this.mobile, required this.web});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) =>
          constraints.maxWidth >= kWebBreakpoint ? web : mobile,
    );
  }
}
