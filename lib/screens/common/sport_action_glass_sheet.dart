import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../home/scheduled_matches_screen.dart';
import '../nearby/nearby_games_screen.dart';
import '../register/register_game_screen.dart';
import '../scoreboard/match_setup_screen.dart';
import '../scoreboard/live_matches_screen.dart';

class SportActionGlassScreen extends StatelessWidget {
  final String sport;
  const SportActionGlassScreen({super.key, required this.sport});

  static String _emoji(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('cricket')) return '🏏';
    if (s.contains('football') || s.contains('soccer')) return '⚽';
    if (s.contains('futsal')) return '⚽';
    if (s.contains('basketball')) return '🏀';
    if (s.contains('netball')) return '🏀';
    if (s.contains('tennis')) return '🎾';
    if (s.contains('padel')) return '🎾';
    if (s.contains('badminton')) return '🏸';
    if (s.contains('volleyball')) return '🏐';
    if (s.contains('baseball')) return '⚾';
    if (s.contains('softball')) return '⚾';
    if (s.contains('rugby')) return '🏉';
    if (s.contains('afl')) return '🏉';
    if (s.contains('hockey') || s.contains('ice')) return '🏑';
    if (s.contains('boxing')) return '🥊';
    if (s.contains('mma') || s.contains('wrestling')) return '🥋';
    if (s.contains('swimming')) return '🏊';
    if (s.contains('golf')) return '⛳';
    if (s.contains('darts')) return '🎯';
    if (s.contains('snooker')) return '🎱';
    if (s.contains('table tennis')) return '🏓';
    if (s.contains('squash')) return '🎾';
    if (s.contains('handball')) return '🤾';
    if (s.contains('kabaddi') || s.contains('kho')) return '🤸';
    if (s.contains('esport') || s.contains('cs:go') ||
        s.contains('valorant') || s.contains('league') ||
        s.contains('dota') || s.contains('fifa')) {
      return '🎮';
    }
    return '🏆';
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final cardBg  = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final titleCol = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Blurred backdrop ─────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),

          // ── Card (no border, no stroke) ───────────────────────────────────
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
                maxWidth: 340,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ───────────────────────────────────────────
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(_emoji(sport),
                                style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            sport,
                            style: TextStyle(
                              color: titleCol,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.close, color: primary, size: 16),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 18),

                      // ── GAMES section ─────────────────────────────────────
                      _SectionLabel(
                        icon: Icons.sports_outlined,
                        label: 'GAMES',
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(height: 8),

                      _ActionRow(
                        icon: Icons.location_searching_rounded,
                        title: 'Nearby Games',
                        primary: primary,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NearbyGamesScreen(sport: sport),
                          ),
                        ),
                      ),

                      _ActionRow(
                        icon: Icons.add_circle_rounded,
                        title: 'Create a Game',
                        primary: primary,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegisterGameScreen(sport: sport),
                          ),
                        ),
                      ),

                      _ActionRow(
                        icon: Icons.manage_accounts_outlined,
                        title: 'Games I\'m Hosting',
                        primary: primary,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScheduledMatchesScreen(
                                sport: sport, myGamesOnly: true),
                          ),
                        ),
                      ),

                      _ActionRow(
                        icon: Icons.calendar_today_outlined,
                        title: 'Scheduled Matches',
                        primary: primary,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScheduledMatchesScreen(sport: sport),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── SCOREBOARD section ────────────────────────────────
                      _SectionLabel(
                        icon: Icons.scoreboard_outlined,
                        label: 'SCOREBOARD',
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(height: 8),

                      _ActionRow(
                        icon: Icons.add_chart_rounded,
                        title: 'Start Scoreboard',
                        primary: primary,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MatchSetupScreen(sportName: sport),
                          ),
                        ),
                      ),

                      _ActionRow(
                        icon: Icons.bar_chart_rounded,
                        title: 'View Scoreboards',
                        primary: primary,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveMatchesScreen(sportName: sport),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    ]);
  }
}

// ── Action row — red text, black bg, no border ────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color primary;
  final bool isDark;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Dark bg for all buttons in both themes
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFF111111);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          // No border/stroke
        ),
        child: Row(children: [
          Icon(icon, color: primary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: primary.withValues(alpha: 0.5),
            size: 20,
          ),
        ]),
      ),
    );
  }
}
