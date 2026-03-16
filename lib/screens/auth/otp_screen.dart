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
  // ── 6 boxes ─────────────────────────────────────────────────────────────
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  bool    _loading  = false;
  String? _error;

  // ── Resend countdown ─────────────────────────────────────────────────────
  int    _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-focus the first box
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNodes[0].requestFocus());
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
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _timer?.cancel();
    super.dispose();
  }

  // ── Collect OTP ──────────────────────────────────────────────────────────
  String get _otp =>
      _controllers.map((c) => c.text).join();

  // ── Box key handler — backspace moves focus back ─────────────────────────
  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Verify ───────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    final code = _otp;
    if (code.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await AuthService().verifyOtp(code);
    if (!mounted) return;
    if (ok) {
      // New user (no name yet) → collect profile details first
      // Existing user → go straight to home
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
        _error   = AuthService().error ?? 'Verification failed. Try again.';
      });
      // Clear boxes so user can re-enter
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
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
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // ── Header ────────────────────────────────────────────────────
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

            // ── 6 OTP boxes ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpBox(
                controller: _controllers[i],
                focusNode:  _focusNodes[i],
                onKey:      (event) => _onKey(i, event),
                onChanged: (val) {
                  if (val.isNotEmpty) {
                    // Auto-advance to next box
                    if (i < 5) {
                      _focusNodes[i + 1].requestFocus();
                    } else {
                      // Last box filled — attempt verify automatically
                      _focusNodes[i].unfocus();
                      _verify();
                    }
                  }
                },
              )),
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── Resend ────────────────────────────────────────────────────
            _countdown > 0
                ? Text(
                    'Resend OTP in ${_countdown}s',
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
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
    );
  }
}

// ── Single OTP digit box ──────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent) onKey;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKey,
      child: Container(
        width: 46,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focusNode.hasFocus
                ? AppColors.primary
                : Colors.white12,
            width: 1.5,
          ),
        ),
        child: TextField(
          controller:   controller,
          focusNode:    focusNode,
          keyboardType: TextInputType.number,
          textAlign:    TextAlign.center,
          maxLength:    1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
          onChanged: (val) {
            // Keep only the last character typed (handles paste/autocomplete)
            if (val.length > 1) {
              controller.text = val[val.length - 1];
              controller.selection = const TextSelection.collapsed(offset: 1);
            }
            onChanged(controller.text);
          },
        ),
      ),
    );
  }
}
