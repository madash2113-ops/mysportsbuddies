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
  int _roleIndex = 0; // 0 = Player, 1 = Host

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

            // Counts for My Tournaments badge
            final myAll = svc.tournaments.where((t) =>
                svc.myEnrolledIds.contains(t.id) || t.createdBy == userId);
            final ongoingCnt  = myAll.where((t) => t.status == TournamentStatus.ongoing).length;
            final upcomingCnt = myAll.where((t) => t.status == TournamentStatus.open).length;
            final myTournamentsBadge = ongoingCnt > 0
                ? '$ongoingCnt ongoing'
                : upcomingCnt > 0 ? '$upcomingCnt upcoming' : null;

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

                // ── Role toggle ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          _RoleToggleButton(
                            label: 'Player',
                            icon: Icons.sports_outlined,
                            selected: _roleIndex == 0,
                            selectedColor: AppColors.primary,
                            onTap: () => setState(() => _roleIndex = 0),
                          ),
                          _RoleToggleButton(
                            label: 'Host',
                            icon: Icons.manage_accounts_outlined,
                            selected: _roleIndex == 1,
                            selectedColor: AppColors.primary,
                            onTap: () => setState(() => _roleIndex = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Hub cards ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _roleIndex == 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HubCard(
                                icon: Icons.search_outlined,
                                title: 'Browse & Register',
                                subtitle: 'Find open tournaments for any sport',
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
                              const SizedBox(height: 10),
                              _HubCard(
                                icon: Icons.how_to_reg_outlined,
                                title: 'My Tournaments',
                                subtitle: 'Upcoming, current & past',
                                accent: const Color(0xFF1565C0),
                                badge: myTournamentsBadge,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _MyRegisteredScreen(userId: userId),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _HubCard(
                                icon: Icons.calendar_month_outlined,
                                title: 'My Fixtures',
                                subtitle: 'Who you play & when',
                                accent: const Color(0xFF2E7D32),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _MyScheduleScreen(userId: userId),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HubCard(
                                icon: Icons.manage_accounts_outlined,
                                title: 'My Hosted Tournaments',
                                subtitle: 'Manage teams, schedule & results',
                                accent: AppColors.primary,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _MyHostedScreen(userId: userId),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.add,
                                      color: Colors.white),
                                  label: const Text('Create New Tournament',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  onPressed: () async {
                                    final created =
                                        await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const LeagueEntryScreen()),
                                    );
                                    if (created == true && context.mounted) {
                                      TournamentService().loadTournaments();
                                    }
                                  },
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

// ── Role toggle pill button ─────────────────────────────────────────────────

class _RoleToggleButton extends StatelessWidget {
  final String      label;
  final IconData    icon;
  final bool        selected;
  final Color       selectedColor;
  final VoidCallback onTap;

  const _RoleToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white38,
                    fontSize: 14,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500)),
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// MY HOSTED TOURNAMENTS → tournaments created by this user
// ══════════════════════════════════════════════════════════════════════════════

class _MyHostedScreen extends StatefulWidget {
  final String userId;
  const _MyHostedScreen({required this.userId});

  @override
  State<_MyHostedScreen> createState() => _MyHostedScreenState();
}

class _MyHostedScreenState extends State<_MyHostedScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await TournamentService().loadTournaments();
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
        title: const Text('My Hosted Tournaments',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const LeagueEntryScreen()),
              );
              if (created == true && mounted) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListenableBuilder(
              listenable: TournamentService(),
              builder: (context, _) {
                final hosted = TournamentService()
                    .tournaments
                    .where((t) => t.createdBy == widget.userId)
                    .toList();

                if (hosted.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.manage_accounts_outlined,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text("You haven't hosted any tournaments yet",
                            style: TextStyle(
                                color: Colors.white38, fontSize: 15)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Create Tournament',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () async {
                            final created = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LeagueEntryScreen()),
                            );
                            if (created == true && mounted) _load();
                          },
                        ),
                      ],
                    ),
                  );
                }

                // Group by status
                final open = hosted
                    .where((t) => t.status == TournamentStatus.open)
                    .toList();
                final ongoing = hosted
                    .where((t) => t.status == TournamentStatus.ongoing)
                    .toList();
                final completed = hosted
                    .where((t) =>
                        t.status == TournamentStatus.completed ||
                        t.status == TournamentStatus.cancelled)
                    .toList();

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (ongoing.isNotEmpty) ...[
                        _hostedGroupHeader('Ongoing', AppColors.primary),
                        ...ongoing.map((t) => _HostedTournamentCard(
                            tournament: t, onTap: () => _openDetail(t))),
                        const SizedBox(height: 16),
                      ],
                      if (open.isNotEmpty) ...[
                        _hostedGroupHeader('Registrations Open', Colors.green),
                        ...open.map((t) => _HostedTournamentCard(
                            tournament: t, onTap: () => _openDetail(t))),
                        const SizedBox(height: 16),
                      ],
                      if (completed.isNotEmpty) ...[
                        _hostedGroupHeader('Completed', Colors.white38),
                        ...completed.map((t) => _HostedTournamentCard(
                            tournament: t, onTap: () => _openDetail(t))),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _hostedGroupHeader(String label, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  void _openDetail(Tournament t) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournamentId: t.id)),
    ).then((_) => _load());
  }
}

// ── Hosted tournament card ───────────────────────────────────────────────────

class _HostedTournamentCard extends StatelessWidget {
  final Tournament   tournament;
  final VoidCallback onTap;
  const _HostedTournamentCard(
      {required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Reuse the shared _TournamentCard with isHost = true
    return _TournamentCard(
      tournament: tournament,
      onTap:      onTap,
      isHost:     true,
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

class _OpenTournamentsScreenState extends State<_OpenTournamentsScreen> {
  String _sport = 'All';
  String _query = '';
  final _searchCtrl = TextEditingController();

  static const _sports = [
    'All', 'Cricket', 'Football', 'Basketball',
    'Badminton', 'Tennis', 'Volleyball', 'Other',
  ];

  static const _sportEmoji = {
    'All':        '🏆',
    'Cricket':    '🏏',
    'Football':   '⚽',
    'Basketball': '🏀',
    'Badminton':  '🏸',
    'Tennis':     '🎾',
    'Volleyball': '🏐',
    'Other':      '🎯',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Tournament> _filtered(List<Tournament> all) {
    // Only show open/ongoing tournaments — no completed or cancelled
    final active = all.where((t) =>
        t.status == TournamentStatus.open ||
        t.status == TournamentStatus.ongoing).toList();
    var list = _sport == 'All'
        ? active
        : active.where((t) => t.sport == _sport).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.location.toLowerCase().contains(q) ||
              t.sport.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: TournamentService(),
        builder: (context, _) {
          final filtered = _filtered(TournamentService().tournaments);
          final isFiltered = _sport != 'All';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                title: const Text('Open Tournaments',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                iconTheme: const IconThemeData(color: Colors.white),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(104),
                  child: Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Column(
                      children: [
                        // ── Search bar ──────────────────────────────────
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) =>
                              setState(() => _query = v.trim()),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search tournaments…',
                            hintStyle: const TextStyle(
                                color: Colors.white38, fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Colors.white38, size: 20),
                            suffixIcon: _query.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                    child: const Icon(Icons.close,
                                        color: Colors.white38, size: 18),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF1E1E1E),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ── Sport dropdown ──────────────────────────────
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDialog<String>(
                              context: context,
                              builder: (_) => _SportPickerDialog(
                                selected: _sport,
                                sports: _sports,
                                emojis: _sportEmoji,
                              ),
                            );
                            if (picked != null) {
                              setState(() => _sport = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _sport != 'All'
                                  ? AppColors.primary
                                      .withValues(alpha: 0.12)
                                  : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _sport != 'All'
                                    ? AppColors.primary
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _sportEmoji[_sport] ?? '🎯',
                                  style:
                                      const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _sport == 'All'
                                      ? 'All Sports'
                                      : _sport,
                                  style: TextStyle(
                                    color: _sport != 'All'
                                        ? AppColors.primary
                                        : Colors.white60,
                                    fontSize: 13,
                                    fontWeight: _sport != 'All'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _sport != 'All'
                                      ? AppColors.primary
                                      : Colors.white38,
                                  size: 20,
                                ),
                                if (_sport != 'All') ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _sport = 'All'),
                                    child: const Icon(Icons.close,
                                        color: AppColors.primary,
                                        size: 16),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Result count strip
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    filtered.isEmpty
                        ? isFiltered
                            ? 'No $_sport tournaments found'
                            : 'No tournaments found'
                        : '${filtered.length} tournament${filtered.length == 1 ? '' : 's'}${isFiltered ? ' · $_sport' : ''}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              filtered.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isFiltered
                                  ? (_sportEmoji[_sport] ?? '🏆')
                                  : '🏆',
                              style: const TextStyle(fontSize: 56),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isFiltered
                                  ? 'No $_sport tournaments'
                                  : 'No tournaments found',
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 16),
                            ),
                            if (isFiltered) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _sport = 'All'),
                                child: const Text('Show all sports',
                                    style: TextStyle(
                                        color: AppColors.primary)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final ongoing = filtered
                              .where((t) => t.status == TournamentStatus.ongoing)
                              .toList();
                          final open = filtered
                              .where((t) => t.status == TournamentStatus.open)
                              .toList();
                          final combined = [
                            if (ongoing.isNotEmpty) ...[
                              const _SectionHeader(label: 'Ongoing', color: AppColors.primary),
                              ...ongoing,
                            ],
                            if (open.isNotEmpty) ...[
                              const _SectionHeader(label: 'Registrations Open', color: Color(0xFF2E7D32)),
                              ...open,
                            ],
                          ];
                          final item = combined[i];
                          if (item is _SectionHeader) return item;
                          final t = item as Tournament;
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
                        childCount: (() {
                          final ongoing = filtered
                              .where((t) => t.status == TournamentStatus.ongoing)
                              .length;
                          final open = filtered
                              .where((t) => t.status == TournamentStatus.open)
                              .length;
                          return filtered.length +
                              (ongoing > 0 ? 1 : 0) +
                              (open > 0 ? 1 : 0);
                        })(),
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

// ── Sport picker dialog ───────────────────────────────────────────────────────

class _SportPickerDialog extends StatelessWidget {
  final String selected;
  final List<String> sports;
  final Map<String, String> emojis;

  const _SportPickerDialog({
    required this.selected,
    required this.sports,
    required this.emojis,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Sport',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.9,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: sports.length,
              itemBuilder: (_, i) {
                final s   = sports[i];
                final sel = s == selected;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary
                          : const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? AppColors.primary : Colors.white10,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emojis[s] ?? '🎯',
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(s,
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 10,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.normal),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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

class _MyRegisteredScreenState extends State<_MyRegisteredScreen>
    with SingleTickerProviderStateMixin {
  bool   _loading = true;
  String _query   = '';
  final  _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([
      TournamentService().loadTournaments(),
      TournamentService().loadMyEnrollments(widget.userId),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  List<Tournament> _applyQuery(List<Tournament> list) {
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where((t) =>
            t.name.toLowerCase().contains(q) ||
            t.sport.toLowerCase().contains(q) ||
            t.location.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Tournaments',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search my tournaments…',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // ── Tabs ────────────────────────────────────────────────────
              TabBar(
                controller: _tabCtrl,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Current'),
                  Tab(text: 'Past'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListenableBuilder(
              listenable: TournamentService(),
              builder: (context, _) {
                final svc = TournamentService();
                final uid = widget.userId;

                final allMine = svc.tournaments
                    .where((t) =>
                        svc.myEnrolledIds.contains(t.id) ||
                        t.createdBy == uid)
                    .toList();

                final upcoming = _applyQuery(allMine
                    .where((t) => t.status == TournamentStatus.open)
                    .toList());
                final current = _applyQuery(allMine
                    .where((t) => t.status == TournamentStatus.ongoing)
                    .toList());
                final past = _applyQuery(allMine
                    .where((t) =>
                        t.status == TournamentStatus.completed ||
                        t.status == TournamentStatus.cancelled)
                    .toList());

                final noResults = _query.isNotEmpty &&
                    upcoming.isEmpty &&
                    current.isEmpty &&
                    past.isEmpty;

                if (noResults) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 56, color: Colors.white12),
                        const SizedBox(height: 14),
                        Text('No results for "$_query"',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 15)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: const Text('Clear search',
                              style:
                                  TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TournamentTabBody(
                      tournaments: upcoming,
                      userId: uid,
                      emptyIcon: Icons.event_available_outlined,
                      emptyText: _query.isNotEmpty
                          ? 'No upcoming matches "$_query"'
                          : 'No upcoming tournaments',
                      emptyHint: 'Register for an open tournament to see it here',
                      showNextMatch: false,
                      onRefresh: _load,
                    ),
                    _TournamentTabBody(
                      tournaments: current,
                      userId: uid,
                      emptyIcon: Icons.sports_outlined,
                      emptyText: _query.isNotEmpty
                          ? 'No active matches "$_query"'
                          : 'No active tournaments',
                      emptyHint: 'Tournaments move here once they start',
                      showNextMatch: true,
                      onRefresh: _load,
                    ),
                    _TournamentTabBody(
                      tournaments: past,
                      userId: uid,
                      emptyIcon: Icons.history_outlined,
                      emptyText: _query.isNotEmpty
                          ? 'No past matches "$_query"'
                          : 'No past tournaments',
                      emptyHint: 'Completed tournaments will appear here',
                      showNextMatch: false,
                      onRefresh: _load,
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ── Tab body (reusable across Upcoming/Current/Past tabs) ────────────────────

class _TournamentTabBody extends StatelessWidget {
  final List<Tournament> tournaments;
  final String           userId;
  final IconData         emptyIcon;
  final String           emptyText;
  final String           emptyHint;
  final bool             showNextMatch;
  final Future<void> Function() onRefresh;

  const _TournamentTabBody({
    required this.tournaments,
    required this.userId,
    required this.emptyIcon,
    required this.emptyText,
    required this.emptyHint,
    required this.showNextMatch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            Text(emptyText,
                style: const TextStyle(color: Colors.white38, fontSize: 15)),
            const SizedBox(height: 6),
            Text(emptyHint,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final svc = TournamentService();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: tournaments.length,
        itemBuilder: (ctx, i) {
          final t      = tournaments[i];
          final isHost = t.createdBy == userId && !svc.myEnrolledIds.contains(t.id);
          final myTeam = svc.myTeamIn(t.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TournamentCard(
                tournament: t,
                teamBadge:  myTeam?.teamName,
                isHost:     isHost,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => TournamentDetailScreen(tournamentId: t.id),
                  ),
                ),
              ),
              if (showNextMatch && myTeam != null)
                _NextMatchChip(tournamentId: t.id, myTeamId: myTeam.id),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }
}

// ── Next Match Chip (shown in Current tab) ───────────────────────────────────

class _NextMatchChip extends StatelessWidget {
  final String tournamentId;
  final String myTeamId;

  const _NextMatchChip({required this.tournamentId, required this.myTeamId});

  @override
  Widget build(BuildContext context) {
    final matches = TournamentService().matchesFor(tournamentId);
    final next = matches
        .where((m) =>
            !m.isBye &&
            m.result == TournamentMatchResult.pending &&
            (m.teamAId == myTeamId || m.teamBId == myTeamId))
        .toList()
      ..sort((a, b) => a.round.compareTo(b.round));

    if (next.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(
          children: const [
            Icon(Icons.schedule_outlined, size: 13, color: Colors.white24),
            SizedBox(width: 5),
            Text('No match scheduled yet',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }

    final m        = next.first;
    final opponent = m.teamAId == myTeamId
        ? (m.teamBName ?? 'TBD')
        : (m.teamAName ?? 'TBD');
    final roundLabel = _roundLabel(m.round,
        TournamentService().matchesFor(tournamentId).map((x) => x.round).toSet().length);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_outlined, size: 13, color: Colors.green),
            const SizedBox(width: 5),
            Text(
              'Next: vs $opponent · $roundLabel',
              style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _roundLabel(int round, int totalRounds) {
    final remaining = totalRounds - round + 1;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semi-Final';
    if (remaining == 3) return 'Quarter-Final';
    return 'Round $round';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MY FIXTURES → per-match fixture cards (who you play & when)
// ══════════════════════════════════════════════════════════════════════════════

// Simple data holder for a single fixture entry
class _MatchEntry {
  final TournamentMatch  match;
  final Tournament       tournament;
  final TournamentTeam   myTeam;
  const _MatchEntry({required this.match, required this.tournament, required this.myTeam});
}

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
    final svc = TournamentService();
    await Future.wait([
      svc.loadTournaments(),
      svc.loadMyEnrollments(widget.userId),
    ]);
    // Load details for all open/ongoing tournaments + any known enrolled ones.
    // This ensures we discover pre-migration enrollments (where the team data
    // lives only in the subcollection, not yet in the top-level enrollments
    // collection). loadDetail() will populate _myTeamMap as a side-effect.
    final toLoad = svc.tournaments.where((t) =>
        t.status == TournamentStatus.open ||
        t.status == TournamentStatus.ongoing ||
        svc.myEnrolledIds.contains(t.id));
    await Future.wait(toLoad.map((t) => svc.loadDetail(t.id)));
    if (mounted) setState(() => _loading = false);
  }

  List<_MatchEntry> _myMatches(TournamentService svc) {
    final result = <_MatchEntry>[];
    for (final t in svc.tournaments) {
      final myTeam = svc.myTeamIn(t.id);
      if (myTeam == null) continue;
      final mine = svc.matchesFor(t.id).where((m) =>
          !m.isBye &&
          (m.teamAId == myTeam.id || m.teamBId == myTeam.id));
      for (final m in mine) {
        result.add(_MatchEntry(match: m, tournament: t, myTeam: myTeam));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My Fixtures',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListenableBuilder(
              listenable: TournamentService(),
              builder: (context, _) {
                final svc     = TournamentService();
                final entries = _myMatches(svc);

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 64, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text('No fixtures yet',
                            style: TextStyle(color: Colors.white38, fontSize: 15)),
                        const SizedBox(height: 8),
                        const Text(
                            'Once a host generates the schedule,\nyour matches will appear here',
                            style: TextStyle(color: Colors.white24, fontSize: 13),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              size: 16, color: AppColors.primary),
                          label: const Text('Back',
                              style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                }

                final upcoming  = entries.where((e) =>
                    e.match.result == TournamentMatchResult.pending).toList();
                final completed = entries.where((e) =>
                    e.match.result != TournamentMatchResult.pending).toList();

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _fixtureHeading('UPCOMING FIXTURES'),
                        ...upcoming.map((e) => _FixtureCard(entry: e)),
                        const SizedBox(height: 8),
                      ],
                      if (completed.isNotEmpty) ...[
                        _fixtureHeading('COMPLETED'),
                        ...completed.map((e) => _FixtureCard(entry: e)),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _fixtureHeading(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );
}

// ── Fixture Card ─────────────────────────────────────────────────────────────

class _FixtureCard extends StatelessWidget {
  final _MatchEntry entry;
  const _FixtureCard({required this.entry});

  static const _sportEmoji = {
    'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
    'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
    'Chess': '♟️', 'Other': '🏆',
  };

  static String _roundLabel(int round, int totalRounds) {
    final remaining = totalRounds - round + 1;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semi-Final';
    if (remaining == 3) return 'Quarter-Final';
    return 'Round $round';
  }

  @override
  Widget build(BuildContext context) {
    final m         = entry.match;
    final t         = entry.tournament;
    final myTeam    = entry.myTeam;
    final isPending = m.result == TournamentMatchResult.pending;
    final iWon      = m.winnerId == myTeam.id;
    final opponent  = m.teamAId == myTeam.id
        ? (m.teamBName ?? 'TBD')
        : (m.teamAName ?? 'TBD');
    final emoji     = _sportEmoji[t.sport] ?? '🏆';

    final borderColor = isPending
        ? Colors.green.withValues(alpha: 0.35)
        : iWon
            ? Colors.blue.withValues(alpha: 0.35)
            : Colors.red.withValues(alpha: 0.35);

    final totalRounds = TournamentService()
        .matchesFor(t.id)
        .map((x) => x.round)
        .toSet()
        .length;
    final roundLabel = _roundLabel(m.round, totalRounds);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournamentId: t.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: emoji + tournament name + round badge
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.name,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(roundLabel,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),

            // VS row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MY TEAM',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(myTeam.teamName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('vs',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('OPPONENT',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(opponent,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom row: date + score chip
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 5),
                Text(
                  m.scheduledAt != null
                      ? '${m.scheduledAt!.day}/${m.scheduledAt!.month}/${m.scheduledAt!.year}'
                      : 'Date TBD',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                if (!isPending) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iWon
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      m.scoreA != null
                          ? (m.teamAId == myTeam.id
                              ? '${m.scoreA} – ${m.scoreB}'
                              : '${m.scoreB} – ${m.scoreA}')
                          : iWon ? 'Won' : 'Lost',
                      style: TextStyle(
                          color: iWon ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Upcoming',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TournamentDetailScreen(tournamentId: t.id),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View →',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

  // Per-sport asset images for the banner
  static const _bannerImages = <String, String>{
    'Cricket':    'assets/sports/cricket.jpg',
    'Football':   'assets/sports/football.jpg',
    'Basketball': 'assets/sports/basketball.jpg',
    'Badminton':  'assets/sports/badminton.jpg',
    'Tennis':     'assets/sports/tennis.jpg',
    'Volleyball': 'assets/sports/volleyball.jpg',
    'Chess':      'assets/sports/chess.jpg',
  };

  // Fallback gradient colors if no image available
  static const _gradients = <String, List<Color>>{
    'Cricket':    [Color(0xFF0D47A1), Color(0xFF1565C0)],
    'Football':   [Color(0xFF1B5E20), Color(0xFF2E7D32)],
    'Basketball': [Color(0xFFBF360C), Color(0xFFD84315)],
    'Badminton':  [Color(0xFF006064), Color(0xFF00838F)],
    'Tennis':     [Color(0xFF33691E), Color(0xFF558B2F)],
    'Volleyball': [Color(0xFF311B92), Color(0xFF4527A0)],
    'Chess':      [Color(0xFF212121), Color(0xFF424242)],
  };

  String _formatLabel(TournamentFormat f) {
    switch (f) {
      case TournamentFormat.knockout:       return 'Knockout';
      case TournamentFormat.roundRobin:     return 'Round Robin';
      case TournamentFormat.leagueKnockout: return 'League+KO';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  (Color, String) _statusStyle(TournamentStatus s) {
    switch (s) {
      case TournamentStatus.open:      return (Colors.green,  'OPEN');
      case TournamentStatus.ongoing:   return (AppColors.primary, 'LIVE');
      case TournamentStatus.completed: return (const Color(0xFF42A5F5), 'ENDED');
      case TournamentStatus.cancelled: return (Colors.red,    'CANCELLED');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradList   = _gradients[tournament.sport] ??
        [const Color(0xFF1A237E), const Color(0xFF283593)];
    final bannerPath = _bannerImages[tournament.sport];
    final maxStr     = tournament.maxTeams == 0
        ? '${tournament.registeredTeams} teams'
        : '${tournament.registeredTeams}/${tournament.maxTeams} teams';
    final isOpen   = tournament.status == TournamentStatus.open;
    final canReg   = isOpen &&
        (tournament.maxTeams == 0 ||
            tournament.registeredTeams < tournament.maxTeams);
    final (statusColor, statusLabel) = _statusStyle(tournament.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradList[0].withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient banner ──────────────────────────────────────────
            SizedBox(
              height: 170,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // custom uploaded banner > sport asset > gradient fallback
                  if (tournament.bannerUrl != null)
                    Image.network(
                      tournament.bannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => bannerPath != null
                          ? Image.asset(bannerPath, fit: BoxFit.cover)
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradList,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                    )
                  else if (bannerPath != null)
                    Image.asset(
                      bannerPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradList,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradList,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  // dark gradient overlay at bottom for readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // content on top of banner
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // format chip + host/status pill
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatLabel(tournament.format),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tournament.sport,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            if (isHost)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('HOST',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(statusLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                        // tournament name at bottom of banner
                        Text(
                          tournament.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1))
                              ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date range row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(_fmtDate(tournament.startDate),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      if (tournament.endDate != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward,
                              size: 11, color: Colors.white30),
                        ),
                        Text(_fmtDate(tournament.endDate!),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Location row
                  Row(
                    children: [
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

                  // My team badge (Registered view only)
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

                  // Teams + fee + action buttons
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined,
                          size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Text(maxStr,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const Spacer(),
                      // Fee chip
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
                      // Register button
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
                          child: const Text('Register',
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
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
