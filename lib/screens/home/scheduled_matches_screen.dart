import 'package:flutter/material.dart';

import '../../core/models/game_listing.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_listing_service.dart';
import '../../services/user_service.dart';
import '../games/game_detail_screen.dart';

class ScheduledMatchesScreen extends StatefulWidget {
  final String? sport; // null = show all sports
  const ScheduledMatchesScreen({super.key, this.sport});

  @override
  State<ScheduledMatchesScreen> createState() =>
      _ScheduledMatchesScreenState();
}

class _ScheduledMatchesScreenState extends State<ScheduledMatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String? _selectedSport; // only used when widget.sport == null

  static const _knownSports = [
    'Cricket', 'Football', 'Basketball', 'Badminton', 'Tennis',
    'Volleyball', 'Table Tennis', 'Boxing', 'Baseball', 'Hockey',
    'Running', 'Swimming', 'Cycling', 'MMA', 'Wrestling',
  ];

  String? get _activeSport => widget.sport ?? _selectedSport;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showSportPicker(BuildContext context, List<String> availableSports) {
    final searchCtrl = TextEditingController();
    List<String> filtered = availableSports;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const Text('Filter by Sport',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_selectedSport != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedSport = null);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear',
                              style: TextStyle(color: AppColors.primary)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search sport…',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (q) {
                      setModal(() {
                        filtered = availableSports
                            .where((s) =>
                                s.toLowerCase().contains(q.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      _SportPickerTile(
                        label: 'All Sports',
                        emoji: '🏅',
                        isSelected: _selectedSport == null,
                        onTap: () {
                          setState(() => _selectedSport = null);
                          Navigator.pop(ctx);
                        },
                      ),
                      ...filtered.map((s) => _SportPickerTile(
                            label: s,
                            emoji: _sportEmoji(s),
                            isSelected: _selectedSport == s,
                            onTap: () {
                              setState(() => _selectedSport = s);
                              Navigator.pop(ctx);
                            },
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _sportEmoji(String sport) {
    const m = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Boxing': '🥊', 'Baseball': '⚾',
      'Hockey': '🏑', 'Running': '🏃', 'Swimming': '🏊',
      'Cycling': '🚴', 'MMA': '🥋', 'Wrestling': '🤼',
    };
    return m[sport] ?? '🏅';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GameListingService(),
      builder: (ctx, _) {
        final myId = UserService().userId ?? '';

        final pool = _activeSport != null
            ? GameListingService().bySport(_activeSport!)
            : GameListingService().openGames;

        final userSports = {
          ...GameListingService().openGames.map((g) => g.sport),
          ..._knownSports,
        }.toList()..sort();

        // Games I'm participating in (organizer is always in playerIds)
        final rsvpd = pool
            .where((g) => g.playerIds.contains(myId))
            .toList();

        final now   = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final past = rsvpd.where((g) {
          final d = DateTime(g.scheduledAt.year, g.scheduledAt.month, g.scheduledAt.day);
          return d.isBefore(today);
        }).toList()..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

        final present = rsvpd.where((g) {
          final d = DateTime(g.scheduledAt.year, g.scheduledAt.month, g.scheduledAt.day);
          return d == today;
        }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        final upcoming = rsvpd.where((g) {
          final d = DateTime(g.scheduledAt.year, g.scheduledAt.month, g.scheduledAt.day);
          return d.isAfter(today);
        }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        final titleSport = _activeSport;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              titleSport != null ? '$titleSport · My Schedule' : 'My Schedule',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Past (${past.length})'),
                Tab(text: 'Today (${present.length})'),
                Tab(text: 'Upcoming (${upcoming.length})'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (widget.sport == null)
                GestureDetector(
                  onTap: () => _showSportPicker(context, userSports),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _selectedSport != null
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedSport != null
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_outlined,
                          size: 18,
                          color: _selectedSport != null
                              ? AppColors.primary
                              : Colors.white38,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedSport != null
                                ? '${_sportEmoji(_selectedSport!)}  $_selectedSport'
                                : 'All Sports',
                            style: TextStyle(
                              color: _selectedSport != null
                                  ? AppColors.primary
                                  : Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: _selectedSport != null
                              ? AppColors.primary
                              : Colors.white38,
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _GameList(games: past,     sport: _activeSport, emptyMsg: 'No past games'),
                    _GameList(games: present,  sport: _activeSport, emptyMsg: 'No games today'),
                    _GameList(games: upcoming, sport: _activeSport, emptyMsg: 'No upcoming games'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sport Picker Tile ─────────────────────────────────────────────────────────

class _SportPickerTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;
  const _SportPickerTile({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontSize: 15,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  final List<GameListing> games;
  final String? sport;
  final String emptyMsg;
  const _GameList(
      {required this.games, required this.sport, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📅', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(emptyMsg,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              emptyMsg == 'No games today'
                  ? (sport != null ? 'RSVP to a nearby $sport game' : 'RSVP to a nearby game')
                  : '',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final myId = UserService().userId ?? '';
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: games.length,
      itemBuilder: (_, i) {
        final g = games[i];
        final isOwner = g.organizerId == myId;
        return _ScheduleCard(
          game: g,
          badge: isOwner ? 'HOST' : 'GOING',
          badgeColor: isOwner ? Colors.red : Colors.green,
        );
      },
    );
  }
}

// ── Schedule Card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final GameListing game;
  final String badge;
  final Color badgeColor;
  const _ScheduleCard({
    required this.game,
    required this.badge,
    required this.badgeColor,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(game.scheduledAt);
    final isToday = dateLabel == 'Today';
    final location = game.venueName.isNotEmpty ? game.venueName : game.address;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameDetailScreen(listing: game)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isToday ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: game.photoUrl != null
                  ? Image.network(
                      game.photoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : const SizedBox(
                              height: 160,
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              ),
                            ),
                      errorBuilder: (context, e, s) =>
                          _SportBanner(sport: game.sport),
                    )
                  : _SportBanner(sport: game.sport),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 5),
                      Text('$dateLabel  ·  ${_formatTime(game.scheduledAt)}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13)),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip('${game.playerIds.length}/${game.maxPlayers} players', Colors.white12),
                      if (game.splitCost && game.totalCost > 0)
                        _chip(
                          '₹${game.costPerPlayer.toStringAsFixed(0)}/person',
                          AppColors.primary.withValues(alpha: 0.25),
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

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
      );
}

// ── Sport gradient banner ─────────────────────────────────────────────────────

class _SportBanner extends StatelessWidget {
  final String sport;
  const _SportBanner({required this.sport});

  static (List<Color>, String) _theme(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('cricket')) {
      return ([const Color(0xFF1B5E20), const Color(0xFF388E3C)], '🏏');
    } else if (s.contains('football') || s.contains('soccer')) {
      return ([const Color(0xFF0D47A1), const Color(0xFF1976D2)], '⚽');
    } else if (s.contains('basketball')) {
      return ([const Color(0xFFE65100), const Color(0xFFF57C00)], '🏀');
    } else if (s.contains('badminton')) {
      return ([const Color(0xFF4A148C), const Color(0xFF7B1FA2)], '🏸');
    } else if (s.contains('tennis')) {
      return ([const Color(0xFF33691E), const Color(0xFF689F38)], '🎾');
    } else if (s.contains('volleyball')) {
      return ([const Color(0xFF1A237E), const Color(0xFF3949AB)], '🏐');
    } else if (s.contains('hockey')) {
      return ([const Color(0xFF37474F), const Color(0xFF546E7A)], '🏑');
    } else if (s.contains('boxing') || s.contains('mma')) {
      return ([const Color(0xFFB71C1C), const Color(0xFFD32F2F)], '🥊');
    } else {
      return ([const Color(0xFF212121), const Color(0xFF424242)], '🏆');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (colors, emoji) = _theme(sport);
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -10,
          bottom: -10,
          child: Text(emoji,
              style: TextStyle(
                  fontSize: 110,
                  color: Colors.white.withValues(alpha: 0.08))),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(sport,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
