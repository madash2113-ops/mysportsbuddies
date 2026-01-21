import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';

class SportActionSheet extends StatelessWidget {
  final String sport;

  const SportActionSheet({
    super.key,
    required this.sport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionTile(
            icon: Icons.app_registration,
            title: 'Register Game',
            onTap: () {
              Navigator.pop(context);
              // Phase 5
            },
          ),
          _ActionTile(
            icon: Icons.location_on,
            title: 'Games Nearby',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _ActionTile(
            icon: Icons.scoreboard,
            title: 'View Scoreboards',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _ActionTile(
            icon: Icons.add_chart,
            title: 'Create Scoreboard',
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.white54,
      ),
      onTap: onTap,
    );
  }
}
