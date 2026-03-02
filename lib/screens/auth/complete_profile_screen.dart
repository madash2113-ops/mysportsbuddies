import 'package:flutter/material.dart';

import '../../core/models/user_profile.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/user_service.dart';

/// Shown to first-time phone-OTP users who don't yet have a name.
/// Collects name (required) + email (optional) and saves to Firestore,
/// then navigates to /home.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool    _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final existing = UserService().profile;
      final updated = existing != null
          ? existing.copyWith(
              name:  name,
              email: email.isEmpty ? existing.email : email,
            )
          : UserProfile(
              id:        UserService().userId ?? '',
              name:      name,
              email:     email,
              phone:     '',
              updatedAt: DateTime.now(),
            );

      await UserService().saveProfile(updated);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      setState(() {
        _saving = false;
        _error  = 'Failed to save profile. Please try again.';
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),

              // ── Icon ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(Icons.person_add_alt_1,
                      size: 36, color: Colors.white),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Heading ───────────────────────────────────────────────
              const Center(
                child: Text(
                  'Complete Your Profile',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Just a few details to get you started',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),

              const SizedBox(height: 36),

              // ── Full Name ─────────────────────────────────────────────
              const Text('Full Name *',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Your full name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Colors.white38, size: 22),
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
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Email (optional) ──────────────────────────────────────
              const Text('Email (optional)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'example@email.com',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Colors.white38, size: 22),
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
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              // ── Error ─────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style:
                        TextStyle(color: Colors.red.shade400, fontSize: 13)),
              ],

              const SizedBox(height: 32),

              // ── Continue button ───────────────────────────────────────
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
                  onPressed: _saving ? null : _continue,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Continue to App',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Skip option ───────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (_) => false),
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
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
