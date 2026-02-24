import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../nearby/nearby_games_screen.dart';
import '../register/register_game_screen.dart';
import '../scoreboard/match_setup_screen.dart';
import '../scoreboard/live_matches_screen.dart';

class SportActionGlassScreen extends StatelessWidget {
  final String sport;

  const SportActionGlassScreen({
    super.key,
    required this.sport,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Blurred + dimmed backdrop (Positioned.fill so it covers the screen) ──
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.60),
                ),
              ),
            ),
          ),

          // ── Centered glass card ──
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    sport,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    thickness: 0.8,
                  ),
                  const SizedBox(height: 18),

                  // ── Action Buttons ──
                  _ActionButton(
                    icon: Icons.app_registration_outlined,
                    label: 'Register Game',
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(
                        builder: (_) => RegisterGameScreen(sport: sport),
                      ));
                    },
                  ),
                  const SizedBox(height: 12),

                  _ActionButton(
                    icon: Icons.location_on_outlined,
                    label: 'Nearby Games',
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(
                        builder: (_) => NearbyGamesScreen(sport: sport),
                      ));
                    },
                  ),
                  const SizedBox(height: 12),

                  _ActionButton(
                    icon: Icons.add_chart_outlined,
                    label: 'Create Scoreboard',
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(
                        builder: (_) => MatchSetupScreen(sportName: sport),
                      ));
                    },
                  ),
                  const SizedBox(height: 12),

                  _ActionButton(
                    icon: Icons.scoreboard_outlined,
                    label: 'View Scoreboards',
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(MaterialPageRoute(
                        builder: (_) => LiveMatchesScreen(sportName: sport),
                      ));
                    },
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
