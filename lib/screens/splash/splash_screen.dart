import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/models/user_profile.dart';
import '../../layout/responsive_layout.dart';
import '../../services/user_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for the logo animation then route based on auth state
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      // Route to the correct home based on saved role
      final role = UserService().profile?.role ?? UserRole.player;
      if (role == UserRole.merchant) {
        Navigator.pushReplacementNamed(context, '/merchant-home');
      } else {
        // player and organizer both use the main home shell
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      Navigator.pushReplacementNamed(
        context,
        kIsWeb ? '/web-landing' : '/welcome',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFCC1F1F), Color(0xFF8B0000)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 70,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'MySports',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'Buddies',
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Find. Play. Connect.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );

    return AuthResponsiveScaffold(
      hero: const AuthHeroPanel(
        eyebrow: 'Responsive Website',
        title: 'Sports discovery,\ncompetition, and community.',
        subtitle:
            'MySportsBuddy now opens into a browser-friendly experience with space for navigation, tournaments, venues, and live updates.',
        bullets: ['Players', 'Venue owners', 'Tournaments'],
        icon: Icons.emoji_events_rounded,
      ),
      panel: SizedBox(
        height: ResponsiveLayout.isMobile(context) ? null : 420,
        child: panel,
      ),
    );
  }
}
