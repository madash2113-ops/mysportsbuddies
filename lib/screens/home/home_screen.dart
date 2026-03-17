import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/match_score.dart';
import '../../core/models/tournament.dart';
import '../../design/colors.dart';

import '../../services/location_service.dart';
import '../../services/scoreboard_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../common/sport_action_glass_sheet.dart';
import '../community/community_feed_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../sports/all_sports_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../tournaments/tournaments_list_screen.dart';
import '../common/app_drawer.dart';
import '../games/create_game_screen.dart';
import '../games/game_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../venues/venue_detail_screen.dart';

import '../../services/game_listing_service.dart';
import '../../services/venue_service.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0 = Home (default), 1 = Tournaments, 2 = Feed, 3 = Profile
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // Sync Firestore-loaded profile into ProfileController so the drawer
    // shows the user's name immediately on first launch (without re-editing).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = UserService().profile;
      if (profile != null && mounted) {
        context.read<ProfileController>().setProfile(
          name:            profile.name,
          email:           profile.email,
          phone:           profile.phone,
          location:        profile.location,
          dob:             profile.dob,
          bio:             profile.bio,
          networkImageUrl: profile.imageUrl,
          numericId:       profile.numericId,
        );
      }
    });
  }

  // 0 = Home, 1 = Tournaments, 2 = Feed, 3 = Profile
  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.emoji_events_outlined),
      activeIcon: Icon(Icons.emoji_events),
      label: 'Tournaments',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.dynamic_feed_outlined),
      activeIcon: Icon(Icons.dynamic_feed),
      label: 'Feed',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;

    final pages = [
      const _HomeTab(),
      const TournamentsListScreen(),
      const CommunityFeedScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColorsLight.background,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context, isDark),
      body: IndexedStack(
        index: _bottomNavIndex,
        children: pages,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primary,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 12,
        items: _navItems,
      ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isDark) {
    final iconColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final primary   = isDark ? AppColors.primary : AppColorsLight.primary;

    return AppBar(
      backgroundColor: isDark ? Colors.black : Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'MySports',
              style: TextStyle(
                color: iconColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: 'Buddies',
              style: TextStyle(
                color: primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      centerTitle: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none, color: iconColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            Positioned(
              right: 8, top: 8,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: iconColor),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserService(),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final profile = UserService().profile;

    final name              = profile?.name     ?? 'Your Name';
    final email             = profile?.email    ?? '';
    final location          = profile?.location ?? '';
    final bio               = profile?.bio      ?? '';
    final numId             = profile?.numericId;
    final tournamentsPlayed = profile?.tournamentsPlayed ?? 0;
    final matchesPlayed     = profile?.matchesPlayed     ?? 0;
    final matchesWon        = profile?.matchesWon        ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        children: [
          // Avatar
          Builder(builder: (context) {
            final img = context.watch<ProfileController>().avatarImage;
            return CircleAvatar(
              radius: 52,
              backgroundColor: primary.withValues(alpha: 0.15),
              backgroundImage: img,
              child: img == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: primary),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 14),

          // Name
          Text(
            name,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          // Numeric ID
          if (numId != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$numId',
                  style: TextStyle(
                      color: primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '$numId'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ID copied'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(Icons.copy_rounded, size: 14, color: primary),
                ),
              ],
            ),
          ],

          // Bio
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13),
            ),
          ],

          // Info chips
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (email.isNotEmpty)
                _InfoChip(
                    icon: Icons.email_outlined,
                    label: email,
                    primary: primary),
              if (location.isNotEmpty)
                _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: location,
                    primary: primary),
            ],
          ),

          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _StatBox(
                  label: 'Tournaments',
                  value: tournamentsPlayed,
                  primary: primary),
              const SizedBox(width: 10),
              _StatBox(
                  label: 'Matches', value: matchesPlayed, primary: primary),
              const SizedBox(width: 10),
              _StatBox(label: 'Won', value: matchesWon, primary: primary),
            ],
          ),

          const SizedBox(height: 20),

          // Edit Profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(Icons.edit_outlined, color: primary, size: 18),
              label: Text('Edit Profile',
                  style: TextStyle(
                      color: primary, fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EditProfileScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int value;
  final Color primary;
  const _StatBox({required this.label, required this.value, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                  color: primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color primary;
  const _InfoChip(
      {required this.icon, required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primary, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF1A1A1A),
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _showSports = true;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  Future<void> _openLocationPicker(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LocationPickerSheet(),
    );
    if (result != null && result.isNotEmpty) {
      final profile = UserService().profile;
      if (profile != null) {
        await UserService().saveProfile(profile.copyWith(location: result));
        if (mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final cardBg  = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0);
    final name    = (UserService().profile?.name ?? '').split(' ').first;

    final location = UserService().profile?.location ?? '';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Banner slider (at top) ───────────────────────────────────────
          const BannerSlider(),

          // ── Greeting + name + location ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(name.isNotEmpty ? name : 'Athlete',
                    style: TextStyle(
                        color: textCol,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _openLocationPicker(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          location.isNotEmpty
                              ? location.split(',').take(2).join(',').trim()
                              : 'Set your location',
                          style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: isDark ? Colors.white24 : Colors.black26),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sports | Venues toggle ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  _ToggleTab(
                    label: 'Sports',
                    icon: Icons.sports_outlined,
                    active: _showSports,
                    primary: primary,
                    isDark: isDark,
                    onTap: () => setState(() => _showSports = true),
                  ),
                  _ToggleTab(
                    label: 'Venues',
                    icon: Icons.stadium_outlined,
                    active: !_showSports,
                    primary: primary,
                    isDark: isDark,
                    onTap: () => setState(() => _showSports = false),
                  ),
                ],
              ),
            ),
          ),

          // ── Context banners (live / tournament / next game) ─────────────
          if (_showSports) const _ContextBanners(),

          const SizedBox(height: 8),

          // ── Content: Sports section OR Venues section ────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _showSports
                  ? const _SportsGrid(key: ValueKey('sports'))
                  : const _VenuesGrid(key: ValueKey('venues')),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Toggle tab (one half of the Sports | Venues bar) ──────────────────────────

class _ToggleTab extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final bool      active;
  final Color     primary;
  final bool      isDark;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          decoration: BoxDecoration(
            color: active ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(
                    color: primary.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: active
                      ? Colors.white
                      : (isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.black45),
                    fontSize: 16,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sports section (horizontal pill scroll) ────────────────────────────────────

class _SportsGrid extends StatelessWidget {
  const _SportsGrid({super.key});

  static const _sports = [
    ('Cricket',    '🏏'),
    ('Football',   '⚽'),
    ('Throwball',  '🎯'),
    ('Handball',   '🤾'),
    ('Badminton',  '🏸'),
    ('Basketball', '🏀'),
    ('Tennis',     '🎾'),
    ('Volleyball', '🏐'),
    ('Kabaddi',    '🤼'),
    ('Boxing',     '🥊'),
    ('Hockey',     '🏑'),
    ('More',       '➕'),
  ];

  // Build ordered list: favorites first, then the rest, always end with More
  List<(String, String)> _orderedSports() {
    final favs = UserService().profile?.favoriteSports ?? const <String>[];
    final favoriteItems = _sports
        .where((s) => s.$1 != 'More' && favs.contains(s.$1))
        .toList();
    final otherItems = _sports
        .where((s) => s.$1 != 'More' && !favs.contains(s.$1))
        .toList();
    return [...favoriteItems, ...otherItems, ('More', '➕')];
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final ordered = _orderedSports();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "Sports" label + See All ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Sports',
                      style: TextStyle(
                          color: textCol,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AllSportsScreen())),
                  child: Text('See All',
                      style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Pills
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: ordered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final (label, emoji) = ordered[i];
                final isMore = label == 'More';
                return GestureDetector(
                  onTap: () {
                    if (isMore) {
                      Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AllSportsScreen()));
                    } else {
                      Navigator.of(context).push(PageRouteBuilder(
                        opaque: false,
                        pageBuilder: (_, _, _) =>
                            SportActionGlassScreen(sport: label),
                        transitionsBuilder: (_, anim, _, child) =>
                            FadeTransition(opacity: anim, child: child),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? primary.withValues(alpha: 0.12)
                          : primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: primary.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(label,
                            style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Sports Near You header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Sports Near You',
                      style: TextStyle(
                          color: textCol,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const CreateGameScreen())),
                  child: Text('+ List',
                      style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const _GamesGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Games grid (2-column card grid) ───────────────────────────────────────────

class _GamesGrid extends StatelessWidget {
  const _GamesGrid();

  static const _emojis = {
    'cricket': '🏏', 'football': '⚽', 'basketball': '🏀',
    'badminton': '🏸', 'tennis': '🎾', 'volleyball': '🏐',
    'boxing': '🥊', 'kabaddi': '🤼', 'hockey': '🏑',
    'throwball': '🎯', 'handball': '🤾',
  };

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun',
                           'Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final cardBg  = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return ListenableBuilder(
      listenable: GameListingService(),
      builder: (context, _) {
        final games = [...GameListingService().openGames]
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        if (games.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text('No games nearby yet',
                      style: TextStyle(
                          color: textCol,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Be the first to list one!',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12)),
                ],
              ),
            ),
          );
        }

        // 2-column grid rendered inside SingleChildScrollView parent
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (int i = 0; i < games.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _GameCard(
                        game: games[i],
                        cardBg: cardBg,
                        textCol: textCol,
                        primary: primary,
                        emoji: _emojis[games[i].sport.toLowerCase()] ?? '🏅',
                        months: _months,
                      )),
                      if (i + 1 < games.length) ...[
                        const SizedBox(width: 10),
                        Expanded(child: _GameCard(
                          game: games[i + 1],
                          cardBg: cardBg,
                          textCol: textCol,
                          primary: primary,
                          emoji: _emojis[games[i + 1].sport.toLowerCase()] ?? '🏅',
                          months: _months,
                        )),
                      ] else
                        const Expanded(child: SizedBox()),
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

class _GameCard extends StatelessWidget {
  final dynamic game;
  final Color cardBg;
  final Color textCol;
  final Color primary;
  final String emoji;
  final List<String> months;

  const _GameCard({
    required this.game,
    required this.cardBg,
    required this.textCol,
    required this.primary,
    required this.emoji,
    required this.months,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dt = game.scheduledAt as DateTime;
    final h  = dt.hour;
    final am = h < 12 ? 'AM' : 'PM';
    final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final timeStr = '${dt.day} ${months[dt.month - 1]} · $hr$am';
    final spots = game.spotsLeft as int;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => GameDetailScreen(listing: game))),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji + sport
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(game.sport as String,
                      style: TextStyle(
                          color: textCol,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Date/time
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 12,
                    color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(timeStr,
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            // Venue (if any)
            if ((game.venueName as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 12,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(game.venueName as String,
                        style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // Spots left badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: spots > 0
                    ? primary.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                spots > 0 ? '$spots spot${spots == 1 ? '' : 's'} left' : 'Full',
                style: TextStyle(
                    color: spots > 0 ? primary : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Venues section (horizontal pill scroll) ────────────────────────────────────

class _VenuesGrid extends StatelessWidget {
  const _VenuesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;

    return ListenableBuilder(
      listenable: VenueService(),
      builder: (context, _) {
        final venues = VenueService().venues;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pills
              if (venues.isEmpty)
                SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stadium_outlined,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text('No venues nearby yet',
                            style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Check back soon!',
                            style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: venues.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final v = venues[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    VenueDetailScreen(venue: v))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? primary.withValues(alpha: 0.12)
                                : primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.30)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stadium_outlined,
                                  color: primary, size: 22),
                              const SizedBox(width: 8),
                              Text(v.name,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<String> _suggestions = [];
  bool _searching = false;
  bool _locating  = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── GPS → reverse geocode ────────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get location. Check permissions.')),
          );
        }
        return;
      }
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=14&addressdetails=1',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'MySportsBuddies/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data    = jsonDecode(res.body) as Map<String, dynamic>;
        final addr    = data['address'] as Map<String, dynamic>? ?? {};
        final parts   = <String>[];
        final suburb  = addr['suburb']       ?? addr['neighbourhood'] ?? addr['hamlet'] ?? '';
        final city    = addr['city']         ?? addr['town']          ?? addr['village'] ?? '';
        final state   = addr['state']        ?? '';
        final country = addr['country']      ?? '';
        if (suburb.isNotEmpty) parts.add(suburb as String);
        if (city.isNotEmpty && city != suburb) parts.add(city as String);
        if (state.isNotEmpty) parts.add(state as String);
        if (country.isNotEmpty) parts.add(country as String);
        final label = parts.isNotEmpty ? parts.join(', ') : (data['display_name'] as String? ?? '');
        if (label.isNotEmpty && mounted) Navigator.pop(context, label);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Search autocomplete ──────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchSuggestions(q.trim()));
  }

  Future<void> _fetchSuggestions(String q) async {
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&limit=8&lang=en',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data     = jsonDecode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        final results  = <String>[];
        for (final f in features) {
          final props   = f['properties'] as Map<String, dynamic>? ?? {};
          final name    = props['name']    as String? ?? '';
          final city    = props['city']    as String? ?? '';
          final state   = props['state']   as String? ?? '';
          final country = props['country'] as String? ?? '';
          final parts   = <String>[];
          if (name.isNotEmpty)                                            parts.add(name);
          if (city.isNotEmpty    && city    != name)                      parts.add(city);
          if (state.isNotEmpty   && state   != city && state   != name)   parts.add(state);
          if (country.isNotEmpty)                                         parts.add(country);
          final label = parts.join(', ');
          if (label.isNotEmpty && !results.contains(label)) results.add(label);
        }
        setState(() { _suggestions = results; _searching = false; });
      } else {
        setState(() => _searching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5);
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text('Set Location',
                      style: TextStyle(
                          color: textCol,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white38 : Colors.black38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Use current location button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_locating ? 'Getting location…' : 'Use Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or search',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12)),
                ),
                Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12)),
              ]),
            ),
            const SizedBox(height: 12),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                onChanged: _onSearchChanged,
                style: TextStyle(color: textCol, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search city, area or address…',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: isDark ? Colors.white38 : Colors.black38),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _suggestions = []);
                              })
                          : null),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Results
            Expanded(
              child: _suggestions.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? 'Start typing to search'
                            : 'No results found',
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12),
                      itemBuilder: (context, i) => ListTile(
                        leading: Icon(Icons.location_on_outlined,
                            color: AppColors.primary, size: 20),
                        title: Text(_suggestions[i],
                            style: TextStyle(
                                color: textCol,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        onTap: () =>
                            Navigator.pop(context, _suggestions[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  late PageController _pageController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page?.toInt() ?? 0) + 1;
        _pageController.animateToPage(
          nextPage % 2,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 195,
      child: PageView(
        controller: _pageController,
        children: const [
          BannerImage(imagePath: 'assets/1.jpg'),
          BannerImage(imagePath: 'assets/2.jpg'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEXT BANNERS — live score · active tournament · next game (single-line)
// ─────────────────────────────────────────────────────────────────────────────

class _ContextBanners extends StatelessWidget {
  const _ContextBanners();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live scoreboard banner
        Consumer<ScoreboardService>(
          builder: (context, svc, _) {
            final live = svc.all.where((m) => m.status == MatchStatus.live).toList();
            if (live.isEmpty) return const SizedBox.shrink();
            final m = live.first;
            final score = _liveScore(m);
            return _BannerRow(
              color: Colors.red,
              leading: const _PulseDot(color: Colors.red),
              label: '${m.teamA} vs ${m.teamB}',
              detail: score,
              actionLabel: 'Resume',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) =>
                      LiveScoreboardScreen(matchId: m.id, isScorer: true))),
            );
          },
        ),
        // Active tournament banner
        ListenableBuilder(
          listenable: TournamentService(),
          builder: (context, _) {
            final svc = TournamentService();
            final ongoing = svc.tournaments.where((t) =>
                t.status == TournamentStatus.ongoing &&
                svc.myEnrolledIds.contains(t.id)).toList();
            if (ongoing.isEmpty) return const SizedBox.shrink();
            final t = ongoing.first;
            return _BannerRow(
              color: AppColors.primary,
              leading: const Icon(Icons.emoji_events, color: AppColors.primary, size: 14),
              label: t.name,
              detail: t.sport,
              actionLabel: 'View',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) =>
                      TournamentDetailScreen(tournamentId: t.id))),
            );
          },
        ),
        // Next game banner
        ListenableBuilder(
          listenable: GameListingService(),
          builder: (context, _) {
            final my = GameListingService().myGames;
            if (my.isEmpty) return const SizedBox.shrink();
            final g  = my.first;
            final dt = g.scheduledAt;
            final h  = dt.hour; final am = h < 12 ? 'AM' : 'PM';
            final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
            final months = ['Jan','Feb','Mar','Apr','May','Jun',
                            'Jul','Aug','Sep','Oct','Nov','Dec'];
            final timeStr = '${dt.day} ${months[dt.month-1]} · $hr$am';
            return _BannerRow(
              color: Colors.orange,
              leading: Text(_sportEmoji(g.sport),
                  style: const TextStyle(fontSize: 14)),
              label: g.sport,
              detail: timeStr,
              actionLabel: 'View',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => GameDetailScreen(listing: g))),
            );
          },
        ),
      ],
    );
  }

  static String _liveScore(LiveMatch m) {
    switch (m.sport) {
      case MatchSport.cricket:
        final inn = m.cricket?.currentInnings;
        return inn != null ? '${inn.runs}/${inn.wickets} (${inn.oversStr})' : 'Live';
      case MatchSport.football:
        return '${m.football?.teamAGoals ?? 0}–${m.football?.teamBGoals ?? 0}';
      case MatchSport.basketball:
        return '${m.basketball?.teamATotal ?? 0}–${m.basketball?.teamBTotal ?? 0}';
      default:
        final g = m.genericScore;
        return g != null ? '${g.teamAScore}–${g.teamBScore}' : 'Live';
    }
  }

  static String _sportEmoji(String sport) {
    const map = {
      'cricket': '🏏', 'football': '⚽', 'basketball': '🏀',
      'badminton': '🏸', 'tennis': '🎾', 'volleyball': '🏐',
      'boxing': '🥊',
    };
    return map[sport.toLowerCase()] ?? '🏅';
  }
}

// Single-line banner row
class _BannerRow extends StatelessWidget {
  final Color      color;
  final Widget     leading;
  final String     label;
  final String     detail;
  final String     actionLabel;
  final VoidCallback onTap;

  const _BannerRow({
    required this.color,
    required this.leading,
    required this.label,
    required this.detail,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label  ·  $detail',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(actionLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// Pulsing dot for live indicator
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class BannerImage extends StatelessWidget {
  final String imagePath;
  const BannerImage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
