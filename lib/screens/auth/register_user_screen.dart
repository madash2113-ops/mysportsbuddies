import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool    _obscurePassword = true;
  bool    _loading         = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final phone    = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // ── Uniqueness checks before creating the Firebase Auth account ─────────
    if (phone.isNotEmpty) {
      final phoneInUse = await UserService().isPhoneInUse(phone);
      if (!mounted) return;
      if (phoneInUse) {
        setState(() {
          _loading = false;
          _error = 'This phone number is already registered. Please sign in instead.';
        });
        return;
      }
    }

    final emailInUse = await UserService().isEmailInUse(email);
    if (!mounted) return;
    if (emailInUse) {
      setState(() {
        _loading = false;
        _error = 'An account with this email already exists. Please sign in instead.';
      });
      return;
    }
    // ────────────────────────────────────────────────────────────────────────

    final ok = await AuthService().signUpWithEmail(
      name:     name,
      email:    email,
      password: password,
      phone:    phone,
    );

    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _loading = false;
        _error   = AuthService().error ?? 'Sign-up failed. Please try again.';
      });
    }
  }

  Future<void> _googleSignUp() async {
    setState(() { _loading = true; _error = null; });
    final ok = await AuthService().signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      await navigateAfterLogin(context);
    } else {
      setState(() {
        _loading = false;
        _error   = AuthService().error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // ── Back button ──────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Heading ──────────────────────────────────────────────────
              const Text(
                'Create Account',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the sports community today',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),

              const SizedBox(height: 32),

              // ── Full Name ────────────────────────────────────────────────
              _InputField(
                controller: _nameCtrl,
                hint: 'Full Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Phone (optional) ─────────────────────────────────────────
              _InputField(
                controller: _phoneCtrl,
                hint: 'Phone Number (optional)',
                icon: Icons.phone_outlined,
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Email ────────────────────────────────────────────────────
              _InputField(
                controller: _emailCtrl,
                hint: 'Email Address',
                icon: Icons.email_outlined,
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Password ─────────────────────────────────────────────────
              TextField(
                controller:  _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Password (min 6 chars)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: Colors.white38, size: 22),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white38,
                      size: 22,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              // ── Error ────────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(
                        color: Colors.red.shade400, fontSize: 13)),
              ],

              const SizedBox(height: 28),

              // ── Create Account button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 24),

              // ── Divider ──────────────────────────────────────────────────
              const Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: Colors.white12, thickness: 0.8)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('or sign up with',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ),
                  Expanded(
                      child: Divider(
                          color: Colors.white12, thickness: 0.8)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Social buttons ───────────────────────────────────────────
              Row(
                children: [
                  // Google
                  Expanded(
                    child: _SocialButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata,
                      iconColor: const Color(0xFFEA4335),
                      onTap: _loading ? null : _googleSignUp,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Facebook — requires native Facebook App ID config
                  Expanded(
                    child: _SocialButton(
                      label: 'Facebook',
                      icon: Icons.facebook,
                      iconColor: const Color(0xFF1877F2),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Facebook login requires additional setup. Coming soon!'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Sign-in link ─────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account?  ',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              const Center(
                child: Text(
                  'By signing up, you agree to Terms & Privacy Policy',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                  textAlign: TextAlign.center,
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

// ── Reusable input field ──────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType inputType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 22),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
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

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
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
        child: Row(
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
