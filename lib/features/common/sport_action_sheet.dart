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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// TITLE
          Text(
            sport,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _ActionTile(
            icon: Icons.app_registration,
            title: 'Register Game',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/register-game',
                arguments: {'sport': sport},
              );
            },
          ),

          _ActionTile(
            icon: Icons.location_on,
            title: 'View Nearby Games',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/sport-games',
                arguments: {'sport': sport},
              );
            },
          ),

          _ActionTile(
            icon: Icons.scoreboard,
            title: 'View Scoreboards',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/scoreboards',
                arguments: {'sport': sport},
              );
            },
          ),

          _ActionTile(
            icon: Icons.add_chart,
            title: 'Create Scoreboard',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/create-scoreboard',
                arguments: {'sport': sport},
              );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        tileColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
      ),
    );
  }
}
