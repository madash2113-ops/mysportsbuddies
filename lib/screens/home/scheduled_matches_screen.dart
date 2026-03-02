import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../nearby/game_detail_screen.dart';
import '../register/register_game_screen.dart';

class ScheduledMatchesScreen extends StatelessWidget {
  final String sport;
  final bool myGamesOnly;
  const ScheduledMatchesScreen({
    super.key,
    required this.sport,
    this.myGamesOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (ctx, gameSvc, _) {
        final myId = UserService().userId;
        final all = gameSvc.bySport(sport);

        // Registered by me
        final mine =
            myId != null ? all.where((g) => g.registeredBy == myId).toList() : <Game>[];

        // Opted-in or tentative (not registered by me — shown separately)
        final rsvpd = myGamesOnly
            ? <Game>[]
            : all
                .where((g) =>
                    g.registeredBy != myId &&
                    (g.status == ParticipationStatus.inGame ||
                        g.status == ParticipationStatus.tentative))
                .toList();

        final appBarTitle = myGamesOnly ? 'My $sport Games' : '$sport — Scheduled';
        final isEmpty = myGamesOnly ? mine.isEmpty : (rsvpd.isEmpty && mine.isEmpty);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              appBarTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
          ),
          body: isEmpty
              ? _EmptyState(sport: sport, myGamesOnly: myGamesOnly)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // ── My Registered Games ───────────────────────────────
                    if (mine.isNotEmpty) ...[
                      _sectionHeader(
                        myGamesOnly ? 'Your Registered Games' : 'Registered by You',
                        Icons.edit_calendar_outlined,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...mine.map((g) => _ScheduleCard(
                            game: g,
                            badge: 'ORGANISER',
                            badgeColor: AppColors.primary,
                            onEdit: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterGameScreen(
                                    sport: sport, existingGame: g),
                              ),
                            ),
                          )),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── RSVP'd Games ──────────────────────────────────────
                    if (!myGamesOnly && rsvpd.isNotEmpty) ...[
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
  final VoidCallback? onEdit;

  const _ScheduleCard({
    required this.game,
    required this.badge,
    required this.badgeColor,
    this.onEdit,
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
        child: Padding(
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

              // Edit row (for owned games)
              if (onEdit != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white60, size: 14),
                          SizedBox(width: 4),
                          Text('Edit',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
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

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String sport;
  final bool myGamesOnly;
  const _EmptyState({required this.sport, this.myGamesOnly = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(myGamesOnly ? '🏅' : '📅', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: AppSpacing.md),
          Text(
            myGamesOnly ? 'No $sport games registered yet' : 'No scheduled $sport matches',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            myGamesOnly
                ? 'Tap "Register Game" to create\nyour first $sport game.'
                : 'RSVP to a nearby game or register\none to see it here.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
