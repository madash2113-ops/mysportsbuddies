import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../sports/league_entry_screen.dart';
import 'enroll_team_sheet.dart';
import 'tournament_detail_screen.dart';

// ── Hub screen shown on the Tournaments bottom-nav tab ─────────────────────

class TournamentsListScreen extends StatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  State<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _TournamentsListScreenState extends State<TournamentsListScreen> {
  @override
  void initState() {
    super.initState();
    final uid = UserService().userId ?? '';
    TournamentService().loadTournaments();
    TournamentService().loadMyEnrollments(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TournamentService(),
          builder: (context, _) {
            final svc     = TournamentService();
            final userId  = UserService().userId ?? '';
            final openCnt = svc.tournaments
                .where((t) => t.status == TournamentStatus.open)
                .length;
            final enrolledCnt = svc.myEnrolledIds.length;

            return CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tournaments',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          openCnt == 0
                              ? 'No open tournaments right now'
                              : '$openCnt open · $enrolledCnt registered',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 3 hub cards ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      children: [
                        // REGISTER — browse all open tournaments + enroll team
                        _HubCard(
                          icon: Icons.app_registration_outlined,
                          title: 'Register',
                          subtitle: 'Browse open tournaments & enroll your team',
                          accent: AppColors.primary,
                          badge: openCnt > 0 ? '$openCnt open' : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _OpenTournamentsScreen(
                                  userId: userId),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // REGISTERED — tournaments where MY team is enrolled
                        _HubCard(
                          icon: Icons.how_to_reg_outlined,
                          title: 'Registered',
                          subtitle: 'Tournaments your team has joined',
                          accent: const Color(0xFF1565C0),
                          badge: enrolledCnt > 0 ? '$enrolledCnt teams' : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _MyRegisteredScreen(userId: userId),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SCHEDULE — match fixtures for enrolled tournaments
                        _HubCard(
                          icon: Icons.calendar_month_outlined,
                          title: 'Schedule',
                          subtitle: 'Match fixtures for your tournaments',
                          accent: const Color(0xFF2E7D32),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _MyScheduleScreen(userId: userId),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // HOST TOURNAMENT — subtle outlined button
                        GestureDetector(
                          onTap: () async {
                            final created = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LeagueEntryScreen()),
                            );
                            if (created == true && mounted) {
                              TournamentService().loadTournaments();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    color: Colors.white38, size: 18),
                                SizedBox(width: 8),
                                Text('Host a Tournament',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Hub card ────────────────────────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    accent;
  final String?  badge;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right,
                color: accent.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REGISTER → browse all open tournaments, enroll team
// ══════════════════════════════════════════════════════════════════════════════

class _OpenTournamentsScreen extends StatefulWidget {
  final String userId;
  const _OpenTournamentsScreen({required this.userId});

  @override
  State<_OpenTournamentsScreen> createState() =>
      _OpenTournamentsScreenState();
}

class _OpenTournamentsScreenState
    extends State<_OpenTournamentsScreen> {
  String _sport  = 'All';
  String _status = 'All';

  static const _sports  = [
    'All', 'Cricket', 'Football', 'Basketball',
    'Badminton', 'Tennis', 'Volleyball', 'Other',
  ];
  static const _statuses = ['All', 'Open', 'Ongoing', 'Completed'];

  List<Tournament> _filtered(List<Tournament> all) => all.where((t) {
        final sp = _sport  == 'All' || t.sport == _sport;
        final st = _status == 'All' ||
            t.status.name.toLowerCase() == _status.toLowerCase();
        return sp && st;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: TournamentService(),
        builder: (context, _) {
          final filtered = _filtered(TournamentService().tournaments);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                title: const Text('Browse & Register',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                iconTheme: const IconThemeData(color: Colors.white),
              ),

              // Sport filter chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    itemCount: _sports.length,
                    itemBuilder: (_, i) {
                      final s   = _sports[i];
                      final sel = s == _sport;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _sport = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(s,
                                style: TextStyle(
                                    color: sel
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.normal)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Status filter chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _statuses.length,
                    itemBuilder: (_, i) {
                      final s   = _statuses[i];
                      final sel = s == _status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _status = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: sel
                                      ? AppColors.primary
                                      : Colors.white12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(s,
                                style: TextStyle(
                                    color: sel
                                        ? AppColors.primary
                                        : Colors.white38,
                                    fontSize: 12)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              filtered.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                size: 64, color: Colors.white12),
                            SizedBox(height: 16),
                            Text('No tournaments found',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final t = filtered[i];
                          return _TournamentCard(
                            tournament: t,
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                builder: (_) => TournamentDetailScreen(
                                    tournamentId: t.id),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REGISTERED → tournaments where MY team enrolled + tournaments I host
// ══════════════════════════════════════════════════════════════════════════════

class _MyRegisteredScreen extends StatefulWidget {
  final String userId;
  const _MyRegisteredScreen({required this.userId});

  @override
  State<_MyRegisteredScreen> createState() => _MyRegisteredScreenState();
}

class _MyRegisteredScreenState extends State<_MyRegisteredScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      TournamentService().loadTournaments(),
      TournamentService().loadMyEnrollments(widget.userId),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Registered',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary))
          : ListenableBuilder(
              listenable: TournamentService(),
              builder: (context, _) {
                final svc = TournamentService();
                final all = svc.tournaments;
                final uid = widget.userId;

                // Tournaments where I enrolled a team
                final enrolled = all
                    .where((t) =>
                        svc.myEnrolledIds.contains(t.id))
                    .toList();

                // Tournaments I created (not already in enrolled)
                final hosted = all
                    .where((t) =>
                        t.createdBy == uid &&
                        !svc.myEnrolledIds.contains(t.id))
                    .toList();

                if (enrolled.isEmpty && hosted.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.how_to_reg_outlined,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text(
                            "You haven't registered for any tournaments",
                            style: TextStyle(
                                color: Colors.white38, fontSize: 15),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(
                            'Tap "Register" to browse open tournaments',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 13)),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              size: 16, color: AppColors.primary),
                          label: const Text('Browse Tournaments',
                              style: TextStyle(
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (enrolled.isNotEmpty) ...[
                        _SectionLabel(
                            '🏆 MY ENROLLED TEAMS (${enrolled.length})'),
                        ...enrolled.map((t) {
                          final myTeam = svc.myTeamIn(t.id);
                          return _TournamentCard(
                            tournament: t,
                            teamBadge: myTeam?.teamName,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TournamentDetailScreen(
                                    tournamentId: t.id),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                      if (hosted.isNotEmpty) ...[
                        _SectionLabel('🎯 HOSTED BY ME (${hosted.length})'),
                        ...hosted.map((t) => _TournamentCard(
                              tournament: t,
                              teamBadge: null,
                              isHost: true,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TournamentDetailScreen(
                                      tournamentId: t.id),
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCHEDULE → match fixtures for enrolled tournaments (tap → detail)
// ══════════════════════════════════════════════════════════════════════════════

class _MyScheduleScreen extends StatefulWidget {
  final String userId;
  const _MyScheduleScreen({required this.userId});

  @override
  State<_MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<_MyScheduleScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      TournamentService().loadTournaments(),
      TournamentService().loadMyEnrollments(widget.userId),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Schedule',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary))
          : ListenableBuilder(
              listenable: TournamentService(),
              builder: (context, _) {
                final svc      = TournamentService();
                final all      = svc.tournaments;
                final enrolled = all
                    .where((t) => svc.myEnrolledIds.contains(t.id))
                    .toList();

                if (enrolled.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text('No tournaments scheduled yet',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 15)),
                        const SizedBox(height: 8),
                        const Text(
                            'Register your team to view match fixtures',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 13)),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              size: 16, color: AppColors.primary),
                          label: const Text('Browse Tournaments',
                              style: TextStyle(
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: enrolled.length,
                    itemBuilder: (ctx, i) {
                      final t      = enrolled[i];
                      final myTeam = svc.myTeamIn(t.id);
                      return _ScheduleCard(
                        tournament: t,
                        teamName: myTeam?.teamName,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => TournamentDetailScreen(
                                tournamentId: t.id),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ── Schedule card (used in _MyScheduleScreen) ────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Tournament tournament;
  final String?    teamName;
  final VoidCallback onTap;

  const _ScheduleCard({
    required this.tournament,
    this.teamName,
    required this.onTap,
  });

  Color get _statusColor {
    switch (tournament.status) {
      case TournamentStatus.open:      return Colors.green;
      case TournamentStatus.ongoing:   return Colors.orange;
      case TournamentStatus.completed: return const Color(0xFF42A5F5);
      case TournamentStatus.cancelled: return Colors.red;
    }
  }

  String get _statusLabel {
    switch (tournament.status) {
      case TournamentStatus.open:      return 'Open';
      case TournamentStatus.ongoing:   return 'Ongoing';
      case TournamentStatus.completed: return 'Completed';
      case TournamentStatus.cancelled: return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + status
            Row(
              children: [
                Expanded(
                  child: Text(tournament.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sport + date
            Row(
              children: [
                const Icon(Icons.sports_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Text(tournament.sport,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 14),
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  '${tournament.startDate.day}/'
                  '${tournament.startDate.month}/'
                  '${tournament.startDate.year}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(tournament.location,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),

            // My team badge
            if (teamName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined,
                        size: 13, color: Color(0xFF66BB6A)),
                    const SizedBox(width: 5),
                    Text('My Team: $teamName',
                        style: const TextStyle(
                            color: Color(0xFF66BB6A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // View Schedule button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32)
                      .withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(
                        color: Color(0xFF2E7D32), width: 0.5),
                  ),
                ),
                child: const Text('View Schedule →',
                    style: TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 0, 10),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );
}

// ── Shared Tournament card ───────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final Tournament   tournament;
  final VoidCallback onTap;
  final String?      teamBadge; // shown in Registered view
  final bool         isHost;

  const _TournamentCard({
    required this.tournament,
    required this.onTap,
    this.teamBadge,
    this.isHost = false,
  });

  static const _sportEmoji = {
    'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
    'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
    'Chess': '♟️', 'Other': '🏆',
  };

  Color _statusColor(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.open:      return Colors.green;
      case TournamentStatus.ongoing:   return Colors.orange;
      case TournamentStatus.completed: return const Color(0xFF42A5F5);
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

  @override
  Widget build(BuildContext context) {
    final emoji  = _sportEmoji[tournament.sport] ?? '🏆';
    final maxStr = tournament.maxTeams == 0
        ? '${tournament.registeredTeams} teams'
        : '${tournament.registeredTeams} / ${tournament.maxTeams} teams';
    final isOpen = tournament.status == TournamentStatus.open;
    final canReg = isOpen &&
        (tournament.maxTeams == 0 ||
            tournament.registeredTeams < tournament.maxTeams);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tournament.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(tournament.sport,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                if (isHost)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('HOST',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                if (!isHost) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(tournament.status)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statusLabel(tournament.status),
                        style: TextStyle(
                            color: _statusColor(tournament.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // Date + Location
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  '${tournament.startDate.day}/${tournament.startDate.month}/${tournament.startDate.year}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(tournament.location,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),

            // My team badge (if in Registered view)
            if (teamBadge != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_outlined,
                        size: 13, color: Color(0xFF42A5F5)),
                    const SizedBox(width: 4),
                    Text('My Team: $teamBadge',
                        style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Bottom row: teams count + fee + buttons
            Row(
              children: [
                const Icon(Icons.groups_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 4),
                Text(maxStr,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: tournament.entryFee == 0
                        ? Colors.green.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tournament.entryFee == 0
                        ? 'Free'
                        : '₹${tournament.totalFee.toInt()}',
                    style: TextStyle(
                        color: tournament.entryFee == 0
                            ? Colors.green
                            : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                // Register Team button (only if open + not already enrolled)
                if (canReg && teamBadge == null && !isHost)
                  TextButton(
                    onPressed: () => EnrollTeamSheet.show(
                      context,
                      tournamentId:   tournament.id,
                      entryFee:       tournament.entryFee,
                      serviceFee:     tournament.serviceFee,
                      playersPerTeam: tournament.playersPerTeam,
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Register Team',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
