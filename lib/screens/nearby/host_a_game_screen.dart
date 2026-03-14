import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../register/register_game_screen.dart';
import 'game_detail_screen.dart';
import '../../widgets/sport_filter_bar.dart';

class HostAGameScreen extends StatefulWidget {
  final String sport;
  const HostAGameScreen({super.key, required this.sport});

  @override
  State<HostAGameScreen> createState() => _HostAGameScreenState();
}

class _HostAGameScreenState extends State<HostAGameScreen> {
  late String _filterSport;

  @override
  void initState() {
    super.initState();
    _filterSport = widget.sport;
  }

  String _emoji(String sport) {
    const m = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Boxing': '🥊', 'Baseball': '⚾',
      'Hockey': '🏑', 'Running': '🏃', 'Swimming': '🏊',
      'Cycling': '🚴', 'MMA': '🥋', 'Wrestling': '🤼',
      'Kabaddi': '🤸', 'Kho Kho': '🏃', 'CS:GO': '🎮', 'Valorant': '🎮',
    };
    return m[sport] ?? '🏅';
  }

  String _formatDate(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(dt.year, dt.month, dt.day);
    final diff  = date.difference(today).inDays;
    if (diff == 0)  return 'Today';
    if (diff == 1)  return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m  = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  Future<void> _goToRegister({Game? existing}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RegisterGameScreen(
          sport: widget.sport, existingGame: existing),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final myId = UserService().userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          Text(_emoji(widget.sport),
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Host a ${widget.sport} Game',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: ListenableBuilder(
            listenable: GameService(),
            builder: (context, child) {
              final sports = GameService()
                  .all
                  .map((g) => g.sport)
                  .toSet()
                  .toList()
                ..sort();
              return SportFilterBar(
                sports: sports,
                selected: _filterSport,
                onSelect: (s) => setState(() => _filterSport = s),
              );
            },
          ),
        ),
      ),
      body: Consumer<GameService>(
        builder: (ctx, gameSvc, _) {
          final hostedGames = myId == null
              ? <Game>[]
              : (_filterSport == 'All'
                      ? gameSvc.all
                      : gameSvc.bySport(_filterSport))
                  .where((g) => g.registeredBy == myId)
                  .toList()
                ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Host a Game create card ─────────────────────────────
                GestureDetector(
                  onTap: _goToRegister,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.85),
                          AppColors.primary.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline,
                          color: Colors.white, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Host a ${widget.sport} Game',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Set location, time, players & format',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white54, size: 16),
                    ]),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Hosted games section header ─────────────────────────
                Row(children: [
                  const Text(
                    'GAMES I\'M HOSTING',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 8),
                  if (hostedGames.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${hostedGames.length}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),

                // ── Empty state or list ─────────────────────────────────
                if (hostedGames.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🏟️', style: TextStyle(fontSize: 44)),
                        SizedBox(height: 12),
                        Text(
                          'No games hosted yet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tap the card above to create your first game',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ...hostedGames.map((game) {
                    final dateLabel = _formatDate(game.dateTime);
                    final isTomorrow = dateLabel == 'Tomorrow';
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GameDetailScreen(game: game)),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: dateLabel == 'Today'
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.06),
                            width: dateLabel == 'Today' ? 1.2 : 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Photo / sport banner ──────────────────────
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15)),
                              child: game.photoUrls.isNotEmpty
                                  ? Image.network(
                                      game.photoUrls.first,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (_, child, prog) =>
                                          prog == null
                                              ? child
                                              : const SizedBox(
                                                  height: 160,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: AppColors
                                                                .primary),
                                                  ),
                                                ),
                                      errorBuilder: (context, e, s) =>
                                          _SportBanner(sport: game.sport),
                                    )
                                  : _SportBanner(sport: game.sport),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
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
                                    const SizedBox(width: 4),
                                    _DateChip(
                                        label: dateLabel,
                                        isToday: dateLabel == 'Today',
                                        isTomorrow: isTomorrow),
                                  ]),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(children: [
                                    const Icon(Icons.access_time_outlined,
                                        color: Colors.white38, size: 14),
                                    const SizedBox(width: 5),
                                    Text(_formatTime(game.dateTime),
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13)),
                                    if (game.maxPlayers != null) ...[
                                      const SizedBox(width: 14),
                                      const Icon(Icons.group_outlined,
                                          color: Colors.white38, size: 14),
                                      const SizedBox(width: 5),
                                      Text('${game.maxPlayers} players',
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13)),
                                    ],
                                  ]),
                                  if (game.notes != null &&
                                      game.notes!.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      game.notes!,
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                          height: 1.4),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Edit row
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.03),
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16)),
                              ),
                              child: Row(children: [
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _goToRegister(existing: game),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.07),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.white12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            color: Colors.white60,
                                            size: 14),
                                        SizedBox(width: 4),
                                        Text('Edit',
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Date chip helper ──────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final bool isToday;
  final bool isTomorrow;
  const _DateChip(
      {required this.label,
      required this.isToday,
      required this.isTomorrow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.15)
            : isTomorrow
                ? Colors.amber.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.5)
              : isTomorrow
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.white12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isToday
              ? AppColors.primary
              : isTomorrow
                  ? Colors.amber
                  : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Sport gradient banner (shown when no photo is uploaded) ───────────────────

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
    } else if (s.contains('rugby')) {
      return ([const Color(0xFF3E2723), const Color(0xFF6D4C41)], '🏉');
    } else if (s.contains('swimming')) {
      return ([const Color(0xFF006064), const Color(0xFF00838F)], '🏊');
    } else if (s.contains('boxing') || s.contains('mma')) {
      return ([const Color(0xFFB71C1C), const Color(0xFFD32F2F)], '🥊');
    } else if (s.contains('esport') || s.contains('gaming')) {
      return ([const Color(0xFF1A237E), const Color(0xFF283593)], '🎮');
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
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Text(emoji,
                style: TextStyle(
                    fontSize: 110,
                    color: Colors.white.withValues(alpha: 0.08))),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  sport,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
