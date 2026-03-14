import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../nearby/game_detail_screen.dart';

class ScheduledMatchesScreen extends StatelessWidget {
  final String sport;
  const ScheduledMatchesScreen({
    super.key,
    required this.sport,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (ctx, gameSvc, _) {
        final myId = UserService().userId;
        final all = gameSvc.bySport(sport);

        // Opted-in or tentative games
        final rsvpd = all
            .where((g) =>
                g.registeredBy != myId &&
                (g.status == ParticipationStatus.inGame ||
                    g.status == ParticipationStatus.tentative))
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '$sport · My Schedule',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
          ),
          body: rsvpd.isEmpty
              ? _EmptyState(sport: sport)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _sectionHeader('Your RSVP', Icons.how_to_reg_outlined),
                    const SizedBox(height: AppSpacing.sm),
                    ...rsvpd.map((g) => _ScheduleCard(
                          game: g,
                          badge: g.status == ParticipationStatus.inGame
                              ? 'GOING'
                              : 'MAYBE',
                          badgeColor: g.status == ParticipationStatus.inGame
                              ? Colors.green
                              : Colors.amber,
                        )),
                  ],
                ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ],
      );
}

// ── Schedule Card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Game game;
  final String badge;
  final Color badgeColor;
  const _ScheduleCard({
    required this.game,
    required this.badge,
    required this.badgeColor,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(game.dateTime);
    final isToday = dateLabel == 'Today';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isToday ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top half: photo or sport banner ──────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: game.photoUrls.isNotEmpty
                  ? Image.network(
                      game.photoUrls.first,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : const SizedBox(
                              height: 160,
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              ),
                            ),
                      errorBuilder: (context, e, s) =>
                          _SportBanner(sport: game.sport),
                    )
                  : _SportBanner(sport: game.sport),
            ),

            // ── Bottom half: details ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: location + badge
                  Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      game.location,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: badgeColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Date + time
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.white38, size: 13),
                  const SizedBox(width: 5),
                  Text('$dateLabel  ·  ${_formatTime(game.dateTime)}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13)),
                ],
              ),

              // Tags
              if (game.skillLevel != null ||
                  game.format != null ||
                  game.maxPlayers != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (game.skillLevel != null)
                      _chip(game.skillLevel!, Colors.white24),
                    if (game.format != null)
                      _chip(game.format!,
                          AppColors.primary.withValues(alpha: 0.25)),
                    if (game.maxPlayers != null)
                      _chip('${game.maxPlayers} players', Colors.white12),
                  ],
                ),
              ],

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
      );
}

// ── Sport gradient banner ─────────────────────────────────────────────────────

class _SportBanner extends StatelessWidget {
  final String sport;
  const _SportBanner({required this.sport});

  static (List<Color>, String) _theme(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('cricket')) {
      return ([const Color(0xFF1B5E20), const Color(0xFF388E3C)], '🏏');
    } else if (s.contains('football') || s.contains('soccer')) {
      return ([const Color(0xFF0D47A1), const Color(0xFF1976D2)], '⚽');
    } else if (s.contains('basketball')) {
      return ([const Color(0xFFE65100), const Color(0xFFF57C00)], '🏀');
    } else if (s.contains('badminton')) {
      return ([const Color(0xFF4A148C), const Color(0xFF7B1FA2)], '🏸');
    } else if (s.contains('tennis')) {
      return ([const Color(0xFF33691E), const Color(0xFF689F38)], '🎾');
    } else if (s.contains('volleyball')) {
      return ([const Color(0xFF1A237E), const Color(0xFF3949AB)], '🏐');
    } else if (s.contains('hockey')) {
      return ([const Color(0xFF37474F), const Color(0xFF546E7A)], '🏑');
    } else if (s.contains('boxing') || s.contains('mma')) {
      return ([const Color(0xFFB71C1C), const Color(0xFFD32F2F)], '🥊');
    } else {
      return ([const Color(0xFF212121), const Color(0xFF424242)], '🏆');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (colors, emoji) = _theme(sport);
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -10,
          bottom: -10,
          child: Text(emoji,
              style: TextStyle(
                  fontSize: 110,
                  color: Colors.white.withValues(alpha: 0.08))),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(sport,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String sport;
  const _EmptyState({required this.sport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📅', style: TextStyle(fontSize: 56)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No $sport games in your schedule',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'RSVP to a nearby game\nto see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
