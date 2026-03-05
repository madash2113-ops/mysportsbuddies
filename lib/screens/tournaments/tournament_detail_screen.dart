import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import 'bracket_widget.dart';
import 'enroll_team_sheet.dart';

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _generatingSchedule = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    TournamentService().loadDetail(widget.tournamentId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Tournament? get _tournament => TournamentService()
      .tournaments
      .where((t) => t.id == widget.tournamentId)
      .firstOrNull;

  bool get _isHost =>
      _tournament?.createdBy == UserService().userId;

  Future<void> _generateSchedule() async {
    setState(() => _generatingSchedule = true);
    try {
      await TournamentService().generateSchedule(widget.tournamentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule generated! Check the Bracket tab.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _tabs.animateTo(1); // switch to Bracket tab
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingSchedule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final t = _tournament;

        if (t == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final teams   = TournamentService().teamsFor(widget.tournamentId);
        final matches = TournamentService().matchesFor(widget.tournamentId);
        final rounds  = TournamentService().buildRounds(widget.tournamentId);
        final isKO    = t.format == TournamentFormat.knockout ||
                        t.format == TournamentFormat.leagueKnockout;
        final isRR    = t.format == TournamentFormat.roundRobin ||
                        t.format == TournamentFormat.leagueKnockout;
        final isOpen  = t.status == TournamentStatus.open;
        final isFull  = t.maxTeams > 0 && teams.length >= t.maxTeams;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                backgroundColor: AppColors.background,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner image or gradient
                      if (t.bannerUrl != null)
                        Image.network(t.bannerUrl!, fit: BoxFit.cover)
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7B0000), Color(0xFF1A0000)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      // Dark overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 56,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Chip(t.sport, Colors.white24, Colors.white),
                                const SizedBox(width: 8),
                                _Chip(_statusLabel(t.status),
                                    _statusColor(t.status).withValues(alpha: 0.25),
                                    _statusColor(t.status)),
                                const SizedBox(width: 8),
                                _Chip(_formatLabel(t.format),
                                    AppColors.primary.withValues(alpha: 0.25),
                                    AppColors.primary),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Schedule'),
                    Tab(text: 'Bracket'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                // ── Tab 1: Schedule ────────────────────────────────────
                _ScheduleTab(
                  tournament:         t,
                  teams:              teams,
                  matches:            matches,
                  isHost:             _isHost,
                  isOpen:             isOpen,
                  isFull:             isFull,
                  generatingSchedule: _generatingSchedule,
                  onEnroll: () => EnrollTeamSheet.show(
                    context,
                    tournamentId:   t.id,
                    entryFee:       t.entryFee,
                    serviceFee:     t.serviceFee,
                    playersPerTeam: t.playersPerTeam,
                  ),
                  onGenerateSchedule:
                      (_isHost && !t.bracketGenerated && teams.length >= 2)
                          ? _generateSchedule
                          : null,
                ),

                // ── Tab 2: Bracket ─────────────────────────────────────
                !t.bracketGenerated
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_tree_outlined,
                                size: 64, color: Colors.white12),
                            const SizedBox(height: 16),
                            const Text('No bracket yet',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 16)),
                            const SizedBox(height: 8),
                            if (_isHost && teams.length >= 2)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                onPressed: _generatingSchedule
                                    ? null
                                    : _generateSchedule,
                                child: _generatingSchedule
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('Generate Schedule',
                                        style: TextStyle(
                                            color: Colors.white)),
                              ),
                          ],
                        ),
                      )
                    : isKO
                        ? isRR
                            ? SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16, 16, 16, 4),
                                      child: Text('Points Table',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                    PointsTableWidget(teams: teams),
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16, 16, 16, 4),
                                      child: Text('Knockout Bracket',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                    BracketWidget(
                                      tournamentId: widget.tournamentId,
                                      rounds: rounds,
                                      isHost: _isHost,
                                    ),
                                  ],
                                ),
                              )
                            : BracketWidget(
                                tournamentId: widget.tournamentId,
                                rounds: rounds,
                                isHost: _isHost,
                              )
                        : PointsTableWidget(teams: teams),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.open:      return Colors.green;
      case TournamentStatus.ongoing:   return Colors.orange;
      case TournamentStatus.completed: return Colors.blue;
      case TournamentStatus.cancelled: return Colors.red;
    }
  }

  String _statusLabel(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.open:      return 'Open';
      case TournamentStatus.ongoing:   return 'Ongoing';
      case TournamentStatus.completed: return 'Completed';
      case TournamentStatus.cancelled: return 'Cancelled';
    }
  }

  String _formatLabel(TournamentFormat f) {
    switch (f) {
      case TournamentFormat.knockout:       return 'Knockout';
      case TournamentFormat.roundRobin:     return 'Round Robin';
      case TournamentFormat.leagueKnockout: return 'League+KO';
    }
  }
}

// ── Schedule Tab ────────────────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  final Tournament             tournament;
  final List<TournamentTeam>   teams;
  final List<TournamentMatch>  matches;
  final bool                   isHost;
  final bool                   isOpen;
  final bool                   isFull;
  final bool                   generatingSchedule;
  final VoidCallback           onEnroll;
  final VoidCallback?          onGenerateSchedule;

  const _ScheduleTab({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.isHost,
    required this.isOpen,
    required this.isFull,
    required this.generatingSchedule,
    required this.onEnroll,
    this.onGenerateSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    // Group matches by round
    final Map<int, List<TournamentMatch>> byRound = {};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final sortedRounds = byRound.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Info strip ────────────────────────────────────────────────
          _InfoStrip(t: t, teamCount: teams.length),
          const SizedBox(height: 16),

          // ── Register / status button ──────────────────────────────────
          if (isOpen)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFull ? Colors.grey.shade700 : AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isFull ? null : onEnroll,
                child: Text(
                  isFull ? 'Tournament Full' : 'Register Your Team',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),

          if (!isOpen)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Enrollment closed — ${t.status.name}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

          // ── Host: Generate schedule button ────────────────────────────
          if (onGenerateSchedule != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed:
                    generatingSchedule ? null : onGenerateSchedule,
                icon: generatingSchedule
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary))
                    : const Icon(Icons.account_tree_outlined,
                        color: AppColors.primary),
                label: Text(
                  generatingSchedule
                      ? 'Generating…'
                      : 'Generate Schedule',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          // ── Rules ─────────────────────────────────────────────────────
          if (t.rules != null && t.rules!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Rules & Regulations',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(t.rules!,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13, height: 1.5)),
            ),
          ],

          // ── Match schedule table ───────────────────────────────────────
          const SizedBox(height: 24),
          if (matches.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_outlined,
                        size: 40, color: Colors.white12),
                    SizedBox(height: 10),
                    Text('No matches scheduled yet',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Generate the schedule to see match fixtures',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else ...[
            const Text('Match Schedule',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final roundNum in sortedRounds) ...[
              _RoundBlock(
                roundNum: roundNum,
                matches: byRound[roundNum]!,
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Info strip ─────────────────────────────────────────────────────────────

class _InfoStrip extends StatelessWidget {
  final Tournament t;
  final int        teamCount;
  const _InfoStrip({required this.t, required this.teamCount});

  @override
  Widget build(BuildContext context) {
    final maxStr = t.maxTeams == 0 ? 'Unlimited' : '${t.maxTeams}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _infoRow(Icons.calendar_today_outlined, 'Start Date',
              '${t.startDate.day}/${t.startDate.month}/${t.startDate.year}'),
          if (t.endDate != null)
            _infoRow(Icons.event_outlined, 'End Date',
                '${t.endDate!.day}/${t.endDate!.month}/${t.endDate!.year}'),
          _infoRow(Icons.location_on_outlined, 'Venue', t.location),
          _infoRow(Icons.groups_outlined, 'Teams',
              '$teamCount / $maxStr enrolled'),
          _infoRow(Icons.sports_outlined, 'Sport', t.sport),
          _infoRow(Icons.format_list_bulleted, 'Format',
              _fmtLabel(t.format)),
          _infoRow(Icons.person_outlined, 'Players/Team',
              t.playersPerTeam == 0
                  ? 'No limit'
                  : '${t.playersPerTeam} players'),
          if (t.prizePool != null && t.prizePool!.isNotEmpty)
            _infoRow(Icons.emoji_events_outlined, 'Prize Pool',
                t.prizePool!),
          _infoRow(Icons.currency_rupee_outlined, 'Entry Fee',
              t.entryFee == 0 ? 'Free' : '₹${t.totalFee.toInt()}'),
          _infoRow(Icons.person_pin_outlined, 'Organized by',
              t.createdByName),
        ],
      ),
    );
  }

  String _fmtLabel(TournamentFormat f) {
    switch (f) {
      case TournamentFormat.knockout:       return 'Knockout';
      case TournamentFormat.roundRobin:     return 'Round Robin';
      case TournamentFormat.leagueKnockout: return 'League + Knockout';
    }
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white38),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

// ── Round block (one round's matches) ──────────────────────────────────────

class _RoundBlock extends StatelessWidget {
  final int                   roundNum;
  final List<TournamentMatch> matches;

  const _RoundBlock({required this.roundNum, required this.matches});

  @override
  Widget build(BuildContext context) {
    final sorted = [...matches]..sort((a, b) =>
        a.matchIndex.compareTo(b.matchIndex));
    final label  = TournamentService.roundLabel(sorted.length);
    final completedCnt = sorted.where((m) => m.isPlayed && !m.isBye).length;
    final totalNonBye  = sorted.where((m) => !m.isBye).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text('Round $roundNum',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (totalNonBye > 0)
                  Text('$completedCnt/$totalNonBye played',
                      style: TextStyle(
                          color: completedCnt == totalNonBye
                              ? Colors.green
                              : Colors.white38,
                          fontSize: 11)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Match rows
          ...sorted.map((m) => _MatchRow(match: m)),
        ],
      ),
    );
  }
}

// ── Single match row ────────────────────────────────────────────────────────

class _MatchRow extends StatelessWidget {
  final TournamentMatch match;
  const _MatchRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final m        = match;
    final isPlayed = m.result != TournamentMatchResult.pending && !m.isBye;
    final isBye    = m.isBye;

    if (isBye) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(m.teamAName ?? 'TBD',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('BYE — advances',
                  style: TextStyle(color: Colors.green, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    final teamAName = m.teamAName ?? 'TBD';
    final teamBName = m.teamBName ?? 'TBD';
    final scoreStr  = isPlayed
        ? '${m.scoreA}  —  ${m.scoreB}'
        : 'vs';

    // Determine winner for highlight
    final aWon = m.result == TournamentMatchResult.teamAWin;
    final bWon = m.result == TournamentMatchResult.teamBWin;

    // Status label
    Widget statusBadge;
    if (isPlayed) {
      statusBadge = const Icon(Icons.check_circle,
          color: Colors.green, size: 16);
    } else if (m.teamAId == null || m.teamBId == null) {
      statusBadge = const Icon(Icons.hourglass_empty,
          color: Colors.white24, size: 16);
    } else {
      statusBadge = const Icon(Icons.schedule_outlined,
          color: Colors.orange, size: 16);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Team A
          Expanded(
            child: Text(
              teamAName,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: aWon
                    ? AppColors.primary
                    : (m.teamAId == null ? Colors.white24 : Colors.white),
                fontSize: 13,
                fontWeight:
                    aWon ? FontWeight.w700 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score / vs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isPlayed
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              scoreStr,
              style: TextStyle(
                color: isPlayed ? AppColors.primary : Colors.white38,
                fontSize: 12,
                fontWeight:
                    isPlayed ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          // Team B
          Expanded(
            child: Text(
              teamBName,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: bWon
                    ? AppColors.primary
                    : (m.teamBId == null ? Colors.white24 : Colors.white),
                fontSize: 13,
                fontWeight:
                    bWon ? FontWeight.w700 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status icon
          const SizedBox(width: 8),
          statusBadge,
        ],
      ),
    );
  }
}

// ── Small helpers ───────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String text;
  final Color  bg;
  final Color  fg;
  const _Chip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}
