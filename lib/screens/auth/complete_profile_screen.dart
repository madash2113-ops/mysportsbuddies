import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/user_profile.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'auth_router.dart';

/// Shown to first-time phone OTP users.
/// Collects the profile details needed before entering the app.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  Uint8List? _photoBytes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = UserService().profile;
    _nameCtrl.text = profile?.name ?? '';
    _phoneCtrl.text = (profile?.phone.isNotEmpty == true)
        ? profile!.phone
        : AuthService().pendingPhone ?? '';
    _emailCtrl.text = profile?.email ?? '';
    _dobCtrl.text = profile?.dob ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not select that photo. Try another one.');
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial =
        _parseDob(_dobCtrl.text) ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 5, now.month, now.day),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: Color(0xFF141414),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _dobCtrl.text = _formatDob(picked);
      _error = null;
    });
  }

  DateTime? _parseDob(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  String _formatDob(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.year}';

  String? _validate() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final dob = _dobCtrl.text.trim();

    if (name.isEmpty) return 'Please enter your full name.';
    if (phone.isEmpty) return 'Please enter your phone number.';
    if (email.isEmpty) return 'Please enter your email address.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (dob.isEmpty) return 'Please select your date of birth.';
    return null;
  }

  Future<void> _continue() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final userSvc = UserService();
      final existing = userSvc.profile;
      String? imageUrl = existing?.imageUrl;

      if (_photoBytes != null) {
        imageUrl = await userSvc.uploadProfileImageBytes(_photoBytes!);
      }

      final updated = existing != null
          ? existing.copyWith(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              dob: _dobCtrl.text.trim(),
              imageUrl: imageUrl,
            )
          : UserProfile(
              id: userSvc.userId ?? '',
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              dob: _dobCtrl.text.trim(),
              imageUrl: imageUrl,
              updatedAt: DateTime.now(),
            );

      await userSvc.saveProfile(updated);
      if (mounted) {
        context.read<ProfileController>().setProfile(
          name: updated.name,
          email: updated.email,
          phone: updated.phone,
          dob: updated.dob,
          networkImageUrl: updated.imageUrl,
          numericId: updated.numericId,
        );
      }

      if (!mounted) return;
      await navigateAfterLogin(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to save profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 36,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 28),
                  _photoPicker(),
                  const SizedBox(height: 26),
                  _field(
                    label: 'Full Name *',
                    controller: _nameCtrl,
                    icon: Icons.person_outline_rounded,
                    hint: 'Your full name',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Phone Number *',
                    controller: _phoneCtrl,
                    icon: Icons.phone_android_rounded,
                    hint: '+1 555 123 4567',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    label: 'Email *',
                    controller: _emailCtrl,
                    icon: Icons.email_outlined,
                    hint: 'name@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _dobField(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _continue,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Column(
      children: [
        Text(
          'Create your profile',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Tell players who you are before you enter MySportsBuddies.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _photoPicker() {
    return Center(
      child: InkWell(
        onTap: _saving ? null : _pickPhoto,
        borderRadius: BorderRadius.circular(62),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF171717),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
                image: _photoBytes == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(_photoBytes!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: _photoBytes == null
                  ? const Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white70,
                      size: 34,
                    )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: 6,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(icon, hint),
        ),
      ],
    );
  }

  Widget _dobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth *',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dobCtrl,
          readOnly: true,
          onTap: _saving ? null : _pickDob,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration:
              _inputDecoration(
                Icons.calendar_month_outlined,
                'MM/DD/YYYY',
              ).copyWith(
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38,
                ),
              ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint) {
    return InputDecoration(
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}
