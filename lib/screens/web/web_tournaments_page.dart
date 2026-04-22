import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/tournament.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../tournaments/enroll_team_sheet.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg = Color(0xFF080808);
const _card = Color(0xFF111111);
const _panel = Color(0xFF0E0E0E);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _orange = Color(0xFFFF9F0A);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

IconData _sportIcon(String sport) {
  const m = {
    'Cricket': Icons.sports_cricket_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Basketball': Icons.sports_basketball_rounded,
    'Badminton': Icons.sports_tennis_rounded,
    'Tennis': Icons.sports_tennis_rounded,
    'Volleyball': Icons.sports_volleyball_rounded,
    'Hockey': Icons.sports_hockey_rounded,
    'Boxing': Icons.sports_mma_rounded,
    'Kabaddi': Icons.sports_kabaddi_rounded,
    'Table Tennis': Icons.sports_tennis_rounded,
    'Rugby': Icons.sports_rugby_rounded,
    'Golf': Icons.sports_golf_rounded,
    'Esports': Icons.sports_esports_rounded,
    'Swimming': Icons.pool_rounded,
    'Athletics': Icons.directions_run_rounded,
  };
  return m[sport] ?? Icons.emoji_events_rounded;
}

Color _sportAccent(String sport) {
  const m = {
    'Cricket': Color(0xFF4CAF50),
    'Football': Color(0xFF66BB6A),
    'Basketball': Color(0xFFFF9800),
    'Badminton': Color(0xFF42A5F5),
    'Tennis': Color(0xFFCDDC39),
    'Volleyball': Color(0xFF7E57C2),
    'Hockey': Color(0xFFFF7043),
    'Boxing': Color(0xFFEF5350),
    'Table Tennis': Color(0xFF26C6DA),
    'Rugby': Color(0xFFFFCA28),
    'Kabaddi': Color(0xFFEC407A),
    'Swimming': Color(0xFF29B6F6),
  };
  return m[sport] ?? _red;
}

String _fmtDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _formatLabel(TournamentFormat format) {
  switch (format) {
    case TournamentFormat.knockout:
      return 'Knockout';
    case TournamentFormat.roundRobin:
      return 'Round Robin';
    case TournamentFormat.leagueKnockout:
      return 'Groups + Knockout';
    case TournamentFormat.league:
      return 'League';
    case TournamentFormat.custom:
      return 'Custom';
  }
}

String _statusLabel(TournamentStatus status) {
  switch (status) {
    case TournamentStatus.open:
      return 'Open';
    case TournamentStatus.ongoing:
      return 'Ongoing';
    case TournamentStatus.completed:
      return 'Completed';
    case TournamentStatus.cancelled:
      return 'Cancelled';
  }
}

Future<void> _openWebTournamentDetail(
  BuildContext context, {
  required String tournamentId,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .62),
    builder: (_) => _WebTournamentDetailDialog(tournamentId: tournamentId),
  );
}

// ── Page ───────────────────────────────────────────────────────────────────────

class WebTournamentsPage extends StatefulWidget {
  const WebTournamentsPage({super.key});

  @override
  State<WebTournamentsPage> createState() => _WebTournamentsPageState();
}

class _WebTournamentsPageState extends State<WebTournamentsPage> {
  int _filterTab = 0; // 0=All 1=Ongoing 2=Upcoming 3=Completed
  String? _sport;

  @override
  void initState() {
    super.initState();
    TournamentService().loadTournaments();
    final uid = UserService().userId ?? '';
    TournamentService().loadMyEnrollments(uid);
  }

  Future<void> _openCreateTournament() async {
    final created = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .62),
      builder: (_) => const _WebCreateTournamentDialog(),
    );
    if (created == true && mounted) {
      await TournamentService().loadTournaments();
    }
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
                    child: Row(
                      children: [
                        Text(
                          'All Tournaments',
                          style: _t(size: 16, weight: FontWeight.w800),
                        ),
                        const Spacer(),
                        _SortPill(),
                      ],
                    ),
                  ),
                ),
                _TournamentGrid(filterTab: _filterTab, sport: _sport),
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
                Text(
                  'Tournaments',
                  style: _t(size: 26, weight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compete. Connect. Win together.',
                  style: _t(size: 14, color: _m1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _RedBtn(
            icon: Icons.add_rounded,
            label: 'Create Tournament',
            onTap: _openCreateTournament,
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
    const tabs = ['All', 'Ongoing', 'Upcoming', 'Completed'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
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
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _red : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        e.value,
                        style: _t(
                          size: 12,
                          weight: FontWeight.w600,
                          color: active ? Colors.white : _m1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
          // Sport filter
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _SportFilterChips(
                selected: _sport,
                onSelect: (s) => setState(() => _sport = s),
              ),
            ),
          ),
        ],
      ),
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
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: .25), const Color(0xFF0A0A0A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Stack(
        children: [
          // Watermark icon
          Positioned(
            right: 30,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: .10,
              child: Center(
                child: Icon(
                  _sportIcon(tournament.sport),
                  color: accent,
                  size: 140,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _red.withValues(alpha: .4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: _red, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'FEATURED',
                        style: _t(
                          size: 10,
                          weight: FontWeight.w800,
                          color: _red,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tournament.name,
                  style: _t(size: 24, weight: FontWeight.w900, height: 1.2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(_sportIcon(tournament.sport), color: accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      tournament.sport,
                      style: _t(
                        size: 13,
                        color: accent,
                        weight: FontWeight.w600,
                      ),
                    ),
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
                    Text(tournament.location, style: _t(size: 13, color: _m1)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _RedBtn(
                      label: 'Register Now',
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EnrollTeamSheet(
                          tournamentId: tournament.id,
                          entryFee: tournament.entryFee,
                          serviceFee: tournament.serviceFee,
                          sport: tournament.sport,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _OutlineBtn(
                      label: 'View Details',
                      onTap: () => _openWebTournamentDetail(
                        context,
                        tournamentId: tournament.id,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
    if (filterTab == 1) {
      list = list.where((t) => t.status == TournamentStatus.ongoing).toList();
    } else if (filterTab == 2) {
      list = list.where((t) => t.status == TournamentStatus.open).toList();
    } else if (filterTab == 3) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, color: _m2, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No tournaments found',
                      style: _t(size: 15, color: _m1, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try a different filter or check back later',
                      style: _t(size: 13, color: _m2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _openWebTournamentDetail(context, tournamentId: t.id),
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
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
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
                    top: Radius.circular(14),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: .18,
                        child: Center(
                          child: Icon(
                            _sportIcon(t.sport),
                            color: accent,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withValues(alpha: .5),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: _t(
                            size: 9,
                            weight: FontWeight.w800,
                            color: statusColor,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(
                          size: 14,
                          weight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(_sportIcon(t.sport), color: accent, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            t.sport,
                            style: _t(
                              size: 11,
                              color: accent,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.format.name,
                              style: _t(size: 10, color: _m1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MetaRow(
                        Icons.people_outline_rounded,
                        '${t.maxTeams} Teams',
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(
                        Icons.calendar_today_outlined,
                        t.endDate != null
                            ? '${_fmtDate(t.startDate)} – ${_fmtDate(t.endDate!)}'
                            : _fmtDate(t.startDate),
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(Icons.location_on_outlined, t.location),
                      const Spacer(),
                      _CardCTA(
                        label: 'View Details  →',
                        onTap: () => _openWebTournamentDetail(
                          context,
                          tournamentId: t.id,
                        ),
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
    return Row(
      children: [
        Icon(icon, size: 12, color: _m2),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: _t(size: 11, color: _m1),
          ),
        ),
      ],
    );
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
      onExit: (_) => setState(() => _hover = false),
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
          child: Text(
            widget.label,
            style: _t(size: 12, weight: FontWeight.w600, color: _m1),
          ),
        ),
      ),
    );
  }
}

// ── Web create tournament dialog ───────────────────────────────────────────────

class _WebCreateTournamentDialog extends StatefulWidget {
  const _WebCreateTournamentDialog();

  @override
  State<_WebCreateTournamentDialog> createState() =>
      _WebCreateTournamentDialogState();
}

class _WebCreateTournamentDialogState
    extends State<_WebCreateTournamentDialog> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _entryFee = TextEditingController();
  final _prize = TextEditingController();
  final _rules = TextEditingController();
  String _sport = 'Cricket';
  TournamentFormat _format = TournamentFormat.leagueKnockout;
  DateTime? _startDate;
  DateTime? _endDate;
  int _maxTeams = 4;
  int _playersPerTeam = 11;
  bool _freeEntry = true;
  bool _private = false;
  bool _saving = false;
  String? _error;

  static const _sports = [
    'Cricket',
    'Football',
    'Basketball',
    'Badminton',
    'Tennis',
    'Volleyball',
    'Hockey',
    'Kabaddi',
    'Boxing',
    'Table Tennis',
    'Throwball',
    'Handball',
  ];

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _entryFee.dispose();
    _prize.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _red,
            surface: Color(0xFF111111),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final location = _location.text.trim();
    if (name.isEmpty || location.isEmpty || _startDate == null) {
      setState(
        () =>
            _error = 'Tournament name, location, and start date are required.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await TournamentService().createTournament(
        name: name,
        sport: _sport,
        format: _format,
        startDate: _startDate!,
        location: location,
        maxTeams: _maxTeams,
        entryFee: _freeEntry
            ? 0
            : (double.tryParse(_entryFee.text.trim()) ?? 0),
        serviceFee: 0,
        scheduleMode: ScheduleMode.auto,
        prizePool: _prize.text.trim().isEmpty ? null : _prize.text.trim(),
        playersPerTeam: _playersPerTeam,
        endDate: _endDate,
        rules: _rules.text.trim().isEmpty ? null : _rules.text.trim(),
        isPrivate: _private,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101010),
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Column(
          children: [
            _DialogHeader(
              icon: Icons.emoji_events_rounded,
              title: 'Create Tournament',
              subtitle: 'Build a tournament for teams on the web dashboard.',
              onClose: _saving ? null : () => Navigator.pop(context, false),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _WebTextField(
                                controller: _name,
                                label: 'Tournament Name',
                                hint: 'Nashville Cricket League',
                                icon: Icons.emoji_events_outlined,
                              ),
                              const SizedBox(height: 14),
                              _WebTextField(
                                controller: _location,
                                label: 'Location',
                                hint: 'Hendersonville, Tennessee',
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PickBox(
                                      label: 'Start Date',
                                      value: _startDate == null
                                          ? 'Select date'
                                          : _fmtDate(_startDate!),
                                      icon: Icons.calendar_today_outlined,
                                      onTap: () => _pickDate(start: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PickBox(
                                      label: 'End Date',
                                      value: _endDate == null
                                          ? 'Optional'
                                          : _fmtDate(_endDate!),
                                      icon: Icons.event_available_outlined,
                                      onTap: () => _pickDate(start: false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 2,
                          child: _CreateSummaryCard(
                            sport: _sport,
                            format: _format,
                            maxTeams: _maxTeams,
                            playersPerTeam: _playersPerTeam,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Sport',
                      style: _t(size: 12, color: _red, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sport in _sports)
                          _ChoicePill(
                            label: sport,
                            icon: _sportIcon(sport),
                            active: _sport == sport,
                            color: _sportAccent(sport),
                            onTap: () => setState(() => _sport = sport),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Tournament Format',
                      style: _t(size: 12, color: _red, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final format in TournamentFormat.values)
                          _ChoicePill(
                            label: _formatLabel(format),
                            icon: Icons.account_tree_outlined,
                            active: _format == format,
                            color: _red,
                            onTap: () => setState(() => _format = format),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberStepper(
                            label: 'Max Teams',
                            value: _maxTeams,
                            min: 2,
                            max: 64,
                            onChanged: (v) => setState(() => _maxTeams = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberStepper(
                            label: 'Players / Team',
                            value: _playersPerTeam,
                            min: 1,
                            max: 30,
                            onChanged: (v) =>
                                setState(() => _playersPerTeam = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleRow(
                            title: 'Free Entry',
                            subtitle: 'No registration fee',
                            value: _freeEntry,
                            onChanged: (v) => setState(() => _freeEntry = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ToggleRow(
                            title: 'Private Tournament',
                            subtitle: 'Invite-only with join code',
                            value: _private,
                            onChanged: (v) => setState(() => _private = v),
                          ),
                        ),
                      ],
                    ),
                    if (!_freeEntry) ...[
                      const SizedBox(height: 14),
                      _WebTextField(
                        controller: _entryFee,
                        label: 'Entry Fee',
                        hint: '25',
                        icon: Icons.attach_money_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _WebTextField(
                      controller: _prize,
                      label: 'Prize Pool',
                      hint: 'Optional prize details',
                      icon: Icons.workspace_premium_outlined,
                    ),
                    const SizedBox(height: 14),
                    _WebTextField(
                      controller: _rules,
                      label: 'Rules',
                      hint: 'Add rules, schedule notes, or eligibility details',
                      icon: Icons.rule_outlined,
                      maxLines: 3,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: _t(size: 12, color: _red)),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border, width: .8)),
              ),
              child: Row(
                children: [
                  Text(
                    'The tournament will appear on the web tournaments page.',
                    style: _t(size: 12, color: _m1),
                  ),
                  const Spacer(),
                  _OutlineBtn(
                    label: 'Cancel',
                    onTap: _saving ? null : () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 10),
                  _RedBtn(
                    label: _saving ? 'Creating...' : 'Create Tournament',
                    icon: Icons.add_rounded,
                    onTap: _saving ? null : _create,
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

// ── Web tournament detail dialog ───────────────────────────────────────────────

class _WebTournamentDetailDialog extends StatefulWidget {
  final String tournamentId;
  const _WebTournamentDetailDialog({required this.tournamentId});

  @override
  State<_WebTournamentDetailDialog> createState() =>
      _WebTournamentDetailDialogState();
}

class _WebTournamentDetailDialogState
    extends State<_WebTournamentDetailDialog> {
  int _tab = 0;
  int _tableTab = 0;

  @override
  void initState() {
    super.initState();
    TournamentService().loadDetail(widget.tournamentId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc = TournamentService();
        final tournament = svc.tournaments
            .where((t) => t.id == widget.tournamentId)
            .cast<Tournament?>()
            .firstOrNull;
        if (tournament == null) {
          return const Dialog(
            backgroundColor: Color(0xFF101010),
            child: SizedBox(
              width: 420,
              height: 220,
              child: Center(child: CircularProgressIndicator(color: _red)),
            ),
          );
        }
        final accent = _sportAccent(tournament.sport);
        final teams = svc.teamsFor(tournament.id);
        final matches = svc.matchesFor(tournament.id);
        final venues = svc.venuesFor(tournament.id);
        final groups = svc.groupsFor(tournament.id);
        final admins = svc.adminsFor(tournament.id);
        final canManage =
            svc.isHost(tournament.id) || svc.isAdmin(tournament.id);
        final isHost = svc.isHost(tournament.id);
        final tabs = [
          'Matches',
          'Table',
          'Stats',
          'Squads',
          'Venues',
          'Forecast',
        ];

        return Dialog(
          backgroundColor: const Color(0xFF101010),
          insetPadding: const EdgeInsets.all(28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: .08)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
            child: Column(
              children: [
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: .28),
                        const Color(0xFF101010),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 42,
                        top: 18,
                        child: Opacity(
                          opacity: .16,
                          child: Icon(
                            _sportIcon(tournament.sport),
                            color: accent,
                            size: 150,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Badge(
                                  label: _formatLabel(tournament.format),
                                  color: _m1,
                                ),
                                const SizedBox(width: 8),
                                _Badge(
                                  label: _statusLabel(tournament.status),
                                  color: accent,
                                ),
                                const Spacer(),
                                if (canManage) ...[
                                  _RedBtn(
                                    label: 'Manage Tournament',
                                    icon: Icons.admin_panel_settings_outlined,
                                    onTap: () =>
                                        setState(() => _tab = tabs.length),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _m1,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              tournament.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(size: 28, weight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 18,
                              runSpacing: 8,
                              children: [
                                _InlineMeta(
                                  icon: _sportIcon(tournament.sport),
                                  text: tournament.sport,
                                  color: accent,
                                ),
                                _InlineMeta(
                                  icon: Icons.location_on_outlined,
                                  text: tournament.location,
                                ),
                                _InlineMeta(
                                  icon: Icons.calendar_today_outlined,
                                  text: tournament.endDate != null
                                      ? '${_fmtDate(tournament.startDate)} - ${_fmtDate(tournament.endDate!)}'
                                      : _fmtDate(tournament.startDate),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _border)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      for (int i = 0; i < tabs.length; i++)
                        _DialogTab(
                          label: tabs[i],
                          active: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                      const Spacer(),
                      if (_tab == tabs.length)
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: _Badge(label: 'Host Portal', color: _red),
                        )
                      else if (!svc.myEnrolledIds.contains(tournament.id))
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: _RedBtn(
                            label: 'Register Team',
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => EnrollTeamSheet(
                                tournamentId: tournament.id,
                                entryFee: tournament.entryFee,
                                serviceFee: tournament.serviceFee,
                                playersPerTeam: tournament.playersPerTeam,
                                sport: tournament.sport,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        _TournamentMatchesPane(matches: matches),
                        _TournamentTablePane(
                          tournament: tournament,
                          teams: teams,
                          matches: matches,
                          tableTab: _tableTab,
                          onTableTabChanged: (value) =>
                              setState(() => _tableTab = value),
                        ),
                        _TournamentStatsPane(
                          tournament: tournament,
                          teams: teams,
                          matches: matches,
                        ),
                        _TournamentSquadsPane(teams: teams),
                        _TournamentVenuesPane(
                          tournament: tournament,
                          venues: venues,
                        ),
                        _TournamentForecastPane(
                          tournament: tournament,
                          matches: matches,
                          venues: venues,
                        ),
                        if (canManage)
                          _TournamentManagePane(
                            tournament: tournament,
                            teams: teams,
                            matches: matches,
                            groups: groups,
                            venues: venues,
                            admins: admins,
                            isHost: isHost,
                            onCloseDialog: () => Navigator.pop(context),
                          )
                        else
                          const _EmptyPane(
                            label:
                                'Management access is only available to hosts and admins.',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _red, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(size: 20, weight: FontWeight.w900)),
                Text(subtitle, style: _t(size: 12, color: _m1)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: _m1),
          ),
        ],
      ),
    );
  }
}

class _WebTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _WebTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: _t(size: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _t(size: 13, color: _m2),
            prefixIcon: Icon(icon, color: _m1, size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: .04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: _red, size: 18),
                  const SizedBox(width: 10),
                  Text(value, style: _t(size: 13, color: _m1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: .14)
                : Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: .48)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? color : _m1, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: _t(
                  size: 13,
                  weight: FontWeight.w700,
                  color: active ? _tx : _m1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateSummaryCard extends StatelessWidget {
  final String sport;
  final TournamentFormat format;
  final int maxTeams;
  final int playersPerTeam;

  const _CreateSummaryCard({
    required this.sport,
    required this.format,
    required this.maxTeams,
    required this.playersPerTeam,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _sportAccent(sport);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .18),
            Colors.white.withValues(alpha: .03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_sportIcon(sport), color: accent, size: 38),
          const SizedBox(height: 14),
          Text(
            'Tournament Setup',
            style: _t(size: 17, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '$sport - ${_formatLabel(format)}',
            style: _t(size: 12, color: _m1),
          ),
          const SizedBox(height: 18),
          _SummaryMetric(label: 'Teams', value: '$maxTeams'),
          _SummaryMetric(label: 'Players / Team', value: '$playersPerTeam'),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: _t(size: 12, color: _m1)),
          const Spacer(),
          Text(value, style: _t(size: 13, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: _t(size: 13, weight: FontWeight.w700)),
          ),
          _SmallIconButton(
            icon: Icons.remove_rounded,
            onTap: value <= min ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: _t(size: 15, weight: FontWeight.w900),
            ),
          ),
          _SmallIconButton(
            icon: Icons.add_rounded,
            onTap: value >= max ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SmallIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: onTap == null ? .02 : .06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: onTap == null ? _m2 : _tx, size: 17),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(size: 13, weight: FontWeight.w800)),
                Text(subtitle, style: _t(size: 11, color: _m1)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: _red, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: Text(
        label,
        style: _t(size: 11, color: color, weight: FontWeight.w800),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InlineMeta({required this.icon, required this.text, this.color = _m1});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(
          text,
          style: _t(size: 13, color: color, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DialogTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DialogTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _red : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: _t(
              size: 13,
              weight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? _tx : _m1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentMatchesPane extends StatelessWidget {
  final List<TournamentMatch> matches;
  const _TournamentMatchesPane({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const _EmptyPane(label: 'No matches scheduled yet');
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = matches[i];
        return _InfoPanel(
          title: 'Match ${i + 1}',
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.teamAName ?? 'Team A',
                    style: _t(size: 14, weight: FontWeight.w800),
                  ),
                ),
                Text(
                  'vs',
                  style: _t(size: 12, color: _m1, weight: FontWeight.w800),
                ),
                Expanded(
                  child: Text(
                    m.teamBName ?? 'Team B',
                    textAlign: TextAlign.end,
                    style: _t(size: 14, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              m.scheduledAt == null
                  ? 'Yet to be scheduled'
                  : '${_fmtDate(m.scheduledAt!)} - ${m.venueName ?? 'Venue TBD'}',
              style: _t(size: 12, color: _m1),
            ),
          ],
        );
      },
    );
  }
}

class _TournamentTablePane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final int tableTab;
  final ValueChanged<int> onTableTabChanged;

  const _TournamentTablePane({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.tableTab,
    required this.onTableTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SubTabBar(
          tabs: const ['Points Table', 'Bracket'],
          selected: tableTab,
          onSelect: onTableTabChanged,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: tableTab == 0
              ? _PointsTable(teams: teams)
              : _TournamentBracketPane(
                  tournament: tournament,
                  matches: matches,
                ),
        ),
      ],
    );
  }
}

class _TournamentStatsPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  const _TournamentStatsPane({
    required this.tournament,
    required this.teams,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    final played = matches.where((m) => m.isPlayed).length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Registered Teams',
                value: '${teams.length}/${tournament.maxTeams}',
                icon: Icons.groups_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Matches Played',
                value: '$played/${matches.length}',
                icon: Icons.sports_score_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Entry',
                value: tournament.entryFee == 0
                    ? 'Free'
                    : '\$${tournament.entryFee.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoPanel(
          title: 'Tournament Details',
          children: [
            _InfoLine(
              'Organizer',
              tournament.createdByName.isEmpty
                  ? 'Unknown'
                  : tournament.createdByName,
            ),
            _InfoLine('Format', _formatLabel(tournament.format)),
            _InfoLine(
              'Players / Team',
              tournament.playersPerTeam == 0
                  ? 'Not specified'
                  : '${tournament.playersPerTeam}',
            ),
            _InfoLine('Privacy', tournament.isPrivate ? 'Private' : 'Public'),
          ],
        ),
      ],
    );
  }
}

class _TournamentSquadsPane extends StatelessWidget {
  final List<TournamentTeam> teams;
  const _TournamentSquadsPane({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const _EmptyPane(label: 'No teams registered yet');
    }
    return ListView.separated(
      itemCount: teams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final team = teams[i];
        return _InfoPanel(
          title: team.teamName,
          children: [
            _InfoLine('Captain', team.captainName),
            _InfoLine('Players', '${team.players.length}'),
            if (team.players.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final player in team.players.take(12))
                    _Badge(label: player, color: _m1),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TournamentVenuesPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentVenue> venues;
  const _TournamentVenuesPane({required this.tournament, required this.venues});

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      return _InfoPanel(
        title: tournament.location,
        children: [
          Text(
            'No venue records have been added yet. Tournament location is ${tournament.location}.',
            style: _t(size: 13, color: _m1),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: venues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final venue = venues[i];
        return _InfoPanel(
          title: venue.name,
          children: [
            _InfoLine(
              'City',
              venue.city.isEmpty ? tournament.location : venue.city,
            ),
            _InfoLine(
              'Address',
              venue.address.isEmpty ? 'Not added' : venue.address,
            ),
            _InfoLine(
              'Capacity',
              venue.capacity == 0 ? 'Not specified' : '${venue.capacity}',
            ),
            _InfoLine('Floodlights', venue.hasFloodlights ? 'Yes' : 'No'),
          ],
        );
      },
    );
  }
}

class _TournamentForecastPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentMatch> matches;
  final List<TournamentVenue> venues;
  const _TournamentForecastPane({
    required this.tournament,
    required this.matches,
    required this.venues,
  });

  @override
  Widget build(BuildContext context) {
    final next = [...matches]
      ..sort(
        (a, b) => (a.scheduledAt ?? DateTime(2100)).compareTo(
          b.scheduledAt ?? DateTime(2100),
        ),
      );
    final nextMatch = next.where((m) => !m.isPlayed).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nextMatch != null)
          _InfoPanel(
            title: 'Next Match',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nextMatch.teamAName ?? 'Team A',
                      style: _t(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'vs',
                    style: _t(size: 13, color: _m1, weight: FontWeight.w900),
                  ),
                  Expanded(
                    child: Text(
                      nextMatch.teamBName ?? 'Team B',
                      textAlign: TextAlign.end,
                      style: _t(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          const _EmptyPane(label: 'No upcoming match available'),
        const SizedBox(height: 14),
        _InfoPanel(
          title: 'Forecast',
          children: [
            Text(
              'Weather integration is not connected yet. Use venue and schedule details to plan the next match.',
              style: _t(size: 13, color: _m1),
            ),
          ],
        ),
      ],
    );
  }
}

class _PointsTable extends StatelessWidget {
  final List<TournamentTeam> teams;
  const _PointsTable({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const _EmptyPane(label: 'No teams in table yet');
    final sorted = [...teams]..sort((a, b) => b.points.compareTo(a.points));
    return _InfoPanel(
      title: 'Points Table',
      children: [
        _TableHeader(),
        for (int i = 0; i < sorted.length; i++)
          _TeamTableRow(index: i + 1, team: sorted[i]),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 34),
          Expanded(
            child: Text(
              'TEAM',
              style: _t(size: 11, color: _m1, weight: FontWeight.w800),
            ),
          ),
          for (final label in ['M', 'W', 'L', 'D', 'PTS'])
            SizedBox(
              width: 46,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: _t(
                  size: 11,
                  color: label == 'PTS' ? _red : _m1,
                  weight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamTableRow extends StatelessWidget {
  final int index;
  final TournamentTeam team;
  const _TeamTableRow({required this.index, required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('$index', style: _t(size: 12, color: _m1)),
          ),
          Expanded(
            child: Text(
              team.teamName,
              style: _t(size: 13, weight: FontWeight.w700),
            ),
          ),
          for (final value in [
            team.played,
            team.wins,
            team.losses,
            team.draws,
            team.points,
          ])
            SizedBox(
              width: 46,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: _t(
                  size: 12,
                  color: value == team.points ? _red : _m1,
                  weight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TournamentBracketPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentMatch> matches;
  const _TournamentBracketPane({
    required this.tournament,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return _InfoPanel(
        title: 'Bracket',
        children: [
          Text(
            'No bracket has been generated yet. Hosts can generate schedule from Manage Tournament.',
            style: _t(size: 13, color: _m1),
          ),
        ],
      );
    }
    final byRound = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }
    final rounds = byRound.keys.toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final round in rounds)
            Container(
              width: 260,
              margin: const EdgeInsets.only(right: 14),
              child: _InfoPanel(
                title: 'Round $round',
                children: [
                  for (final match in byRound[round]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${match.teamAName ?? 'TBD'}  vs  ${match.teamBName ?? 'TBD'}',
                        style: _t(size: 12, color: _m1),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TournamentManagePane extends StatefulWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final List<TournamentGroup> groups;
  final List<TournamentVenue> venues;
  final List<TournamentAdmin> admins;
  final bool isHost;
  final VoidCallback onCloseDialog;

  const _TournamentManagePane({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.groups,
    required this.venues,
    required this.admins,
    required this.isHost,
    required this.onCloseDialog,
  });

  @override
  State<_TournamentManagePane> createState() => _TournamentManagePaneState();
}

class _TournamentManagePaneState extends State<_TournamentManagePane> {
  bool _busy = false;

  Future<void> _confirm({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() run,
    bool closesDialog = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(title, style: _t(size: 17, weight: FontWeight.w900)),
        content: Text(message, style: _t(size: 13, color: _m1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: _t(size: 13, color: _m1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action,
              style: _t(size: 13, color: _red, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await run();
      if (closesDialog && mounted) widget.onCloseDialog();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTournament() => _confirm(
    title: 'Start Tournament?',
    message: 'This marks the tournament as ongoing.',
    action: 'Start',
    run: () => TournamentService().updateTournamentStatus(
      widget.tournament.id,
      TournamentStatus.ongoing,
    ),
  );

  Future<void> _generateSchedule() => _confirm(
    title: 'Generate Schedule?',
    message: 'This will generate tournament matches based on registered teams.',
    action: 'Generate',
    run: () => TournamentService().generateSchedule(widget.tournament.id),
  );

  Future<void> _resetTeams() => _confirm(
    title: 'Reset Teams & Matches?',
    message:
        'Deletes all registered teams, matches, and points. This cannot be undone.',
    action: 'Reset',
    run: () => TournamentService().clearTeamsAndMatches(widget.tournament.id),
  );

  Future<void> _deleteTournament() => _confirm(
    title: 'Delete Tournament?',
    message:
        'Permanently deletes this tournament and all its data. This cannot be undone.',
    action: 'Delete',
    closesDialog: true,
    run: () => TournamentService().deleteTournament(widget.tournament.id),
  );

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(widget.tournament.status).toUpperCase();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoPanel(
            title: 'Tournament Status',
            children: [
              Row(
                children: [
                  Text('Status:', style: _t(size: 13, color: _m1)),
                  const SizedBox(width: 8),
                  _Badge(
                    label: status,
                    color: _sportAccent(widget.tournament.sport),
                  ),
                  const Spacer(),
                  if (widget.tournament.status == TournamentStatus.open)
                    _OutlineBtn(
                      label: 'Starts today',
                      icon: Icons.event_available_outlined,
                      onTap: _busy ? null : _startTournament,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Tournament has ${widget.teams.length} teams registered and ${widget.matches.length} matches scheduled.',
                style: _t(size: 13, color: _m1),
              ),
              const SizedBox(height: 12),
              _RedBtn(
                label: _busy ? 'Working...' : 'Start Tournament',
                onTap: _busy ? null : _startTournament,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoPanel(
            title: 'Join Code',
            children: [
              Row(
                children: [
                  Icon(Icons.key_rounded, color: _m1, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    widget.tournament.joinCode ?? 'Public tournament',
                    style: _t(size: 18, weight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Manage',
            style: _t(size: 12, color: _m1, weight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 132,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: [
              _ManageActionCard(
                title: 'Edit Tournament',
                subtitle: 'Update basic tournament details',
                icon: Icons.edit_outlined,
                color: Colors.blue,
                onTap: () {},
              ),
              _ManageActionCard(
                title: 'Manage Teams',
                subtitle: '${widget.teams.length} registered teams',
                icon: Icons.groups_outlined,
                color: _red,
                badge: '${widget.teams.length}',
                onTap: () {},
              ),
              _ManageActionCard(
                title: 'Groups',
                subtitle: '${widget.groups.length} groups',
                icon: Icons.account_tree_outlined,
                color: Colors.deepPurple,
                onTap: () {},
              ),
              _ManageActionCard(
                title: 'Schedule Matches',
                subtitle: '${widget.matches.length} matches',
                icon: Icons.calendar_month_outlined,
                color: Colors.indigo,
                onTap: _busy ? null : _generateSchedule,
              ),
              _ManageActionCard(
                title: 'Squads',
                subtitle: 'Review team rosters',
                icon: Icons.badge_outlined,
                color: Colors.purple,
                onTap: () {},
              ),
              _ManageActionCard(
                title: 'Venues',
                subtitle: '${widget.venues.length} venues',
                icon: Icons.stadium_outlined,
                color: Colors.teal,
                onTap: () {},
              ),
              _ManageActionCard(
                title: 'Admins',
                subtitle: '${widget.admins.length} admins',
                icon: Icons.admin_panel_settings_outlined,
                color: Colors.deepOrange,
                onTap: () {},
              ),
              _ManageActionCard(
                title: 'Enter Results',
                subtitle: 'Update match scores',
                icon: Icons.scoreboard_outlined,
                color: Colors.green,
                onTap: () {},
              ),
            ],
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 18),
            Text(
              'Danger Zone',
              style: _t(size: 12, color: _m1, weight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _DangerAction(
              title: 'Reset Teams & Matches',
              subtitle:
                  'Deletes all registered teams, matches and points. Cannot be undone.',
              icon: Icons.cleaning_services_outlined,
              onTap: _busy ? null : _resetTeams,
            ),
            const SizedBox(height: 10),
            _DangerAction(
              title: 'Delete Tournament',
              subtitle:
                  'Permanently deletes this tournament and all its data. Cannot be undone.',
              icon: Icons.delete_forever_outlined,
              onTap: _busy ? null : _deleteTournament,
            ),
          ],
        ],
      ),
    );
  }
}

class _SubTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _SubTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == i ? _red : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: _t(
                      size: 12,
                      color: selected == i ? _tx : _m1,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManageActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _ManageActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .28)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Badge(label: badge!, color: color),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(size: 14, weight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: _t(size: 12, color: _m1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _DangerAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _red, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _t(size: 14, color: _red, weight: FontWeight.w900),
                    ),
                    Text(subtitle, style: _t(size: 12, color: _m1)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _red),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _red, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: _t(size: 19, weight: FontWeight.w900)),
              Text(label, style: _t(size: 11, color: _m1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _t(size: 14, weight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: _t(size: 12, color: _m1)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: _t(size: 12, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  final String label;
  const _EmptyPane({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: _t(size: 14, color: _m1, weight: FontWeight.w700),
      ),
    );
  }
}

// ── Sport filter chips ─────────────────────────────────────────────────────────

class _SportFilterChips extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _SportFilterChips({required this.selected, required this.onSelect});

  @override
  State<_SportFilterChips> createState() => _SportFilterChipsState();
}

class _SportFilterChipsState extends State<_SportFilterChips> {
  final _query = TextEditingController();
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  bool _open = false;

  static const _quickSports = [
    'Cricket',
    'Football',
    'Basketball',
    'Badminton',
    'Tennis',
  ];

  static const _allSports = [
    'Cricket',
    'Football',
    'Basketball',
    'Badminton',
    'Tennis',
    'Volleyball',
    'Hockey',
    'Kabaddi',
    'Boxing',
    'Table Tennis',
    'Throwball',
    'Handball',
    'Swimming',
    'Rugby',
    'Golf',
    'Athletics',
    'Cycling',
    'Archery',
    'Squash',
    'Esports',
  ];

  @override
  void dispose() {
    _overlayController.hide();
    _query.dispose();
    super.dispose();
  }

  List<String> get _filteredSports {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _allSports;
    return _allSports.where((s) => s.toLowerCase().contains(q)).toList();
  }

  void _select(String? sport) {
    widget.onSelect(sport);
    _closeDropdown();
  }

  void _toggleDropdown() {
    setState(() => _open = !_open);
    if (_open) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  void _closeDropdown() {
    _overlayController.hide();
    setState(() {
      _open = false;
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final dropdownActive = selected == null || !_quickSports.contains(selected);
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final panelWidth = screenWidth < 520 ? screenWidth - 32 : 360.0;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Material(
                type: MaterialType.transparency,
                child: _AllSportsFilterPanel(
                  width: panelWidth,
                  query: _query,
                  sports: _filteredSports,
                  selected: selected,
                  onSearchChanged: (_) => setState(() {}),
                  onSelect: _select,
                ),
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AllSportsFilterButton(
              label: dropdownActive && selected != null
                  ? selected
                  : 'All Sports',
              active: dropdownActive,
              open: _open,
              onTap: _toggleDropdown,
            ),
            for (final s in _quickSports)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _Chip(
                  label: s,
                  active: selected == s,
                  onTap: () => _select(s),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllSportsFilterButton extends StatefulWidget {
  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  const _AllSportsFilterButton({
    required this.label,
    required this.active,
    required this.open,
    required this.onTap,
  });

  @override
  State<_AllSportsFilterButton> createState() => _AllSportsFilterButtonState();
}

class _AllSportsFilterButtonState extends State<_AllSportsFilterButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.active
                ? _red.withValues(alpha: .15)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: widget.open
                  ? _red.withValues(alpha: .8)
                  : widget.active
                  ? _red.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: widget.active ? _red : _m1,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: _t(
                  size: 12,
                  weight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  color: widget.active ? _red : _m1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                widget.open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: widget.active ? _red : _m1,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSportsFilterPanel extends StatelessWidget {
  final double width;
  final TextEditingController query;
  final List<String> sports;
  final String? selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onSelect;

  const _AllSportsFilterPanel({
    required this.width,
    required this.query,
    required this.sports,
    required this.selected,
    required this.onSearchChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .42),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: query,
              autofocus: true,
              onChanged: onSearchChanged,
              style: _t(size: 13),
              decoration: InputDecoration(
                hintText: 'Search sport...',
                hintStyle: _t(size: 13, color: _m1),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _m1,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _red),
                ),
                isDense: true,
              ),
            ),
          ),
          Container(height: .8, color: _border),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  _AllSportsFilterTile(
                    icon: Icons.grid_view_rounded,
                    label: 'All Sports',
                    color: _red,
                    selected: selected == null,
                    onTap: () => onSelect(null),
                  ),
                  for (final sport in sports)
                    _AllSportsFilterTile(
                      icon: _sportIcon(sport),
                      label: sport,
                      color: _sportAccent(sport),
                      selected: selected == sport,
                      onTap: () => onSelect(sport),
                    ),
                  if (sports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No sports found',
                        style: _t(size: 13, color: _m1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllSportsFilterTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AllSportsFilterTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AllSportsFilterTile> createState() => _AllSportsFilterTileState();
}

class _AllSportsFilterTileState extends State<_AllSportsFilterTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? _red.withValues(alpha: .15)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.selected ? _red : _m1, size: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    size: 13,
                    weight: FontWeight.w700,
                    color: widget.selected ? _tx : (_hover ? _tx : _m1),
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check_rounded, color: _red, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

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
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            Text(
              'Tournament Spotlight',
              style: _t(size: 15, weight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _BracketPreview(),
            const SizedBox(height: 24),
            Text(
              'Tournament Highlights',
              style: _t(size: 15, weight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _HighlightStats(),
            const SizedBox(height: 24),
            Text(
              'Popular Sports',
              style: _t(size: 15, weight: FontWeight.w800),
            ),
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
            child: Text(
              'No featured tournament',
              style: _t(size: 13, color: _m1),
            ),
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
          child: Column(
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: .25), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(_sportIcon(t.sport), color: accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              size: 13,
                              weight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          Text(t.format.name, style: _t(size: 11, color: _m1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () =>
                        _openWebTournamentDetail(context, tournamentId: t.id),
                    child: Container(
                      height: 36,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'View Full Bracket',
                        style: _t(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        final active = all
            .where((t) => t.status == TournamentStatus.ongoing)
            .length;
        final total = all.length;
        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _StatRow(
                Icons.emoji_events_rounded,
                'Active Tournaments',
                '$active',
                _red,
              ),
              Container(height: .8, color: _border),
              _StatRow(
                Icons.people_outline_rounded,
                'Total Tournaments',
                '$total',
                _orange,
              ),
            ],
          ),
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
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: _t(size: 13, color: _m1)),
          ),
          Text(
            value,
            style: _t(size: 16, weight: FontWeight.w800, color: _tx),
          ),
        ],
      ),
    );
  }
}

class _PopularSports extends StatelessWidget {
  static const _sports = [
    ('Football', Icons.sports_soccer_rounded),
    ('Cricket', Icons.sports_cricket_rounded),
    ('Basketball', Icons.sports_basketball_rounded),
    ('Badminton', Icons.sports_tennis_rounded),
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
          final (sport, icon) = e.value;
          return Column(
            children: [
              if (e.key > 0) Container(height: .8, color: _border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: _red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sport,
                        style: _t(size: 13, weight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _m2, size: 18),
                  ],
                ),
              ),
            ],
          );
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort by: Start Date', style: _t(size: 12, color: _m1)),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 16),
        ],
      ),
    );
  }
}

// ── Shared button components ───────────────────────────────────────────────────

class _RedBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _RedBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_RedBtn> createState() => _RedBtnState();
}

class _RedBtnState extends State<_RedBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: _t(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: _m1, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: _t(size: 13, weight: FontWeight.w600, color: _tx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
