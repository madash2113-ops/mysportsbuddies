import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../core/models/game.dart';

class MySchedulesScreen extends StatefulWidget {
  const MySchedulesScreen({super.key});

  @override
  State<MySchedulesScreen> createState() => _MySchedulesScreenState();
}

class _MySchedulesScreenState extends State<MySchedulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Schedules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: Consumer<GameService>(
        builder: (context, svc, _) {
          final now = DateTime.now();
          final upcoming = svc.all
              .where((g) => g.dateTime.isAfter(now))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
          final past = svc.all
              .where((g) => g.dateTime.isBefore(now))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return TabBarView(
            controller: _tab,
            children: [
              _GameList(games: upcoming, isEmpty: upcoming.isEmpty, label: 'upcoming'),
              _GameList(games: past, isEmpty: past.isEmpty, label: 'past'),
            ],
          );
        },
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  final List<Game> games;
  final bool isEmpty;
  final String label;

  const _GameList({required this.games, required this.isEmpty, required this.label});

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return _EmptyState(label: label);
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: games.length,
      itemBuilder: (_, i) => _ScheduleCard(game: games[i]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No $label games',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label == 'upcoming'
                ? 'Register a game to see it here'
                : 'Your played games will appear here',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Game game;
  const _ScheduleCard({required this.game});

  String _emoji(String sport) {
    const m = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Boxing': '🥊', 'Baseball': '⚾',
      'Hockey': '🏑',
    };
    return m[sport] ?? '🏅';
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;
    String day;
    if (diff == 0) {
      day = 'Today';
    } else if (diff == 1) {
      day = 'Tomorrow';
    } else if (diff == -1) {
      day = 'Yesterday';
    } else {
      day = '${dt.day}/${dt.month}/${dt.year}';
    }

    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '$day  •  $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = game.dateTime.isAfter(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUpcoming
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
          width: isUpcoming ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(_emoji(game.sport), style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.sport,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white38, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        game.location,
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined,
                        color: Colors.white38, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(game.dateTime),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                if (game.skillLevel != null || game.format != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (game.skillLevel != null)
                        _chip(game.skillLevel!, AppColors.primary.withValues(alpha: 0.2)),
                      if (game.format != null)
                        _chip(game.format!, Colors.white12),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUpcoming)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Registered',
                style: TextStyle(
                    color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
        ],
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
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      );
}
