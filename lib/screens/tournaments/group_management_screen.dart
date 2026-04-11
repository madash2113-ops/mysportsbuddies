import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// GroupManagementScreen
// ══════════════════════════════════════════════════════════════════════════════

class GroupManagementScreen extends StatefulWidget {
  final String tournamentId;
  const GroupManagementScreen({super.key, required this.tournamentId});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Refresh detail so groups are loaded
    TournamentService().loadDetail(widget.tournamentId);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[700] : Colors.green[700],
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── dialogs ────────────────────────────────────────────────────────────────

  void _showGroupCountPicker(BuildContext context, int existingCount) {
    showDialog<int>(
      context: context,
      builder: (_) => _GroupCountDialog(
        existingCount: existingCount,
        teamCount: TournamentService().teamsFor(widget.tournamentId).length,
      ),
    ).then((count) {
      if (count != null && count >= 2) {
        _run(() => TournamentService()
            .createGroups(widget.tournamentId, count)
            .then((_) => _snack('$count groups created')));
      }
    });
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete All Groups',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove all groups and their generated matches.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        _run(() => TournamentService()
            .deleteAllGroups(widget.tournamentId)
            .then((_) => _snack('All groups removed')));
      }
    });
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc        = TournamentService();
        final groups     = svc.groupsFor(widget.tournamentId);
        final allTeams   = svc.teamsFor(widget.tournamentId);
        final canManage  = svc.isHost(widget.tournamentId) ||
            svc.canDo(widget.tournamentId, AdminPermission.scheduleMatches);

        final assignedIds =
            groups.expand((g) => g.teamIds).toSet();
        final unassigned =
            allTeams.where((t) => !assignedIds.contains(t.id)).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Group Stage',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            centerTitle: true,
            actions: [
              if (canManage && groups.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent, size: 22),
                  tooltip: 'Delete all groups',
                  onPressed: () => _confirmDeleteAll(context),
                ),
            ],
          ),
          body: Stack(
            children: [
              groups.isEmpty
                  ? _EmptyGroupState(
                      canManage: canManage,
                      onCreate: () =>
                          _showGroupCountPicker(context, 0),
                    )
                  : _GroupListBody(
                      groups:       groups,
                      allTeams:     allTeams,
                      unassigned:   unassigned,
                      canManage:    canManage,
                      tournamentId: widget.tournamentId,
                      onReconfigure: () =>
                          _showGroupCountPicker(context, groups.length),
                      onAssign: (groupId, team) => _run(() =>
                          svc.assignTeamToGroup(
                            tournamentId: widget.tournamentId,
                            groupId:      groupId,
                            teamId:       team.id,
                            teamName:     team.teamName,
                          )),
                      onRemove: (groupId, teamId) => _run(() =>
                          svc.removeTeamFromGroup(
                            tournamentId: widget.tournamentId,
                            groupId:      groupId,
                            teamId:       teamId,
                          )),
                      onGenerateMatches: (groupId) => _run(() =>
                          svc
                              .generateGroupMatches(
                                  widget.tournamentId, groupId)
                              .then((_) => _snack('Matches generated!'))),
                    ),
              if (_busy)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyGroupState extends StatelessWidget {
  final bool canManage;
  final VoidCallback onCreate;
  const _EmptyGroupState(
      {required this.canManage, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text('No Groups Yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
              'Divide your teams into groups for a\nleague-style group stage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            if (canManage) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Create Groups',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                onPressed: onCreate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Scrollable body with group cards ─────────────────────────────────────────

class _GroupListBody extends StatelessWidget {
  final List<TournamentGroup>   groups;
  final List<TournamentTeam>    allTeams;
  final List<TournamentTeam>    unassigned;
  final bool                    canManage;
  final String                  tournamentId;
  final VoidCallback            onReconfigure;
  final void Function(String groupId, TournamentTeam team) onAssign;
  final void Function(String groupId, String teamId)       onRemove;
  final void Function(String groupId)                      onGenerateMatches;

  const _GroupListBody({
    required this.groups,
    required this.allTeams,
    required this.unassigned,
    required this.canManage,
    required this.tournamentId,
    required this.onReconfigure,
    required this.onAssign,
    required this.onRemove,
    required this.onGenerateMatches,
  });

  @override
  Widget build(BuildContext context) {
    final matchCounts = <String, int>{};
    for (final m in TournamentService().matchesFor(tournamentId)) {
      if (m.groupId != null) {
        matchCounts[m.groupId!] = (matchCounts[m.groupId!] ?? 0) + 1;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Header row ──────────────────────────────────────────────────
        Row(children: [
          Text(
            '${groups.length} GROUPS  ·  ${allTeams.length} TEAMS',
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2),
          ),
          const Spacer(),
          if (canManage)
            GestureDetector(
              onTap: onReconfigure,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, color: Colors.white54, size: 14),
                    SizedBox(width: 4),
                    Text('Reconfigure',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ]),
        const SizedBox(height: 16),

        // ── Group cards ──────────────────────────────────────────────────
        for (final group in groups) ...[
          _GroupCard(
            group:          group,
            allTeams:       allTeams,
            unassigned:     unassigned,
            canManage:      canManage,
            matchCount:     matchCounts[group.id] ?? 0,
            onAssign:       (team) => onAssign(group.id, team),
            onRemove:       (teamId) => onRemove(group.id, teamId),
            onGenerateMatches: () => onGenerateMatches(group.id),
          ),
          const SizedBox(height: 12),
        ],

        // ── Unassigned section ───────────────────────────────────────────
        if (unassigned.isNotEmpty) ...[
          const SizedBox(height: 8),
          _UnassignedSection(
            teams:      unassigned,
            groups:     groups,
            canManage:  canManage,
            onAssign:   onAssign,
          ),
        ],
      ],
    );
  }
}

// ── Group card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final TournamentGroup      group;
  final List<TournamentTeam> allTeams;
  final List<TournamentTeam> unassigned;
  final bool                 canManage;
  final int                  matchCount;
  final void Function(TournamentTeam) onAssign;
  final void Function(String teamId)  onRemove;
  final VoidCallback                  onGenerateMatches;

  const _GroupCard({
    required this.group,
    required this.allTeams,
    required this.unassigned,
    required this.canManage,
    required this.matchCount,
    required this.onAssign,
    required this.onRemove,
    required this.onGenerateMatches,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  TournamentTeam? _pendingAdd;

  // Map teamId → teamName for quick lookup
  List<TournamentTeam> get _assignedTeams {
    final ids = widget.group.teamIds.toSet();
    return widget.allTeams.where((t) => ids.contains(t.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final teams = _assignedTeams;
    final hasEnough = teams.length >= 2;
    // group color based on index
    final groupIdx =
        widget.group.name.codeUnitAt(widget.group.name.length - 1) - 65;
    final groupColors = [
      AppColors.primary,
      Colors.indigo,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.green,
    ];
    final color = groupColors[groupIdx % groupColors.length];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13)),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  widget.group.name.split(' ').last, // "A", "B", …
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.group.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      Text(
                        '${teams.length} team${teams.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ]),
              ),
              // Match count badge
              if (widget.matchCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.matchCount} match${widget.matchCount == 1 ? '' : 'es'}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                ),
              // Generate matches button
              if (widget.canManage)
                Tooltip(
                  message: hasEnough
                      ? 'Generate round-robin matches'
                      : 'Add at least 2 teams first',
                  child: GestureDetector(
                    onTap: hasEnough ? widget.onGenerateMatches : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasEnough
                            ? color.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: hasEnough
                                ? color.withValues(alpha: 0.5)
                                : Colors.white12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_fix_high_outlined,
                            color: hasEnough ? color : Colors.white24,
                            size: 13),
                        const SizedBox(width: 4),
                        Text('Generate',
                            style: TextStyle(
                                color: hasEnough
                                    ? color
                                    : Colors.white24,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),

          // ── Team list ──────────────────────────────────────────────────
          if (teams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text('No teams assigned yet.',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            )
          else
            for (int i = 0; i < teams.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05)),
              _TeamRow(
                team:       teams[i],
                color:      color,
                canRemove:  widget.canManage,
                onRemove:   () => widget.onRemove(teams[i].id),
              ),
            ],

          // ── Add team dropdown (admin only) ─────────────────────────────
          if (widget.canManage && widget.unassigned.isNotEmpty) ...[
            Divider(
                height: 1, color: Colors.white.withValues(alpha: 0.07)),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TournamentTeam>(
                      value: _pendingAdd,
                      hint: Row(children: [
                        Icon(Icons.add_circle_outline,
                            size: 16, color: color),
                        const SizedBox(width: 6),
                        const Text('Add team…',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ]),
                      dropdownColor: const Color(0xFF252525),
                      iconEnabledColor: Colors.white38,
                      isExpanded: true,
                      items: widget.unassigned
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.teamName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (t) =>
                          setState(() => _pendingAdd = t),
                    ),
                  ),
                ),
                if (_pendingAdd != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final t = _pendingAdd!;
                      setState(() => _pendingAdd = null);
                      widget.onAssign(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text('Add',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Team row inside a group card ──────────────────────────────────────────────

class _TeamRow extends StatelessWidget {
  final TournamentTeam team;
  final Color          color;
  final bool           canRemove;
  final VoidCallback   onRemove;
  const _TeamRow({
    required this.team,
    required this.color,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            team.teamName.isNotEmpty
                ? team.teamName[0].toUpperCase()
                : '?',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.teamName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text('Captain: ${team.captainName}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
        ),
        if (canRemove)
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, color: Colors.white38, size: 18),
            ),
          ),
      ]),
    );
  }
}

// ── Unassigned teams section ──────────────────────────────────────────────────

class _UnassignedSection extends StatelessWidget {
  final List<TournamentTeam>    teams;
  final List<TournamentGroup>   groups;
  final bool                    canManage;
  final void Function(String groupId, TournamentTeam team) onAssign;

  const _UnassignedSection({
    required this.teams,
    required this.groups,
    required this.canManage,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('UNASSIGNED',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${teams.length}',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < teams.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05)),
                _UnassignedRow(
                  team:      teams[i],
                  groups:    groups,
                  canAssign: canManage,
                  onAssign:  (groupId) => onAssign(groupId, teams[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UnassignedRow extends StatefulWidget {
  final TournamentTeam        team;
  final List<TournamentGroup> groups;
  final bool                  canAssign;
  final void Function(String groupId) onAssign;
  const _UnassignedRow({
    required this.team,
    required this.groups,
    required this.canAssign,
    required this.onAssign,
  });

  @override
  State<_UnassignedRow> createState() => _UnassignedRowState();
}

class _UnassignedRowState extends State<_UnassignedRow> {
  TournamentGroup? _selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            widget.team.teamName.isNotEmpty
                ? widget.team.teamName[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(widget.team.teamName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
        if (widget.canAssign) ...[
          DropdownButtonHideUnderline(
            child: DropdownButton<TournamentGroup>(
              value: _selected,
              hint: const Text('Assign to…',
                  style:
                      TextStyle(color: Colors.white54, fontSize: 12)),
              dropdownColor: const Color(0xFF252525),
              iconEnabledColor: Colors.orange,
              items: widget.groups
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (g) {
                if (g != null) {
                  widget.onAssign(g.id);
                  setState(() => _selected = null);
                }
              },
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Group count picker dialog ─────────────────────────────────────────────────

class _GroupCountDialog extends StatefulWidget {
  final int existingCount;
  final int teamCount;
  const _GroupCountDialog(
      {required this.existingCount, required this.teamCount});

  @override
  State<_GroupCountDialog> createState() => _GroupCountDialogState();
}

class _GroupCountDialogState extends State<_GroupCountDialog> {
  int _selected = 2;

  @override
  void initState() {
    super.initState();
    _selected = widget.existingCount >= 2 ? widget.existingCount : 2;
  }

  @override
  Widget build(BuildContext context) {
    final options = [2, 3, 4, 6, 8]
        .where((n) => n <= widget.teamCount)
        .toList();
    // Always offer at least 2 if team count allows
    if (options.isEmpty && widget.teamCount >= 2) options.add(2);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existingCount == 0
            ? 'Create Groups'
            : 'Reconfigure Groups',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.teamCount} team${widget.teamCount == 1 ? '' : 's'} registered.',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (widget.existingCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Existing group assignments and matches will be cleared.',
                    style: TextStyle(
                        color: Colors.orange, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Number of groups:',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (options.isEmpty)
            const Text(
              'You need at least 2 teams to create groups.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((n) {
                final isSelected = n == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white24,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      '$n',
                      style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white60,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54))),
        if (options.isNotEmpty)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(
              widget.existingCount == 0 ? 'Create' : 'Reconfigure',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
