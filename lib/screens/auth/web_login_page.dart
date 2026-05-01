import 'package:flutter/material.dart';

import '../../design/colors.dart';

// ── Design tokens (shared with web_landing_page.dart) ─────────────────────────
const _bg = Color(0xFF080808);
const _surface = Color(0xFF0F0F0F);
const _card = Color(0xFF161616);
const _bd = Color(0xFF1E1E1E);
const _bd2 = Color(0xFF2A2A2A);
const _tx = Color(0xFFF0F0F0);
const _muted = Color(0xFF888888);
const _red = Color(0xFFFB3640);
const _redDark = Color(0xFF8B0000);

// ── Entry widget ──────────────────────────────────────────────────────────────
class WebLoginPage extends StatefulWidget {
  final String pendingRole;
  final bool googleLoading;
  final String? error;
  final VoidCallback onGoogleSignIn;

  const WebLoginPage({
    super.key,
    required this.pendingRole,
    required this.googleLoading,
    required this.error,
    required this.onGoogleSignIn,
  });

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  final _cursor = ValueNotifier<Offset>(const Offset(-9999, -9999));

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    // _cursor is a ValueNotifier<Offset> — no native resources, no explicit dispose needed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formOffsetX = constraints.maxWidth >= 1200
            ? 454.0
            : constraints.maxWidth >= 900
            ? 120.0
            : 0.0;

        return Scaffold(
          backgroundColor: _bg,
          body: MouseRegion(
            onHover: (e) => _cursor.value = e.localPosition,
            onExit: (_) => _cursor.value = const Offset(-9999, -9999),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Hero fills the entire background ────────────────────────
                _HeroPanel(role: widget.pendingRole, glowAnim: _glow),

                // ── Floating form card — shifted right on wide screens ─────
                Center(
                  child: Transform.translate(
                    offset: Offset(formOffsetX, 0),
                    child: Container(
                      width: 420,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _bd2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 60,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: _FormPanel(
                        role: widget.pendingRole,
                        googleLoading: widget.googleLoading,
                        error: widget.error,
                        onGoogle: widget.onGoogleSignIn,
                      ),
                    ),
                  ),
                ),

                // ── Cursor spotlight ────────────────────────────────────────
                ValueListenableBuilder<Offset>(
                  valueListenable: _cursor,
                  builder: (_, pos, _) => Positioned(
                    left: pos.dx - 300,
                    top: pos.dy - 300,
                    width: 600,
                    height: 600,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.045),
                              _red.withValues(alpha: 0.018),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Left hero panel ───────────────────────────────────────────────────────────
class _HeroPanel extends StatelessWidget {
  final String role;
  final Animation<double> glowAnim;

  const _HeroPanel({required this.role, required this.glowAnim});

  bool get _isMerchant => role == 'merchant';
  Color get _accent => _isMerchant ? const Color(0xFF7986CB) : _red;
  Color get _accentDeep => _isMerchant ? const Color(0xFF1A237E) : _redDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Grid background
        CustomPaint(painter: _GridPainter()),

        // Ambient glow — top-left
        Positioned(
          top: -120,
          left: -100,
          child: AnimatedBuilder(
            animation: glowAnim,
            builder: (_, _) => Container(
              width: 640,
              height: 640,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (_isMerchant ? const Color(0xFF3949AB) : _red).withValues(
                      alpha: 0.18 + glowAnim.value * 0.08,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Ambient glow — bottom-right
        Positioned(
          bottom: -80,
          right: -60,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (_isMerchant
                          ? const Color(0xFF1A237E)
                          : const Color(0xFF781A20))
                      .withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main content
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(64, 52, 100, 52),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Logo row ───────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isMerchant
                                ? [
                                    const Color(0xFF1A237E),
                                    const Color(0xFF3949AB),
                                  ]
                                : [_redDark, _red],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isMerchant ? const Color(0xFF3949AB) : _red)
                                      .withValues(alpha: 0.35),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'MySports',
                              style: TextStyle(
                                color: _tx,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: 'Buddies',
                              style: TextStyle(
                                color: _red,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: _bd2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.018),
                          _accentDeep.withValues(alpha: 0.14),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 40,
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -40,
                          left: -60,
                          child: Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _accent.withValues(alpha: 0.16),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 72,
                          right: 56,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _accent.withValues(alpha: 0.28),
                                  _accentDeep.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              _isMerchant
                                  ? Icons.workspace_premium_rounded
                                  : Icons.military_tech_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(36, 34, 36, 34),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Role badge ────────────────────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_isMerchant
                                              ? const Color(0xFF1A237E)
                                              : _red)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color:
                                        (_isMerchant
                                                ? const Color(0xFF3949AB)
                                                : _red)
                                            .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isMerchant
                                          ? Icons.storefront_rounded
                                          : Icons.sports_soccer_rounded,
                                      color: _isMerchant
                                          ? const Color(0xFF7986CB)
                                          : _red,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      _isMerchant ? 'VENUE OWNER' : 'PLAYER',
                                      style: TextStyle(
                                        color: _isMerchant
                                            ? const Color(0xFF7986CB)
                                            : _red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _isMerchant
                                    ? 'Manage venues.\nDelight players.\nGrow revenue.'
                                    : 'Find games.\nMeet players.\nPlay more.',
                                style: const TextStyle(
                                  color: _tx,
                                  fontSize: 54,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.8,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 680,
                                ),
                                child: Text(
                                  _isMerchant
                                      ? 'The all-in-one dashboard for venue owners. List your courts, manage bookings, and create a premium experience players return to.'
                                      : 'Join thousands of athletes across India discovering pickup games, entering tournaments, and staying closer to the sport they actually play.',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 15,
                                    height: 1.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _isMerchant
                                    ? const [
                                        _HeroFeaturePill(
                                          icon: Icons.calendar_month_rounded,
                                          label: 'Real-time bookings',
                                        ),
                                        _HeroFeaturePill(
                                          icon: Icons.payments_outlined,
                                          label: 'Faster payouts',
                                        ),
                                        _HeroFeaturePill(
                                          icon: Icons.groups_rounded,
                                          label: 'Loyal player base',
                                        ),
                                      ]
                                    : const [
                                        _HeroFeaturePill(
                                          icon: Icons.flash_on_rounded,
                                          label: 'Instant game alerts',
                                        ),
                                        _HeroFeaturePill(
                                          icon: Icons.emoji_events_outlined,
                                          label: 'Join tournaments',
                                        ),
                                        _HeroFeaturePill(
                                          icon: Icons.scoreboard_outlined,
                                          label: 'Track live scores',
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _isMerchant
                        ? [
                            _StatChip(value: '500+', label: 'Venues'),
                            _StatChip(value: '10K+', label: 'Bookings/mo'),
                            _StatChip(value: '50+', label: 'Cities'),
                          ]
                        : [
                            _StatChip(value: '50K+', label: 'Players'),
                            _StatChip(value: '500+', label: 'Games/week'),
                            _StatChip(value: '15+', label: 'Sports'),
                          ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'All systems operational',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroFeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _bd2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _tx),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _tx,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Right form panel ──────────────────────────────────────────────────────────
class _FormPanel extends StatelessWidget {
  final String role;
  final bool googleLoading;
  final String? error;
  final VoidCallback onGoogle;

  const _FormPanel({
    required this.role,
    required this.googleLoading,
    required this.error,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back link ────────────────────────────────────────────────
          GestureDetector(
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/role-picker'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new_rounded, color: _muted, size: 12),
                SizedBox(width: 6),
                Text(
                  'Change role',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // ── Heading ──────────────────────────────────────────────────
          const Text(
            'Welcome back',
            style: TextStyle(
              color: _tx,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to continue to your account.',
            style: TextStyle(color: _muted, fontSize: 13.5, height: 1.5),
          ),

          const SizedBox(height: 32),

          // ── Google — primary CTA ──────────────────────────────────────
          _FilledAuthButton(
            label: 'Continue with Google',
            icon: Icons.g_mobiledata,
            loading: googleLoading,
            onPressed: googleLoading ? null : onGoogle,
          ),

          const SizedBox(height: 20),

          // ── "or" divider ──────────────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider(color: _bd2, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: _bd2, thickness: 1)),
            ],
          ),

          const SizedBox(height: 20),

          // ── Email ────────────────────────────────────────────────────
          _OutlinedAuthButton(
            label: 'Continue with Email',
            icon: Icons.email_outlined,
            onPressed: () => Navigator.pushNamed(context, '/email-login'),
          ),

          // ── Error ────────────────────────────────────────────────────
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _red.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _red,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: _red,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),
          const Divider(color: _bd, thickness: 1),
          const SizedBox(height: 20),

          // ── Register link ─────────────────────────────────────────────
          Row(
            children: [
              const Text(
                "Don't have an account?",
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/register-user'),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: _red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'By continuing you agree to our Terms of Service\nand Privacy Policy.',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 11,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _tx,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── M3 Auth buttons ───────────────────────────────────────────────────────────
//
// Primary  → FilledButton  (M3 tonal filled, StadiumBorder, 48dp)
// Secondary→ OutlinedButton (M3 outlined, StadiumBorder, 48dp)
// Ghost    → TextButton    (M3 text, StadiumBorder, 48dp)
//
// All buttons use:
//   • Shape   : StadiumBorder (M3 "full" shape token = fully rounded pill)
//   • Height  : 48dp (4dp above M3 minimum for web accessibility)
//   • Label   : labelLarge — 14sp, weight 500, letterSpacing 0.1
//   • Padding : 24dp horizontal (M3 button spec)

const _m3LabelLarge = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
);

class _FilledAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  const _FilledAuthButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style:
            FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _red.withValues(alpha: 0.4),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: _m3LabelLarge,
              elevation: 0,
            ).copyWith(
              overlayColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.08),
              ),
            ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Text(label, style: _m3LabelLarge),
                ],
              ),
      ),
    );
  }
}

class _OutlinedAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _OutlinedAuthButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: _tx,
              shape: const StadiumBorder(),
              side: const BorderSide(color: _bd2, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyle: _m3LabelLarge,
            ).copyWith(
              overlayColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.05),
              ),
            ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(label, style: _m3LabelLarge),
          ],
        ),
      ),
    );
  }
}

// ── Subtle grid background ────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF141414)
      ..strokeWidth = 0.6;

    const step = 52.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
