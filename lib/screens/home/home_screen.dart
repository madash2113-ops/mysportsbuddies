import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/match_score.dart';
import '../../core/models/tournament.dart';
import '../../design/colors.dart';

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

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final name    = (UserService().profile?.name ?? '').split(' ').first;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Greeting row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12)),
                const SizedBox(height: 1),
                Text(name.isNotEmpty ? name : 'Athlete',
                    style: TextStyle(
                        color: textCol,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ],
            ),
          ),

          // ── Image banner slider ──────────────────────────────────────────
          const BannerSlider(),

          // ── Context banners (live / tournament / next game) ─────────────
          const _ContextBanners(),

          const SizedBox(height: 14),

          // ── Popular Sports ───────────────────────────────────────────────
          _SectionRow(
            title: 'Popular Sports',
            actionLabel: 'See All',
            primary: primary,
            textCol: textCol,
            onAction: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AllSportsScreen())),
          ),
          const SizedBox(height: 8),
          const _SportsPillRow(),

          const SizedBox(height: 18),

          // ── Nearby Venues ────────────────────────────────────────────────
          _SectionRow(
            title: 'Nearby Venues',
            actionLabel: 'See All',
            primary: Colors.teal,
            textCol: textCol,
            onAction: () => Navigator.pushNamed(context, '/venues'),
          ),
          const SizedBox(height: 8),
          const _VenuesPillRow(),

          const SizedBox(height: 18),

          // ── Games Near You ───────────────────────────────────────────────
          _SectionRow(
            title: 'Games Near You',
            actionLabel: '+ List',
            primary: primary,
            textCol: textCol,
            onAction: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateGameScreen())),
          ),
          const SizedBox(height: 8),
          const _GamesPillRow(),

          const Spacer(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Open games row ────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String     title;
  final String     actionLabel;
  final Color      primary;
  final Color      textCol;
  final VoidCallback onAction;

  const _SectionRow({
    required this.title,
    required this.actionLabel,
    required this.primary,
    required this.textCol,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: textCol,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel,
                style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Sports pill row (single horizontal scroll) ────────────────────────────────

class _SportsPillRow extends StatelessWidget {
  const _SportsPillRow();

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
    ('More',       '➕'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _sports.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, emoji) = _sports[i];
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? primary.withValues(alpha: 0.10)
                    : primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: primary.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Venues pill row ───────────────────────────────────────────────────────────

class _VenuesPillRow extends StatelessWidget {
  const _VenuesPillRow();

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Colors.teal;

    return ListenableBuilder(
      listenable: VenueService(),
      builder: (context, _) {
        final venues = VenueService().venues;

        if (venues.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('No venues nearby yet',
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13)),
          );
        }

        return SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final v = venues[i];
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => VenueDetailScreen(venue: v))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? primary.withValues(alpha: 0.10)
                        : primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stadium_outlined,
                          color: primary, size: 15),
                      const SizedBox(width: 6),
                      Text(v.name,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Games pill row ────────────────────────────────────────────────────────────

class _GamesPillRow extends StatelessWidget {
  const _GamesPillRow();

  static const _emojis = {
    'cricket': '🏏', 'football': '⚽', 'basketball': '🏀',
    'badminton': '🏸', 'tennis': '🎾', 'volleyball': '🏐',
    'boxing': '🥊', 'kabaddi': '🤼', 'hockey': '🏑',
    'throwball': '🎯', 'handball': '🤾',
  };

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;

    return ListenableBuilder(
      listenable: GameListingService(),
      builder: (context, _) {
        final games = [...GameListingService().openGames]
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        if (games.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('No games nearby — be the first to list one!',
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13)),
          );
        }

        return SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final g = games[i];
              final emoji = _emojis[g.sport.toLowerCase()] ?? '🏅';
              final dt    = g.scheduledAt;
              final h     = dt.hour;
              final am    = h < 12 ? 'AM' : 'PM';
              final hr    = h == 0 ? 12 : (h > 12 ? h - 12 : h);
              final months = ['Jan','Feb','Mar','Apr','May','Jun',
                              'Jul','Aug','Sep','Oct','Nov','Dec'];
              final label = '${g.sport} · ${dt.day} ${months[dt.month-1]} $hr$am';

              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => GameDetailScreen(listing: g))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? primary.withValues(alpha: 0.10)
                        : primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
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
      height: 155,
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
