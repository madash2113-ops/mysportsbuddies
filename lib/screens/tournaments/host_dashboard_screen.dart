import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../sports/league_entry_screen.dart';
import 'admin_management_screen.dart';
import 'enroll_team_sheet.dart';
import 'group_management_screen.dart';
import 'schedule_management_screen.dart';
import 'squad_management_screen.dart';
import 'venue_management_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HostDashboardScreen — management hub for host/admin
// ══════════════════════════════════════════════════════════════════════════════

class HostDashboardScreen extends StatelessWidget {
  final String tournamentId;
  const HostDashboardScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc      = TournamentService();
        final t        = svc.tournaments.where((x) => x.id == tournamentId).firstOrNull;
        final isHost   = svc.isHost(tournamentId);
        final teams    = svc.teamsFor(tournamentId);

        if (t == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Tournament Management',
                style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Tournament info strip
              _TournamentStrip(tournament: t, teamCount: teams.length),
              const SizedBox(height: 24),

              // Status management (host only)
              if (isHost) ...[
                const _SectionLabel('Tournament Status'),
                const SizedBox(height: 8),
                _StatusCard(tournament: t, tournamentId: tournamentId),
                const SizedBox(height: 24),
              ],

              // Action grid
              const _SectionLabel('Manage'),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  // Edit tournament (host only — all statuses)
                  if (isHost)
                    _DashCard(
                      icon:  Icons.edit_outlined,
                      label: 'Edit Tournament',
                      color: Colors.blue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LeagueEntryScreen(
                              existingTournament: t))),
                    ),

                  // Manage Teams
                  _DashCard(
                    icon:  Icons.groups_outlined,
                    label: 'Manage Teams',
                    badge: '${teams.length}',
                    color: AppColors.primary,
                    onTap: () => _showTeamsSheet(context, t, teams, isHost),
                  ),

                  // Group Stage
                  _DashCard(
                    icon:  Icons.workspaces_outlined,
                    label: 'Groups',
                    badge: t.hasGroups ? '${t.groupCount}' : null,
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GroupManagementScreen(
                            tournamentId: tournamentId))),
                  ),

                  // Schedule Matches
                  _DashCard(
                    icon:  Icons.calendar_month_outlined,
                    label: 'Schedule\nMatches',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ScheduleManagementScreen(
                            tournamentId: tournamentId))),
                  ),

                  // Manage Squads
                  _DashCard(
                    icon:  Icons.person_pin_outlined,
                    label: 'Squads',
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SquadManagementScreen(tournamentId: tournamentId))),
                  ),

                  // Manage Venues
                  _DashCard(
                    icon:  Icons.stadium_outlined,
                    label: 'Venues',
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => VenueManagementScreen(tournamentId: tournamentId))),
                  ),

                  // Manage Admins (host only)
                  if (isHost)
                    _DashCard(
                      icon:  Icons.admin_panel_settings_outlined,
                      label: 'Admins',
                      color: Colors.red,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdminManagementScreen(tournamentId: tournamentId))),
                    ),

                  // Enter Results shortcut
                  _DashCard(
                    icon:  Icons.scoreboard_outlined,
                    label: 'Enter Results',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ScheduleManagementScreen(
                            tournamentId: tournamentId))),
                  ),
                ],
              ),
              // ── Danger zone (host only) ────────────────────────────
              if (isHost) ...[
                const SizedBox(height: 32),
                const _SectionLabel('Danger Zone'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _confirmReset(context, t.name),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reset Teams & Matches',
                                  style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('Deletes all registered teams, matches and points. Cannot be undone.',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.redAccent, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _confirmDelete(context, t.name),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.7)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_forever_outlined, color: Colors.red, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Delete Tournament',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('Permanently deletes this tournament and all its data. Cannot be undone.',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.red, size: 20),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 80),
            ]),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String tournamentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Delete Tournament',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete "$tournamentName" and ALL its teams, matches, groups and data.\n\nThis cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TournamentService().deleteTournament(tournamentId);
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, String tournamentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Reset Teams & Matches',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete ALL registered teams, matches, and points for "$tournamentName".\n\nThis cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TournamentService().clearTeamsAndMatches(tournamentId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All teams and matches cleared.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showTeamsSheet(BuildContext context, Tournament t,
      List<TournamentTeam> teams, bool isHost) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TeamsSheet(
          tournament: t, teams: teams, isHost: isHost),
    );
  }
}

// ── Tournament strip ──────────────────────────────────────────────────────────

class _TournamentStrip extends StatelessWidget {
  final Tournament tournament;
  final int        teamCount;
  const _TournamentStrip({required this.tournament, required this.teamCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(
            tournament.name.isNotEmpty ? tournament.name[0].toUpperCase() : 'T',
            style: const TextStyle(color: AppColors.primary,
                fontSize: 20, fontWeight: FontWeight.w800),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tournament.name, style: const TextStyle(color: Colors.white,
              fontSize: 15, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          Text('${tournament.sport}  •  $teamCount teams  •  ${tournament.status.name}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
      ]),
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
          fontWeight: FontWeight.w700, letterSpacing: 1));
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatefulWidget {
  final Tournament tournament;
  final String     tournamentId;
  const _StatusCard({required this.tournament, required this.tournamentId});

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _updating = false;

  Future<void> _setStatus(TournamentStatus status) async {
    setState(() => _updating = true);
    try {
      await TournamentService().updateTournamentStatus(widget.tournamentId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status updated to ${status.name}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t       = widget.tournament;
    final teams   = TournamentService().teamsFor(widget.tournamentId);
    final status  = t.status;
    final now     = DateTime.now();
    final start   = t.startDate;

    // Date helpers
    final todayOnly   = DateTime(now.year, now.month, now.day);
    final startOnly   = DateTime(start.year, start.month, start.day);
    final isFuture    = startOnly.isAfter(todayOnly);
    final isToday     = startOnly == todayOnly;
    final isPast      = startOnly.isBefore(todayOnly);
    final daysUntil   = startOnly.difference(todayOnly).inDays;
    final dateArrived = isToday || isPast; // start date has come

    // Date changed to future while status is ongoing → prompt to reset
    final shouldSuggestReset =
        isFuture && status == TournamentStatus.ongoing;

    // ignore: no_leading_underscores_for_local_identifiers - Local function  
    String _fmtDate(DateTime d) =>
        '${d.day}/${d.month}/${d.year}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Current status row ──────────────────────────────────────
        Row(children: [
          const Text('Status: ',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          _StatusChip(status),
          const Spacer(),
          // Start date pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dateArrived
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: dateArrived
                    ? Colors.orange.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                dateArrived
                    ? Icons.event_available_outlined
                    : Icons.calendar_today_outlined,
                size: 11,
                color: dateArrived ? Colors.orange : Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                isFuture
                    ? 'Starts ${_fmtDate(start)}  ($daysUntil day${daysUntil == 1 ? '' : 's'})'
                    : isToday
                        ? 'Starts today!'
                        : 'Started ${_fmtDate(start)}',
                style: TextStyle(
                  color: dateArrived ? Colors.orange : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Date-aware prompt banner ──────────────────────────────────
        if (shouldSuggestReset) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Start date moved to future — reset status to Open for new registrations?',
                  style: TextStyle(
                      color: Colors.blue, fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        if (status == TournamentStatus.open && dateArrived && teams.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.flag_outlined, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isToday
                      ? 'Tournament starts today! ${teams.length} team${teams.length == 1 ? '' : 's'} registered.'
                      : 'Start date passed. ${teams.length} team${teams.length == 1 ? '' : 's'} registered. Ready to begin?',
                  style: const TextStyle(
                      color: Colors.green, fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        // ── Action buttons ────────────────────────────────────────────
        if (_updating)
          const Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [

            // Reset to open when date moved to future
            if (shouldSuggestReset)
              _ActionBtn(
                label: 'Reset to Open',
                color: Colors.blue,
                onTap: () => _setStatus(TournamentStatus.open),
              ),

            // Start Tournament: show when open + date arrived + has teams
            if (status == TournamentStatus.open && dateArrived && teams.length >= 2)
              _ActionBtn(
                label: 'Start Tournament',
                color: Colors.green,
                onTap: () => _setStatus(TournamentStatus.ongoing),
              ),

            // Allow early start when open + date is future (optional override)
            if (status == TournamentStatus.open && isFuture && teams.length >= 2)
              _ActionBtn(
                label: 'Start Early',
                color: Colors.orange,
                onTap: () => _setStatus(TournamentStatus.ongoing),
                outlined: true,
              ),

            if (status == TournamentStatus.ongoing)
              _ActionBtn(
                label: 'Mark Completed',
                color: Colors.blue,
                onTap: () => _setStatus(TournamentStatus.completed),
              ),

            // Reopen from completed/cancelled if date changed to future
            if ((status == TournamentStatus.completed ||
                    status == TournamentStatus.cancelled) &&
                isFuture)
              _ActionBtn(
                label: 'Reopen Registration',
                color: Colors.green,
                onTap: () => _setStatus(TournamentStatus.open),
                outlined: true,
              ),

            if (status != TournamentStatus.cancelled &&
                status != TournamentStatus.completed)
              _ActionBtn(
                label: 'Cancel',
                color: Colors.red,
                onTap: () => _setStatus(TournamentStatus.cancelled),
                outlined: true,
              ),
          ]),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TournamentStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final colors = {
      TournamentStatus.open:      Colors.green,
      TournamentStatus.ongoing:   Colors.red,
      TournamentStatus.completed: Colors.blue,
      TournamentStatus.cancelled: Colors.red,
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(status.name.toUpperCase(),
          style: TextStyle(color: color,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String    label;
  final Color     color;
  final VoidCallback onTap;
  final bool      outlined;
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withAlpha(120)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        onPressed: onTap,
        child: Text(label, style: TextStyle(color: color,
            fontSize: 13, fontWeight: FontWeight.w600)),
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        elevation: 0,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white,
          fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Dashboard card ────────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final String?    badge;
  final Color      color;
  final VoidCallback onTap;
  const _DashCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(icon, color: color, size: 20)),
            ),
            if (badge != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge!,
                    style: TextStyle(color: color,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const Spacer(),
          Text(label, style: const TextStyle(color: Colors.white,
              fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Teams sheet ───────────────────────────────────────────────────────────────

class _TeamsSheet extends StatefulWidget {
  final Tournament        tournament;
  final List<TournamentTeam> teams;
  final bool              isHost;
  const _TeamsSheet({
    required this.tournament,
    required this.teams,
    required this.isHost,
  });

  @override
  State<_TeamsSheet> createState() => _TeamsSheetState();
}

class _TeamsSheetState extends State<_TeamsSheet> {
  Future<void> _remove(TournamentTeam team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Team',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text('Remove "${team.teamName}"?',
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await TournamentService().removeTeam(widget.tournament.id, team.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final teams  = TournamentService().teamsFor(widget.tournament.id);
    final canRem = widget.isHost && widget.tournament.status == TournamentStatus.open;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize:     0.9,
      minChildSize:     0.4,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Text('Teams (${teams.length}/${widget.tournament.maxTeams > 0 ? widget.tournament.maxTeams : "∞"})',
                style: const TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (widget.isHost)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close teams sheet
                  EnrollTeamSheet.show(
                    context,
                    tournamentId:   widget.tournament.id,
                    entryFee:       widget.tournament.entryFee,
                    serviceFee:     widget.tournament.serviceFee,
                    playersPerTeam: widget.tournament.playersPerTeam,
                    sport:          widget.tournament.sport,
                  );
                },
                icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                label: const Text('Add Team',
                    style: TextStyle(color: AppColors.primary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(color: Colors.white12),
        Expanded(child: ListView.builder(
          controller: ctrl,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: teams.length,
          itemBuilder: (_, i) {
            final team = teams[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30), shape: BoxShape.circle),
                  child: Center(child: Text('${i + 1}',
                      style: const TextStyle(color: AppColors.primary,
                          fontSize: 13, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(team.teamName, style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${team.captainName}  •  ${team.players.length} players',
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ])),
                if (team.paymentConfirmed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PAID',
                        style: TextStyle(color: Colors.green,
                            fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                if (canRem) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    onPressed: () => _remove(team),
                  ),
                ],
              ]),
            );
          },
        )),
      ]),
    );
  }
}
