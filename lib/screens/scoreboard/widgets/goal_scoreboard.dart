import 'package:flutter/material.dart';
import '../../../design/colors.dart';
import '../../../design/spacing.dart';

/// Goal scoreboard widget for sports using goal scoring (e.g., Football, Hockey)
class GoalScoreboard extends StatelessWidget {
  final String team1Name;
  final String team2Name;
  final int team1Goals;
  final int team2Goals;

  const GoalScoreboard({
    super.key,
    required this.team1Name,
    required this.team2Name,
    required this.team1Goals,
    required this.team2Goals,
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
            'Goal Scoreboard',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GoalDisplay(team: team1Name, goals: team1Goals),
              const Text('vs', style: TextStyle(color: Colors.white70)),
              _GoalDisplay(team: team2Name, goals: team2Goals),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalDisplay extends StatelessWidget {
  final String team;
  final int goals;

  const _GoalDisplay({required this.team, required this.goals});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(team, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          goals.toString(),
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
