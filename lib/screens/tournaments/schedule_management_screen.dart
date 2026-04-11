import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ScheduleManagementScreen — manual drag-and-drop + auto-generate fixtures
// ══════════════════════════════════════════════════════════════════════════════

class ScheduleManagementScreen extends StatefulWidget {
  final String tournamentId;
  const ScheduleManagementScreen({super.key, required this.tournamentId});

  @override
  State<ScheduleManagementScreen> createState() => _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  TournamentTeam? _slotA;
  TournamentTeam? _slotB;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // Tap a team chip to assign to next empty slot, or deselect if already selected
  void _onTapTeam(TournamentTeam team) {
    setState(() {
      if (_slotA?.id == team.id) {
        _slotA = null;
        return;
      }
      if (_slotB?.id == team.id) {
        _slotB = null;
        return;
      }
      if (_slotA == null) {
        _slotA = team;
        return;
      }
      if (_slotB == null) {
        _slotB = team;
        return;
      }
    });
    // Both full — ask which to replace
    if (_slotA != null && _slotB != null) {
      _showReplaceDialog(team);
    }
  }

  void _showReplaceDialog(TournamentTeam team) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Assign to slot',
            style: TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Replace Slot A (${_slotA?.teamName}) or Slot B (${_slotB?.teamName})?',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _slotA = team);
            },
            child: const Text('Slot A',
                style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _slotB = team);
            },
            child: const Text('Slot B',
                style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  Future<void> _onScheduleMatch() async {
    if (_slotA == null || _slotB == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TimeVenueSheet(
        tournamentId: widget.tournamentId,
        teamA: _slotA!,
        teamB: _slotB!,
      ),
    );
    if (ok == true) {
      setState(() { _slotA = null; _slotB = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Schedule Matches',
            style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Manual Builder'),
            Tab(text: 'Auto Generate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ManualBuilderTab(
            tournamentId: widget.tournamentId,
            slotA:        _slotA,
            slotB:        _slotB,
            onDropSlotA:  (t) => setState(() => _slotA = t),
            onDropSlotB:  (t) => setState(() => _slotB = t),
            onClearSlotA: () => setState(() => _slotA = null),
            onClearSlotB: () => setState(() => _slotB = null),
            onTapTeam:    _onTapTeam,
            onSchedule:   _onScheduleMatch,
            onClearAll:   () => setState(() { _slotA = null; _slotB = null; }),
          ),
          _AutoGenerateTab(tournamentId: widget.tournamentId),
        ],
      ),
    );
  }
}

// ── Manual Builder Tab ────────────────────────────────────────────────────────

class _ManualBuilderTab extends StatelessWidget {
  final String tournamentId;
  final TournamentTeam?          slotA;
  final TournamentTeam?          slotB;
  final ValueChanged<TournamentTeam> onDropSlotA;
  final ValueChanged<TournamentTeam> onDropSlotB;
  final VoidCallback             onClearSlotA;
  final VoidCallback             onClearSlotB;
  final ValueChanged<TournamentTeam> onTapTeam;
  final VoidCallback             onSchedule;
  final VoidCallback             onClearAll;

  const _ManualBuilderTab({
    required this.tournamentId,
    required this.slotA,
    required this.slotB,
    required this.onDropSlotA,
    required this.onDropSlotB,
    required this.onClearSlotA,
    required this.onClearSlotB,
    required this.onTapTeam,
    required this.onSchedule,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final teams   = TournamentService().teamsFor(tournamentId);
        final matches = TournamentService().matchesFor(tournamentId);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Teams pool ─────────────────────────────────────────────────
            _SectionLabel('Teams Pool (${teams.length})'),
            const SizedBox(height: 10),
            if (teams.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No teams registered yet',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: teams.map((team) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LongPressDraggable<TournamentTeam>(
                      data: team,
                      feedback: Material(
                        color: Colors.transparent,
                        child: _TeamChip(
                            team: team, selected: false, isDragging: true),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: _TeamChip(
                            team: team, selected: false, isDragging: false),
                      ),
                      child: GestureDetector(
                        onTap: () => onTapTeam(team),
                        child: _TeamChip(
                          team: team,
                          selected: slotA?.id == team.id || slotB?.id == team.id,
                          isDragging: false,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 20),

            // ── Pairing builder ────────────────────────────────────────────
            _SectionLabel('Pairing Builder'),
            const SizedBox(height: 4),
            const Text('Long-press & drag teams to slots, or tap to quick-assign',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: DragTarget<TournamentTeam>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (d) => onDropSlotA(d.data),
                  builder: (context, candidates, _) => _DropSlot(
                    team:          slotA,
                    label:         'Team A',
                    color:         AppColors.primary,
                    isHighlighted: candidates.isNotEmpty,
                    onClear:       slotA != null ? onClearSlotA : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('vs',
                    style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: DragTarget<TournamentTeam>(
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (d) => onDropSlotB(d.data),
                  builder: (context, candidates, _) => _DropSlot(
                    team:          slotB,
                    label:         'Team B',
                    color:         Colors.orange,
                    isHighlighted: candidates.isNotEmpty,
                    onClear:       slotB != null ? onClearSlotB : null,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: slotA != null && slotB != null
                        ? AppColors.primary
                        : Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: (slotA != null && slotB != null) ? onSchedule : null,
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 18),
                  label: const Text('Schedule This Match',
                      style: TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              if (slotA != null || slotB != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.clear_rounded, color: Colors.white38),
                  tooltip: 'Clear slots',
                ),
              ],
            ]),
            const SizedBox(height: 28),

            // ── Scheduled matches ──────────────────────────────────────────
            _SectionLabel('Scheduled Matches (${matches.length})'),
            const SizedBox(height: 10),
            if (matches.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_outlined,
                        color: Colors.white24, size: 40),
                    SizedBox(height: 8),
                    Text('No matches scheduled yet',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Pair teams above or use Auto Generate tab',
                        style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ]),
                ),
              )
            else
              _MatchesList(tournamentId: tournamentId, matches: matches),
          ]),
        );
      },
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(color: Colors.white38, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1.2));
}

// ── Team chip (draggable source) ──────────────────────────────────────────────

class _TeamChip extends StatelessWidget {
  final TournamentTeam team;
  final bool           selected;
  final bool           isDragging;
  const _TeamChip({
    required this.team,
    required this.selected,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.white24;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withAlpha(30) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: isDragging ? 2 : 1),
        boxShadow: isDragging
            ? [BoxShadow(
                color: AppColors.primary.withAlpha(80),
                blurRadius: 12, spreadRadius: 2)]
            : null,
      ),
      child: Text(team.teamName,
          style: TextStyle(
              color: selected ? AppColors.primary : Colors.white70,
              fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Drop slot (DragTarget container) ─────────────────────────────────────────

class _DropSlot extends StatelessWidget {
  final TournamentTeam? team;
  final String          label;
  final Color           color;
  final bool            isHighlighted;
  final VoidCallback?   onClear;
  const _DropSlot({
    required this.team,
    required this.label,
    required this.color,
    required this.isHighlighted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 84,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withAlpha(50)
            : team != null
                ? color.withAlpha(20)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? color
              : team != null ? color.withAlpha(160) : Colors.white24,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: team == null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline, color: color.withAlpha(140), size: 22),
              const SizedBox(height: 4),
              Text(
                isHighlighted ? 'Release to assign' : 'Drag or tap $label',
                textAlign: TextAlign.center,
                style: TextStyle(color: color.withAlpha(140), fontSize: 10),
              ),
            ])
          : Stack(children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(team!.teamName,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color,
                          fontSize: 12, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              if (onClear != null)
                Positioned(
                  top: 0, right: 0,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.cancel_rounded,
                        color: color.withAlpha(180), size: 18),
                  ),
                ),
            ]),
    );
  }
}

// ── Matches list ──────────────────────────────────────────────────────────────

class _MatchesList extends StatelessWidget {
  final String               tournamentId;
  final List<TournamentMatch> matches;
  const _MatchesList({required this.tournamentId, required this.matches});

  String _fmtDt(DateTime? dt) {
    if (dt == null) return 'No date set';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final Map<int, List<TournamentMatch>> byRound = {};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final sortedRounds = byRound.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedRounds.map((round) {
        final roundMatches = byRound[round]!;
        final firstNote = roundMatches.first.note;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Text('Round $round',
                      style: const TextStyle(color: AppColors.primary,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                if (firstNote != null && firstNote.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(firstNote,
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ]),
            ),
            ...roundMatches.map((m) => _MatchRow(
              match: m,
              tournamentId: tournamentId,
              fmtDt: _fmtDt,
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final TournamentMatch  match;
  final String           tournamentId;
  final String Function(DateTime?) fmtDt;
  const _MatchRow({
    required this.match,
    required this.tournamentId,
    required this.fmtDt,
  });

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Match',
            style: TextStyle(color: Colors.white,
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${match.teamAName ?? "TBD"} vs ${match.teamBName ?? "TBD"}"?',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TournamentService().deleteMatch(tournamentId, match.id);
  }

  Future<void> _edit(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TimeVenueSheet(
        tournamentId:  tournamentId,
        existingMatch: match,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${match.teamAName ?? "TBD"}  vs  ${match.teamBName ?? "TBD"}',
            style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule_outlined, color: Colors.white38, size: 12),
            const SizedBox(width: 4),
            Text(fmtDt(match.scheduledAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
          if (match.venueName != null && match.venueName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.stadium_outlined, color: Colors.white38, size: 12),
              const SizedBox(width: 4),
              Expanded(child: Text(match.venueName!,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: [
          // Result indicator
          if (match.isPlayed)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('DONE',
                  style: TextStyle(color: Colors.green,
                      fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
            onPressed: () => _edit(context),
            tooltip: 'Edit schedule',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => _delete(context),
            tooltip: 'Delete match',
          ),
        ]),
      ]),
    );
  }
}

// ── Time + Venue Bottom Sheet ─────────────────────────────────────────────────

class _TimeVenueSheet extends StatefulWidget {
  final String           tournamentId;
  final TournamentTeam?  teamA;
  final TournamentTeam?  teamB;
  final TournamentMatch? existingMatch;
  const _TimeVenueSheet({
    required this.tournamentId,
    this.teamA,
    this.teamB,
    this.existingMatch,
  });

  @override
  State<_TimeVenueSheet> createState() => _TimeVenueSheetState();
}

class _TimeVenueSheetState extends State<_TimeVenueSheet> {
  DateTime?        _date;
  TimeOfDay?       _time;
  TournamentVenue? _venue;
  final _noteCtrl  = TextEditingController();
  final _roundCtrl = TextEditingController(text: '1');
  bool _saving     = false;

  @override
  void initState() {
    super.initState();
    final m = widget.existingMatch;
    if (m != null) {
      if (m.scheduledAt != null) {
        _date = m.scheduledAt;
        _time = TimeOfDay(
            hour: m.scheduledAt!.hour, minute: m.scheduledAt!.minute);
      }
      _noteCtrl.text  = m.note ?? '';
      _roundCtrl.text = '${m.round}';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = widget.existingMatch;
    if (m?.venueId != null && _venue == null) {
      _venue = TournamentService()
          .venuesFor(widget.tournamentId)
          .where((v) => v.id == m!.venueId)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _roundCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  DateTime? get _combined {
    if (_date == null) return null;
    final t = _time ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(_date!.year, _date!.month, _date!.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = TournamentService();
      if (widget.existingMatch != null) {
        await svc.updateMatchSchedule(
          tournamentId: widget.tournamentId,
          matchId:      widget.existingMatch!.id,
          scheduledAt:  _combined,
          venueId:      _venue?.id,
          venueName:    _venue?.name,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          round: int.tryParse(_roundCtrl.text.trim()),
        );
      } else {
        await svc.createCustomMatch(
          tournamentId: widget.tournamentId,
          teamAId:      widget.teamA!.id,
          teamAName:    widget.teamA!.teamName,
          teamBId:      widget.teamB!.id,
          teamBName:    widget.teamB!.teamName,
          scheduledAt:  _combined,
          venueId:      _venue?.id,
          venueName:    _venue?.name,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          round: int.tryParse(_roundCtrl.text.trim()) ?? 1,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()),
                backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venues = TournamentService().venuesFor(widget.tournamentId);
    final isEdit = widget.existingMatch != null;

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        Text(isEdit ? 'Reschedule Match' : 'Schedule Match',
            style: const TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),

        if (!isEdit && widget.teamA != null && widget.teamB != null) ...[
          const SizedBox(height: 6),
          Text('${widget.teamA!.teamName}  vs  ${widget.teamB!.teamName}',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
        const SizedBox(height: 20),

        // Date & time
        Row(children: [
          Expanded(child: _SheetTile(
            icon:  Icons.calendar_today_outlined,
            label: _date != null
                ? '${_date!.day}/${_date!.month}/${_date!.year}'
                : 'Pick Date',
            onTap: _pickDate,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SheetTile(
            icon:  Icons.schedule_outlined,
            label: _time != null ? _time!.format(context) : 'Pick Time',
            onTap: _pickTime,
          )),
        ]),
        const SizedBox(height: 10),

        // Venue dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButton<TournamentVenue?>(
            value: _venue,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            hint: const Text('Select Venue (optional)',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            items: [
              const DropdownMenuItem<TournamentVenue?>(
                value: null,
                child: Text('No Venue',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
              ...venues.map((v) => DropdownMenuItem<TournamentVenue?>(
                value: v,
                child: Text(v.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              )),
            ],
            onChanged: (v) => setState(() => _venue = v),
          ),
        ),
        const SizedBox(height: 10),

        // Round + label row
        Row(children: [
          SizedBox(
            width: 80,
            child: TextField(
              controller: _roundCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Round',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true, fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Label (e.g. Quarter-Final, Group A)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                filled: true, fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(isEdit ? 'Save Changes' : 'Save Match',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
            style: const TextStyle(color: Colors.white70,
                fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ── Auto Generate Tab ─────────────────────────────────────────────────────────

class _AutoGenerateTab extends StatefulWidget {
  final String tournamentId;
  const _AutoGenerateTab({required this.tournamentId});

  @override
  State<_AutoGenerateTab> createState() => _AutoGenerateTabState();
}

class _AutoGenerateTabState extends State<_AutoGenerateTab> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await TournamentService().generateSchedule(widget.tournamentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Schedule generated successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc     = TournamentService();
        final t       = svc.tournaments
            .where((x) => x.id == widget.tournamentId).firstOrNull;
        final teams   = svc.teamsFor(widget.tournamentId);
        final matches = svc.matchesFor(widget.tournamentId);

        if (t == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final recommendation = TournamentService.scheduleRecommendation(
            teams.length, t.sport, t.format);
        final canGenerate = teams.length >= 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOURNAMENT INFO',
                    style: TextStyle(color: Colors.white38, fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                _InfoRow(label: 'Sport',  value: t.sport),
                const SizedBox(height: 6),
                _InfoRow(label: 'Format', value: t.format.name),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Teams',
                  value: '${teams.length} registered'
                      '${t.maxTeams > 0 ? " / ${t.maxTeams} max" : ""}',
                ),
                const SizedBox(height: 6),
                _InfoRow(label: 'Status', value: t.status.name),
              ]),
            ),
            const SizedBox(height: 16),

            // Recommendation card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.lightbulb_outline,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  const Text('RECOMMENDED SCHEDULE',
                      style: TextStyle(color: AppColors.primary,
                          fontSize: 10, fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ]),
                const SizedBox(height: 10),
                Text(recommendation,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 14, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 12),

            // Warning if matches already exist
            if (matches.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_outlined,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will replace ${matches.length} existing '
                      'match${matches.length > 1 ? "es" : ""}',
                      style: const TextStyle(color: Colors.amber, fontSize: 13),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 20),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canGenerate
                      ? AppColors.primary : Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (!canGenerate || _generating) ? null : _generate,
                icon: _generating
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_fix_high,
                        color: Colors.white, size: 20),
                label: Text(
                  _generating ? 'Generating...' : 'Auto Generate Schedule',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            if (!canGenerate) ...[
              const SizedBox(height: 8),
              const Center(
                child: Text('Need at least 2 registered teams',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(
      width: 58,
      child: Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ),
    Expanded(child: Text(value,
        style: const TextStyle(color: Colors.white70,
            fontSize: 12, fontWeight: FontWeight.w600))),
  ]);
}
