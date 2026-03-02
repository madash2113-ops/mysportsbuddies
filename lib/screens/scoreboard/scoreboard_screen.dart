import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../common/sport_action_glass_sheet.dart';
import '../sports/all_sports_screen.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({super.key});

  static const _sports = [
    ('Cricket',      '🏏'),
    ('Football',     '⚽'),
    ('Basketball',   '🏀'),
    ('Badminton',    '🏸'),
    ('Tennis',       '🎾'),
    ('Volleyball',   '🏐'),
    ('Table Tennis', '🏓'),
    ('Boxing',       '🥊'),
    ('Hockey',       '🏑'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scoreboards',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AllSportsScreen())),
            child: const Text('All Sports',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header hint
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Tap a sport to create a scoreboard or view live matches',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Sports grid
            const Text(
              'SELECT A SPORT',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: AppSpacing.md),

            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ..._sports.map((s) => _SportTile(label: s.$1, emoji: s.$2)),
                _SportTile(label: 'More', emoji: '➕', isMore: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SportTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isMore;

  const _SportTile({
    required this.label,
    required this.emoji,
    this.isMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isMore) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AllSportsScreen()));
        } else {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, _, _) =>
                  SportActionGlassScreen(sport: label),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isMore
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF2A0000), Color(0xFF120000)]),
              color: isMore ? AppColors.card : null,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
