import 'package:flutter/material.dart';
import '../../../design/colors.dart';
import '../../../design/spacing.dart';

/// Inning scoreboard widget for cricket and similar sports
class InningScoreboard extends StatelessWidget {
  final String battingTeam;
  final String bowlingTeam;
  final int runs;
  final int wickets;
  final int overs;
  final int balls;

  const InningScoreboard({
    super.key,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.balls,
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
            'Inning Scoreboard',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$battingTeam vs $bowlingTeam',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _InningDisplay(label: 'Runs', value: runs.toString()),
              _InningDisplay(label: 'Wickets', value: '$wickets/10'),
              _InningDisplay(label: 'Overs', value: '$overs.$balls'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InningDisplay extends StatelessWidget {
  final String label;
  final String value;

  const _InningDisplay({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
