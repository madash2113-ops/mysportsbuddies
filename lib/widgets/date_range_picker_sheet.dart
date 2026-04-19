import 'package:flutter/material.dart';
import '../design/colors.dart';

// ── Public API ────────────────────────────────────────────────────────────────

Future<DateTimeRange?> showCustomDateRangePicker({
  required BuildContext context,
  DateTime? initialStart,
  DateTime? initialEnd,
}) =>
    showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateRangeSheet(
        initialStart: initialStart,
        initialEnd: initialEnd,
      ),
    );

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _DateRangeSheet extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  const _DateRangeSheet({this.initialStart, this.initialEnd});

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late DateTime _viewMonth;
  DateTime? _start;
  DateTime? _end;

  static const _kMonthNames = [
    'JAN','FEB','MAR','APR','MAY','JUN',
    'JUL','AUG','SEP','OCT','NOV','DEC',
  ];
  static const _kDayLabels = ['Mo','Tu','We','Th','Fr','Sa','Su'];

  // Strip strip color matching the screenshot
  static const _kStripColor = Color(0xFFEDEDED);

  @override
  void initState() {
    super.initState();
    // Normalise to date-only to avoid time-component comparison bugs
    _start = widget.initialStart.let(_dateOnly);
    _end   = widget.initialEnd.let(_dateOnly);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    // Open on the start date's month only if it's current or future;
    // otherwise land on today so the user sees selectable dates immediately.
    final startMonth = _start != null && !_start!.isBefore(currentMonth)
        ? DateTime(_start!.year, _start!.month)
        : currentMonth;
    _viewMonth = startMonth;
    // Reset existing selection so the user must pick fresh dates.
    _start = null;
    _end   = null;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(DateTime d) {
    if (_start == null || _end == null) return false;
    return d.isAfter(_start!) && d.isBefore(_end!);
  }

  void _onDayTap(DateTime day) {
    // If nothing selected OR both already selected → start fresh
    if (_start == null || _end != null) {
      setState(() { _start = day; _end = null; });
      return;
    }
    // Have start but no end
    if (day.isBefore(_start!)) {
      // Tapped before start → reset and use this as new start
      setState(() { _start = day; _end = null; });
    } else {
      // Valid end (same day or after)
      final end = day;
      setState(() => _end = end);
      // Brief delay so user sees the highlight before sheet closes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.of(context).pop(DateTimeRange(start: _start!, end: end));
        }
      });
    }
  }

  // ── Prev / Next month constraints ─────────────────────────────────────────

  bool get _canGoPrev {
    final now = DateTime.now();
    return !(_viewMonth.year == now.year && _viewMonth.month == now.month);
  }

  @override
  Widget build(BuildContext context) {
    final today    = _dateOnly(DateTime.now());
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // Monday-first: DateTime.weekday → 1=Mon … 7=Sun → leading empties = weekday-1
    final leadingEmpty = firstDay.weekday - 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────────
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Month navigation ───────────────────────────────────────────────
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                enabled: _canGoPrev,
                onTap: () => setState(() =>
                    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
              ),
              Expanded(
                child: Text(
                  '${_kMonthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                enabled: true,
                onTap: () => setState(() =>
                    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Day-of-week labels ─────────────────────────────────────────────
          Row(
            children: _kDayLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: const TextStyle(
                                color: Colors.black38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),

          // ── Calendar grid ──────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            children: [
              for (int i = 0; i < leadingEmpty; i++) const SizedBox(),
              for (int d = 1; d <= daysInMonth; d++) _buildCell(d, today),
            ],
          ),
          const SizedBox(height: 8),

          // ── Helper text ────────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _start == null
                  ? 'Tap to select start date'
                  : _end == null
                      ? 'Now tap to select end date'
                      : '',
              style: const TextStyle(color: Colors.black38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),

          // ── Cancel button ──────────────────────────────────────────────────
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.black87),
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              // "Done" only if user manually wants to confirm without closing
              if (_start != null && _end != null)
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop(DateTimeRange(start: _start!, end: _end!)),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int d, DateTime today) {
    final date    = DateTime(_viewMonth.year, _viewMonth.month, d);
    final isPast  = date.isBefore(today);
    final isStart = _start != null && _same(date, _start!);
    final isEnd   = _end   != null && _same(date, _end!);
    final inRange = _inRange(date);
    final isSingle = isStart && isEnd;

    return GestureDetector(
      onTap: isPast ? null : () => _onDayTap(date),
      behavior: HitTestBehavior.opaque,
      child: _DayCell(
        day: d,
        isPast: isPast,
        isStart: isStart,
        isEnd: isEnd,
        inRange: inRange,
        isSingle: isSingle,
        stripColor: _kStripColor,
      ),
    );
  }
}

// ── Day Cell ──────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int        day;
  final bool       isPast;
  final bool       isStart;
  final bool       isEnd;
  final bool       inRange;
  final bool       isSingle;
  final Color      stripColor;

  const _DayCell({
    required this.day,
    required this.isPast,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.isSingle,
    required this.stripColor,
  });

  @override
  Widget build(BuildContext context) {
    // Show strip only when both endpoints are selected and it's not a single day
    final showStrip = !isSingle && (isStart || isEnd || inRange);

    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Horizontal range strip ─────────────────────────────────────────
        if (showStrip)
          Positioned.fill(
            // Vertical inset so strip doesn't touch row above/below
            top: 5,
            bottom: 5,
            child: Row(
              children: [
                // Left half: transparent for start cell, colored otherwise
                Expanded(
                  child: Container(
                    color: isStart ? Colors.transparent : stripColor,
                  ),
                ),
                // Right half: transparent for end cell, colored otherwise
                Expanded(
                  child: Container(
                    color: isEnd ? Colors.transparent : stripColor,
                  ),
                ),
              ],
            ),
          ),

        // ── Selection circle ───────────────────────────────────────────────
        if (isStart || isEnd)
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),

        // ── Day number ─────────────────────────────────────────────────────
        Text(
          '$day',
          style: TextStyle(
            color: isPast
                ? Colors.black26
                : (isStart || isEnd)
                    ? Colors.white
                    : Colors.black87,
            fontSize: 14,
            fontWeight: (isStart || isEnd)
                ? FontWeight.w700
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ── Nav button ────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData   icon;
  final bool       enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon,
            color: enabled ? Colors.black87 : Colors.black26, size: 22),
        onPressed: enabled ? onTap : null,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
}

// ── Extension helper ──────────────────────────────────────────────────────────

extension _LetExt on DateTime? {
  DateTime? let(DateTime Function(DateTime) fn) =>
      this == null ? null : fn(this!);
}
