import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design/colors.dart';
import 'scoreboard_screen.dart';
import 'live_matches_screen.dart';

/// Glass overlay popup shown when user taps "Scoreboards".
/// Two options: Create Scoreboard (→ sport grid) and View Scoreboards (→ all matches).
class ScoreboardMenuScreen extends StatelessWidget {
  const ScoreboardMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Blurred + dimmed backdrop ────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),

          // ── Centered glass card ──────────────────────────────────────────
          Center(
            child: Container(
              width: 300,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon + title
                  const Icon(Icons.scoreboard_outlined,
                      color: AppColors.primary, size: 36),
                  const SizedBox(height: 10),
                  const Text(
                    'Scoreboards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Divider(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    thickness: 0.8,
                  ),
                  const SizedBox(height: 18),

                  // ── Create Scoreboard ────────────────────────────────────
                  _MenuButton(
                    icon: Icons.add_chart_outlined,
                    label: 'Create Scoreboard',
                    subtitle: 'Start scoring a new match',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ScoreboardScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ── View Scoreboards ─────────────────────────────────────
                  _MenuButton(
                    icon: Icons.scoreboard_outlined,
                    label: 'View Scoreboards',
                    subtitle: 'See live & completed matches',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LiveMatchesScreen()),
                      );
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

// ── Menu button ───────────────────────────────────────────────────────────────

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }
}
