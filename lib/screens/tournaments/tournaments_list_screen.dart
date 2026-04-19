import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    TournamentService().loadTournaments().then((_) {
      // Pre-load match detail for ongoing tournaments so live scores show on cards
      for (final t in TournamentService().tournaments) {
        if (t.status == TournamentStatus.ongoing) {
          TournamentService().loadDetail(t.id);
        }
      }
    });
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
  String _sport  = 'All';
  String _format = 'All';
  String _query  = '';
  final _searchCtrl = TextEditingController();

  static const _formatOptions = [
    ('All',                  'All Formats'),
    ('knockout',             'Knockout'),
    ('roundRobin',           'Round Robin'),
    ('leagueKnockout',       'League + KO'),
  ];

  static const _allSports = [
    ('All',          '🏆'),
    ('Cricket',      '🏏'),
    ('Football',     '⚽'),
    ('Basketball',   '🏀'),
    ('Badminton',    '🏸'),
    ('Tennis',       '🎾'),
    ('Volleyball',   '🏐'),
    ('Table Tennis', '🏓'),
    ('Hockey',       '🏑'),
    ('Boxing',       '🥊'),
    ('Kabaddi',      '🤼'),
    ('Throwball',    '🎯'),
    ('Handball',     '🤾'),
    ('Swimming',     '🏊'),
    ('Cycling',      '🚴'),
    ('Rugby',        '🏉'),
    ('Golf',         '⛳'),
    ('Squash',       '🎾'),
    ('Wrestling',    '🤼'),
    ('Athletics',    '🏃'),
    ('Archery',      '🏹'),
    ('Other',        '🎯'),
  ];

  static final _sportEmoji = {
    for (final (name, emoji) in _allSports) name: emoji,
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
    if (_format != 'All') {
      list = list.where((t) => t.format.name == _format).toList();
    }
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
                  preferredSize: Size.fromHeight(
                      _sport != 'All' ? 148 : 104),
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
                                sports: _allSports,
                                emojis: _sportEmoji,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _sport = picked;
                                // Reset format when sport changes
                                _format = 'All';
                              });
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
                                    onTap: () => setState(() {
                                      _sport  = 'All';
                                      _format = 'All';
                                    }),
                                    child: const Icon(Icons.close,
                                        color: AppColors.primary,
                                        size: 16),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // ── Format dropdown — only when sport is selected ──
                        if (_sport != 'All') ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDialog<String>(
                                context: context,
                                builder: (_) => _FormatPickerDialog(
                                  selected: _format,
                                  options:  _formatOptions,
                                ),
                              );
                              if (picked != null) {
                                setState(() => _format = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _format != 'All'
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _format != 'All'
                                      ? AppColors.primary
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(children: [
                                const Icon(Icons.filter_list_rounded,
                                    color: Colors.white38, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _format == 'All'
                                      ? 'All Formats'
                                      : _formatOptions
                                          .firstWhere((o) => o.$1 == _format)
                                          .$2,
                                  style: TextStyle(
                                    color: _format != 'All'
                                        ? AppColors.primary
                                        : Colors.white60,
                                    fontSize: 13,
                                    fontWeight: _format != 'All'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.keyboard_arrow_down_rounded,
                                    color: _format != 'All'
                                        ? AppColors.primary
                                        : Colors.white38,
                                    size: 20),
                                if (_format != 'All') ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _format = 'All'),
                                    child: const Icon(Icons.close,
                                        color: AppColors.primary, size: 16),
                                  ),
                                ],
                              ]),
                            ),
                          ),
                        ],
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
                            ? 'No ${_format != 'All' ? '${_formatOptions.firstWhere((o) => o.$1 == _format).$2} ' : ''}$_sport tournaments found'
                            : 'No tournaments found'
                        : '${filtered.length} tournament${filtered.length == 1 ? '' : 's'}${isFiltered ? ' · $_sport' : ''}${_format != 'All' ? ' · ${_formatOptions.firstWhere((o) => o.$1 == _format).$2}' : ''}',
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

class _SportPickerDialog extends StatefulWidget {
  final String selected;
  final List<(String, String)> sports;
  final Map<String, String> emojis;

  const _SportPickerDialog({
    required this.selected,
    required this.sports,
    required this.emojis,
  });

  @override
  State<_SportPickerDialog> createState() => _SportPickerDialogState();
}

class _SportPickerDialogState extends State<_SportPickerDialog> {
  String _search = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<(String, String)> get _filtered {
    if (_search.isEmpty) return widget.sports;
    final q = _search.toLowerCase();
    return widget.sports
        .where((s) => s.$1.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Sport',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            // ── Search field ──────────────────────────────────────
            TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _search = v.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search sports…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.white38, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() => _search = '');
                        },
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF252525),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Sport list ────────────────────────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No sports found',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final (name, emoji) = list[i];
                        final sel = name == widget.selected;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(context, name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: sel ? AppColors.primary : Colors.white70,
                                      fontSize: 14,
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (sel)
                                  const Icon(Icons.check_circle,
                                      color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Format picker dialog ──────────────────────────────────────────────────────

class _FormatPickerDialog extends StatelessWidget {
  final String selected;
  final List<(String, String)> options;

  const _FormatPickerDialog({
    required this.selected,
    required this.options,
  });

  static const _formatIcons = {
    'All':             Icons.grid_view_rounded,
    'knockout':        Icons.account_tree_rounded,
    'roundRobin':      Icons.repeat_rounded,
    'leagueKnockout':  Icons.emoji_events_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Format',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final (value, label) = opt;
              final sel = value == selected;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context, value),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(
                      _formatIcons[value] ?? Icons.tune_rounded,
                      color: sel ? AppColors.primary : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                            color: sel ? AppColors.primary : Colors.white70,
                            fontSize: 14,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.normal,
                          )),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 20),
                  ]),
                ),
              );
            }),
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
  String _sport   = 'All';
  String _format  = 'All';
  final  _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  static const _formatOptions = [
    ('All',            'All Formats'),
    ('knockout',       'Knockout'),
    ('roundRobin',     'Round Robin'),
    ('leagueKnockout', 'League + KO'),
  ];

  static const _allSports = [
    ('All',          '🏆'),
    ('Cricket',      '🏏'),
    ('Football',     '⚽'),
    ('Basketball',   '🏀'),
    ('Badminton',    '🏸'),
    ('Tennis',       '🎾'),
    ('Volleyball',   '🏐'),
    ('Table Tennis', '🏓'),
    ('Hockey',       '🏑'),
    ('Boxing',       '🥊'),
    ('Kabaddi',      '🤼'),
    ('Throwball',    '🎯'),
    ('Handball',     '🤾'),
    ('Swimming',     '🏊'),
    ('Cycling',      '🚴'),
    ('Rugby',        '🏉'),
    ('Golf',         '⛳'),
    ('Squash',       '🎾'),
    ('Wrestling',    '🤼'),
    ('Athletics',    '🏃'),
    ('Archery',      '🏹'),
    ('Other',        '🎯'),
  ];

  static final _sportEmoji = {
    for (final (name, emoji) in _allSports) name: emoji,
  };

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

  List<Tournament> _applyFilters(List<Tournament> list) {
    var result = list;
    if (_sport != 'All') {
      result = result.where((t) => t.sport == _sport).toList();
    }
    if (_format != 'All') {
      result = result.where((t) => t.format.name == _format).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.sport.toLowerCase().contains(q) ||
              t.location.toLowerCase().contains(q))
          .toList();
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
        title: const Text('My Tournaments',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_sport != 'All' ? 208 : 156),
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
              // ── Sport dropdown ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDialog<String>(
                      context: context,
                      builder: (_) => _SportPickerDialog(
                        selected: _sport,
                        sports: _allSports,
                        emojis: _sportEmoji,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _sport  = picked;
                        _format = 'All';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _sport != 'All'
                          ? AppColors.primary.withValues(alpha: 0.12)
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
                        Text(_sportEmoji[_sport] ?? '🎯',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          _sport == 'All' ? 'All Sports' : _sport,
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
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: _sport != 'All'
                                ? AppColors.primary
                                : Colors.white38,
                            size: 20),
                        if (_sport != 'All') ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() {
                              _sport  = 'All';
                              _format = 'All';
                            }),
                            child: const Icon(Icons.close,
                                color: AppColors.primary, size: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // ── Format dropdown (only when sport selected) ──────────────
              if (_sport != 'All')
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDialog<String>(
                        context: context,
                        builder: (_) => _FormatPickerDialog(
                          selected: _format,
                          options:  _formatOptions,
                        ),
                      );
                      if (picked != null) setState(() => _format = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _format != 'All'
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _format != 'All'
                              ? AppColors.primary
                              : Colors.white12,
                        ),
                      ),
                      child: Row(children: [
                        const Icon(Icons.filter_list_rounded,
                            color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _format == 'All'
                              ? 'All Formats'
                              : _formatOptions
                                  .firstWhere((o) => o.$1 == _format)
                                  .$2,
                          style: TextStyle(
                            color: _format != 'All'
                                ? AppColors.primary
                                : Colors.white60,
                            fontSize: 13,
                            fontWeight: _format != 'All'
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: _format != 'All'
                                ? AppColors.primary
                                : Colors.white38,
                            size: 20),
                        if (_format != 'All') ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _format = 'All'),
                            child: const Icon(Icons.close,
                                color: AppColors.primary, size: 16),
                          ),
                        ],
                      ]),
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

                final upcoming = _applyFilters(allMine
                    .where((t) => t.status == TournamentStatus.open)
                    .toList());
                final current = _applyFilters(allMine
                    .where((t) => t.status == TournamentStatus.ongoing)
                    .toList());
                final past = _applyFilters(allMine
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
  DateTime _selectedDay = _dayOnly(DateTime.now());
  final _stripCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _stripCtrl.dispose();
    super.dispose();
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    final svc = TournamentService();
    await Future.wait([
      svc.loadTournaments(),
      svc.loadMyEnrollments(widget.userId),
    ]);
    final toLoad = svc.tournaments.where((t) =>
        t.status == TournamentStatus.open ||
        t.status == TournamentStatus.ongoing ||
        svc.myEnrolledIds.contains(t.id));
    await Future.wait(toLoad.map((t) => svc.loadDetail(t.id)));
    if (mounted) setState(() => _loading = false);
  }

  List<_MatchEntry> _myMatches(TournamentService svc) {
    final uid    = widget.userId;
    final result = <_MatchEntry>[];
    for (final t in svc.tournaments) {
      final myTeam = svc.myTeamIn(t.id);
      if (myTeam == null) continue;
      // Only include teams where the user is personally in the roster.
      // If playerUserIds is empty the team has no per-player tracking, so
      // fall back to trusting the enrolledBy check already done by myTeamIn().
      if (myTeam.playerUserIds.isNotEmpty &&
          !myTeam.playerUserIds.contains(uid)) {
        continue;
      }
      for (final m in svc.matchesFor(t.id)) {
        if (m.isBye) {
          continue;
        }
        if (m.teamAId != myTeam.id && m.teamBId != myTeam.id) {
          continue;
        }
        result.add(_MatchEntry(match: m, tournament: t, myTeam: myTeam));
      }
    }
    result.sort((a, b) {
      final at = a.match.scheduledAt;
      final bt = b.match.scheduledAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
    return result;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListenableBuilder(
              listenable: TournamentService(),
              builder: (context, _) {
                final allEntries = _myMatches(TournamentService());
                if (allEntries.isEmpty) return _buildEmpty(context);

                // All days that have scheduled matches (for strip dots)
                final matchDaySet = allEntries
                    .where((e) => e.match.scheduledAt != null)
                    .map((e) => _dayOnly(e.match.scheduledAt!))
                    .toSet();

                // Unscheduled (no date/time yet)
                final tbdEntries = allEntries
                    .where((e) => e.match.scheduledAt == null)
                    .toList();

                // Timed matches for the selected day only
                final dayEntries = allEntries
                    .where((e) =>
                        e.match.scheduledAt != null &&
                        _dayOnly(e.match.scheduledAt!) == _selectedDay)
                    .toList()
                  ..sort((a, b) =>
                      a.match.scheduledAt!.compareTo(b.match.scheduledAt!));

                return Column(
                  children: [
                    // ── Date strip ─────────────────────────────────────
                    _CalendarStrip(
                      matchDays:  matchDaySet,
                      selected:   _selectedDay,
                      scrollCtrl: _stripCtrl,
                      onSelect:   (d) => setState(() => _selectedDay = d),
                    ),
                    // ── Unscheduled matches (pinned at top) ────────────
                    if (tbdEntries.isNotEmpty) _TbdSection(entries: tbdEntries),
                    // ── Time-grid for selected day ──────────────────────
                    Expanded(
                      child: dayEntries.isEmpty
                          ? _buildNoMatchesDay()
                          : _DayTimeGrid(
                              key: ValueKey(_selectedDay),
                              entries: dayEntries,
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildNoMatchesDay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.event_busy_outlined, size: 48, color: Colors.white12),
          SizedBox(height: 12),
          Text('No matches on this day',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Calendar date strip ───────────────────────────────────────────────────────

class _CalendarStrip extends StatefulWidget {
  final Set<DateTime>    matchDays;
  final DateTime         selected;
  final ScrollController scrollCtrl;
  final void Function(DateTime) onSelect;
  const _CalendarStrip({
    required this.matchDays,
    required this.selected,
    required this.scrollCtrl,
    required this.onSelect,
  });

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  static const _kDayW = 52.0;
  static const _kDays = 60; // show 60 days from today

  late final DateTime _start;
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _start = DateTime(today.year, today.month, today.day);
    _days  = List.generate(_kDays, (i) => _start.add(Duration(days: i)));
    // scroll so today is near the left
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _days.indexWhere((d) => d == widget.selected);
      if (idx > 0 && widget.scrollCtrl.hasClients) {
        widget.scrollCtrl.jumpTo((idx * _kDayW).clamp(
            0, widget.scrollCtrl.position.maxScrollExtent));
      }
    });
  }

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months   = ['Jan','Feb','Mar','Apr','May','Jun',
                              'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              '${_months[widget.selected.month - 1]} ${widget.selected.year}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Day chips
          SizedBox(
            height: 72,
            child: ListView.builder(
              controller: widget.scrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _days.length,
              itemBuilder: (_, i) {
                final d       = _days[i];
                final isToday = d == _start;
                final isSel   = d == widget.selected;
                final hasMat  = widget.matchDays.contains(d);
                return GestureDetector(
                  onTap: () => widget.onSelect(d),
                  child: Container(
                    width: _kDayW,
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.primary
                          : isToday
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSel
                          ? null
                          : isToday
                              ? Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4))
                              : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayNames[d.weekday - 1],
                          style: TextStyle(
                            color: isSel
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            color: isSel
                                ? Colors.white
                                : isToday
                                    ? AppColors.primary
                                    : Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Dot indicator for days with matches
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasMat
                                ? (isSel ? Colors.white : AppColors.primary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }
}

// ── Unscheduled (TBD) section pinned at top of day view ─────────────────────

class _TbdSection extends StatelessWidget {
  final List<_MatchEntry> entries;
  const _TbdSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.schedule_rounded, color: Colors.white38, size: 12),
            const SizedBox(width: 5),
            const Text('Unscheduled',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Expanded(child: Divider(color: Colors.white10)),
          ]),
          const SizedBox(height: 6),
          for (final e in entries) _TimeGridEventCard(entry: e),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
        ],
      ),
    );
  }
}

// ── Day time-grid (Teams / Google Calendar style) ─────────────────────────────

class _DayTimeGrid extends StatefulWidget {
  final List<_MatchEntry> entries;
  const _DayTimeGrid({super.key, required this.entries});

  @override
  State<_DayTimeGrid> createState() => _DayTimeGridState();
}

class _DayTimeGridState extends State<_DayTimeGrid> {
  static const double _kHourH  = 60.0; // px per hour
  static const double _kTimeW  = 46.0; // width of time-label column
  static const int    _kStart  = 6;    // 6 AM
  static const int    _kEnd    = 23;   // 11 PM

  final _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFirst());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scrollToFirst() {
    if (!_ctrl.hasClients || widget.entries.isEmpty) return;
    final dt     = widget.entries.first.match.scheduledAt!;
    final offset = ((dt.hour - _kStart + dt.minute / 60) * _kHourH - 40)
        .clamp(0.0, _ctrl.position.maxScrollExtent);
    _ctrl.jumpTo(offset);
  }

  String _hourLabel(int h) {
    if (h == 0)  return '12\nAM';
    if (h == 12) return '12\nPM';
    return h < 12 ? '$h\nAM' : '${h - 12}\nPM';
  }

  @override
  Widget build(BuildContext context) {
    final totalH = (_kEnd - _kStart) * _kHourH;
    final now    = DateTime.now();
    final todayD = DateTime(now.year, now.month, now.day);
    final firstD = widget.entries.first.match.scheduledAt!;
    final isToday = DateTime(firstD.year, firstD.month, firstD.day) == todayD;

    return SingleChildScrollView(
      controller: _ctrl,
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      child: SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hour labels ──────────────────────────────────────────
            SizedBox(
              width: _kTimeW,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int h = _kStart; h <= _kEnd; h++)
                    Positioned(
                      top: (h - _kStart) * _kHourH - 10,
                      left: 0,
                      right: 4,
                      child: Text(
                        _hourLabel(h),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Grid lines + events ──────────────────────────────────
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Hour dividers
                  for (int h = _kStart; h <= _kEnd; h++)
                    Positioned(
                      top: (h - _kStart) * _kHourH,
                      left: 0, right: 0,
                      child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.07)),
                    ),
                  // Half-hour dashes
                  for (int h = _kStart; h < _kEnd; h++)
                    Positioned(
                      top: (h - _kStart) * _kHourH + _kHourH / 2,
                      left: 0, right: 0,
                      child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.03)),
                    ),
                  // Current-time indicator (today only)
                  if (isToday &&
                      now.hour >= _kStart && now.hour <= _kEnd)
                    Positioned(
                      top: (now.hour - _kStart + now.minute / 60) * _kHourH,
                      left: 0, right: 0,
                      child: Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                            child: Container(
                                height: 1.5,
                                color: AppColors.primary)),
                      ]),
                    ),
                  // Match event cards
                  for (final e in widget.entries)
                    _positionedCard(e),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _positionedCard(_MatchEntry e) {
    final dt  = e.match.scheduledAt!;
    final top = (dt.hour - _kStart + dt.minute / 60) * _kHourH;
    return Positioned(
      top: top,
      left: 4, right: 4,
      child: _TimeGridEventCard(entry: e),
    );
  }
}

// ── Compact event card used inside the time-grid and TBD section ─────────────

class _TimeGridEventCard extends StatelessWidget {
  final _MatchEntry entry;
  const _TimeGridEventCard({required this.entry});

  static const _sportEmoji = {
    'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
    'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
    'Table Tennis': '🏓', 'Chess': '♟️',
  };

  static String _roundLabel(int round, int total) {
    final rem = total - round + 1;
    if (rem == 1) return 'Final';
    if (rem == 2) return 'Semi-Final';
    if (rem == 3) return 'Quarter-Final';
    return 'Round $round';
  }

  static String _timeStr(DateTime dt) {
    final h  = dt.hour;
    final m  = dt.minute.toString().padLeft(2, '0');
    final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hr:$m ${h < 12 ? "AM" : "PM"}';
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final m  = entry.match;
    final t  = entry.tournament;
    final dt = m.scheduledAt!;
    final end = dt.add(const Duration(hours: 2));

    String fmt(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}'
        'T${d.hour.toString().padLeft(2,'0')}${d.minute.toString().padLeft(2,'0')}00';

    final opp = m.teamAId == entry.myTeam.id
        ? (m.teamBName ?? 'TBD')
        : (m.teamAName ?? 'TBD');

    final url = Uri.parse(
        'https://calendar.google.com/calendar/r/eventedit'
        '?text=${Uri.encodeComponent('${t.sport}: ${entry.myTeam.teamName} vs $opp')}'
        '&dates=${fmt(dt)}/${fmt(end)}'
        '&details=${Uri.encodeComponent('Tournament: ${t.name}\nRound: ${m.round}')}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open calendar')));
    }
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
    final accent    = isPending
        ? AppColors.primary
        : iWon ? Colors.green : Colors.red;
    final total     = TournamentService().matchesFor(t.id)
        .map((x) => x.round).toSet().length;
    final roundLbl  = _roundLabel(m.round, total);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => TournamentDetailScreen(tournamentId: t.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: sport + name + round badge
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(t.name,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(roundLbl,
                    style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 5),
            // Teams row
            Row(children: [
              Expanded(
                child: Text(myTeam.teamName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  isPending
                      ? 'vs'
                      : m.scoreA != null
                          ? (m.teamAId == myTeam.id
                              ? '${m.scoreA}–${m.scoreB}'
                              : '${m.scoreB}–${m.scoreA}')
                          : 'vs',
                  style: TextStyle(
                      color: isPending ? Colors.white38 : accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(opponent,
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end),
              ),
            ]),
            // Bottom row: time + add-to-calendar (only when time is set)
            if (m.scheduledAt != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 11, color: accent.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(_timeStr(m.scheduledAt!),
                    style: TextStyle(
                        color: accent.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _addToCalendar(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 10, color: Colors.white38),
                    const SizedBox(width: 3),
                    const Text('Add to Calendar',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared Tournament card ───────────────────────────────────────────────────

class _TournamentCard extends StatefulWidget {
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

  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  @override
  void initState() {
    super.initState();
    // Load matches for ongoing tournaments so live score can be shown
    if (widget.tournament.status == TournamentStatus.ongoing) {
      TournamentService().loadDetail(widget.tournament.id);
    }
  }

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

  /// Frosted-glass pill used for date and fee overlaid on the banner image.
  Widget _glassPill({
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.65), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11,
                  color: iconColor ?? Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 5),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLabel(TournamentFormat f) {
    switch (f) {
      case TournamentFormat.knockout:       return 'Knockout';
      case TournamentFormat.roundRobin:     return 'Round Robin';
      case TournamentFormat.leagueKnockout: return 'League+KO';
      case TournamentFormat.league:         return 'League';
      case TournamentFormat.custom:         return 'Custom';
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

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
    final tournament = widget.tournament;
    final onTap      = widget.onTap;
    final teamBadge  = widget.teamBadge;
    final isHost     = widget.isHost;

    // Live match for ongoing tournaments
    final liveMatch = tournament.status == TournamentStatus.ongoing
        ? TournamentService().matchesFor(tournament.id)
            .where((m) => m.isLive)
            .firstOrNull
        : null;

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
    // Sport emoji for body row
    const sportEmoji = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Chess': '♟️',
    };
    final emoji = sportEmoji[tournament.sport] ?? '🏆';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.09),
            width: 1.0,
          ),
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
            // ── Banner image (date + fee glass pills live inside) ────────
            SizedBox(
              height: 200,
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
                  // Dual gradient: dark at top (pills) + dark at bottom (name)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.60),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black,
                          ],
                          stops: const [0.0, 0.30, 0.60, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // ── Date glass pill (top-left) ──────────────────────────
                  Positioned(
                    top: 10, left: 12,
                    child: _glassPill(
                      icon: Icons.calendar_today_outlined,
                      text: tournament.endDate != null &&
                              tournament.endDate != tournament.startDate
                          ? '${_fmtDate(tournament.startDate)} - ${_fmtDate(tournament.endDate!)}'
                          : _fmtDate(tournament.startDate),
                    ),
                  ),
                  // ── Fee glass pill (top-right) ──────────────────────────
                  Positioned(
                    top: 10, right: 12,
                    child: _glassPill(
                      icon: tournament.entryFee == 0
                          ? Icons.check_circle_outline_rounded
                          : Icons.attach_money_rounded,
                      text: tournament.entryFee == 0
                          ? 'Free'
                          : '${tournament.totalFee.toInt()}/Team',
                      iconColor: tournament.entryFee == 0
                          ? Colors.greenAccent
                          : Colors.white,
                    ),
                  ),
                  // ── LIVE / HOST badge (below fee pill) ─────────────────
                  if (isHost || tournament.status != TournamentStatus.open)
                    Positioned(
                      top: 46, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isHost
                              ? AppColors.primary.withValues(alpha: 0.9)
                              : statusColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isHost ? 'HOST' : statusLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  // ── Tournament name + format (bottom-left) ─────────────
                  Positioned(
                    bottom: 10, left: 12, right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tournament.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                    color: Colors.black,
                                    blurRadius: 6,
                                    offset: Offset(0, 1))
                              ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatLabel(tournament.format),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 4)
                              ]),
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
                  // Sport + teams count row
                  Row(
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 7),
                      Text(tournament.sport,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (tournament.isPrivate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded,
                                  size: 10, color: Colors.white54),
                              SizedBox(width: 3),
                              Text('Private',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.groups_outlined,
                          size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(maxStr,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Location row
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.white38),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(tournament.location,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
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

                  // Full-width Register button
                  if (canReg && teamBadge == null && !isHost) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => EnrollTeamSheet.show(
                          context,
                          tournamentId:   tournament.id,
                          entryFee:       tournament.entryFee,
                          serviceFee:     tournament.serviceFee,
                          playersPerTeam: tournament.playersPerTeam,
                          sport:          tournament.sport,
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryDark, AppColors.primary],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            alignment: Alignment.center,
                            child: const Text('Register',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),     // Container
                        ),       // Ink
                      ),         // TextButton
                    ),           // SizedBox
                  ],
                  // ── Status strip (ongoing skipped — LIVE badge already shown) ──
                  if (tournament.status != TournamentStatus.open &&
                      tournament.status != TournamentStatus.ongoing) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        if (tournament.status == TournamentStatus.ongoing)
                          Container(
                            width: 7, height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 4)],
                            ),
                          ),
                        Text(
                          tournament.status == TournamentStatus.ongoing
                              ? 'Tournament is Live'
                              : tournament.status == TournamentStatus.completed
                                  ? 'Tournament Ended'
                                  : 'Tournament Cancelled',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ],

                  // ── Live match score strip ────────────────────────────
                  if (liveMatch != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            liveMatch.teamAName ?? 'Team A',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${liveMatch.scoreA ?? 0}  –  ${liveMatch.scoreB ?? 0}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            liveMatch.teamBName ?? 'Team B',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ]),
                    ),
                  ],
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
