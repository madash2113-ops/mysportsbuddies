import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/auth_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  Country _country = CountryParser.parseCountryCode('IN');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }

    final fullPhone = '+${_country.phoneCode}$number';
    setState(() { _loading = true; _error = null; });

    await AuthService().sendOtp(
      fullPhone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pushNamed(context, '/otp');
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() { _loading = false; _error = msg; });
      },
      onAutoVerified: () {
        // Android auto-verified — OTP entered automatically, go home
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pushReplacementNamed(context, '/home');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Login with Phone',
            style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Subtitle ──────────────────────────────────────────────────
            const Text(
              'Enter your mobile number and we\'ll send\nyou a one-time password.',
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),

            const Text('Phone Number',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: AppSpacing.sm),

            // ── Country picker + phone input ───────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: _error != null
                    ? Border.all(color: Colors.red.shade700, width: 1.2)
                    : null,
              ),
              child: Row(
                children: [
                  // Country selector
                  InkWell(
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14)),
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: true,
                        countryListTheme: CountryListThemeData(
                          backgroundColor: AppColors.background,
                          textStyle: const TextStyle(color: Colors.white),
                          bottomSheetHeight: 500,
                        ),
                        onSelect: (c) => setState(() => _country = c),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_country.flagEmoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Text('+${_country.phoneCode}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white12),
                  // Phone number input
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '9876543210',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                      ),
                      onSubmitted: (_) => _sendOtp(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Error message ─────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
            ],

            const Spacer(),

            // ── Continue button ───────────────────────────────────────────
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
                onPressed: _loading ? null : _sendOtp,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send OTP',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Note about test numbers ───────────────────────────────────
            const Center(
              child: Text(
                'You can add test numbers in Firebase Console\n'
                'Authentication → Sign-in method → Phone → Test phone numbers',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
