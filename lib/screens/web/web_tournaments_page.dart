import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/tournament.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../tournaments/enroll_team_sheet.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg     = Color(0xFF080808);
const _card   = Color(0xFF111111);
const _panel  = Color(0xFF0E0E0E);
const _tx     = Color(0xFFF2F2F2);
const _m1     = Color(0xFF888888);
const _m2     = Color(0xFF3A3A3A);
const _red    = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _orange = Color(0xFFFF9F0A);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

String _emojiFor(String sport) {
  const m = {
    'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
    'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
    'Hockey': '🏑', 'Boxing': '🥊', 'Kabaddi': '🤼',
    'Table Tennis': '🏓', 'Rugby': '🏉', 'Golf': '⛳',
    'Esports': '🎮', 'Swimming': '🏊', 'Athletics': '🏃',
  };
  return m[sport] ?? '🏅';
}

Color _sportAccent(String sport) {
  const m = {
    'Cricket': Color(0xFF4CAF50), 'Football': Color(0xFF66BB6A),
    'Basketball': Color(0xFFFF9800), 'Badminton': Color(0xFF42A5F5),
    'Tennis': Color(0xFFCDDC39), 'Volleyball': Color(0xFF7E57C2),
    'Hockey': Color(0xFFFF7043), 'Boxing': Color(0xFFEF5350),
    'Table Tennis': Color(0xFF26C6DA), 'Rugby': Color(0xFFFFCA28),
    'Kabaddi': Color(0xFFEC407A), 'Swimming': Color(0xFF29B6F6),
  };
  return m[sport] ?? _red;
}

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

// ── Page ───────────────────────────────────────────────────────────────────────

class WebTournamentsPage extends StatefulWidget {
  const WebTournamentsPage({super.key});

  @override
  State<WebTournamentsPage> createState() => _WebTournamentsPageState();
}

class _WebTournamentsPageState extends State<WebTournamentsPage> {
  int _filterTab = 0; // 0=Ongoing 1=Upcoming 2=Completed 3=All
  String? _sport;

  @override
  void initState() {
    super.initState();
    TournamentService().loadTournaments();
    final uid = UserService().userId ?? '';
    TournamentService().loadMyEnrollments(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildFilterRow()),
                SliverToBoxAdapter(child: _buildFeaturedBanner()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Row(children: [
                      Text('All Tournaments',
                          style: _t(size: 16, weight: FontWeight.w800)),
                      const Spacer(),
                      _SortPill(),
                    ]),
                  ),
                ),
                _TournamentGrid(
                    filterTab: _filterTab, sport: _sport),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
          // ── Right stats panel ─────────────────────────────────────────────
          _RightStatsPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tournaments',
                    style: _t(size: 26, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Compete. Connect. Win together.',
                    style: _t(size: 14, color: _m1)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _RedBtn(
            icon: Icons.add_rounded,
            label: '+ Create Tournament',
            onTap: () {},
          ),
          const SizedBox(width: 10),
          _OutlineBtn(
            icon: Icons.group_add_outlined,
            label: 'Join Tournament',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const tabs = ['Ongoing', 'Upcoming', 'Completed', 'All'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(children: [
        // Filter tabs
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: tabs.asMap().entries.map((e) {
              final active = e.key == _filterTab;
              return GestureDetector(
                onTap: () => setState(() => _filterTab = e.key),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? _red : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(e.value,
                        style: _t(
                          size: 12,
                          weight: FontWeight.w600,
                          color: active ? Colors.white : _m1,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        // Sport filter
        _SportFilterChips(
          selected: _sport,
          onSelect: (s) => setState(() => _sport = s),
        ),
      ]),
    );
  }

  Widget _buildFeaturedBanner() {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final tours = TournamentService().tournaments;
        if (tours.isEmpty) return const SizedBox(height: 20);
        final featured = tours.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: _FeaturedBanner(tournament: featured),
        );
      },
    );
  }
}

// ── Featured banner ────────────────────────────────────────────────────────────

class _FeaturedBanner extends StatelessWidget {
  final Tournament tournament;
  const _FeaturedBanner({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final accent = _sportAccent(tournament.sport);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .25),
            const Color(0xFF0A0A0A),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Stack(children: [
        // Watermark emoji
        Positioned(
          right: 30, top: 0, bottom: 0,
          child: Opacity(
            opacity: .10,
            child: Center(
              child: Text(_emojiFor(tournament.sport),
                  style: const TextStyle(fontSize: 140)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _red.withValues(alpha: .4)),
                ),
                child: Text('⭐  FEATURED',
                    style: _t(size: 10, weight: FontWeight.w800,
                        color: _red, height: 1)),
              ),
              const SizedBox(height: 12),
              Text(tournament.name,
                  style: _t(size: 24, weight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 8),
              Row(children: [
                Text(_emojiFor(tournament.sport),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(tournament.sport,
                    style: _t(size: 13, color: accent,
                        weight: FontWeight.w600)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today_outlined, size: 13, color: _m1),
                const SizedBox(width: 5),
                Text(
                  tournament.endDate != null
                      ? '${_fmtDate(tournament.startDate)} – ${_fmtDate(tournament.endDate!)}'
                      : _fmtDate(tournament.startDate),
                  style: _t(size: 13, color: _m1),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on_outlined, size: 13, color: _m1),
                const SizedBox(width: 5),
                Text(tournament.location,
                    style: _t(size: 13, color: _m1)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                _RedBtn(
                  label: 'Register Now',
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => EnrollTeamSheet(
                      tournamentId: tournament.id,
                      entryFee:     tournament.entryFee,
                      serviceFee:   tournament.serviceFee,
                      sport:        tournament.sport,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _OutlineBtn(
                  label: 'View Details',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => TournamentDetailScreen(
                              tournamentId: tournament.id))),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Tournament grid ────────────────────────────────────────────────────────────

class _TournamentGrid extends StatelessWidget {
  final int filterTab;
  final String? sport;
  const _TournamentGrid({required this.filterTab, required this.sport});

  List<Tournament> _filter(List<Tournament> all) {
    var list = all;
    if (filterTab == 0) {
      list = list.where((t) => t.status == TournamentStatus.ongoing).toList();
    } else if (filterTab == 1) {
      list = list.where((t) => t.status == TournamentStatus.open).toList();
    } else if (filterTab == 2) {
      list = list.where((t) => t.status == TournamentStatus.completed).toList();
    }
    if (sport != null) {
      list = list.where((t) => t.sport == sport).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final items = _filter(TournamentService().tournaments);
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events_outlined, color: _m2, size: 48),
                  const SizedBox(height: 12),
                  Text('No tournaments found',
                      style: _t(size: 15, color: _m1,
                          weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Try a different filter or check back later',
                      style: _t(size: 13, color: _m2)),
                ]),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: .85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _TournamentCard(tournament: items[i]),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

class _TournamentCard extends StatefulWidget {
  final Tournament tournament;
  const _TournamentCard({required this.tournament});

  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final accent = _sportAccent(t.sport);
    final statusLabel = t.status == TournamentStatus.ongoing
        ? 'ONGOING'
        : t.status == TournamentStatus.open
            ? 'UPCOMING'
            : 'COMPLETED';
    final statusColor = t.status == TournamentStatus.ongoing
        ? _red
        : t.status == TournamentStatus.open
            ? _orange
            : _m1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) =>
                    TournamentDetailScreen(tournamentId: t.id))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .06),
            ),
            boxShadow: _hover
                ? [BoxShadow(
                    color: accent.withValues(alpha: .12),
                    blurRadius: 20,
                    offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sport header
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: .3),
                      accent.withValues(alpha: .05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                ),
                child: Stack(children: [
                  Positioned(
                    right: 12, top: 0, bottom: 0,
                    child: Opacity(
                      opacity: .18,
                      child: Center(
                        child: Text(_emojiFor(t.sport),
                            style: const TextStyle(fontSize: 64)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: statusColor.withValues(alpha: .5)),
                      ),
                      child: Text(statusLabel,
                          style: _t(
                            size: 9,
                            weight: FontWeight.w800,
                            color: statusColor,
                            height: 1,
                          )),
                    ),
                  ),
                ]),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 14, weight: FontWeight.w800,
                              height: 1.2)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(_emojiFor(t.sport),
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(t.sport,
                            style: _t(size: 11, color: accent,
                                weight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.format.name,
                            style: _t(size: 10, color: _m1),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      _MetaRow(Icons.people_outline_rounded,
                          '${t.maxTeams} Teams'),
                      const SizedBox(height: 4),
                      _MetaRow(Icons.calendar_today_outlined,
                          t.endDate != null
                              ? '${_fmtDate(t.startDate)} – ${_fmtDate(t.endDate!)}'
                              : _fmtDate(t.startDate)),
                      const SizedBox(height: 4),
                      _MetaRow(Icons.location_on_outlined, t.location),
                      const Spacer(),
                      _CardCTA(
                        label: 'View Details  →',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => TournamentDetailScreen(
                                    tournamentId: t.id))),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 12, color: _m2),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: _t(size: 11, color: _m1)),
      ),
    ]);
  }
}

class _CardCTA extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CardCTA({required this.label, required this.onTap});

  @override
  State<_CardCTA> createState() => _CardCTAState();
}

class _CardCTAState extends State<_CardCTA> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .06)
                : Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: Text(widget.label,
              style: _t(size: 12, weight: FontWeight.w600, color: _m1)),
        ),
      ),
    );
  }
}

// ── Sport filter chips ─────────────────────────────────────────────────────────

class _SportFilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _SportFilterChips(
      {required this.selected, required this.onSelect});

  static const _sports = [
    'Cricket', 'Football', 'Basketball', 'Badminton', 'Tennis',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Chip(
          label: 'All Sports',
          active: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final s in _sports)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _Chip(
              label: s,
              active: selected == s,
              onTap: () => onSelect(s),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.active, required this.onTap});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active
                ? _red.withValues(alpha: .15)
                : (_hover
                    ? Colors.white.withValues(alpha: .05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: widget.active
                  ? _red.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Text(
            widget.label,
            style: _t(
              size: 12,
              weight: widget.active ? FontWeight.w700 : FontWeight.w500,
              color: widget.active ? _red : _m1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right stats panel ──────────────────────────────────────────────────────────

class _RightStatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _border, width: .8)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tournament Spotlight',
                style: _t(size: 15, weight: FontWeight.w800)),
            const SizedBox(height: 16),
            _BracketPreview(),
            const SizedBox(height: 24),
            Text('Tournament Highlights',
                style: _t(size: 15, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            _HighlightStats(),
            const SizedBox(height: 24),
            Text('Popular Sports',
                style: _t(size: 15, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            _PopularSports(),
          ],
        ),
      ),
    );
  }
}

class _BracketPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final tours = TournamentService().tournaments;
        if (tours.isEmpty) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: Text('No featured tournament',
                style: _t(size: 13, color: _m1)),
          );
        }
        final t = tours.first;
        final accent = _sportAccent(t.sport);
        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: .25),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Text(_emojiFor(t.sport),
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 13, weight: FontWeight.w800,
                              height: 1.2)),
                      Text(t.format.name,
                          style: _t(size: 11, color: _m1)),
                    ],
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => TournamentDetailScreen(
                              tournamentId: t.id))),
                  child: Container(
                    height: 36,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('View Full Bracket',
                        style: _t(size: 12, weight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _HighlightStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final all = TournamentService().tournaments;
        final active = all.where((t) => t.status == TournamentStatus.ongoing).length;
        final total = all.length;
        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            _StatRow(Icons.emoji_events_rounded, 'Active Tournaments',
                '$active', _red),
            Container(height: .8, color: _border),
            _StatRow(Icons.people_outline_rounded, 'Total Tournaments',
                '$total', _orange),
          ]),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: _t(size: 13, color: _m1))),
        Text(value,
            style: _t(size: 16, weight: FontWeight.w800, color: _tx)),
      ]),
    );
  }
}

class _PopularSports extends StatelessWidget {
  static const _sports = [
    ('Football', '⚽'), ('Cricket', '🏏'),
    ('Basketball', '🏀'), ('Badminton', '🏸'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: _sports.asMap().entries.map((e) {
          final (sport, emoji) = e.value;
          return Column(children: [
            if (e.key > 0)
              Container(height: .8, color: _border),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(sport,
                        style: _t(size: 13, weight: FontWeight.w600))),
                Icon(Icons.chevron_right_rounded, color: _m2, size: 18),
              ]),
            ),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Sort pill ──────────────────────────────────────────────────────────────────

class _SortPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Sort by: Start Date',
            style: _t(size: 12, color: _m1)),
        const SizedBox(width: 6),
        Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 16),
      ]),
    );
  }
}

// ── Shared button components ───────────────────────────────────────────────────

class _RedBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _RedBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_RedBtn> createState() => _RedBtnState();
}

class _RedBtnState extends State<_RedBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _hover ? .4 : .2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
            ],
            Text(widget.label,
                style: _t(size: 13, weight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .06)
                : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: _m1, size: 15),
              const SizedBox(width: 6),
            ],
            Text(widget.label,
                style: _t(size: 13, weight: FontWeight.w600, color: _tx)),
          ]),
        ),
      ),
    );
  }
}
