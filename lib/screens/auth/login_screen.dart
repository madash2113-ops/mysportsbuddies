import 'package:flutter/material.dart';
import '../../../design/colors.dart';
import '../../../design/spacing.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // 🔴 LOGO
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // APP NAME
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'MySports',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: 'Buddies',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              const Text(
                'Sign in to continue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 📱 PHONE LOGIN ✅ FIXED
              _AuthButton(
                icon: Icons.phone,
                text: 'Continue with Phone',
                onTap: () {
                  Navigator.pushNamed(context, '/phone-login');
                },
              ),

              // 📧 EMAIL LOGIN ✅ FIXED
              _AuthButton(
                icon: Icons.email,
                text: 'Continue with Email',
                onTap: () {
                  Navigator.pushNamed(context, '/email-login');
                },
              ),

              // 🔵 GOOGLE (placeholder)
              _AuthButton(
                icon: Icons.g_mobiledata,
                text: 'Continue with Google',
                onTap: () {
                  // TODO: Google Auth
                },
              ),

              // 🔵 FACEBOOK (placeholder)
              _AuthButton(
                icon: Icons.facebook,
                text: 'Continue with Facebook',
                onTap: () {
                  // TODO: Facebook Auth
                },
              ),

              const Spacer(),

              // 📝 REGISTER
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/register-user');
                },
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Not registered yet? ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: 'Register',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              const Text(
                'By continuing, you agree to Terms & Privacy Policy',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔴 UNIFIED AUTH BUTTON (UNCHANGED)
class _AuthButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _AuthButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(icon, color: Colors.white),
          label: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onTap,
        ),
      ),
    );
  }
}
