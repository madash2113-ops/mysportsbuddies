import 'package:flutter/material.dart';
import '../../../design/colors.dart';
import '../../../design/spacing.dart';

/// Rally scoreboard widget for sports using rally scoring system (e.g., Volleyball, Badminton)
class RallyScoreboard extends StatelessWidget {
  final String team1Name;
  final String team2Name;
  final int team1Score;
  final int team2Score;

  const RallyScoreboard({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.team1Score,
    required this.team2Score,
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
            'Rally Scoreboard',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreDisplay(team: team1Name, score: team1Score),
              const Text('vs', style: TextStyle(color: Colors.white70)),
              _ScoreDisplay(team: team2Name, score: team2Score),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreDisplay extends StatelessWidget {
  final String team;
  final int score;

  const _ScoreDisplay({required this.team, required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(team, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          score.toString(),
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
