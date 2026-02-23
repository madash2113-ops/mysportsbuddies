import 'package:flutter/material.dart';
import '../../../design/colors.dart';
import '../../../design/spacing.dart';

/// Timed point scoreboard widget for sports with time-based scoring
class TimedPointScoreboard extends StatelessWidget {
  final String team1Name;
  final String team2Name;
  final int team1Points;
  final int team2Points;
  final Duration elapsedTime;

  const TimedPointScoreboard({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.team1Points,
    required this.team2Points,
    required this.elapsedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Timed Points Scoreboard',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Time: ${elapsedTime.inMinutes}:${(elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PointDisplay(team: team1Name, points: team1Points),
              const Text('vs', style: TextStyle(color: Colors.white70)),
              _PointDisplay(team: team2Name, points: team2Points),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointDisplay extends StatelessWidget {
  final String team;
  final int points;

  const _PointDisplay({required this.team, required this.points});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(team, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          points.toString(),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
