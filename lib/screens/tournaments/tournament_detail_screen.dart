import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import 'bracket_widget.dart';
import 'enroll_team_sheet.dart';
import 'host_dashboard_screen.dart';
import 'match_detail_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TournamentDetailScreen — 6-tab fixed, all users
// ══════════════════════════════════════════════════════════════════════════════

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  // Fixed length — never changes, no disposal errors
  late final TabController _tabs = TabController(length: 6, vsync: this);
  bool _generatingSchedule = false;

  @override
  void initState() {
    super.initState();
    TournamentService().loadDetail(widget.tournamentId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Tournament? get _t => TournamentService()
      .tournaments.where((t) => t.id == widget.tournamentId).firstOrNull;

  bool get _canManage => TournamentService().isHost(widget.tournamentId) ||
      TournamentService().isAdmin(widget.tournamentId);

  void _snack(String msg, [Color color = Colors.green]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Result entry sheet ────────────────────────────────────────────────────

  void _showResultSheet(TournamentMatch m) {
    if (m.teamAId == null || m.teamBId == null) {
      _snack('Both teams must be set before entering a result.', Colors.orange);
      return;
    }
    final aCtrl = TextEditingController(text: m.scoreA?.toString() ?? '');
    final bCtrl = TextEditingController(text: m.scoreB?.toString() ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Enter Result', style: Theme.of(ctx).textTheme.titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Column(children: [
                  Text(m.teamAName ?? 'Team A',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  _ScoreField(controller: aCtrl),
                ])),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('vs', style: TextStyle(color: Colors.white38, fontSize: 18)),
                ),
                Expanded(child: Column(children: [
                  Text(m.teamBName ?? 'Team B',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  _ScoreField(controller: bCtrl),
                ])),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                  onPressed: saving ? null : () async {
                    final sA = int.tryParse(aCtrl.text.trim()) ?? -1;
                    final sB = int.tryParse(bCtrl.text.trim()) ?? -1;
                    if (sA < 0 || sB < 0) {
                      _snack('Enter valid scores', Colors.orange); return;
                    }
                    setS(() => saving = true);
                    try {
                      final winnerId   = sA > sB ? m.teamAId! : sB > sA ? m.teamBId! : m.teamAId!;
                      final winnerName = sA > sB ? m.teamAName! : sB > sA ? m.teamBName! : 'Draw';
                      await TournamentService().updateMatchResult(
                        tournamentId: widget.tournamentId,
                        matchId:      m.id,
                        scoreA:       sA,
                        scoreB:       sB,
                        winnerId:     winnerId,
                        winnerName:   winnerName,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Result saved!');
                    } catch (e) {
                      setS(() => saving = false);
                      _snack(e.toString(), Colors.red);
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Result',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Generate schedule ─────────────────────────────────────────────────────

  Future<void> _generateSchedule() async {
    setState(() => _generatingSchedule = true);
    try {
      await TournamentService().generateSchedule(widget.tournamentId);
      if (!mounted) return;
      _snack('Schedule generated!');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _generatingSchedule = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final t = _t;
        if (t == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final canManage = _canManage;
        final tid = widget.tournamentId;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: const Color(0xFF121212),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.dashboard_outlined,
                          color: Colors.white70),
                      tooltip: 'Management',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => HostDashboardScreen(tournamentId: tid))),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _TournamentBanner(tournament: t),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Matches'),
                    Tab(text: 'Table'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Squads'),
                    Tab(text: 'Venues'),
                    Tab(text: 'Forecast'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _MatchesTab(
                  tournamentId: tid,
                  tournament:   t,
                  canManage:    canManage,
                  onResult:     _showResultSheet,
                  onGenerate:   canManage ? _generateSchedule : null,
                  generating:   _generatingSchedule,
                ),
                _TableTab(tournamentId: tid, tournament: t),
                _StatsTab(tournamentId: tid, tournament: t),
                _SquadsTab(tournamentId: tid),
                _VenuesTab(tournamentId: tid, canManage: canManage),
                _ForecastTab(tournamentId: tid, tournament: t),
              ],
            ),
          ),
          // Management FAB for host/admin
          floatingActionButton: canManage ? FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => HostDashboardScreen(tournamentId: tid))),
            backgroundColor: Colors.deepOrange,
            icon: const Icon(Icons.manage_accounts_rounded, color: Colors.white),
            label: const Text('Manage',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ) : null,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Banner header
// ══════════════════════════════════════════════════════════════════════════════

class _TournamentBanner extends StatefulWidget {
  final Tournament tournament;
  const _TournamentBanner({required this.tournament});

  @override
  State<_TournamentBanner> createState() => _TournamentBannerState();
}

class _TournamentBannerState extends State<_TournamentBanner> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await TournamentService()
          .uploadBanner(widget.tournament.id, File(picked.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournament = widget.tournament;
    final isHost = tournament.createdBy == (UserService().userId ?? '');

    return Stack(fit: StackFit.expand, children: [
      // Background
      if (tournament.bannerUrl != null)
        Image.network(tournament.bannerUrl!, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _defaultBg())
      else
        _defaultBg(),
      // Gradient overlay
      DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withAlpha(220)],
        ),
      )),
      // Host edit button (top-right)
      if (isHost)
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ),
      // Content
      Positioned(bottom: 52, left: 16, right: 16, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _FormatChip(tournament.format),
            const SizedBox(width: 8),
            _StatusPill(tournament.status),
          ]),
          const SizedBox(height: 6),
          Text(tournament.name,
              style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w800),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${tournament.sport}  •  ${tournament.location}',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      )),
    ]);
  }

  Widget _defaultBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
  );
}

class _FormatChip extends StatelessWidget {
  final TournamentFormat format;
  const _FormatChip(this.format);

  @override
  Widget build(BuildContext context) {
    final labels = {
      TournamentFormat.knockout:       'Knockout',
      TournamentFormat.roundRobin:     'Round Robin',
      TournamentFormat.leagueKnockout: 'League+KO',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(labels[format] ?? format.name,
          style: const TextStyle(color: Colors.white70,
              fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TournamentStatus status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final configs = {
      TournamentStatus.open:      (Colors.green,      'OPEN'),
      TournamentStatus.ongoing:   (Colors.orange,     'ONGOING'),
      TournamentStatus.completed: (Colors.blue,       'COMPLETED'),
      TournamentStatus.cancelled: (Colors.red,        'CANCELLED'),
    };
    final (color, label) = configs[status] ?? (Colors.grey, status.name.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == TournamentStatus.ongoing) ...[
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: Colors.orange,
                  shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        Text(label,
            style: TextStyle(color: color,
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 1: Matches (inner 3 sub-tabs)
// ══════════════════════════════════════════════════════════════════════════════

class _MatchesTab extends StatelessWidget {
  final String          tournamentId;
  final Tournament      tournament;
  final bool            canManage;
  final void Function(TournamentMatch) onResult;
  final VoidCallback?   onGenerate;
  final bool            generating;

  const _MatchesTab({
    required this.tournamentId,
    required this.tournament,
    required this.canManage,
    required this.onResult,
    required this.onGenerate,
    required this.generating,
  });

  @override
  Widget build(BuildContext context) {
    final svc     = TournamentService();
    final matches = svc.matchesFor(tournamentId);
    final myTeam  = svc.myTeamIn(tournamentId);
    final uid     = UserService().userId ?? '';

    // If no schedule yet
    if (!tournament.bracketGenerated) {
      return _NoScheduleState(
        canManage: canManage,
        format:    tournament.format,
        teamCount: svc.teamsFor(tournamentId).length,
        sport:     tournament.sport,
        onGenerate: onGenerate,
        generating: generating,
      );
    }

    final upcoming = matches.where((m) => !m.isPlayed).toList();
    final recent   = matches.where((m) => m.isPlayed).toList();

    return DefaultTabController(
      length: 3,
      child: Column(children: [
        // Enroll button banner if open + not enrolled
        if (tournament.status == TournamentStatus.open &&
            !svc.myEnrolledIds.contains(tournamentId) && uid.isNotEmpty)
          _EnrollBanner(tournamentId: tournamentId, tournament: tournament),

        Container(
          color: const Color(0xFF121212),
          child: const TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Recent'),
              Tab(text: 'All'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _MatchList(matches: upcoming, myTeamId: myTeam?.id,
              canManage: canManage, onResult: onResult),
          _MatchList(matches: [...recent].reversed.toList(), myTeamId: myTeam?.id,
              canManage: canManage, onResult: onResult),
          _MatchList(matches: matches, myTeamId: myTeam?.id,
              canManage: canManage, onResult: onResult),
        ])),
      ]),
    );
  }
}

class _EnrollBanner extends StatelessWidget {
  final String     tournamentId;
  final Tournament tournament;
  const _EnrollBanner({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(30), AppColors.primary.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Row(children: [
        const Icon(Icons.sports_outlined, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Register your team to compete!',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EnrollTeamSheet(
              tournamentId:  tournament.id,
              entryFee:      tournament.entryFee,
              serviceFee:    tournament.serviceFee,
              playersPerTeam: tournament.playersPerTeam,
            ),
          ),
          child: const Text('Enroll',
              style: TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _NoScheduleState extends StatelessWidget {
  final bool           canManage;
  final TournamentFormat format;
  final int            teamCount;
  final String         sport;
  final VoidCallback?  onGenerate;
  final bool           generating;

  const _NoScheduleState({
    required this.canManage,
    required this.format,
    required this.teamCount,
    required this.sport,
    required this.onGenerate,
    required this.generating,
  });

  @override
  Widget build(BuildContext context) {
    final rec = teamCount >= 2
        ? TournamentService.scheduleRecommendation(teamCount, sport, format)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 40),
        const Icon(Icons.calendar_month_outlined, color: Colors.white24, size: 64),
        const SizedBox(height: 16),
        const Text('Schedule Not Generated',
            style: TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(teamCount < 2
            ? 'Need at least 2 registered teams to generate schedule.'
            : 'The tournament schedule hasn\'t been generated yet.',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center),
        if (rec != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Schedule Preview',
                  style: TextStyle(color: Colors.white60,
                      fontSize: 11, fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Text(rec,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ]),
          ),
        ],
        if (canManage && onGenerate != null && teamCount >= 2) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_fix_high_rounded,
                      color: Colors.white, size: 20),
              label: Text(generating ? 'Generating…' : 'Generate Schedule',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<TournamentMatch>          matches;
  final String?                        myTeamId;
  final bool                           canManage;
  final void Function(TournamentMatch) onResult;

  const _MatchList({
    required this.matches,
    required this.myTeamId,
    required this.canManage,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const _EmptyState(icon: Icons.sports_score_outlined,
          label: 'No matches here yet');
    }

    // Group by note/label
    final Map<String, List<TournamentMatch>> grouped = {};
    for (final m in matches) {
      final key = m.note ?? 'Matches';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: grouped.entries.expand((entry) => [
        _GroupHeader(label: entry.key, matches: entry.value),
        ...entry.value.map((m) => _CricbuzzMatchCard(
          match:     m,
          myTeamId:  myTeamId,
          canManage: canManage,
          onResult:  () => onResult(m),
          onTap:     () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MatchDetailScreen(
                  tournamentId: m.tournamentId, matchId: m.id))),
        )),
      ]).toList(),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String               label;
  final List<TournamentMatch> matches;
  const _GroupHeader({required this.label, required this.matches});

  @override
  Widget build(BuildContext context) {
    final played = matches.where((m) => m.isPlayed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Text(label,
              style: const TextStyle(color: AppColors.primary,
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(width: 8),
        Text('$played/${matches.length} played',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Cricbuzz-style Match Card
// ══════════════════════════════════════════════════════════════════════════════

class _CricbuzzMatchCard extends StatelessWidget {
  final TournamentMatch            match;
  final String?                    myTeamId;
  final bool                       canManage;
  final VoidCallback               onResult;
  final VoidCallback               onTap;

  const _CricbuzzMatchCard({
    required this.match,
    required this.myTeamId,
    required this.canManage,
    required this.onResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m          = match;
    final isMyMatchA = myTeamId != null && myTeamId == m.teamAId;
    final isMyMatchB = myTeamId != null && myTeamId == m.teamBId;
    final isMyMatch  = isMyMatchA || isMyMatchB;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyMatch
                ? AppColors.primary.withAlpha(120)
                : Colors.white12,
          ),
        ),
        child: Column(children: [
          // ── Top: VS banner ───────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(11)),
            child: _MatchVsBanner(
              teamA: m.teamAName ?? 'TBD',
              teamB: m.teamBName ?? 'TBD',
              label: m.note?.isNotEmpty == true ? m.note! : 'Round ${m.round}',
              isLive: m.isLive,
              isPlayed: m.isPlayed,
            ),
          ),

          // ── Status header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              if (m.isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.withAlpha(100)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, color: Colors.red, size: 6),
                    SizedBox(width: 4),
                    Text('LIVE', style: TextStyle(color: Colors.red,
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                  ]),
                )
              else
                Text(
                  m.isPlayed ? 'RESULT' : m.isTBD ? 'TBD' : 'UPCOMING',
                  style: TextStyle(
                    color: m.isPlayed ? Colors.blue : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              const Spacer(),
              if (isMyMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('YOUR MATCH',
                      style: TextStyle(color: AppColors.primary,
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          // ── Team A ──
          _TeamRow(
            name:   m.teamAName ?? 'TBD',
            score:  m.scoreA,
            isWinner: m.result == TournamentMatchResult.teamAWin,
            isPlayed: m.isPlayed,
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.white12,
              indent: 16, endIndent: 16),
          // ── Team B ──
          _TeamRow(
            name:   m.teamBName ?? 'TBD',
            score:  m.scoreB,
            isWinner: m.result == TournamentMatchResult.teamBWin,
            isPlayed: m.isPlayed,
          ),
          // ── Footer ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(child: Text(
                _footerText(m),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              )),
              if (canManage && !m.isBye)
                GestureDetector(
                  onTap: onResult,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: m.isPlayed
                          ? Colors.white12
                          : AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: m.isPlayed
                            ? Colors.white24
                            : AppColors.primary.withAlpha(80),
                      ),
                    ),
                    child: Text(
                      m.isPlayed ? 'Edit Result' : 'Enter Result',
                      style: TextStyle(
                        color: m.isPlayed ? Colors.white54 : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _footerText(TournamentMatch m) {
    if (m.isBye)     return '${m.teamAName ?? "Team"} advances (bye)';
    if (m.isPlayed) {
      if (m.result == TournamentMatchResult.draw) return 'Match drawn';
      return '${m.winnerName ?? "?"} won';
    }
    if (m.venueName != null) return m.venueName!;
    return 'Yet to be played';
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final int?   score;
  final bool   isWinner;
  final bool   isPlayed;
  const _TeamRow({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.isPlayed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        // Avatar
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: isWinner
                ? AppColors.primary.withAlpha(40)
                : Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: isWinner ? AppColors.primary : Colors.white60,
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: TextStyle(
                color: isWinner ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis),
        ),
        if (isPlayed && score != null)
          Text(score.toString(),
              style: TextStyle(
                color: isWinner ? Colors.white : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              )),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 16),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 2: Table — two sub-tabs: Points Table + Bracket
// ══════════════════════════════════════════════════════════════════════════════

class _TableTab extends StatelessWidget {
  final String     tournamentId;
  final Tournament tournament;
  const _TableTab({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: const Color(0xFF121212),
          child: const TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Points Table'),
              Tab(text: 'Bracket'),
            ],
          ),
        ),
        Expanded(child: TabBarView(children: [
          _PointsTableView(
              tournamentId: tournamentId, tournament: tournament),
          ListenableBuilder(
            listenable: TournamentService(),
            builder: (context, _) {
              final rounds = TournamentService().buildRounds(tournamentId);
              final isHost = TournamentService().isHost(tournamentId);
              if (rounds.isEmpty) {
                return const _EmptyState(
                    icon: Icons.account_tree_outlined,
                    label: 'No bracket generated yet');
              }
              return BracketWidget(
                tournamentId: tournamentId,
                rounds:       rounds,
                isHost:       isHost,
              );
            },
          ),
        ])),
      ]),
    );
  }
}

// ── Points table stat accumulator ────────────────────────────────────────────

class _PTStat {
  final String name;
  int played = 0, won = 0, lost = 0, drawn = 0;
  int scoreFor = 0, scoreAgainst = 0;
  _PTStat(this.name);
  int get pts => won * 2 + drawn;
  double get nrr =>
      played == 0 ? 0 : (scoreFor - scoreAgainst) / played.toDouble();
}

// ── Points Table View ─────────────────────────────────────────────────────────

class _PointsTableView extends StatelessWidget {
  final String     tournamentId;
  final Tournament tournament;
  const _PointsTableView(
      {required this.tournamentId, required this.tournament});

  Map<String, _PTStat> _buildStats(
      List<TournamentMatch> matches, List<TournamentTeam> teams) {
    final stats = {for (final t in teams) t.id: _PTStat(t.teamName)};
    for (final m in matches) {
      if (!m.isPlayed || m.isBye) continue;
      _accum(stats, m.teamAId, m.scoreA, m.scoreB, m.result, isA: true);
      _accum(stats, m.teamBId, m.scoreB, m.scoreA, m.result, isA: false);
    }
    return stats;
  }

  void _accum(Map<String, _PTStat> stats, String? id, int? sf, int? sa,
      TournamentMatchResult result, {required bool isA}) {
    if (id == null || !stats.containsKey(id)) return;
    final s = stats[id]!;
    s.played++;
    s.scoreFor += sf ?? 0;
    s.scoreAgainst += sa ?? 0;
    if (result == TournamentMatchResult.teamAWin) {
      if (isA) { s.won++; } else { s.lost++; }
    } else if (result == TournamentMatchResult.teamBWin) {
      if (!isA) { s.won++; } else { s.lost++; }
    } else if (result == TournamentMatchResult.draw) {
      s.drawn++;
    }
  }

  List<_PTStat> _sorted(Map<String, _PTStat> all, Set<String> ids) =>
      all.entries
          .where((e) => ids.contains(e.key))
          .map((e) => e.value)
          .toList()
        ..sort((a, b) {
          final c = b.pts.compareTo(a.pts);
          return c != 0 ? c : b.nrr.compareTo(a.nrr);
        });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc     = TournamentService();
        final teams   = svc.teamsFor(tournamentId);
        final matches = svc.matchesFor(tournamentId);
        final groups  = svc.groupsFor(tournamentId);

        if (teams.isEmpty) {
          return const _EmptyState(
              icon: Icons.table_chart_outlined,
              label: 'No teams registered yet');
        }

        final allStats = _buildStats(matches, teams);

        if (groups.isNotEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: groups.map((g) {
              final sorted = _sorted(allStats, g.teamIds.toSet());
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GroupTableHeader(groupName: g.name),
                  _CricbuzzTable(
                      stats: sorted, sport: tournament.sport),
                  const SizedBox(height: 24),
                ],
              );
            }).toList(),
          );
        }

        final allIds = {for (final t in teams) t.id};
        final sorted = _sorted(allStats, allIds);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _CricbuzzTable(stats: sorted, sport: tournament.sport),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

// ── Group header for table ────────────────────────────────────────────────────

class _GroupTableHeader extends StatelessWidget {
  final String groupName;
  const _GroupTableHeader({required this.groupName});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withAlpha(80)),
        ),
        child: Text(groupName,
            style: const TextStyle(color: AppColors.primary,
                fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ── Cricbuzz-style points table ───────────────────────────────────────────────

class _CricbuzzTable extends StatelessWidget {
  final List<_PTStat> stats;
  final String        sport;
  const _CricbuzzTable({required this.stats, required this.sport});

  bool   get _isCricket => sport.toLowerCase() == 'cricket';
  String get _diffLabel => _isCricket ? 'NRR' : 'GD';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: [
        // ── Header row ────────────────────────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF222222),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            const SizedBox(width: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('TEAM',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            _th('M'),
            _th('W'),
            _th('L'),
            _th('D'),
            _th('PTS', color: AppColors.primary),
            _th(_diffLabel),
          ]),
        ),
        const Divider(height: 1, color: Colors.white12),
        // ── Data rows ─────────────────────────────────────────────────────
        if (stats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No results yet',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          )
        else
          ...stats.asMap().entries.map((e) {
            final rank = e.key + 1;
            final s    = e.value;
            final top2 = rank <= 2 && s.played > 0;
            return Column(children: [
              if (e.key > 0)
                const Divider(height: 1, color: Colors.white10),
              Container(
                color: top2
                    ? AppColors.primary.withAlpha(10)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                child: Row(children: [
                  // Rank
                  SizedBox(
                    width: 20,
                    child: Text('$rank',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: top2
                                ? AppColors.primary
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  // Avatar
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: top2
                          ? AppColors.primary.withAlpha(40)
                          : Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        s.name.isNotEmpty
                            ? s.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: top2
                                ? AppColors.primary
                                : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Team name
                  Expanded(
                    child: Text(s.name,
                        style: TextStyle(
                            color:
                                top2 ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: top2
                                ? FontWeight.w700
                                : FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  _td('${s.played}'),
                  _td('${s.won}',
                      color: s.won > 0 ? Colors.green[300] : null),
                  _td('${s.lost}',
                      color: s.lost > 0 ? Colors.red[300] : null),
                  _td('${s.drawn}'),
                  _td('${s.pts}',
                      bold: true, color: AppColors.primary),
                  _td(
                    s.played == 0
                        ? '–'
                        : '${s.nrr >= 0 ? "+" : ""}${s.nrr.toStringAsFixed(2)}',
                    color: s.nrr > 0
                        ? Colors.green
                        : s.nrr < 0
                            ? Colors.red[300]
                            : Colors.white38,
                  ),
                ]),
              ),
            ]);
          }),
      ]),
    );
  }

  Widget _th(String text, {Color color = Colors.white38}) => SizedBox(
        width: 38,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _td(String text, {bool bold = false, Color? color}) => SizedBox(
        width: 38,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color ?? Colors.white54,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 3: Stats
// ══════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatelessWidget {
  final String     tournamentId;
  final Tournament tournament;
  const _StatsTab({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final matches = TournamentService().matchesFor(tournamentId);
    final played  = matches.where((m) => m.isPlayed && !m.isBye).toList();

    if (played.isEmpty) {
      return const _EmptyState(
          icon: Icons.bar_chart_outlined, label: 'No results yet');
    }

    // Aggregate team stats from played matches
    final Map<String, _TeamStat> stats = {};
    for (final m in played) {
      if (m.teamAId != null && m.teamAName != null) {
        stats.putIfAbsent(m.teamAId!, () => _TeamStat(m.teamAName!));
        stats[m.teamAId!]!.goalsFor     += m.scoreA ?? 0;
        stats[m.teamAId!]!.goalsAgainst += m.scoreB ?? 0;
        if (m.result == TournamentMatchResult.teamAWin) stats[m.teamAId!]!.wins++;
      }
      if (m.teamBId != null && m.teamBName != null) {
        stats.putIfAbsent(m.teamBId!, () => _TeamStat(m.teamBName!));
        stats[m.teamBId!]!.goalsFor     += m.scoreB ?? 0;
        stats[m.teamBId!]!.goalsAgainst += m.scoreA ?? 0;
        if (m.result == TournamentMatchResult.teamBWin) stats[m.teamBId!]!.wins++;
      }
    }

    final sorted = stats.values.toList()
      ..sort((a, b) {
        final wCmp = b.wins.compareTo(a.wins);
        if (wCmp != 0) return wCmp;
        return b.goalsFor.compareTo(a.goalsFor);
      });

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _StatsHeader(sport: tournament.sport),
        const SizedBox(height: 8),
        ...sorted.asMap().entries.map((e) => _StatRow(
          rank: e.key + 1,
          stat: e.value,
          sport: tournament.sport,
        )),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _TeamStat {
  final String name;
  int wins        = 0;
  int goalsFor    = 0;
  int goalsAgainst = 0;
  _TeamStat(this.name);
  int get goalDiff => goalsFor - goalsAgainst;
}

class _StatsHeader extends StatelessWidget {
  final String sport;
  const _StatsHeader({required this.sport});

  String get _scoreLabel {
    switch (sport.toLowerCase()) {
      case 'cricket':    return 'Runs';
      case 'basketball': return 'Points';
      case 'tennis':     return 'Sets';
      case 'volleyball': return 'Sets';
      default:           return 'Goals';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const SizedBox(width: 24),
        const SizedBox(width: 12),
        const Expanded(child: Text('Team',
            style: TextStyle(color: Colors.white54, fontSize: 12,
                fontWeight: FontWeight.w600))),
        SizedBox(width: 40, child: Text('W',
            style: const TextStyle(color: Colors.white54, fontSize: 12,
                fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        SizedBox(width: 50, child: Text(_scoreLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 12,
                fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
        SizedBox(width: 40, child: const Text('+/-',
            style: TextStyle(color: Colors.white54, fontSize: 12,
                fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
      ]),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int       rank;
  final _TeamStat stat;
  final String    sport;
  const _StatRow({required this.rank, required this.stat, required this.sport});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rank == 1 ? AppColors.primary.withAlpha(15) : const Color(0xFF161616),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: rank == 1 ? AppColors.primary.withAlpha(60) : Colors.transparent),
      ),
      child: Row(children: [
        SizedBox(width: 24,
          child: Text('$rank', style: TextStyle(
            color: rank <= 3 ? AppColors.primary : Colors.white38,
            fontSize: 13, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(stat.name,
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis)),
        SizedBox(width: 40, child: Text('${stat.wins}',
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
        SizedBox(width: 50, child: Text('${stat.goalsFor}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center)),
        SizedBox(width: 40, child: Text(
          '${stat.goalDiff >= 0 ? "+" : ""}${stat.goalDiff}',
          style: TextStyle(
            color: stat.goalDiff > 0 ? Colors.green
                : stat.goalDiff < 0 ? Colors.red
                : Colors.white38,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 4: Squads
// ══════════════════════════════════════════════════════════════════════════════

class _SquadsTab extends StatefulWidget {
  final String tournamentId;
  const _SquadsTab({required this.tournamentId});

  @override
  State<_SquadsTab> createState() => _SquadsTabState();
}

class _SquadsTabState extends State<_SquadsTab> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final svc   = TournamentService();
    final teams = svc.teamsFor(widget.tournamentId);

    if (teams.isEmpty) {
      return const _EmptyState(
          icon: Icons.group_outlined, label: 'No teams registered yet');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: teams.map((team) {
        final isOpen = _expanded.contains(team.id);
        final squad  = svc.squadFor(widget.tournamentId, team.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(children: [
            // Team header (tap to expand)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                setState(() {
                  if (isOpen) { _expanded.remove(team.id); }
                  else { _expanded.add(team.id); }
                });
                if (!isOpen) {
                  await svc.loadSquad(widget.tournamentId, team.id);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(team.teamName[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team.teamName,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Captain: ${team.captainName}  •  ${team.players.length} players',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  )),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38),
                ]),
              ),
            ),
            // Squad list
            if (isOpen) ...[
              const Divider(height: 1, color: Colors.white12),
              if (squad.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No squad members added yet',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center),
                )
              else
                ...squad.map((p) => _SquadPlayerTile(player: p)),
              const SizedBox(height: 8),
            ],
          ]),
        );
      }).toList(),
    );
  }
}

class _SquadPlayerTile extends StatelessWidget {
  final TournamentSquadPlayer player;
  const _SquadPlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(player.jerseyNumber > 0
                ? '${player.jerseyNumber}'
                : player.playerName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white70,
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(player.playerName,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (player.isCaptain) ...[
                const SizedBox(width: 6),
                _RoleBadge('C', AppColors.primary),
              ],
              if (player.isViceCaptain) ...[
                const SizedBox(width: 4),
                _RoleBadge('VC', Colors.orange),
              ],
            ]),
            if (player.role.isNotEmpty)
              Text(player.role,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        )),
        if (player.playerId.isNotEmpty)
          Text('#${player.playerId}',
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
      ]),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _RoleBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 5: Venues
// ══════════════════════════════════════════════════════════════════════════════

class _VenuesTab extends StatelessWidget {
  final String tournamentId;
  final bool   canManage;
  const _VenuesTab({required this.tournamentId, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final venues = TournamentService().venuesFor(tournamentId);

    if (venues.isEmpty) {
      return _EmptyState(
        icon: Icons.location_on_outlined,
        label: 'No venues added yet',
        action: canManage ? ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: () => _showAddVenueSheet(context),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: const Text('Add Venue',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ) : null,
      );
    }

    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: venues.map((v) => _VenueCard(
          venue:     v,
          canManage: canManage,
          onDelete:  () async {
            await TournamentService().removeVenue(tournamentId, v.id);
          },
        )).toList(),
      ),
      if (canManage)
        Positioned(
          bottom: 80, right: 16,
          child: FloatingActionButton.small(
            heroTag: 'add_venue',
            backgroundColor: AppColors.primary,
            onPressed: () => _showAddVenueSheet(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
    ]);
  }

  void _showAddVenueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddVenueSheet(tournamentId: tournamentId),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final TournamentVenue venue;
  final bool            canManage;
  final VoidCallback    onDelete;
  const _VenueCard({
    required this.venue,
    required this.canManage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            color: Colors.blue.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.stadium_outlined, color: Colors.blue, size: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(venue.name, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
            if (venue.address.isNotEmpty || venue.city.isNotEmpty)
              Text('${venue.address}${venue.city.isNotEmpty ? ", ${venue.city}" : ""}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Row(children: [
              if (venue.pitchType.isNotEmpty)
                _Tag(venue.pitchType, Colors.purple),
              if (venue.hasFloodlights) ...[
                const SizedBox(width: 6),
                _Tag('Floodlights', Colors.amber),
              ],
              if (venue.capacity > 0) ...[
                const SizedBox(width: 6),
                _Tag('${venue.capacity} cap', Colors.teal),
              ],
            ]),
          ],
        )),
        if (canManage)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
          ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _AddVenueSheet extends StatefulWidget {
  final String tournamentId;
  const _AddVenueSheet({required this.tournamentId});

  @override
  State<_AddVenueSheet> createState() => _AddVenueSheetState();
}

class _AddVenueSheetState extends State<_AddVenueSheet> {
  final _nameCtrl     = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _capCtrl      = TextEditingController();
  String _pitchType   = '';
  bool   _floodlights = false;
  bool   _saving      = false;

  static const _pitchTypes = ['Grass', 'Turf', 'Indoor', 'Hard Court', 'Clay', 'Parquet'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Add Venue', style: TextStyle(color: Colors.white,
            fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _Field(controller: _nameCtrl,    hint: 'Venue name *'),
        const SizedBox(height: 10),
        _Field(controller: _addressCtrl, hint: 'Address'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Field(controller: _cityCtrl, hint: 'City')),
          const SizedBox(width: 10),
          Expanded(child: _Field(controller: _capCtrl,  hint: 'Capacity',
              keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButton<String>(
            value: _pitchType.isEmpty ? null : _pitchType,
            hint: const Text('Pitch type',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: _pitchTypes.map((p) => DropdownMenuItem(
              value: p, child: Text(p),
            )).toList(),
            onChanged: (v) => setState(() => _pitchType = v ?? ''),
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Has Floodlights',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          value: _floodlights,
          onChanged: (v) => setState(() => _floodlights = v),
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.primary,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add Venue',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await TournamentService().addVenue(
        tournamentId:   widget.tournamentId,
        name:           _nameCtrl.text.trim(),
        address:        _addressCtrl.text.trim(),
        city:           _cityCtrl.text.trim(),
        capacity:       int.tryParse(_capCtrl.text.trim()) ?? 0,
        pitchType:      _pitchType,
        hasFloodlights: _floodlights,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 6: Forecast
// ══════════════════════════════════════════════════════════════════════════════

class _ForecastTab extends StatelessWidget {
  final String     tournamentId;
  final Tournament tournament;
  const _ForecastTab({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final svc     = TournamentService();
    final matches = svc.matchesFor(tournamentId);
    final teams   = svc.teamsFor(tournamentId);

    final upcoming = matches.where((m) => !m.isPlayed && !m.isBye && !m.isTBD).toList();
    final played   = matches.where((m) => m.isPlayed && !m.isBye).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Next match preview
        if (upcoming.isNotEmpty) ...[
          const _SectionTitle('Next Match'),
          const SizedBox(height: 8),
          _NextMatchCard(match: upcoming.first, teams: teams),
          const SizedBox(height: 24),
        ],

        // Tournament progress
        if (played.isNotEmpty) ...[
          const _SectionTitle('Tournament Progress'),
          const SizedBox(height: 8),
          _ProgressCard(
            played:  played.length,
            total:   matches.where((m) => !m.isBye).length,
            status:  tournament.status,
          ),
          const SizedBox(height: 24),
        ],

        // Team form (win rate)
        if (played.isNotEmpty) ...[
          const _SectionTitle('Team Form'),
          const SizedBox(height: 8),
          _TeamFormCard(played: played, teams: teams),
          const SizedBox(height: 80),
        ],

        if (upcoming.isEmpty && played.isEmpty)
          const _EmptyState(icon: Icons.insights_outlined,
              label: 'No data to forecast yet'),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Colors.white54,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1));
}

class _NextMatchCard extends StatelessWidget {
  final TournamentMatch       match;
  final List<TournamentTeam>  teams;
  const _NextMatchCard({required this.match, required this.teams});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E1E3A), const Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(children: [
        if (match.note != null)
          Text(match.note!.toUpperCase(),
              style: const TextStyle(color: AppColors.primary,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TeamPreview(
              name: match.teamAName ?? 'TBD', teams: teams, teamId: match.teamAId)),
          const Column(mainAxisSize: MainAxisSize.min, children: [
            Text('VS', style: TextStyle(color: Colors.white38,
                fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          Expanded(child: _TeamPreview(
              name: match.teamBName ?? 'TBD', teams: teams,
              teamId: match.teamBId, alignRight: true)),
        ]),
        if (match.venueName != null) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on_outlined, color: Colors.white38, size: 14),
            const SizedBox(width: 4),
            Text(match.venueName!,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ],
      ]),
    );
  }
}

class _TeamPreview extends StatelessWidget {
  final String            name;
  final List<TournamentTeam> teams;
  final String?           teamId;
  final bool              alignRight;
  const _TeamPreview({
    required this.name,
    required this.teams,
    required this.teamId,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Center(
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white,
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700),
            textAlign: alignRight ? TextAlign.end : TextAlign.start,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int              played;
  final int              total;
  final TournamentStatus status;
  const _ProgressCard({
    required this.played,
    required this.total,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? played / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$played / $total matches played',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           pct,
            backgroundColor: Colors.white12,
            color:           AppColors.primary,
            minHeight:       6,
          ),
        ),
      ]),
    );
  }
}

class _TeamFormCard extends StatelessWidget {
  final List<TournamentMatch>  played;
  final List<TournamentTeam>   teams;
  const _TeamFormCard({required this.played, required this.teams});

  @override
  Widget build(BuildContext context) {
    // Calculate win rate per team
    final Map<String, ({String name, int w, int p})> form = {};
    for (final m in played) {
      if (m.teamAId != null) {
        final prev = form[m.teamAId!];
        form[m.teamAId!] = (
          name: m.teamAName ?? '',
          w: (prev?.w ?? 0) + (m.result == TournamentMatchResult.teamAWin ? 1 : 0),
          p: (prev?.p ?? 0) + 1,
        );
      }
      if (m.teamBId != null) {
        final prev = form[m.teamBId!];
        form[m.teamBId!] = (
          name: m.teamBName ?? '',
          w: (prev?.w ?? 0) + (m.result == TournamentMatchResult.teamBWin ? 1 : 0),
          p: (prev?.p ?? 0) + 1,
        );
      }
    }
    final sorted = form.values.toList()
      ..sort((a, b) {
        final ra = a.p > 0 ? a.w / a.p : 0.0;
        final rb = b.p > 0 ? b.w / b.p : 0.0;
        return rb.compareTo(ra);
      });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: sorted.map((f) {
          final rate = f.p > 0 ? f.w / f.p : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(f.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
              Text('${f.w}W/${f.p}G',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 10),
              SizedBox(width: 60, child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: rate,
                  backgroundColor: Colors.white12,
                  color: rate >= 0.6 ? Colors.green : rate >= 0.4 ? Colors.orange : Colors.red,
                  minHeight: 5,
                ),
              )),
              const SizedBox(width: 6),
              Text('${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70,
                      fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.end),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final Widget?    action;
  const _EmptyState({required this.icon, required this.label, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withAlpha(35), size: 56),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 20),
          action!,
        ],
      ]),
    ),
  );
}

class _ScoreField extends StatelessWidget {
  final TextEditingController controller;
  const _ScoreField({required this.controller});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    style: const TextStyle(color: Colors.white,
        fontSize: 32, fontWeight: FontWeight.w800),
    decoration: InputDecoration(
      filled: true, fillColor: const Color(0xFF222222),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                hint;
  final TextInputType         keyboardType;
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:   controller,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}

// ── Match VS banner (top half of tournament match cards) ──────────────────────

class _MatchVsBanner extends StatelessWidget {
  final String teamA;
  final String teamB;
  final String label;
  final bool isLive;
  final bool isPlayed;

  const _MatchVsBanner({
    required this.teamA,
    required this.teamB,
    required this.label,
    required this.isLive,
    required this.isPlayed,
  });

  @override
  Widget build(BuildContext context) {
    final bg1 = isLive
        ? const Color(0xFF7B0000)
        : isPlayed
            ? const Color(0xFF0D1B3E)
            : const Color(0xFF1A1035);
    final bg2 = isLive
        ? const Color(0xFFB71C1C)
        : isPlayed
            ? const Color(0xFF1565C0)
            : const Color(0xFF3A1C6E);

    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg1, bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Faded background text
        Positioned(
          right: 8,
          bottom: 4,
          child: Text('VS',
              style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.05))),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Label row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (isLive)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.6)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, color: Colors.red, size: 6),
                      SizedBox(width: 4),
                      Text('LIVE',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ]),
                  ),
                Text(
                  label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8),
                ),
              ]),
              const SizedBox(height: 8),

              // Teams VS row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      teamA,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('VS',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ),
                  Expanded(
                    child: Text(
                      teamB,
                      textAlign: TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
