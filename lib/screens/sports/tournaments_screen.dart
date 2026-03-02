import 'package:flutter/material.dart';
import '../../design/colors.dart';
import 'register_league_screen.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  String _selectedSport = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _sports = [
    'All', 'Cricket', 'Football', 'Basketball',
    'Badminton', 'Tennis', 'Volleyball',
  ];

  static const _tournaments = [
    _Tournament(
      name: 'City Cricket Championship',
      sport: 'Cricket',
      emoji: '🏏',
      location: 'DY Patil Stadium, Mumbai',
      date: 'Mar 15 – Apr 5, 2026',
      teams: 16,
      prize: '₹50,000',
      status: TStatus.open,
      color: Color(0xFFD32F2F),
      format: 'T20',
    ),
    _Tournament(
      name: 'State Football League',
      sport: 'Football',
      emoji: '⚽',
      location: 'Fatorda Stadium, Goa',
      date: 'Mar 20 – Apr 10, 2026',
      teams: 12,
      prize: '₹1,00,000',
      status: TStatus.open,
      color: Color(0xFF1976D2),
      format: '11-a-side',
    ),
    _Tournament(
      name: 'Hyderabad Basketball Open',
      sport: 'Basketball',
      emoji: '🏀',
      location: 'Gachibowli Indoor, HYD',
      date: 'Apr 1 – Apr 3, 2026',
      teams: 8,
      prize: '₹25,000',
      status: TStatus.open,
      color: Color(0xFFE65100),
      format: '5-on-5',
    ),
    _Tournament(
      name: 'National Badminton Series',
      sport: 'Badminton',
      emoji: '🏸',
      location: 'Siri Fort Sports Complex, Delhi',
      date: 'Apr 12 – Apr 14, 2026',
      teams: 0,
      prize: '₹75,000',
      status: TStatus.upcoming,
      color: Color(0xFF388E3C),
      format: 'Singles & Doubles',
    ),
    _Tournament(
      name: 'Summer Tennis Cup',
      sport: 'Tennis',
      emoji: '🎾',
      location: 'DLTA Complex, New Delhi',
      date: 'May 5 – May 8, 2026',
      teams: 0,
      prize: '₹30,000',
      status: TStatus.upcoming,
      color: Color(0xFF6A1B9A),
      format: 'Singles',
    ),
    _Tournament(
      name: 'Beach Volleyball Classic',
      sport: 'Volleyball',
      emoji: '🏐',
      location: 'Juhu Beach, Mumbai',
      date: 'Apr 28 – Apr 29, 2026',
      teams: 10,
      prize: '₹20,000',
      status: TStatus.open,
      color: Color(0xFF00838F),
      format: '2v2 Beach',
    ),
    _Tournament(
      name: 'Pro Cricket Invitational',
      sport: 'Cricket',
      emoji: '🏏',
      location: 'Eden Gardens, Kolkata',
      date: 'Feb 10 – Feb 28, 2026',
      teams: 8,
      prize: '₹2,00,000',
      status: TStatus.ongoing,
      color: Color(0xFFD32F2F),
      format: 'ODI',
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Tournament> get _filtered {
    return _tournaments.where((t) {
      final matchSport = _selectedSport == 'All' || t.sport == _selectedSport;
      final matchSearch = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.location.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchSport && matchSearch;
    }).toList();
  }

  void _register(_Tournament t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterLeagueScreen(
          tournamentName: t.name,
          sport: t.sport,
          format: t.format,
          date: t.date,
          location: t.location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.background : AppColorsLight.background;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final textCol = isDark ? Colors.white : const Color(0xFF111827);
    final subCol  = isDark ? Colors.white54 : Colors.black54;
    final cardBg  = isDark ? const Color(0xFF111111) : Colors.white;

    final filtered = _filtered;
    final featured = filtered.isNotEmpty ? filtered.first : null;
    final rest = filtered.length > 1 ? filtered.sublist(1) : <_Tournament>[];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Title bar ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tournaments',
                        style: TextStyle(
                          color: textCol,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record,
                              color: primary, size: 8),
                          const SizedBox(width: 4),
                          Text(
                            '${_tournaments.where((t) => t.status == TStatus.ongoing).length} Live',
                            style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Search bar ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search, color: subCol, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                          style: TextStyle(color: textCol, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search tournaments…',
                            hintStyle:
                                TextStyle(color: subCol, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child:
                                Icon(Icons.close, color: subCol, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sport filter chips ─────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  itemCount: _sports.length,
                  itemBuilder: (_, i) {
                    final sport = _sports[i];
                    final selected = _selectedSport == sport;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedSport = sport),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? primary
                              : (isDark
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? primary
                                : (isDark
                                    ? Colors.white12
                                    : Colors.black12),
                          ),
                        ),
                        child: Text(
                          sport,
                          style: TextStyle(
                            color:
                                selected ? Colors.white : subCol,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Featured tournament ────────────────────────────────────
            if (featured != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _FeaturedCard(
                    tournament: featured,
                    onRegister: () => _register(featured),
                  ),
                ),
              ),

            // ── Section label ──────────────────────────────────────────
            if (rest.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Text(
                    'All Tournaments',
                    style: TextStyle(
                      color: textCol,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // ── Tournament list ────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final t = rest[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _TournamentCard(
                      tournament: t,
                      isDark: isDark,
                      primary: primary,
                      textCol: textCol,
                      subCol: subCol,
                      cardBg: cardBg,
                      onRegister: () => _register(t),
                    ),
                  );
                },
                childCount: rest.length,
              ),
            ),

            // ── Empty state ────────────────────────────────────────────
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_outlined,
                          color: subCol, size: 48),
                      const SizedBox(height: 12),
                      Text('No tournaments found',
                          style:
                              TextStyle(color: subCol, fontSize: 15)),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ── Featured card ─────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final _Tournament tournament;
  final VoidCallback onRegister;
  const _FeaturedCard(
      {required this.tournament, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.color, t.color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Text(t.emoji,
                style: const TextStyle(fontSize: 110),
                textScaler: TextScaler.noScaling),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(status: t.status),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t.format,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('⭐ Featured',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  t.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 ${t.location}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.date,
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11)),
                          if (t.prize.isNotEmpty)
                            Text('🏆 Prize: ${t.prize}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (t.status == TStatus.open)
                      GestureDetector(
                        onTap: onRegister,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Register',
                            style: TextStyle(
                              color: t.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

// ── Tournament card ───────────────────────────────────────────────────────────

class _TournamentCard extends StatelessWidget {
  final _Tournament tournament;
  final bool isDark;
  final Color primary, textCol, subCol, cardBg;
  final VoidCallback onRegister;
  const _TournamentCard({
    required this.tournament,
    required this.isDark,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black12,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: t.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(t.emoji,
                  style: const TextStyle(fontSize: 26),
                  textScaler: TextScaler.noScaling),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        style: TextStyle(
                          color: textCol,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: t.status, small: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text('📍 ${t.location}',
                    style: TextStyle(color: subCol, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('🗓 ${t.date}',
                    style: TextStyle(color: subCol, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (t.teams > 0) ...[
                      Icon(Icons.group_outlined,
                          size: 13, color: subCol),
                      const SizedBox(width: 3),
                      Text('${t.teams} Teams',
                          style:
                              TextStyle(color: subCol, fontSize: 12)),
                      const SizedBox(width: 10),
                    ],
                    Text(t.format,
                        style: TextStyle(
                            color: t.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    if (t.prize.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text('🏆 ${t.prize}',
                            style: TextStyle(
                                color: textCol,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    const Spacer(),
                    if (t.status == TStatus.open)
                      GestureDetector(
                        onTap: onRegister,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Register',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (t.status == TStatus.upcoming)
                      GestureDetector(
                        onTap: onRegister,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primary),
                          ),
                          child: Text('Notify Me',
                              style: TextStyle(
                                  color: primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
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

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final TStatus status;
  final bool small;
  const _StatusBadge({required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case TStatus.open:
        color = const Color(0xFF2E7D32);
        label = 'Open';
        break;
      case TStatus.ongoing:
        color = AppColors.primary;
        label = 'Ongoing';
        break;
      case TStatus.upcoming:
        color = const Color(0xFF1565C0);
        label = 'Upcoming';
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TStatus.ongoing)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: small ? 9 : 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

enum TStatus { open, ongoing, upcoming }

class _Tournament {
  final String name, sport, emoji, location, date, prize, format;
  final int teams;
  final TStatus status;
  final Color color;
  const _Tournament({
    required this.name,
    required this.sport,
    required this.emoji,
    required this.location,
    required this.date,
    required this.teams,
    required this.prize,
    required this.status,
    required this.color,
    required this.format,
  });
}
