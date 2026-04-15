import 'package:flutter/material.dart';
import '../core/models/tournament.dart';
import '../design/colors.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _FmtOption {
  final String           id;
  final String           label;
  final TournamentFormat format;
  final String           overview;
  const _FmtOption({
    required this.id,
    required this.label,
    required this.format,
    required this.overview,
  });
}

const _kOptions = [
  _FmtOption(
    id: 'knockout',
    label: 'Quick Knockout',
    format: TournamentFormat.knockout,
    overview:
        'A single-elimination format. If a team loses once, they are out of '
        'the tournament. This is the fastest option and works best when time '
        'is limited.',
  ),
  _FmtOption(
    id: 'leagueKnockout',
    label: 'Standard Groups + Knockout',
    format: TournamentFormat.leagueKnockout,
    overview:
        'Teams are divided into groups first. Each team plays the others in '
        'its group. The top teams from each group move to the knockout stage. '
        'This is the best balance of fairness and time for 1-day corporate '
        'tournaments.',
  ),
  _FmtOption(
    id: 'roundRobin',
    label: 'Round Robin',
    format: TournamentFormat.roundRobin,
    overview:
        'Every team plays every other team. This format is the fairest because '
        'everyone gets multiple matches, but it takes more time than knockout '
        'formats.',
  ),
  _FmtOption(
    id: 'league',
    label: 'League',
    format: TournamentFormat.league,
    overview:
        'Teams earn points over multiple matches or matchdays, and rankings '
        'are based on the standings table. This is best for recurring office '
        'leagues or season-based events, not usually for a 1-day tournament.',
  ),
  _FmtOption(
    id: 'custom',
    label: 'Custom',
    format: TournamentFormat.custom,
    overview:
        'Allows the organizer to create their own format by choosing group '
        'count, knockout rounds, qualification rules, and other settings.',
  ),
];

// ── Public widget ─────────────────────────────────────────────────────────────

/// Reusable tournament format picker.
///
/// - Tapping a **row** selects that format (calls [onChanged]).
/// - Tapping the **chevron icon** expands / collapses the overview text for
///   that format without changing the selection.
/// - Only one overview is open at a time.
class TournamentFormatPicker extends StatefulWidget {
  final TournamentFormat        selected;
  final ValueChanged<TournamentFormat> onChanged;

  const TournamentFormatPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<TournamentFormatPicker> createState() => _TournamentFormatPickerState();
}

class _TournamentFormatPickerState extends State<TournamentFormatPicker> {
  // Default: Standard Groups + Knockout overview open on first load.
  String? _expandedId = 'leagueKnockout';

  void _toggleExpand(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section title ───────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Tournament Format',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),

        // ── Format cards ────────────────────────────────────────────────────
        for (final opt in _kOptions) ...[
          _FormatCard(
            option:          opt,
            isSelected:      widget.selected == opt.format,
            isExpanded:      _expandedId == opt.id,
            onSelect:        () => widget.onChanged(opt.format),
            onToggleExpand:  () => _toggleExpand(opt.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _FormatCard extends StatelessWidget {
  final _FmtOption    option;
  final bool          isSelected;
  final bool          isExpanded;
  final VoidCallback  onSelect;
  final VoidCallback  onToggleExpand;

  const _FormatCard({
    required this.option,
    required this.isSelected,
    required this.isExpanded,
    required this.onSelect,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.09)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.white12,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // ── Header row ─────────────────────────────────────────────────
            // InkWell covers the FULL row (select on tap anywhere).
            // A GestureDetector with HitTestBehavior.opaque sits on top of
            // the chevron to absorb only the arrow tap (no selection change).
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSelect,
                splashColor: AppColors.primary.withValues(alpha: 0.08),
                highlightColor: AppColors.primary.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      // Selected indicator dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width:  isSelected ? 8  : 0,
                        height: isSelected ? 8  : 0,
                        margin: EdgeInsets.only(right: isSelected ? 10 : 0),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),

                      // Format name
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),

                      // Chevron — arrow-only tap zone (does NOT select)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggleExpand,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: AnimatedRotation(
                            turns:    isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve:    Curves.easeInOut,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isExpanded
                                  ? AppColors.primary
                                  : Colors.white38,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Expandable overview ─────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve:    Curves.easeInOut,
              child: isExpanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Divider
                          Container(
                            height: 1,
                            color: Colors.white10,
                            margin: const EdgeInsets.only(bottom: 10),
                          ),
                          // Overview text
                          Text(
                            option.overview,
                            style: const TextStyle(
                              color:  Colors.white54,
                              fontSize: 13,
                              height:   1.6,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
