import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

// Design tokens — matches phone_login_screen.dart & web_login_page.dart
const _bg      = Color(0xFF080808);
const _surface = Color(0xFF0F0F0F);
const _card    = Color(0xFF161616);
const _bd2     = Color(0xFF2A2A2A);
const _tx      = Color(0xFFF0F0F0);
const _muted   = Color(0xFF888888);
const _red     = Color(0xFFFB3640);

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Single hidden field drives all 6 display boxes.
  // Required for iOS SMS autofill (UITextContentTypeOneTimeCode) + paste.
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  String  _otp      = '';
  bool    _loading  = false;
  String? _error;

  int    _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) { t.cancel(); return; }
      if (mounted) setState(() => _countdown--);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String val) {
    final digits = val.replaceAll(RegExp(r'\D'), '');
    final capped  = digits.length > 6 ? digits.substring(0, 6) : digits;
    if (capped != val) {
      _ctrl.value = TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }
    setState(() { _otp = capped; _error = null; });
    if (capped.length == 6) {
      _focus.unfocus();
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await AuthService().verifyOtp(_otp);
    if (!mounted) return;
    if (ok) {
      final profile   = UserService().profile;
      final isNewUser = profile == null || profile.name.trim().isEmpty;
      if (isNewUser) {
        Navigator.pushReplacementNamed(context, '/complete-profile');
      } else {
        await navigateAfterLogin(context);
      }
    } else {
      setState(() {
        _loading = false;
        _error   = AuthService().error ?? 'Verification failed. Try again.';
        _otp     = '';
      });
      _ctrl.clear();
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    final phone = AuthService().pendingPhone;
    if (phone == null || phone.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    await AuthService().sendOtp(
      phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _loading = false);
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New OTP sent!')),
        );
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() { _loading = false; _error = msg; });
      },
    );
  }

  Widget _box(int i) {
    final filled   = i < _otp.length;
    final isActive = _focus.hasFocus && i == _otp.length && i < 6;
    final char     = filled ? _otp[i] : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 48,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled
            ? _red.withValues(alpha: 0.08)
            : _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? _red
              : filled
                  ? _red.withValues(alpha: 0.5)
                  : _bd2,
          width: isActive ? 2 : 1.2,
        ),
      ),
      child: Text(
        char,
        style: const TextStyle(
          color: _tx,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = AuthService().pendingPhone ?? 'your number';

    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        onTap: () => _focus.requestFocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Grid background ───────────────────────────────────────────
            CustomPaint(painter: _GridPainter()),

            // ── Ambient red glow ──────────────────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.0,
                  colors: [
                    _red.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // ── Centered card ─────────────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 48),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back link ───────────────────────────────────────
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded,
                                color: _muted, size: 12),
                            SizedBox(width: 6),
                            Text('Back',
                                style: TextStyle(
                                    color: _muted, fontSize: 13)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Lock icon ───────────────────────────────────────
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _red.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.lock_open_rounded,
                            color: _red, size: 26),
                      ),

                      const SizedBox(height: 20),

                      // ── Heading ─────────────────────────────────────────
                      const Text(
                        'Verify your number',
                        style: TextStyle(
                          color: _tx,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: _muted,
                              fontSize: 13.5,
                              height: 1.5),
                          children: [
                            const TextSpan(
                                text: 'We sent a 6-digit code to '),
                            TextSpan(
                              text: phone,
                              style: const TextStyle(
                                color: _tx,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── 6 OTP boxes + hidden input ──────────────────────
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: List.generate(6, _box),
                          ),
                          Opacity(
                            opacity: 0,
                            child: AutofillGroup(
                              child: TextField(
                                controller:      _ctrl,
                                focusNode:       _focus,
                                autofillHints:
                                    const [AutofillHints.oneTimeCode],
                                keyboardType:    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                maxLength:       6,
                                onChanged:       _onChanged,
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Error banner ────────────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _red.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                  Icons.error_outline_rounded,
                                  color: _red,
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: _red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Resend row ──────────────────────────────────────
                      Center(
                        child: _countdown > 0
                            ? Text(
                                'Resend OTP in ${_countdown}s',
                                style: const TextStyle(
                                    color: _muted, fontSize: 13),
                              )
                            : GestureDetector(
                                onTap: _loading ? null : _resend,
                                child: const Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: _red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 28),

                      // ── Verify button ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            disabledBackgroundColor:
                                _red.withValues(alpha: 0.5),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          onPressed: _loading ? null : _verify,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid background painter ───────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    const step = 60.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
