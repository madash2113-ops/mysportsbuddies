import 'package:flutter/material.dart';
import '../design/colors.dart';

/// Horizontally scrollable sport filter chip bar.
/// Shows "All" first, then one chip per sport name in [sports].
/// The currently [selected] chip is highlighted.
class SportFilterBar extends StatelessWidget {
  final List<String> sports;
  final String selected; // 'All' or a sport name
  final ValueChanged<String> onSelect;

  const SportFilterBar({
    super.key,
    required this.sports,
    required this.selected,
    required this.onSelect,
  });

  static String _emoji(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('cricket'))    return '🏏';
    if (s.contains('football') || s.contains('soccer')) return '⚽';
    if (s.contains('futsal'))     return '⚽';
    if (s.contains('basketball')) return '🏀';
    if (s.contains('netball'))    return '🏀';
    if (s.contains('tennis'))     return '🎾';
    if (s.contains('badminton'))  return '🏸';
    if (s.contains('volleyball')) return '🏐';
    if (s.contains('baseball') || s.contains('softball')) return '⚾';
    if (s.contains('rugby') || s.contains('afl')) return '🏉';
    if (s.contains('hockey'))     return '🏑';
    if (s.contains('boxing') || s.contains('mma') || s.contains('wrestling')) {
      return '🥊';
    }
    if (s.contains('swimming'))   return '🏊';
    if (s.contains('golf'))       return '⛳';
    if (s.contains('esport') || s.contains('cs:go') ||
        s.contains('valorant') || s.contains('league') ||
        s.contains('dota') || s.contains('fifa')) {
      return '🎮';
    }
    return '🏅';
  }

  @override
  Widget build(BuildContext context) {
    final chips = ['All', ...sports];

    return Container(
      height: 44,
      color: AppColors.background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = chips[i];
          final isSelected = label == selected;
          return GestureDetector(
            onTap: () => onSelect(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.7)
                      : Colors.white12,
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Text(
                label == 'All' ? '🏟 All' : '${_emoji(label)} $label',
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
