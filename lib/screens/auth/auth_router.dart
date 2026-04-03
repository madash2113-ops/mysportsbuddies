import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/user_profile.dart';
import '../../services/user_service.dart';
import 'sports_interest_screen.dart';

/// Call this after any successful sign-in to save the pending role
/// (selected on WelcomeScreen) and navigate to the correct home shell.
Future<void> navigateAfterLogin(BuildContext context) async {
  final prefs       = await SharedPreferences.getInstance();
  final pendingRole = prefs.getString('pending_role') ?? 'player';
  final role        = pendingRole == 'merchant' ? UserRole.merchant : UserRole.player;

  // Persist role into the user's Firestore profile
  final svc      = UserService();
  final existing = svc.profile;
  if (existing != null && existing.role != role) {
    await svc.saveProfile(existing.copyWith(role: role));
  } else if (existing == null) {
    await svc.saveProfile(
      UserProfile(id: svc.userId ?? '', updatedAt: DateTime.now(), role: role),
    );
  }

  await prefs.remove('pending_role');

  if (!context.mounted) return;
  if (role == UserRole.merchant) {
    Navigator.pushNamedAndRemoveUntil(context, '/merchant-home', (_) => false);
  } else {
    final profile = UserService().profile;
    final isNewUser = (profile?.favoriteSports ?? []).isEmpty;
    if (isNewUser) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SportsInterestScreen()),
        (_) => false,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }
}
