import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'auth_router.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg      = Color(0xFF030303);
const _panelR  = Color(0xFF0B0B0B);
const _tx      = Color(0xFFF2F2F2);
const _m1      = Color(0xFF888888);
const _red     = Color(0xFFFF2B2B);
const _redDeep = Color(0xFFB3001B);

// ──────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  String? _activeMethod; // 'phone' | 'email' | null
  bool    _googleLoading = false;
  bool    _obscurePass   = true;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..forward();

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    final ok = await AuthService().signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() { _googleLoading = false; _error = AuthService().error; });
    }
  }

  void _submitPhone() {
    final n = _phoneCtrl.text.trim();
    if (n.isEmpty) return;
    Navigator.pushNamed(context, '/phone-login', arguments: n);
  }

  void _submitEmail() {
    Navigator.pushNamed(context, '/email-login',
        arguments: _emailCtrl.text.trim());
  }

  void _toggle(String method) => setState(() {
        _activeMethod = _activeMethod == method ? null : method;
        _error = null;
      });

  // ── Layout router ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (_, c) => c.maxWidth >= 900
            ? _webLayout(context)
            : _mobileLayout(context),
      ),
    );
  }

  // ── Web: two-column split ─────────────────────────────────────────────────

  Widget _webLayout(BuildContext context) {
    return Row(children: [
      const Expanded(flex: 55, child: _LeftPanel()),
      Expanded(flex: 45, child: _rightPanel(context)),
    ]);
  }

  // ── Mobile: single-column ─────────────────────────────────────────────────

  Widget _mobileLayout(BuildContext context) {
    return Stack(children: [
      Positioned(top: -100, left: -100,
          child: _GlowOrb(400, _red.withValues(alpha: .12))),
      Positioned(bottom: -60, right: -80,
          child: _GlowOrb(300, _red.withValues(alpha: .08))),
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 16),
            _mobileTopRow(context),
            const SizedBox(height: 44),
            const _MobileBrand(),
            const SizedBox(height: 36),
            _authForm(context),
            const SizedBox(height: 28),
            _signUpRow(context),
            const SizedBox(height: 14),
            _termsText(),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    ]);
  }

  // ── Right auth panel (web) ─────────────────────────────────────────────────

  Widget _rightPanel(BuildContext context) {
    return Container(
      color: _panelR,
      child: Stack(children: [
        Positioned(bottom: -80, right: -80,
            child: _GlowOrb(360, _red.withValues(alpha: .07))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                      parent: _fadeCtrl, curve: Curves.easeOut),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back to site
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                            context, '/web-landing'),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.arrow_back_ios_new,
                              color: _m1, size: 13),
                          const SizedBox(width: 6),
                          const Text('Back to site',
                              style: TextStyle(color: _m1, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 44),

                      // Header
                      const Text('Welcome back 👋',
                          style: TextStyle(
                              color: _tx,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.5)),
                      const SizedBox(height: 6),
                      const Text('Sign in to your account',
                          style: TextStyle(color: _m1, fontSize: 14)),
                      const SizedBox(height: 36),

                      _authForm(context),

                      const SizedBox(height: 28),
                      _signUpRow(context),
                      const SizedBox(height: 14),
                      _termsText(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Shared auth form ───────────────────────────────────────────────────────

  Widget _authForm(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // ── Phone ──────────────────────────────────────────────────────────────
      _MethodBtn(
        label: 'Continue with Phone',
        icon: Icons.phone_android_rounded,
        primary: true,
        active: _activeMethod == 'phone',
        onTap: () => _toggle('phone'),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _activeMethod == 'phone'
            ? _PhoneForm(ctrl: _phoneCtrl, onSend: _submitPhone)
            : const SizedBox.shrink(),
      ),

      const SizedBox(height: 12),

      // ── Email ──────────────────────────────────────────────────────────────
      _MethodBtn(
        label: 'Continue with Email',
        icon: Icons.mail_outline_rounded,
        primary: false,
        active: _activeMethod == 'email',
        onTap: () => _toggle('email'),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _activeMethod == 'email'
            ? _EmailForm(
                emailCtrl: _emailCtrl,
                passCtrl: _passCtrl,
                obscure: _obscurePass,
                onToggleObscure: () =>
                    setState(() => _obscurePass = !_obscurePass),
                onSubmit: _submitEmail,
              )
            : const SizedBox.shrink(),
      ),

      const SizedBox(height: 28),

      // ── Divider ────────────────────────────────────────────────────────────
      Row(children: [
        Expanded(child: Container(height: .8,
            color: Colors.white.withValues(alpha: .07))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or continue with',
              style: TextStyle(
                  color: _m1.withValues(alpha: .6), fontSize: 11)),
        ),
        Expanded(child: Container(height: .8,
            color: Colors.white.withValues(alpha: .07))),
      ]),

      const SizedBox(height: 20),

      // ── Social row ─────────────────────────────────────────────────────────
      Row(children: [
        Expanded(child: _SocialTile(
          label: 'Google',
          icon: Icons.g_mobiledata,
          iconColor: const Color(0xFFEA4335),
          loading: _googleLoading,
          onTap: _googleLoading ? null : _googleSignIn,
        )),
        const SizedBox(width: 12),
        Expanded(child: _SocialTile(
          label: 'Facebook',
          icon: Icons.facebook,
          iconColor: const Color(0xFF1877F2),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Facebook login coming soon!'))),
        )),
      ]),

      // ── Error ──────────────────────────────────────────────────────────────
      if (_error != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red.withValues(alpha: .22)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!,
                style: const TextStyle(color: _red, fontSize: 12))),
          ]),
        ),
      ],
    ]);
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _mobileTopRow(BuildContext context) {
    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, '/welcome'),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_ios_new, color: _m1, size: 13),
          SizedBox(width: 6),
          Text('Back', style: TextStyle(color: _m1, fontSize: 13)),
        ]),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: _red.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(99),
          color: _red.withValues(alpha: .08),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_soccer_rounded, color: _red, size: 12),
          SizedBox(width: 5),
          Text('Player',
              style: TextStyle(
                  color: _red, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    ]);
  }

  Widget _signUpRow(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/register-user'),
        child: const Text.rich(TextSpan(children: [
          TextSpan(text: "Don't have an account?  ",
              style: TextStyle(color: _m1, fontSize: 14)),
          TextSpan(text: 'Sign Up',
              style: TextStyle(
                  color: _red, fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
      ),
    );
  }

  Widget _termsText() {
    return Center(
      child: Text(
        'By continuing you agree to our Terms & Privacy Policy',
        style: TextStyle(
            color: Colors.white.withValues(alpha: .18), fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LEFT VISUAL PANEL
// ══════════════════════════════════════════════════════════════════════════════

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Stack(children: [
        // Faint grid
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),

        // Glow orbs
        Positioned(top: -60, left: -80,
            child: _GlowOrb(480, _red.withValues(alpha: .10))),
        Positioned(bottom: -80, right: -60,
            child: _GlowOrb(380, _redDeep.withValues(alpha: .08))),
        Positioned(top: 0, bottom: 0, left: 0, right: 0,
            child: Center(child: _GlowOrb(600, _red.withValues(alpha: .06)))),

        // Floating sport emojis (decorative)
        const Positioned(top: 90,  left: 52,   child: _FloatEmoji('⚽', 22, .30)),
        const Positioned(top: 200, right: 70,  child: _FloatEmoji('🏏', 20, .22)),
        const Positioned(top: 340, left: 36,   child: _FloatEmoji('🏀', 24, .28)),
        const Positioned(top: 470, right: 48,  child: _FloatEmoji('🎾', 20, .20)),
        const Positioned(top: 600, left: 72,   child: _FloatEmoji('🥊', 22, .22)),
        const Positioned(bottom: 200, right: 56, child: _FloatEmoji('🏊', 20, .18)),
        const Positioned(bottom: 130, left: 44,  child: _FloatEmoji('🏋️', 20, .20)),

        // Main content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 36, 40, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Logo row
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                          colors: [_red, _redDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(
                          color: _red.withValues(alpha: .38), blurRadius: 14)],
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Text.rich(TextSpan(children: [
                    TextSpan(text: 'My',
                        style: TextStyle(color: _tx, fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    TextSpan(text: 'Sports',
                        style: TextStyle(color: _red, fontSize: 14,
                            fontWeight: FontWeight.w900)),
                    TextSpan(text: 'Buddies',
                        style: TextStyle(color: _tx, fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ])),
                ]),

                const Spacer(),

                // Hero headline
                const Text.rich(TextSpan(children: [
                  TextSpan(text: 'Where\n',
                      style: TextStyle(
                          color: _tx, fontSize: 60, fontWeight: FontWeight.w900,
                          height: 1.0, letterSpacing: -2.5)),
                  TextSpan(text: 'Sports\n',
                      style: TextStyle(
                          color: _red, fontSize: 60, fontWeight: FontWeight.w900,
                          height: 1.05, letterSpacing: -2.5)),
                  TextSpan(text: 'Comes Alive',
                      style: TextStyle(
                          color: _tx, fontSize: 60, fontWeight: FontWeight.w900,
                          height: 1.05, letterSpacing: -2.5)),
                ])),

                const SizedBox(height: 20),

                const SizedBox(
                  width: 420,
                  child: Text(
                    "India's #1 Sports Social Platform — discover games, host tournaments, book venues & connect with your sports community.",
                    style: TextStyle(color: _m1, fontSize: 15, height: 1.65),
                  ),
                ),

                const SizedBox(height: 36),

                // Stats
                Row(children: [
                  _StatChip('50K+', 'Players'),
                  const SizedBox(width: 12),
                  _StatChip('5K+', 'Tournaments'),
                  const SizedBox(width: 12),
                  _StatChip('22+', 'Sports'),
                ]),

                const SizedBox(height: 36),

                // Testimonial card
                Container(
                  width: 420,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⭐⭐⭐⭐⭐',
                          style: TextStyle(fontSize: 13, height: 1.2)),
                      const SizedBox(height: 10),
                      const Text(
                        '"Found my cricket team in under 20 minutes. The app is incredible!"',
                        style: TextStyle(color: _tx, fontSize: 14,
                            height: 1.55, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                colors: [_red.withValues(alpha: .8), _redDeep]),
                          ),
                          alignment: Alignment.center,
                          child: const Text('R',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rahul Kumar',
                                style: TextStyle(color: _tx, fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text('Cricketer · Mumbai',
                                style: TextStyle(color: _m1, fontSize: 11)),
                          ],
                        ),
                      ]),
                    ],
                  ),
                ),

                const Spacer(),

                // Made-in-India badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .08)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 8),
                    Text('Made in India',
                        style: TextStyle(color: _m1, fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: _red, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: -.5)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: _m1, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Float emoji ───────────────────────────────────────────────────────────────

class _FloatEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  final double opacity;
  const _FloatEmoji(this.emoji, this.size, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MOBILE BRAND
// ══════════════════════════════════════════════════════════════════════════════

class _MobileBrand extends StatelessWidget {
  const _MobileBrand();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [_red, _redDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [BoxShadow(
              color: Color(0x44FF2B2B), blurRadius: 28, spreadRadius: 3)],
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _bg),
          child: const Icon(Icons.emoji_events_rounded, color: _red, size: 34),
        ),
      ),
      const SizedBox(height: 20),
      const Text.rich(TextSpan(children: [
        TextSpan(text: 'My',
            style: TextStyle(color: _tx, fontSize: 26,
                fontWeight: FontWeight.w800)),
        TextSpan(text: 'Sports',
            style: TextStyle(color: _red, fontSize: 26,
                fontWeight: FontWeight.w900)),
        TextSpan(text: 'Buddies',
            style: TextStyle(color: _tx, fontSize: 26,
                fontWeight: FontWeight.w800)),
      ])),
      const SizedBox(height: 6),
      const Text('Find. Play. Connect.',
          style: TextStyle(color: _m1, fontSize: 13, letterSpacing: .5)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// METHOD BUTTON (phone / email toggles)
// ══════════════════════════════════════════════════════════════════════════════

class _MethodBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final bool active;
  final VoidCallback onTap;
  const _MethodBtn({
    required this.label, required this.icon, required this.primary,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [_red, _redDeep],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
              : null,
          color: primary ? null : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(
                  color: active
                      ? _red.withValues(alpha: .5)
                      : Colors.white.withValues(alpha: .1)),
          boxShadow: primary
              ? [BoxShadow(
                  color: _red.withValues(alpha: active ? .45 : .28),
                  blurRadius: active ? 24 : 16,
                  offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: primary
                  ? Colors.white
                  : (active ? _red : _tx.withValues(alpha: .7)),
              size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: primary
                      ? Colors.white
                      : (active ? _red : _tx.withValues(alpha: .85)),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: active ? .5 : 0,
            duration: const Duration(milliseconds: 250),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: primary
                    ? Colors.white.withValues(alpha: .7)
                    : (active ? _red : _m1),
                size: 18),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHONE INLINE FORM
// ══════════════════════════════════════════════════════════════════════════════

class _PhoneForm extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _PhoneForm({required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: .28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Enter your phone number',
            style: TextStyle(
                color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Row(children: [
          // Country code
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('🇮🇳', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text('+91',
                  style: TextStyle(
                      color: _tx, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 10),
          // Number field
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: const TextStyle(color: _tx, fontSize: 15),
              decoration: _inputDeco('Phone number'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _GradientBtn(label: 'Send OTP', icon: Icons.send_rounded, onTap: onSend),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EMAIL INLINE FORM
// ══════════════════════════════════════════════════════════════════════════════

class _EmailForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  const _EmailForm({
    required this.emailCtrl, required this.passCtrl,
    required this.obscure, required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: .28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Enter your email address',
            style: TextStyle(
                color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          style: const TextStyle(color: _tx, fontSize: 15),
          decoration: _inputDeco('Email address'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passCtrl,
          obscureText: obscure,
          style: const TextStyle(color: _tx, fontSize: 15),
          decoration: _inputDeco('Password').copyWith(
            suffixIcon: GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _m1, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _GradientBtn(
            label: 'Sign In', icon: Icons.login_rounded, onTap: onSubmit),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: onSubmit,
            child: Text('Send a one-time password to email',
                style: TextStyle(
                    color: _red.withValues(alpha: .75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ]),
    );
  }
}

// ── Shared input decoration ────────────────────────────────────────────────────

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _m1.withValues(alpha: .55), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF111111),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .1))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .1))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5)),
    );

// ── Gradient action button ─────────────────────────────────────────────────────

class _GradientBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GradientBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_red, _redDeep],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: _red.withValues(alpha: .35),
              blurRadius: 16,
              offset: const Offset(0, 5))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SOCIAL TILE
// ══════════════════════════════════════════════════════════════════════════════

class _SocialTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool loading;
  const _SocialTile({
    required this.label, required this.icon, required this.iconColor,
    required this.onTap, this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: _tx,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRIMITIVES
// ══════════════════════════════════════════════════════════════════════════════

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb(this.size, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color, Colors.transparent], stops: const [0, .65]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFF2B2B).withValues(alpha: .035)
      ..strokeWidth = .5;
    const step = 46.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
