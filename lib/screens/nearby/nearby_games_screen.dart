import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/game_listing.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_listing_service.dart';
import '../../services/location_service.dart';
import '../../widgets/map_picker_sheet.dart';
import '../games/create_game_screen.dart';
import '../games/game_detail_screen.dart';
import '../home/scheduled_matches_screen.dart';

class NearbyGamesScreen extends StatefulWidget {
  final String? sport;
  const NearbyGamesScreen({super.key, this.sport});

  @override
  State<NearbyGamesScreen> createState() => _NearbyGamesScreenState();
}

class _NearbyGamesScreenState extends State<NearbyGamesScreen>
    with SingleTickerProviderStateMixin {
  Position? _userPos;
  bool _locating = true;
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _locationQuery = '';
  double? _radiusMiles; // null = no radius filter

  static const _tabs = ['Upcoming', 'Today', 'Past'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _initLocation();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    // Fast: try last-known first for instant distance sort
    final quick = await LocationService().getLastKnownPosition();
    if (quick != null && mounted) setState(() => _userPos = quick);

    // Accurate: full GPS fix
    final precise = await LocationService().getCurrentPosition();
    if (mounted) {
      setState(() {
        _userPos = precise ?? quick;
        _locating = false;
      });
    }
  }

  // ── Classify games into tabs ──────────────────────────────────────────────

  List<List<GameListing>> _split(List<GameListing> raw) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = <GameListing>[];
    final todayGs = <GameListing>[];
    final past = <GameListing>[];

    for (final g in raw) {
      final d = DateTime(g.scheduledAt.year, g.scheduledAt.month, g.scheduledAt.day);
      if (d.isBefore(today)) {
        past.add(g);
      } else if (d.isAtSameMomentAs(today)) {
        todayGs.add(g);
      } else {
        upcoming.add(g);
      }
    }

    // Upcoming: soonest first; Today: by time; Past: most recent first
    upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    todayGs.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    past.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return [upcoming, todayGs, past];
  }

  // Sort by distance if we have a position, else by createdAt desc
  List<GameListing> _sorted(List<GameListing> raw) {
    if (_userPos == null) {
      return [...raw]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    final svc = LocationService();
    return [...raw]..sort((a, b) {
      final dA = (a.latitude != null && a.longitude != null)
          ? svc.distanceInKm(
              _userPos!.latitude,
              _userPos!.longitude,
              a.latitude!,
              a.longitude!,
            )
          : double.infinity;
      final dB = (b.latitude != null && b.longitude != null)
          ? svc.distanceInKm(
              _userPos!.latitude,
              _userPos!.longitude,
              b.latitude!,
              b.longitude!,
            )
          : double.infinity;
      return dA.compareTo(dB);
    });
  }

  double? _distanceTo(GameListing g) {
    if (_userPos == null || g.latitude == null || g.longitude == null) {
      return null;
    }
    return LocationService().distanceInKm(
      _userPos!.latitude,
      _userPos!.longitude,
      g.latitude!,
      g.longitude!,
    );
  }

  String _emoji(String sport) {
    const m = {
      'Cricket': '🏏',
      'Football': '⚽',
      'Basketball': '🏀',
      'Badminton': '🏸',
      'Tennis': '🎾',
      'Squash': '🎾',
      'Volleyball': '🏐',
      'Table Tennis': '🏓',
      'Boxing': '🥊',
      'Baseball': '⚾',
      'Hockey': '🏑',
      'Rugby': '🏉',
      'Swimming': '🏊',
      'Cycling': '🚴',
      'MMA': '🥋',
      'Wrestling': '🤼',
      'Kabaddi': '🤼',
      'Throwball': '🎯',
      'Handball': '🤾',
      'Golf': '⛳',
      'Athletics': '🏃',
      'Archery': '🏹',
      'CS:GO': '🎮',
      'Valorant': '🎮',
    };
    return m[sport] ?? '🏅';
  }

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
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  Future<void> _onGpsTap() async {
    setState(() => _locating = true);
    final pos = await LocationService().getCurrentPosition();
    if (mounted) {
      setState(() {
        _userPos = pos;
        _locating = false;
      });
    }
  }

  void _showRadiusSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RadiusSheet(
        initial: _radiusMiles ?? 10,
        onApply: (miles) {
          Navigator.pop(context);
          setState(() => _radiusMiles = miles <= 0 ? null : miles);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CreateGameScreen(
              prefilledSport: widget.sport,
            ),
          ),
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.sports_handball_outlined, color: Colors.white),
        label: const Text(
          'Host a Game',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Text(
              _emoji(widget.sport ?? ''),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Nearby${widget.sport != null ? ' ${widget.sport}' : ''} Games',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'My Schedule',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScheduledMatchesScreen(sport: widget.sport),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Today'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: GameListingService(),
        builder: (ctx, _) {
          final allSorted = _sorted(
            widget.sport != null
                ? GameListingService().bySport(widget.sport!)
                : GameListingService().openGames,
          );
          final filtered = allSorted.where((g) {
            final loc = '${g.venueName} ${g.address}'.toLowerCase();
            final matchText = _locationQuery.isEmpty ||
                loc.contains(_locationQuery.toLowerCase());
            // convert miles → km for distance comparison
            final matchRadius =
                _radiusMiles == null ||
                (_distanceTo(g) != null &&
                    _distanceTo(g)! <= _radiusMiles! * 1.60934);
            return matchText && matchRadius;
          }).toList();
          final splits = _split(filtered); // [upcoming, today, past]

          return Column(
            children: [
              // ── Location search bar ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _locationQuery = v.trim()),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by location…',
                          hintStyle: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textHint,
                            size: 18,
                          ),
                          suffixIcon: _locationQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.textHint,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _locationQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Combined GPS + radius pill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      decoration: BoxDecoration(
                        color: _radiusMiles != null
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _radiusMiles != null
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // GPS tap — gets current location
                          GestureDetector(
                            onTap: _locating ? null : _onGpsTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: _locating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.my_location_rounded,
                                      color: _userPos != null
                                          ? AppColors.primary
                                          : Colors.white38,
                                      size: 20,
                                    ),
                            ),
                          ),
                          // Divider
                          Container(
                            width: 1,
                            height: 22,
                            color: AppColors.border,
                          ),
                          // Radius dropdown arrow
                          GestureDetector(
                            onTap: _showRadiusSheet,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Icon(
                                Icons.expand_more_rounded,
                                color: _radiusMiles != null
                                    ? AppColors.primary
                                    : Colors.white38,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Active radius chip
              if (_radiusMiles != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.radio_button_checked,
                              color: AppColors.primary,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Within ${_radiusMiles!.toStringAsFixed(_radiusMiles! == _radiusMiles!.roundToDouble() ? 0 : 1)} mi',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _radiusMiles = null),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.textHint,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // ── Tabs 0-2: Upcoming / Today / Past ────────────────
                    ...List.generate(3, (tabIdx) {
                      final games = splits[tabIdx];
                      if (games.isEmpty) {
                        return _EmptyTab(
                          label: _tabs[tabIdx],
                          sport: widget.sport ?? '',
                          onAdd: null,
                        );
                      }
                      return RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.card,
                        onRefresh: () async {
                          GameListingService().listenToOpenGames();
                          await _initLocation();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: games.length,
                          itemBuilder: (_, i) {
                            final game = games[i];
                            return _GameCard(
                              game: game,
                              distance: _distanceTo(game),
                              formatDate: _formatDate,
                              formatTime: _formatTime,
                              onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => GameDetailScreen(listing: game),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Empty tab state ───────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final String label;
  final String sport;
  final VoidCallback? onAdd;
  const _EmptyTab({required this.label, required this.sport, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isPast = label == 'Past';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isPast ? '📋' : '🏟️', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPast
                  ? 'No past $sport games'
                  : label == 'Today'
                  ? 'No $sport games today'
                  : 'No upcoming $sport games',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isPast
                  ? 'Completed games will appear here'
                  : 'Be the first to add one in your area!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                  onPressed: onAdd,
                  child: const Text(
                    'Add a Game',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Game Card ─────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final GameListing game;
  final double? distance;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  const _GameCard({
    required this.game,
    required this.distance,
    required this.onTap,
    required this.formatDate,
    required this.formatTime,
  });

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
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 11,
                color: iconColor ?? Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatDate(game.scheduledAt);
    final timeLabel = formatTime(game.scheduledAt);
    final isToday = dateLabel == 'Today';
    final isTomorrow = dateLabel == 'Tomorrow';
    final location =
        game.venueName.isNotEmpty ? game.venueName : game.address;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.09),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner ────────────────────────────────────────────────────
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  game.photoUrl != null
                      ? Image.network(
                          game.photoUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, prog) => prog == null
                              ? child
                              : const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                          errorBuilder: (context, e, s) =>
                              _SportBanner(sport: game.sport),
                        )
                      : _SportBanner(sport: game.sport),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.0, 0.28, 0.62, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    child: _glassPill(
                      icon: Icons.calendar_today_outlined,
                      text: dateLabel,
                      iconColor: isToday
                          ? AppColors.primary
                          : isTomorrow
                          ? AppColors.warning
                          : Colors.white,
                    ),
                  ),
                  if (distance != null)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: _glassPill(
                        icon: Icons.near_me_outlined,
                        text: LocationService().formatDistance(distance!),
                        iconColor: const Color(0xFF42A5F5),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.sport,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showMapPickerSheet(
                      context,
                      lat: game.latitude,
                      lng: game.longitude,
                      label: location,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.textHint,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location.isNotEmpty ? location : 'Location TBD',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        color: AppColors.textHint,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.group_outlined,
                        color: AppColors.textHint,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${game.playerIds.length}/${game.maxPlayers} players',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (!game.isFull)
                        _InfoChip(
                          label:
                              '${game.spotsLeft} spot${game.spotsLeft == 1 ? '' : 's'} left',
                          color: Colors.green.withValues(alpha: 0.2),
                        )
                      else
                        _InfoChip(
                          label: 'Full',
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      if (game.splitCost && game.costPerPlayer > 0)
                        _InfoChip(
                          label:
                              '₹${game.costPerPlayer.toStringAsFixed(0)}/player',
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                    ],
                  ),
                  if (game.note != null && game.note!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      game.note!,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }
}

// ── Radius Sheet (slider + text input, 0-100 miles) ──────────────────────────

class _RadiusSheet extends StatefulWidget {
  final double initial;
  final void Function(double miles) onApply;
  const _RadiusSheet({required this.initial, required this.onApply});

  @override
  State<_RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends State<_RadiusSheet> {
  late double _miles;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _miles = widget.initial.clamp(0, 100);
    _ctrl = TextEditingController(text: _miles.toInt().toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSlider(double v) {
    setState(() => _miles = v);
    _ctrl.text = v.toInt().toString();
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  void _onText(String v) {
    final parsed = int.tryParse(v);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, 100).toDouble();
    setState(() => _miles = clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Search Radius',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Slider row
          Row(
            children: [
              const Text(
                '0',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withValues(
                      alpha: 0.2,
                    ),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _miles,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: _onSlider,
                  ),
                ),
              ),
              const Text(
                '100',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Text input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF252525),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: _onText,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'miles',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => widget.onApply(0), // 0 = clear filter
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => widget.onApply(_miles),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sport gradient banner (shown when no photo is uploaded) ───────────────────

class _SportBanner extends StatelessWidget {
  final String sport;
  const _SportBanner({required this.sport});

  static (List<Color>, String) _theme(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('cricket')) {
      return ([const Color(0xFF1B5E20), const Color(0xFF388E3C)], '🏏');
    }
    if (s.contains('football') || s.contains('soccer')) {
      return ([const Color(0xFF0D47A1), const Color(0xFF1976D2)], '⚽');
    }
    if (s.contains('basketball')) {
      return ([const Color(0xFFE65100), const Color(0xFFF57C00)], '🏀');
    }
    if (s.contains('badminton')) {
      return ([const Color(0xFF4A148C), const Color(0xFF7B1FA2)], '🏸');
    }
    if (s.contains('table tennis')) {
      return ([const Color(0xFF01579B), const Color(0xFF0288D1)], '🏓');
    }
    if (s.contains('tennis') || s.contains('squash')) {
      return ([const Color(0xFF33691E), const Color(0xFF689F38)], '🎾');
    }
    if (s.contains('volleyball')) {
      return ([const Color(0xFF1A237E), const Color(0xFF3949AB)], '🏐');
    }
    if (s.contains('hockey')) {
      return ([const Color(0xFF37474F), const Color(0xFF546E7A)], '🏑');
    }
    if (s.contains('rugby')) {
      return ([const Color(0xFF3E2723), const Color(0xFF6D4C41)], '🏉');
    }
    if (s.contains('swimming')) {
      return ([const Color(0xFF006064), const Color(0xFF00838F)], '🏊');
    }
    if (s.contains('boxing') || s.contains('mma')) {
      return ([const Color(0xFFB71C1C), const Color(0xFFD32F2F)], '🥊');
    }
    if (s.contains('cycling')) {
      return ([const Color(0xFF1565C0), const Color(0xFF42A5F5)], '🚴');
    }
    if (s.contains('kabaddi')) {
      return ([const Color(0xFFBF360C), const Color(0xFFE64A19)], '🤼');
    }
    if (s.contains('throwball')) {
      return ([const Color(0xFF6A1B9A), const Color(0xFF8E24AA)], '🎯');
    }
    if (s.contains('handball')) {
      return ([const Color(0xFF00695C), const Color(0xFF00897B)], '🤾');
    }
    if (s.contains('golf')) {
      return ([const Color(0xFF2E7D32), const Color(0xFF66BB6A)], '⛳');
    }
    if (s.contains('wrestling')) {
      return ([const Color(0xFF4A148C), const Color(0xFF7B1FA2)], '🤼');
    }
    if (s.contains('athletics') || s.contains('running')) {
      return ([const Color(0xFFE65100), const Color(0xFFFFA000)], '🏃');
    }
    if (s.contains('archery')) {
      return ([const Color(0xFF1B5E20), const Color(0xFF558B2F)], '🏹');
    }
    if (s.contains('esport') || s.contains('gaming')) {
      return ([const Color(0xFF1A237E), const Color(0xFF283593)], '🎮');
    }
    return ([const Color(0xFF212121), const Color(0xFF424242)], '🏆');
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
      child: Stack(
        children: [
          // Large faded emoji as background texture
          Positioned(
            right: -10,
            bottom: -10,
            child: Text(
              emoji,
              style: TextStyle(fontSize: 110, color: AppColors.border),
            ),
          ),
          // Sport label + emoji centred
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  sport,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
