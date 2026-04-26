import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/location_country_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

// Design tokens — matches web_login_page.dart
const _bg = Color(0xFF080808);
const _surface = Color(0xFF0F0F0F);
const _card = Color(0xFF161616);
const _bd2 = Color(0xFF2A2A2A);
const _tx = Color(0xFFF0F0F0);
const _muted = Color(0xFF888888);
const _red = Color(0xFFFB3640);

enum _Step { phone, otp }

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  // ── Shared ──────────────────────────────────────────────────────────────
  _Step _step = _Step.phone;
  bool _loading = false;
  String? _error;

  // ── Phone step ───────────────────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  late Country _country;

  // ── OTP step ─────────────────────────────────────────────────────────────
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  String _otp = '';
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _country =
        LocationCountryService.detectFromLocale() ??
        CountryParser.parseCountryCode('IN');
    _refineCountry();
    _otpFocus.addListener(() => setState(() {}));
  }

  void _refineCountry() {
    LocationCountryService()
        .getCachedOrDetectCountryCode()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => '+${_country.phoneCode}',
        )
        .then((code) {
          if (!mounted) return;
          final refined = LocationCountryService.getCountryFromCode(code);
          if (refined.countryCode != _country.countryCode) {
            setState(() => _country = refined);
          }
        })
        .catchError((dynamic _) {});
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
        return;
      }
      if (mounted) setState(() => _countdown--);
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Send OTP ─────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }
    final fullPhone = '+${_country.phoneCode}$number';
    setState(() {
      _loading = true;
      _error = null;
    });

    final inUse = await UserService().isPhoneInUse(fullPhone);
    if (!mounted) return;
    if (!inUse) {
      setState(() => _loading = false);
      Navigator.pushNamed(
        context,
        '/register-user',
        arguments: {'phone': fullPhone},
      );
      return;
    }

    await AuthService().sendOtp(
      fullPhone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _step = _Step.otp;
          _error = null;
        });
        _startCountdown();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _otpFocus.requestFocus(),
        );
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = msg;
        });
      },
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _loading = false);
        navigateAfterLogin(context);
      },
    );
  }

  // ── OTP input ────────────────────────────────────────────────────────────
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
      _verify();
    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await AuthService().verifyOtp(_otp);
    if (!mounted) return;
    if (ok) {
      final profile = UserService().profile;
      final isNewUser = profile == null || profile.name.trim().isEmpty;
      if (isNewUser) {
        Navigator.pushReplacementNamed(context, '/complete-profile');
      } else {
        await navigateAfterLogin(context);
      }
    } else {
      setState(() {
        _loading = false;
        _error = AuthService().error ?? 'Verification failed. Try again.';
        _otp = '';
      });
      _otpCtrl.clear();
      _otpFocus.requestFocus();
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────────────
  Future<void> _resend() async {
    final phone = AuthService().pendingPhone;
    if (phone == null || phone.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await AuthService().sendOtp(
      phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _loading = false);
        _otp = '';
        _otpCtrl.clear();
        _startCountdown();
        _otpFocus.requestFocus();
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = msg;
        });
      },
    );
  }

  // ── OTP box ───────────────────────────────────────────────────────────────
  Widget _box(int i) {
    final filled = i < _otp.length;
    final isActive = _otpFocus.hasFocus && i == _otp.length && i < 6;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 48,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? _red.withValues(alpha: 0.08) : _card,
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
        filled ? _otp[i] : '',
        style: const TextStyle(
          color: _tx,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Error text ────────────────────────────────────────────────────────────
  Widget _errorBanner(String msg) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      msg,
      style: TextStyle(color: _red.withValues(alpha: 0.9), fontSize: 13),
    ),
  );

  // ── Phone content ─────────────────────────────────────────────────────────
  Widget _buildPhone() {
    return Column(
      key: const ValueKey('phone'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded, color: _muted, size: 12),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(color: _muted, fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 32),

        const Text(
          'Enter your number',
          style: TextStyle(
            color: _tx,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "We'll send a one-time code to verify your number.",
          style: TextStyle(color: _muted, fontSize: 13.5, height: 1.5),
        ),

        const SizedBox(height: 32),

        const Text(
          'Phone Number',
          style: TextStyle(
            color: _tx,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Country picker + input
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _error != null ? _red.withValues(alpha: 0.8) : _bd2,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                onTap: () => showCountryPicker(
                  context: context,
                  showPhoneCode: true,
                  countryListTheme: CountryListThemeData(
                    backgroundColor: _surface,
                    textStyle: const TextStyle(color: _tx),
                    bottomSheetHeight: 500,
                  ),
                  onSelect: (c) => setState(() => _country = c),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _country.flagEmoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${_country.phoneCode}',
                        style: const TextStyle(
                          color: _tx,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: _muted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: _bd2),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: const TextStyle(color: _tx, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Enter your number',
                    hintStyle: TextStyle(color: _muted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                  ),
                  onSubmitted: (_) => _sendOtp(),
                ),
              ),
            ],
          ),
        ),

        if (_error != null) _errorBanner(_error!),

        const SizedBox(height: 28),

        // Send OTP button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              disabledBackgroundColor: _red.withValues(alpha: 0.5),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: _loading ? null : _sendOtp,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 28),

        const Center(
          child: Text(
            'You can add test numbers in Firebase Console\n'
            'Authentication → Sign-in method → Phone → Test phone numbers',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11, height: 1.6),
          ),
        ),
      ],
    );
  }

  // ── OTP content ───────────────────────────────────────────────────────────
  Widget _buildOtp() {
    final phone = AuthService().pendingPhone ?? 'your number';
    return Column(
      key: const ValueKey('otp'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back → go back to phone step
        GestureDetector(
          onTap: () {
            _timer?.cancel();
            _otpCtrl.clear();
            setState(() {
              _step = _Step.phone;
              _otp = '';
              _error = null;
            });
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded, color: _muted, size: 12),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(color: _muted, fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Lock icon
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _red.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.lock_open_rounded, color: _red, size: 26),
        ),

        const SizedBox(height: 20),

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
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: phone,
                style: const TextStyle(color: _tx, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 6 boxes + hidden input
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, _box),
            ),
            Opacity(
              opacity: 0,
              child: AutofillGroup(
                child: TextField(
                  controller: _otpCtrl,
                  focusNode: _otpFocus,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  onChanged: _onOtpChanged,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_error != null) _errorBanner(_error!),

        const SizedBox(height: 24),

        // Resend row
        Center(
          child: _countdown > 0
              ? Text(
                  'Resend OTP in ${_countdown}s',
                  style: const TextStyle(color: _muted, fontSize: 13),
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

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              disabledBackgroundColor: _red.withValues(alpha: 0.5),
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
                      color: Colors.white,
                    ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        onTap: _step == _Step.otp ? () => _otpFocus.requestFocus() : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Grid background ─────────────────────────────────────────
            CustomPaint(painter: _GridPainter()),

            // ── Ambient red glow ────────────────────────────────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.0,
                  colors: [_red.withValues(alpha: 0.07), Colors.transparent],
                ),
              ),
            ),

            // ── Centered card (stays fixed; only content animates) ───────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 48,
                ),
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
                    horizontal: 36,
                    vertical: 40,
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _step == _Step.phone ? _buildPhone() : _buildOtp(),
                    ),
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
