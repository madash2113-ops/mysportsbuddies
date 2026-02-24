import 'package:flutter/material.dart';
import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../register/register_game_screen.dart';

class NearbyGamesScreen extends StatefulWidget {
  final String sport;

  const NearbyGamesScreen({super.key, required this.sport});

  @override
  State<NearbyGamesScreen> createState() => _NearbyGamesScreenState();
}

class _NearbyGamesScreenState extends State<NearbyGamesScreen> {
  List<Game> _games = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _games = GameService.bySport(widget.sport));
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(dt.year, dt.month, dt.day);
    final diff  = date.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m  = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Text(_emoji(widget.sport), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Nearby ${widget.sport} Games',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RegisterGameScreen(sport: widget.sport),
              ));
              _load(); // Refresh after returning
            },
            icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
            label: const Text(
              'Add',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: _games.isEmpty ? _EmptyState(sport: widget.sport, onAdd: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RegisterGameScreen(sport: widget.sport),
        ));
        _load();
      }) : RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: () async => _load(),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: _games.length,
          itemBuilder: (context, index) =>
              _GameCard(game: _games[index], formatDate: _formatDate, formatTime: _formatTime),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String sport;
  final VoidCallback onAdd;

  const _EmptyState({required this.sport, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏟️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No $sport games yet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Be the first to register a game\nin your area!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                ),
                onPressed: onAdd,
                child: const Text(
                  'Register a Game',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game Card ─────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final Game game;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  const _GameCard({
    required this.game,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatDate(game.dateTime);
    final timeLabel = formatTime(game.dateTime);
    final isToday   = dateLabel == 'Today';
    final isTomorrow = dateLabel == 'Tomorrow';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
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
          // ── Header: venue + date badge ──────────────────────────────────
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  game.location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Date badge
              Container(
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
                  dateLabel,
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
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Time ────────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.access_time_outlined, color: Colors.white38, size: 14),
              const SizedBox(width: 5),
              Text(
                timeLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              if (game.maxPlayers != null) ...[
                const SizedBox(width: 14),
                const Icon(Icons.group_outlined, color: Colors.white38, size: 14),
                const SizedBox(width: 5),
                Text(
                  '${game.maxPlayers} players',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ],
          ),

          // ── Chips ────────────────────────────────────────────────────────
          if (game.skillLevel != null || game.format != null || game.ballType != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (game.skillLevel != null)
                  _InfoChip(label: game.skillLevel!, color: Colors.white24),
                if (game.format != null)
                  _InfoChip(label: game.format!, color: AppColors.primary.withValues(alpha: 0.25)),
                if (game.ballType != null)
                  _InfoChip(label: game.ballType!, color: Colors.white12),
              ],
            ),
          ],

          // ── Notes ────────────────────────────────────────────────────────
          if (game.notes != null && game.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              game.notes!,
              style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}
