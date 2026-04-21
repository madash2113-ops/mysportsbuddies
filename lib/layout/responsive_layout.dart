import 'package:flutter/material.dart';

import '../design/colors.dart';

class ResponsiveLayout {
  static const double mobile = 720;
  static const double tablet = 1080;
  static const double contentMaxWidth = 1240;
  static const double authPanelWidth = 520;
  static const double sideNavWidth = 280;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static double contentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (isDesktop(context)) {
      return width.clamp(0, contentMaxWidth).toDouble();
    }
    if (isTablet(context)) {
      return width.clamp(0, 920).toDouble();
    }
    return width;
  }
}

class ResponsivePagePadding extends StatelessWidget {
  final Widget child;

  const ResponsivePagePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final horizontal = ResponsiveLayout.isDesktop(context)
        ? 32.0
        : ResponsiveLayout.isTablet(context)
        ? 24.0
        : 16.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: child,
    );
  }
}

class ResponsiveCenteredContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveCenteredContent({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = maxWidth ?? ResponsiveLayout.contentWidth(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

class AuthResponsiveScaffold extends StatelessWidget {
  final Widget hero;
  final Widget panel;
  final PreferredSizeWidget? appBar;

  const AuthResponsiveScaffold({
    super.key,
    required this.hero,
    required this.panel,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = ResponsiveLayout.isMobile(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF020906),
              AppColors.background,
              const Color(0xFF150406),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: mobile
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: panel,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1380),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Expanded(child: hero),
                              const SizedBox(width: 24),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: ResponsiveLayout.authPanelWidth,
                                ),
                                child: panel,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class AuthHeroPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final IconData icon;

  const AuthHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.03),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 28),
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE0999F),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: bullets
                .map(
                  (bullet) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  final Widget? side;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? mobileDrawer;
  final Widget? mobileBottomNavigationBar;

  const AppShell({
    super.key,
    required this.child,
    this.side,
    this.appBar,
    this.backgroundColor,
    this.mobileDrawer,
    this.mobileBottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = ResponsiveLayout.isDesktop(context);
    return Scaffold(
      backgroundColor: backgroundColor ?? AppC.bg(context),
      drawer: desktop ? null : mobileDrawer,
      appBar: desktop ? null : appBar,
      bottomNavigationBar: desktop ? null : mobileBottomNavigationBar,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (desktop && side != null)
              Container(
                width: ResponsiveLayout.sideNavWidth,
                margin: const EdgeInsets.all(20),
                child: side,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 0 : 0,
                  desktop ? 20 : 0,
                  desktop ? 20 : 0,
                  0,
                ),
                child: Column(
                  children: [
                    if (desktop && appBar != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: appBar!,
                      ),
                    if (desktop && appBar != null) const SizedBox(height: 20),
                    Expanded(child: ResponsiveCenteredContent(child: child)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
