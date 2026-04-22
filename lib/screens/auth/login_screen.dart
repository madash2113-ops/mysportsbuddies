import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

enum _PhoneStep { phone, otp }

enum _AuthMode { signIn, signUp }

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF030303);
const _panelR = Color(0xFF0B0B0B);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _red = Color(0xFFFF2B2B);
const _redDeep = Color(0xFFB3001B);

// ──────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  _AuthMode _authMode = _AuthMode.signIn;
  String? _activeMethod; // 'phone' | 'email' | null
  bool _googleLoading = false;
  bool _obscurePass = true;
  bool _obscureSignUpPass = true;
  bool _phoneLoading = false;
  bool _emailLoading = false;
  bool _signUpLoading = false;
  String? _error;

  // Phone step state
  _PhoneStep _phoneStep = _PhoneStep.phone;
  String _otp = '';
  int _otpCountdown = 60;
  Timer? _otpTimer;
  String _lastPhone = '';

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _signUpNameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPassCtrl = TextEditingController();
  final _signUpPhoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  String _signUpDialCode = '+1';
  String _signUpFlag = '🇺🇸';

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _signUpNameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPassCtrl.dispose();
    _signUpPhoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _toggle(String method) => setState(() {
    _authMode = _AuthMode.signIn;
    _activeMethod = _activeMethod == method ? null : method;
    _error = null;
    if (_activeMethod != 'phone') {
      _phoneStep = _PhoneStep.phone;
      _otpTimer?.cancel();
      _otp = '';
      _otpCtrl.clear();
    }
  });

  // ── Google ────────────────────────────────────────────────────────────────

  Future<void> _googleSignIn() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
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

  // ── Phone OTP flow ────────────────────────────────────────────────────────

  Future<void> _sendOtp(String phone) async {
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    setState(() {
      _phoneLoading = true;
      _error = null;
      _lastPhone = phone;
    });
    await AuthService().sendOtp(
      phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _phoneLoading = false;
          _phoneStep = _PhoneStep.otp;
          _otpCountdown = 60;
        });
        _startOtpTimer();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _otpFocus.requestFocus(),
        );
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _phoneLoading = false;
          _error = msg;
        });
      },
    );
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_otpCountdown == 0) {
        t.cancel();
        return;
      }
      if (mounted) setState(() => _otpCountdown--);
    });
  }

  void _onOtpChanged(String val) {
    final digits = val.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 6 ? digits.substring(0, 6) : digits;
    if (capped != val) {
      _otpCtrl.value = TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }
    setState(() {
      _otp = capped;
      _error = null;
    });
    if (capped.length == 6) {
      _otpFocus.unfocus();
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _phoneLoading = true;
      _error = null;
    });
    final ok = await AuthService().verifyOtp(_otp);
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _phoneLoading = false;
        _error = AuthService().error ?? 'Verification failed. Try again.';
        _otp = '';
        _otpCtrl.clear();
      });
      _otpFocus.requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_lastPhone.isEmpty) return;
    setState(() {
      _phoneLoading = true;
      _error = null;
    });
    final phone = _lastPhone;
    await AuthService().sendOtp(
      phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _phoneLoading = false;
          _otpCountdown = 60;
        });
        _startOtpTimer();
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _phoneLoading = false;
          _error = msg;
        });
      },
    );
  }

  void _backToPhone() {
    _otpTimer?.cancel();
    setState(() {
      _phoneStep = _PhoneStep.phone;
      _otp = '';
      _otpCtrl.clear();
      _error = null;
    });
  }

  // ── Email sign-in ─────────────────────────────────────────────────────────

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _emailLoading = true;
      _error = null;
    });
    final ok = await AuthService().signInWithEmail(email, pass);
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _emailLoading = false;
        _error = AuthService().error ?? 'Sign in failed. Try again.';
      });
    }
  }

  Future<void> _submitSignUp() async {
    final name = _signUpNameCtrl.text.trim();
    final email = _signUpEmailCtrl.text.trim();
    final pass = _signUpPassCtrl.text;
    final rawPhone = _signUpPhoneCtrl.text.trim();
    final phone = rawPhone.isEmpty
        ? ''
        : (rawPhone.startsWith('+') ? rawPhone : '$_signUpDialCode$rawPhone');

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
    if (rawPhone.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }

    setState(() {
      _signUpLoading = true;
      _error = null;
    });

    final phoneInUse = await UserService().isPhoneInUse(phone);
    if (!mounted) return;
    if (phoneInUse) {
      setState(() {
        _signUpLoading = false;
        _error = 'This phone number is already registered.';
      });
      return;
    }

    final emailInUse = await UserService().isEmailInUse(email);
    if (!mounted) return;
    if (emailInUse) {
      setState(() {
        _signUpLoading = false;
        _error = 'An account with this email already exists.';
      });
      return;
    }

    final ok = await AuthService().signUpWithEmail(
      name: name,
      email: email,
      password: pass,
      phone: phone,
    );
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _signUpLoading = false;
        _error = AuthService().error ?? 'Sign-up failed. Try again.';
      });
    }
  }

  void _switchAuthMode(_AuthMode mode) {
    _otpTimer?.cancel();
    setState(() {
      _authMode = mode;
      _error = null;
      _activeMethod = null;
      _phoneStep = _PhoneStep.phone;
      _phoneLoading = false;
      _emailLoading = false;
      _signUpLoading = false;
      _otp = '';
      _otpCtrl.clear();
    });
  }

  Future<void> _showSignUpCountryPicker() async {
    final result = await showModalBottomSheet<_CC>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _signUpDialCode = result.dial;
        _signUpFlag = result.flag;
      });
    }
  }

  // ── Layout router ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (_, c) =>
            c.maxWidth >= 900 ? _webLayout(context) : _mobileLayout(context),
      ),
    );
  }

  // ── Web: two-column split ─────────────────────────────────────────────────

  Widget _webLayout(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 55, child: _LeftPanel()),
        Expanded(flex: 45, child: _rightPanel(context)),
      ],
    );
  }

  // ── Mobile: single-column ─────────────────────────────────────────────────

  Widget _mobileLayout(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: _GlowOrb(400, _red.withValues(alpha: .12)),
        ),
        Positioned(
          bottom: -60,
          right: -80,
          child: _GlowOrb(300, _red.withValues(alpha: .08)),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Right auth panel (web) ─────────────────────────────────────────────────

  Widget _rightPanel(BuildContext context) {
    return Container(
      color: _panelR,
      child: Stack(
        children: [
          Positioned(
            bottom: -80,
            right: -80,
            child: _GlowOrb(360, _red.withValues(alpha: .07)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 56,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _fadeCtrl,
                      curve: Curves.easeOut,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back to site
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                            context,
                            '/web-landing',
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_back_ios_new,
                                color: _m1,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Back to site',
                                style: TextStyle(color: _m1, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 44),

                        // Header
                        Text(
                          _authMode == _AuthMode.signIn
                              ? 'Welcome back 👋'
                              : 'Create account',
                          style: const TextStyle(
                            color: _tx,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _authMode == _AuthMode.signIn
                              ? 'Sign in to your account'
                              : 'Join the sports community today',
                          style: const TextStyle(color: _m1, fontSize: 14),
                        ),
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
        ],
      ),
    );
  }

  // ── Shared auth form ───────────────────────────────────────────────────────

  Widget _authForm(BuildContext context) {
    if (_authMode == _AuthMode.signUp) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: _InlineSignUpForm(
          key: const ValueKey('sign-up-form'),
          nameCtrl: _signUpNameCtrl,
          emailCtrl: _signUpEmailCtrl,
          passCtrl: _signUpPassCtrl,
          phoneCtrl: _signUpPhoneCtrl,
          dialCode: _signUpDialCode,
          flag: _signUpFlag,
          obscure: _obscureSignUpPass,
          loading: _signUpLoading,
          error: _error,
          onPickCountry: _showSignUpCountryPicker,
          onToggleObscure: () =>
              setState(() => _obscureSignUpPass = !_obscureSignUpPass),
          onSubmit: _submitSignUp,
        ),
      );
    }

    final phoneActive = _activeMethod == 'phone';
    final emailActive = _activeMethod == 'email';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(-0.04, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Column(
        key: const ValueKey('sign-in-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Phone ──────────────────────────────────────────────────────────────
          _MethodBtn(
            label: 'Continue with Phone',
            icon: Icons.phone_android_rounded,
            primary: true,
            active: phoneActive,
            onTap: () => _toggle('phone'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: phoneActive
                ? _phoneStep == _PhoneStep.phone
                      ? _PhoneForm(
                          loading: _phoneLoading,
                          onSend: _sendOtp,
                          error: _error,
                        )
                      : _OtpForm(
                          otp: _otp,
                          otpCtrl: _otpCtrl,
                          otpFocus: _otpFocus,
                          loading: _phoneLoading,
                          countdown: _otpCountdown,
                          onChanged: _onOtpChanged,
                          onVerify: _verifyOtp,
                          onResend: _resendOtp,
                          onBack: _backToPhone,
                          error: _error,
                        )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // ── Email ──────────────────────────────────────────────────────────────
          _MethodBtn(
            label: 'Continue with Email',
            icon: Icons.mail_outline_rounded,
            primary: false,
            active: emailActive,
            onTap: () => _toggle('email'),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: emailActive
                ? _EmailForm(
                    emailCtrl: _emailCtrl,
                    passCtrl: _passCtrl,
                    obscure: _obscurePass,
                    loading: _emailLoading,
                    onToggleObscure: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    onSubmit: _submitEmail,
                    error: _error,
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 28),

          // ── Divider ────────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  height: .8,
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or continue with',
                  style: TextStyle(
                    color: _m1.withValues(alpha: .6),
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: .8,
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Social row ─────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SocialTile(
                  label: 'Google',
                  icon: Icons.g_mobiledata,
                  iconColor: const Color(0xFFEA4335),
                  loading: _googleLoading,
                  onTap: _googleLoading ? null : _googleSignIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SocialTile(
                  label: 'Facebook',
                  icon: Icons.facebook,
                  iconColor: const Color(0xFF1877F2),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Facebook login coming soon!'),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Error (global, shown when no form is active) ───────────────────────
          if (_error != null && !phoneActive && !emailActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withValues(alpha: .22)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  Widget _mobileTopRow(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/welcome'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new, color: _m1, size: 13),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(color: _m1, fontSize: 13)),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: _red.withValues(alpha: .45)),
            borderRadius: BorderRadius.circular(99),
            color: _red.withValues(alpha: .08),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_soccer_rounded, color: _red, size: 12),
              SizedBox(width: 5),
              Text(
                'Player',
                style: TextStyle(
                  color: _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _signUpRow(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => _switchAuthMode(
          _authMode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _authMode == _AuthMode.signIn
                    ? "Don't have an account?  "
                    : 'Already have an account?  ',
                style: const TextStyle(color: _m1, fontSize: 14),
              ),
              TextSpan(
                text: _authMode == _AuthMode.signIn ? 'Sign Up' : 'Sign In',
                style: const TextStyle(
                  color: _red,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsText() {
    return Center(
      child: Text(
        'By continuing you agree to our Terms & Privacy Policy',
        style: TextStyle(
          color: Colors.white.withValues(alpha: .18),
          fontSize: 11,
        ),
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
      child: Stack(
        children: [
          // Faint grid
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Glow orbs
          Positioned(
            top: -60,
            left: -80,
            child: _GlowOrb(480, _red.withValues(alpha: .10)),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _GlowOrb(380, _redDeep.withValues(alpha: .08)),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(child: _GlowOrb(600, _red.withValues(alpha: .06))),
          ),

          // Floating sport emojis (decorative)
          const Positioned(top: 90, left: 52, child: _FloatEmoji('⚽', 22, .30)),
          const Positioned(
            top: 200,
            right: 70,
            child: _FloatEmoji('🏏', 20, .22),
          ),
          const Positioned(
            top: 340,
            left: 36,
            child: _FloatEmoji('🏀', 24, .28),
          ),
          const Positioned(
            top: 470,
            right: 48,
            child: _FloatEmoji('🎾', 20, .20),
          ),
          const Positioned(
            top: 600,
            left: 72,
            child: _FloatEmoji('🥊', 22, .22),
          ),
          const Positioned(
            bottom: 200,
            right: 56,
            child: _FloatEmoji('🏊', 20, .18),
          ),
          const Positioned(
            bottom: 130,
            left: 44,
            child: _FloatEmoji('🏋️', 20, .20),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 36, 40, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo row
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [_red, _redDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _red.withValues(alpha: .38),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'My',
                              style: TextStyle(
                                color: _tx,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: 'Sports',
                              style: TextStyle(
                                color: _red,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(
                              text: 'Buddies',
                              style: TextStyle(
                                color: _tx,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Hero headline
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Where\n',
                          style: TextStyle(
                            color: _tx,
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: -2.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Sports\n',
                          style: TextStyle(
                            color: _red,
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -2.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Comes Alive',
                          style: TextStyle(
                            color: _tx,
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -2.5,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                  Row(
                    children: [
                      _StatChip('50K+', 'Players'),
                      const SizedBox(width: 12),
                      _StatChip('5K+', 'Tournaments'),
                      const SizedBox(width: 12),
                      _StatChip('22+', 'Sports'),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // Testimonial card
                  Container(
                    width: 420,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⭐⭐⭐⭐⭐',
                          style: TextStyle(fontSize: 13, height: 1.2),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '"Found my cricket team in under 20 minutes. The app is incredible!"',
                          style: TextStyle(
                            color: _tx,
                            fontSize: 14,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _red.withValues(alpha: .8),
                                    _redDeep,
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'R',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rahul Kumar',
                                  style: TextStyle(
                                    color: _tx,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Cricketer · Mumbai',
                                  style: TextStyle(color: _m1, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Made-in-India badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🇮🇳', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 8),
                        Text(
                          'Made in India',
                          style: TextStyle(
                            color: _m1,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _red,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _m1,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_red, _redDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x44FF2B2B),
                blurRadius: 28,
                spreadRadius: 3,
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _bg),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: _red,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'My',
                style: TextStyle(
                  color: _tx,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: 'Sports',
                style: TextStyle(
                  color: _red,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: 'Buddies',
                style: TextStyle(
                  color: _tx,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find. Play. Connect.',
          style: TextStyle(color: _m1, fontSize: 13, letterSpacing: .5),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// METHOD BUTTON — becomes a flat section title when active
// ══════════════════════════════════════════════════════════════════════════════

class _MethodBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary; // unused for active styling, kept for inactive style
  final bool active;
  final VoidCallback onTap;
  const _MethodBtn({
    required this.label,
    required this.icon,
    required this.primary,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (active) {
      // Plain title row — no button background
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: _red, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _tx,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Inactive — full button
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
                  end: Alignment.centerRight,
                )
              : null,
          color: primary ? null : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: .1)),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: _red.withValues(alpha: .28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: primary ? Colors.white : _tx.withValues(alpha: .7),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : _tx.withValues(alpha: .85),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PHONE INLINE FORM  (manages its own ctrl + country code + dropdown overlay)
// ══════════════════════════════════════════════════════════════════════════════

class _PhoneForm extends StatefulWidget {
  final bool loading;
  final ValueChanged<String> onSend;
  final String? error;
  const _PhoneForm({required this.loading, required this.onSend, this.error});

  @override
  State<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<_PhoneForm> {
  final _ctrl = TextEditingController();
  final _overlayCtrl = OverlayPortalController();
  final _link = LayerLink();
  String _dialCode = '+1';
  String _flag = '🇺🇸';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final raw = _ctrl.text.trim();
    widget.onSend(
      raw.isEmpty ? '' : (raw.startsWith('+') ? raw : '$_dialCode$raw'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mobile number',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                // ── Country code with anchored dropdown ─────────────────────────
                OverlayPortal(
                  controller: _overlayCtrl,
                  overlayChildBuilder: (ctx) => TapRegion(
                    onTapOutside: (_) => _overlayCtrl.hide(),
                    child: CompositedTransformFollower(
                      link: _link,
                      targetAnchor: Alignment.bottomLeft,
                      followerAnchor: Alignment.topLeft,
                      offset: const Offset(0, 4),
                      child: _CountryDropdown(
                        width: 180,
                        onSelect: (cc) {
                          setState(() {
                            _dialCode = cc.dial;
                            _flag = cc.flag;
                          });
                          _overlayCtrl.hide();
                        },
                      ),
                    ),
                  ),
                  child: CompositedTransformTarget(
                    link: _link,
                    child: GestureDetector(
                      onTap: _overlayCtrl.toggle,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 5),
                            Text(
                              _dialCode,
                              style: const TextStyle(
                                color: _tx,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: _m1,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ── Phone number input ──────────────────────────────────────────
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    style: const TextStyle(color: _tx, fontSize: 15),
                    decoration: _inputDeco('Phone number'),
                  ),
                ),
              ],
            ),
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.error!,
              style: TextStyle(color: _red.withValues(alpha: .9), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          _GradientBtn(
            label: widget.loading ? 'Sending…' : 'Send OTP',
            icon: Icons.send_rounded,
            onTap: widget.loading ? () {} : _send,
            loading: widget.loading,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// OTP INLINE FORM
// ══════════════════════════════════════════════════════════════════════════════

class _OtpForm extends StatelessWidget {
  final String otp;
  final TextEditingController otpCtrl;
  final FocusNode otpFocus;
  final bool loading;
  final int countdown;
  final ValueChanged<String> onChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;
  final String? error;

  const _OtpForm({
    required this.otp,
    required this.otpCtrl,
    required this.otpFocus,
    required this.loading,
    required this.countdown,
    required this.onChanged,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
    this.error,
  });

  Widget _box(int i) {
    final filled = i < otp.length;
    final char = filled ? otp[i] : '';
    final showCaret = otpFocus.hasFocus && otp.length < 6 && i == otp.length;
    final highlight = filled || showCaret;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 42,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? _red.withValues(alpha: .08) : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: showCaret
              ? Colors.white
              : filled
              ? _red.withValues(alpha: .5)
              : Colors.white.withValues(alpha: .1),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            char,
            style: const TextStyle(
              color: _tx,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showCaret)
            Positioned(
              bottom: 10,
              child: Container(
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => otpFocus.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back link
            GestureDetector(
              onTap: onBack,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, color: _m1, size: 11),
                  SizedBox(width: 5),
                  Text(
                    'Change number',
                    style: TextStyle(color: _m1, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Enter 6-digit OTP',
              style: TextStyle(
                color: _m1,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // OTP boxes + hidden field (Positioned.fill so it covers all 6 boxes)
            ListenableBuilder(
              listenable: otpFocus,
              builder: (_, _) => Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _box),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: AutofillGroup(
                        child: TextField(
                          controller: otpCtrl,
                          focusNode: otpFocus,
                          autofocus: true,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          onChanged: onChanged,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(
                  color: _red.withValues(alpha: .9),
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Resend row
            Center(
              child: countdown > 0
                  ? Text(
                      'Resend OTP in ${countdown}s',
                      style: const TextStyle(color: _m1, fontSize: 12),
                    )
                  : GestureDetector(
                      onTap: loading ? null : onResend,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: _red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 14),
            _GradientBtn(
              label: loading ? 'Verifying…' : 'Verify & Continue',
              icon: Icons.verified_rounded,
              onTap: loading ? () {} : onVerify,
              loading: loading,
            ),
          ],
        ),
      ),
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
  final bool loading;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final String? error;
  const _EmailForm({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.onToggleObscure,
    required this.onSubmit,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Email address',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: const TextStyle(color: _tx, fontSize: 15),
            decoration: _inputDeco('Email address'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Password',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
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
                  color: _m1,
                  size: 18,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: _red.withValues(alpha: .9), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          _GradientBtn(
            label: loading ? 'Signing in…' : 'Sign In',
            icon: Icons.login_rounded,
            onTap: loading ? () {} : onSubmit,
            loading: loading,
          ),
        ],
      ),
    );
  }
}

class _InlineSignUpForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController phoneCtrl;
  final String dialCode;
  final String flag;
  final bool obscure;
  final bool loading;
  final VoidCallback onPickCountry;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final String? error;

  const _InlineSignUpForm({
    super.key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.phoneCtrl,
    required this.dialCode,
    required this.flag,
    required this.obscure,
    required this.loading,
    required this.onPickCountry,
    required this.onToggleObscure,
    required this.onSubmit,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Full name',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            style: const TextStyle(color: _tx, fontSize: 15),
            decoration: _inputDeco('Your full name'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Email address',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _tx, fontSize: 15),
            decoration: _inputDeco('Email address'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Phone number',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: onPickCountry,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 5),
                      Text(
                        dialCode,
                        style: const TextStyle(
                          color: _tx,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: _m1,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: _tx, fontSize: 15),
                  decoration: _inputDeco('Phone number'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Password',
            style: TextStyle(
              color: _m1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passCtrl,
            obscureText: obscure,
            style: const TextStyle(color: _tx, fontSize: 15),
            decoration: _inputDeco('Min 6 characters').copyWith(
              suffixIcon: GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _m1,
                  size: 18,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: _red.withValues(alpha: .9), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          _GradientBtn(
            label: loading ? 'Creating…' : 'Create Account',
            icon: Icons.person_add_rounded,
            onTap: loading ? () {} : onSubmit,
            loading: loading,
          ),
        ],
      ),
    );
  }
}

// ── Shared input decoration ────────────────────────────────────────────────────

InputDecoration _inputDeco(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: _m1.withValues(alpha: .55), fontSize: 14),
  filled: true,
  fillColor: const Color(0xFF111111),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: .1)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _red, width: 1.5),
  ),
);

// ── Gradient action button ─────────────────────────────────────────────────────

class _GradientBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _GradientBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _red.withValues(alpha: loading ? .5 : 1),
              _redDeep.withValues(alpha: loading ? .5 : 1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: _red.withValues(alpha: .35),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.loading = false,
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _tx,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COUNTRY CODE PICKER
// ══════════════════════════════════════════════════════════════════════════════

class _CC {
  final String flag;
  final String name;
  final String dial;
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
  _CC('🇨🇴', 'Colombia', '+57'),
  _CC('🇰🇪', 'Kenya', '+254'),
  _CC('🇬🇭', 'Ghana', '+233'),
];

// ── Anchored country dropdown (used by OverlayPortal in _PhoneFormState) ──────

class _CountryDropdown extends StatefulWidget {
  final double width;
  final ValueChanged<_CC> onSelect;
  const _CountryDropdown({required this.width, required this.onSelect});

  @override
  State<_CountryDropdown> createState() => _CountryDropdownState();
}

class _CountryDropdownState extends State<_CountryDropdown> {
  final _search = TextEditingController();
  List<_CC> _filtered = _kCountries;

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = _kCountries
          .where(
            (c) =>
                c.name.toLowerCase().contains(lower) || c.dial.contains(lower),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .65),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                style: const TextStyle(color: _tx, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search country or code…',
                  hintStyle: TextStyle(
                    color: _m1.withValues(alpha: .5),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _m1,
                    size: 15,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF111111),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final cc = _filtered[i];
                  return InkWell(
                    onTap: () => widget.onSelect(cc),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Text(cc.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cc.name,
                              style: const TextStyle(
                                color: _tx,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            cc.dial,
                            style: const TextStyle(color: _m1, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          .where(
            (c) =>
                c.name.toLowerCase().contains(lower) || c.dial.contains(lower),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * .65,
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Country',
            style: TextStyle(
              color: _tx,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              autofocus: true,
              style: const TextStyle(color: _tx, fontSize: 14),
              decoration: _inputDeco('Search country or code').copyWith(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _m1,
                  size: 18,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Text(cc.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            cc.name,
                            style: const TextStyle(
                              color: _tx,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          cc.dial,
                          style: const TextStyle(color: _m1, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0, .65],
        ),
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
