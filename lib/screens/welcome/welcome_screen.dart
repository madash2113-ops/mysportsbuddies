import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _continue(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_role', 'player');
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo ──────────────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFCC1F1F).withValues(alpha: 0.15),
                  border: Border.all(
                      color: const Color(0xFFCC1F1F).withValues(alpha: 0.4),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCC1F1F).withValues(alpha: 0.35),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_soccer_rounded,
                    size: 46, color: Color(0xFFCC1F1F)),
              ),

              const SizedBox(height: 20),

              // ── Brand name ────────────────────────────────────────────────
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'MySports',
                      style: TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: 'Buddies',
                      style: TextStyle(
                          fontSize: 26,
                          color: Color(0xFFCC1F1F),
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              const Text(
                'Find games, join tournaments & connect',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),

              const Spacer(flex: 2),

              // ── Player card ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFCC1F1F).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC1F1F).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sports_soccer_rounded,
                          color: Color(0xFFCC1F1F), size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I'm a Player",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Find games, join tournaments,\ndiscover sports buddies near you.',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Continue button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFCC1F1F)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCC1F1F).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _continue(context),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
