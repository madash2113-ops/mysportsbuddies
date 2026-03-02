import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool    _googleLoading = false;
  String? _error;

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    final ok = await AuthService().signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 52),

              // ── Logo ────────────────────────────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.emoji_events,
                    size: 42, color: Colors.white),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Brand name ───────────────────────────────────────────────
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'MySports',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: 'Buddies',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text('Welcome back',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),

              const SizedBox(height: 40),

              // ── Continue with Phone OTP ──────────────────────────────────
              _PrimaryButton(
                label: 'Continue with Phone OTP',
                icon:  Icons.phone_android_outlined,
                onTap: () => Navigator.pushNamed(context, '/phone-login'),
              ),

              const SizedBox(height: 12),

              // ── Continue with Email ──────────────────────────────────────
              _OutlineButton(
                label: 'Continue with Email',
                icon:  Icons.email_outlined,
                onTap: () => Navigator.pushNamed(context, '/email-login'),
              ),

              const SizedBox(height: 28),

              // ── Divider ──────────────────────────────────────────────────
              const Row(
                children: [
                  Expanded(
                      child:
                          Divider(color: Colors.white12, thickness: 0.8)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('or continue with',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ),
                  Expanded(
                      child:
                          Divider(color: Colors.white12, thickness: 0.8)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Social buttons ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SocialButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata,
                      iconColor: const Color(0xFFEA4335),
                      loading: _googleLoading,
                      onTap: _googleLoading ? null : _googleSignIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(
                      label: 'Facebook',
                      icon: Icons.facebook,
                      iconColor: const Color(0xFF1877F2),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Facebook login coming soon!')),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // ── Error ────────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red.shade400, fontSize: 13)),
              ],

              const SizedBox(height: 32),

              // ── Register link ────────────────────────────────────────────
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, '/register-user'),
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: "Don't have an account?  ",
                        style: TextStyle(
                            color: Colors.white54, fontSize: 14),
                      ),
                      TextSpan(
                        text: 'Sign Up',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              const Text(
                'By continuing, you agree to Terms & Privacy Policy',
                style: TextStyle(color: Colors.white24, fontSize: 11),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon:  Icon(icon, color: Colors.white, size: 20),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }
}

// ── Outline button ────────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppColors.primary.withValues(alpha: 0.06),
        ),
        icon:  Icon(icon, color: AppColors.primary, size: 20),
        label: Text(label,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }
}

// ── Social button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool loading;

  const _SocialButton({
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
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10, width: 0.8),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 26),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
