import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../home/scheduled_matches_screen.dart';
import '../nearby/nearby_games_screen.dart';
import '../nearby/host_a_game_screen.dart';
import '../scoreboard/match_setup_screen.dart';
import '../scoreboard/live_matches_screen.dart';

class SportActionGlassScreen extends StatefulWidget {
  final String sport;
  const SportActionGlassScreen({super.key, required this.sport});

  @override
  State<SportActionGlassScreen> createState() => _SportActionGlassScreenState();
}

class _SportActionGlassScreenState extends State<SportActionGlassScreen> {
  bool _showSports = true;

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
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = isDark ? AppColors.primary : AppColorsLight.primary;
    final cardBg   = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final titleCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final toggleBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F0F0);

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

          // ── Card ─────────────────────────────────────────────────────────
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──────────────────────────────────────
                          Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(_emoji(widget.sport),
                                    style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.sport,
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

                          const SizedBox(height: 16),

                          // ── Toggle ──────────────────────────────────────
                          Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: toggleBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _Tab(
                                  label: 'Sports',
                                  icon: Icons.sports_outlined,
                                  active: _showSports,
                                  primary: primary,
                                  isDark: isDark,
                                  onTap: () => setState(() => _showSports = true),
                                ),
                                _Tab(
                                  label: 'Scoreboard',
                                  icon: Icons.scoreboard_outlined,
                                  active: !_showSports,
                                  primary: primary,
                                  isDark: isDark,
                                  onTap: () => setState(() => _showSports = false),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),
                        ],
                      ),
                    ),

                    // ── Content ─────────────────────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showSports
                              ? _buildSportsActions(primary, isDark)
                              : _buildScoreboardActions(primary, isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsActions(Color primary, bool isDark) {
    return Column(
      key: const ValueKey('sports'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionRow(
          icon: Icons.location_searching_rounded,
          title: 'Nearby Games',
          primary: primary,
          isDark: isDark,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NearbyGamesScreen(sport: widget.sport),
            ),
          ),
        ),
        _ActionRow(
          icon: Icons.sports_handball_outlined,
          title: 'Host a Game',
          primary: primary,
          isDark: isDark,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HostAGameScreen(sport: widget.sport),
            ),
          ),
        ),
        _ActionRow(
          icon: Icons.calendar_today_outlined,
          title: 'My Schedule',
          primary: primary,
          isDark: isDark,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScheduledMatchesScreen(sport: widget.sport),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreboardActions(Color primary, bool isDark) {
    return Column(
      key: const ValueKey('scoreboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionRow(
          icon: Icons.add_chart_rounded,
          title: 'Start Scoreboard',
          primary: primary,
          isDark: isDark,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchSetupScreen(sportName: widget.sport),
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
              builder: (_) => LiveMatchesScreen(sportName: widget.sport),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Toggle tab ─────────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: active ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active
                      ? Colors.white
                      : (isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.black45),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

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
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFF111111);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
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
