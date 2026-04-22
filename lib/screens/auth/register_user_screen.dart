import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

// ── Design tokens (matches login_screen.dart) ─────────────────────────────────
const _bg      = Color(0xFF030303);
const _panelR  = Color(0xFF0B0B0B);
const _tx      = Color(0xFFF2F2F2);
const _m1      = Color(0xFF888888);
const _red     = Color(0xFFFF2B2B);
const _redDeep = Color(0xFFB3001B);

// ── Country code model ────────────────────────────────────────────────────────
class _CC {
  final String flag, name, dial;
  const _CC(this.flag, this.name, this.dial);
}

const _kCountries = [
  _CC('🇺🇸', 'United States', '+1'),
  _CC('🇮🇳', 'India', '+91'),
  _CC('🇬🇧', 'United Kingdom', '+44'),
  _CC('🇨🇦', 'Canada', '+1'),
  _CC('🇦🇺', 'Australia', '+61'),
  _CC('🇩🇪', 'Germany', '+49'),
  _CC('🇫🇷', 'France', '+33'),
  _CC('🇯🇵', 'Japan', '+81'),
  _CC('🇨🇳', 'China', '+86'),
  _CC('🇧🇷', 'Brazil', '+55'),
  _CC('🇸🇬', 'Singapore', '+65'),
  _CC('🇦🇪', 'UAE', '+971'),
  _CC('🇳🇬', 'Nigeria', '+234'),
  _CC('🇵🇰', 'Pakistan', '+92'),
  _CC('🇧🇩', 'Bangladesh', '+880'),
  _CC('🇲🇾', 'Malaysia', '+60'),
  _CC('🇿🇦', 'South Africa', '+27'),
  _CC('🇲🇽', 'Mexico', '+52'),
  _CC('🇮🇹', 'Italy', '+39'),
  _CC('🇪🇸', 'Spain', '+34'),
  _CC('🇰🇷', 'South Korea', '+82'),
  _CC('🇵🇭', 'Philippines', '+63'),
  _CC('🇮🇩', 'Indonesia', '+62'),
  _CC('🇸🇦', 'Saudi Arabia', '+966'),
  _CC('🇹🇷', 'Turkey', '+90'),
  _CC('🇳🇿', 'New Zealand', '+64'),
  _CC('🇦🇷', 'Argentina', '+54'),
];

// ─────────────────────────────────────────────────────────────────────────────

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});
  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool    _obscurePass   = true;
  bool    _loading       = false;
  bool    _googleLoading = false;
  String? _error;
  String  _dialCode      = '+1';
  String  _countryFlag   = '🇺🇸';

  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
        ..forward();

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCountryPicker() async {
    final result = await showModalBottomSheet<_CC>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (result != null) {
      setState(() { _dialCode = result.dial; _countryFlag = result.flag; });
    }
  }

  Future<void> _register() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    final rawPhone = _phoneCtrl.text.trim();
    final phone = rawPhone.isEmpty
        ? ''
        : (rawPhone.startsWith('+') ? rawPhone : '$_dialCode$rawPhone');

    if (name.isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    if (phone.isNotEmpty) {
      final inUse = await UserService().isPhoneInUse(phone);
      if (!mounted) return;
      if (inUse) {
        setState(() {
          _loading = false;
          _error = 'This phone number is already registered.';
        });
        return;
      }
    }

    final emailInUse = await UserService().isEmailInUse(email);
    if (!mounted) return;
    if (emailInUse) {
      setState(() {
        _loading = false;
        _error = 'An account with this email already exists.';
      });
      return;
    }

    final ok = await AuthService().signUpWithEmail(
      name: name, email: email, password: pass, phone: phone,
    );
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _loading = false;
        _error = AuthService().error ?? 'Sign-up failed. Try again.';
      });
    }
  }

  Future<void> _googleSignUp() async {
    setState(() { _googleLoading = true; _error = null; });
    final ok = await AuthService().signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _googleLoading = false;
        _error = AuthService().error;
      });
    }
  }

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

  // ── Web: centered card ────────────────────────────────────────────────────

  Widget _webLayout(BuildContext context) {
    return Row(children: [
      const Expanded(flex: 55, child: _LeftPanel()),
      Expanded(flex: 45, child: _rightPanel(context)),
    ]);
  }

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
                  opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
                  child: _formColumn(context, showBackToSite: true),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Mobile ────────────────────────────────────────────────────────────────

  Widget _mobileLayout(BuildContext context) {
    return Stack(children: [
      Positioned(top: -100, left: -100,
          child: _GlowOrb(400, _red.withValues(alpha: .12))),
      Positioned(bottom: -60, right: -80,
          child: _GlowOrb(300, _red.withValues(alpha: .08))),
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _formColumn(context, showBackToSite: false),
        ),
      ),
    ]);
  }

  // ── Shared form column ────────────────────────────────────────────────────

  Widget _formColumn(BuildContext context, {required bool showBackToSite}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Back link
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back_ios_new, color: _m1, size: 13),
            const SizedBox(width: 6),
            Text(showBackToSite ? 'Back to sign in' : 'Back',
                style: const TextStyle(color: _m1, fontSize: 13)),
          ]),
        ),

        const SizedBox(height: 36),

        // Heading
        const Text('Create Account',
            style: TextStyle(
                color: _tx, fontSize: 28,
                fontWeight: FontWeight.w800, letterSpacing: -.5)),
        const SizedBox(height: 6),
        const Text('Join the sports community today',
            style: TextStyle(color: _m1, fontSize: 14)),

        const SizedBox(height: 32),

        // ── Full Name ──────────────────────────────────────────────────────
        const Text('Full Name',
            style: TextStyle(color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: _tx, fontSize: 15),
          decoration: _inputDeco('Your full name'),
        ),

        const SizedBox(height: 16),

        // ── Email ──────────────────────────────────────────────────────────
        const Text('Email Address',
            style: TextStyle(color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: _tx, fontSize: 15),
          decoration: _inputDeco('Email address'),
        ),

        const SizedBox(height: 16),

        // ── Password ───────────────────────────────────────────────────────
        const Text('Password',
            style: TextStyle(color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          style: const TextStyle(color: _tx, fontSize: 15),
          decoration: _inputDeco('Min 6 characters').copyWith(
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePass = !_obscurePass),
              child: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _m1, size: 18),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Phone (optional) ───────────────────────────────────────────────
        Row(children: [
          const Text('Phone Number',
              style: TextStyle(color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text('optional',
              style: TextStyle(
                  color: _m1.withValues(alpha: .45), fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_countryFlag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 5),
                Text(_dialCode,
                    style: const TextStyle(
                        color: _tx, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_drop_down_rounded, color: _m1, size: 16),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: _tx, fontSize: 15),
              decoration: _inputDeco('Phone number'),
            ),
          ),
        ]),

        // Error
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: TextStyle(color: _red.withValues(alpha: .9), fontSize: 12)),
        ],

        const SizedBox(height: 24),

        // ── Create Account button ──────────────────────────────────────────
        _GradientBtn(
          label: _loading ? 'Creating…' : 'Create Account',
          icon: Icons.person_add_rounded,
          onTap: _loading ? () {} : _register,
          loading: _loading,
        ),

        const SizedBox(height: 24),

        // ── Divider ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Container(height: .8,
              color: Colors.white.withValues(alpha: .07))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or sign up with',
                style: TextStyle(
                    color: _m1.withValues(alpha: .6), fontSize: 11)),
          ),
          Expanded(child: Container(height: .8,
              color: Colors.white.withValues(alpha: .07))),
        ]),

        const SizedBox(height: 18),

        // ── Social ─────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _SocialTile(
            label: 'Google',
            icon: Icons.g_mobiledata,
            iconColor: const Color(0xFFEA4335),
            loading: _googleLoading,
            onTap: _googleLoading ? null : _googleSignUp,
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

        const SizedBox(height: 28),

        Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text.rich(TextSpan(children: [
              TextSpan(text: 'Already have an account?  ',
                  style: TextStyle(color: _m1, fontSize: 14)),
              TextSpan(text: 'Sign In',
                  style: TextStyle(
                      color: _red, fontSize: 14, fontWeight: FontWeight.w700)),
            ])),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: Text(
            'By signing up, you agree to our Terms & Privacy Policy',
            style: TextStyle(
                color: Colors.white.withValues(alpha: .18), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LEFT PANEL (same as login)
// ══════════════════════════════════════════════════════════════════════════════

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        Positioned(top: -60, left: -80,
            child: _GlowOrb(480, _red.withValues(alpha: .10))),
        Positioned(bottom: -80, right: -60,
            child: _GlowOrb(380, _redDeep.withValues(alpha: .08))),
        const Positioned(top: 120, left: 52,  child: _FloatEmoji('⚽', 22, .28)),
        const Positioned(top: 240, right: 70, child: _FloatEmoji('🏏', 20, .22)),
        const Positioned(top: 380, left: 36,  child: _FloatEmoji('🏀', 24, .26)),
        const Positioned(top: 520, right: 48, child: _FloatEmoji('🎾', 20, .20)),
        const Positioned(top: 660, left: 72,  child: _FloatEmoji('🥊', 22, .22)),
        const Positioned(bottom: 220, right: 56, child: _FloatEmoji('🏐', 20, .18)),
        const Positioned(bottom: 140, left: 44,  child: _FloatEmoji('🏋️', 20, .20)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 36, 40, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        style: TextStyle(color: _tx, fontSize: 14, fontWeight: FontWeight.w800)),
                    TextSpan(text: 'Sports',
                        style: TextStyle(color: _red, fontSize: 14, fontWeight: FontWeight.w900)),
                    TextSpan(text: 'Buddies',
                        style: TextStyle(color: _tx, fontSize: 14, fontWeight: FontWeight.w800)),
                  ])),
                ]),
                const Spacer(),
                const Text.rich(TextSpan(children: [
                  TextSpan(text: 'Join\n',
                      style: TextStyle(color: _tx, fontSize: 60, fontWeight: FontWeight.w900,
                          height: 1.0, letterSpacing: -2.5)),
                  TextSpan(text: 'Sports\n',
                      style: TextStyle(color: _red, fontSize: 60, fontWeight: FontWeight.w900,
                          height: 1.05, letterSpacing: -2.5)),
                  TextSpan(text: 'Community',
                      style: TextStyle(color: _tx, fontSize: 60, fontWeight: FontWeight.w900,
                          height: 1.05, letterSpacing: -2.5)),
                ])),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 420,
                  child: Text(
                    "Create your free account and start discovering games, tournaments, venues & athletes near you.",
                    style: TextStyle(color: _m1, fontSize: 15, height: 1.65),
                  ),
                ),
                const SizedBox(height: 36),
                Row(children: [
                  _StatChip('50K+', 'Players'),
                  const SizedBox(width: 12),
                  _StatChip('5K+', 'Tournaments'),
                  const SizedBox(width: 12),
                  _StatChip('22+', 'Sports'),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: .08)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🇮🇳', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 8),
                    Text('Made in India',
                        style: TextStyle(color: _m1, fontSize: 12, fontWeight: FontWeight.w500)),
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

// ══════════════════════════════════════════════════════════════════════════════
// COUNTRY PICKER SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _search = TextEditingController();
  List<_CC> _filtered = _kCountries;

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = _kCountries
          .where((c) =>
              c.name.toLowerCase().contains(lower) || c.dial.contains(lower))
          .toList();
    });
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .65,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(height: 16),
        const Text('Select Country',
            style: TextStyle(color: _tx, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            autofocus: true,
            style: const TextStyle(color: _tx, fontSize: 14),
            decoration: _inputDeco('Search country or code').copyWith(
              prefixIcon: const Icon(Icons.search_rounded, color: _m1, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final cc = _filtered[i];
              return InkWell(
                onTap: () => Navigator.pop(context, cc),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  child: Row(children: [
                    Text(cc.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(cc.name,
                        style: const TextStyle(
                            color: _tx, fontSize: 14, fontWeight: FontWeight.w500))),
                    Text(cc.dial, style: const TextStyle(color: _m1, fontSize: 13)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED PRIMITIVES
// ══════════════════════════════════════════════════════════════════════════════

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _m1.withValues(alpha: .55), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF111111),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _GradientBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _GradientBtn({
    required this.label, required this.icon, required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                _red.withValues(alpha: loading ? .5 : 1),
                _redDeep.withValues(alpha: loading ? .5 : 1),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: loading ? null : [BoxShadow(
              color: _red.withValues(alpha: .35),
              blurRadius: 16,
              offset: const Offset(0, 5))],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

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
                        color: _tx, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
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

class _FloatEmoji extends StatelessWidget {
  final String emoji;
  final double size, opacity;
  const _FloatEmoji(this.emoji, this.size, this.opacity);

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: opacity, child: Text(emoji, style: TextStyle(fontSize: size)));
}

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
