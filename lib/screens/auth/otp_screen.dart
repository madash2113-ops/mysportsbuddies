import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Single controller + focus — one hidden field drives all 6 display boxes.
  // This pattern is required for iOS SMS autofill (UITextContentTypeOneTimeCode)
  // and for proper paste handling.
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  String  _otp      = '';
  bool    _loading  = false;
  String? _error;

  // ── Resend countdown ─────────────────────────────────────────────────────
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
    // Strip non-digits (safety) and cap at 6
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

  // ── Verify ───────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await AuthService().verifyOtp(_otp);
    if (!mounted) return;
    if (ok) {
      final profile  = UserService().profile;
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

  // ── Resend ───────────────────────────────────────────────────────────────
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

  // ── Single display box ───────────────────────────────────────────────────
  Widget _box(int i) {
    final filled   = i < _otp.length;
    final isActive = _focus.hasFocus && i == _otp.length && i < 6;
    final char     = filled ? _otp[i] : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : filled
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.white12,
          width: isActive ? 2 : 1.5,
        ),
      ),
      child: Text(
        char,
        style: const TextStyle(
          color: Colors.white,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Verify OTP',
            style: TextStyle(color: Colors.white)),
      ),
      body: GestureDetector(
        onTap: () => _focus.requestFocus(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // ── Header ──────────────────────────────────────────────────
              const Icon(Icons.lock_open_rounded,
                  color: AppColors.primary, size: 48),
              const SizedBox(height: AppSpacing.md),

              const Text(
                'Enter OTP',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              Text(
                'We sent a 6-digit code to $phone',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),

              const SizedBox(height: 36),

              // ── 6 display boxes + hidden input ───────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Visual boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _box),
                  ),

                  // Hidden TextField — captures all input including SMS autofill.
                  // Opacity 0 keeps it invisible but still interactive.
                  Opacity(
                    opacity: 0,
                    child: AutofillGroup(
                      child: TextField(
                        controller:      _ctrl,
                        focusNode:       _focus,
                        autofillHints:   const [AutofillHints.oneTimeCode],
                        keyboardType:    TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

              // ── Error ────────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // ── Resend ───────────────────────────────────────────────────
              _countdown > 0
                  ? Text(
                      'Resend OTP in ${_countdown}s',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 14),
                    )
                  : TextButton(
                      onPressed: _loading ? null : _resend,
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),

              const Spacer(),

              // ── Verify button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Verify & Continue',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
