import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../../services/user_service.dart';
import '../common/sport_action_glass_sheet.dart';
import '../community/community_feed_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../sports/all_sports_screen.dart';
import '../sports/live_streaming_screen.dart';
import '../sports/tournaments_screen.dart';
import '../premium/premium_screen.dart';
import '../common/app_drawer.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.sports_outlined),
      activeIcon: Icon(Icons.sports),
      label: 'Sports',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.live_tv_outlined),
      activeIcon: Icon(Icons.live_tv),
      label: 'Live',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_alt_outlined),
      activeIcon: Icon(Icons.people_alt),
      label: 'Community',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.emoji_events_outlined),
      activeIcon: Icon(Icons.emoji_events),
      label: 'Tournaments',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.workspace_premium_outlined),
      activeIcon: Icon(Icons.workspace_premium),
      label: 'Membership',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      const _HomeTab(),
      const LiveStreamingScreen(),
      const CommunityFeedScreen(),
      const TournamentsScreen(),
      const PremiumScreen(),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColorsLight.background,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context, isDark),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: _navItems,
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
        Consumer<ProfileController>(
          builder: (context, controller, _) => IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            icon: controller.profileImage != null
                ? CircleAvatar(
                    radius: 14,
                    backgroundImage: FileImage(controller.profileImage!),
                    backgroundColor: Colors.transparent,
                  )
                : Icon(Icons.person_outline, color: iconColor),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB — full reimagined content
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Banner ─────────────────────────────────────────────────
          const _HeroBanner(),

          // ── Resume Scoreboard Banner (above Browse Sports) ───────────────
          Consumer<ScoreboardService>(
            builder: (context, svc, _) {
              final live = svc.all
                  .where((m) => m.status == MatchStatus.live)
                  .toList();
              if (live.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(
                    top: AppSpacing.sm, left: AppSpacing.md, right: AppSpacing.md),
                child: _ResumeScoreboardBanner(match: live.first),
              );
            },
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Browse Sports heading ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Browse Sports',
              style: TextStyle(
                color: textCol,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                SportTile(label: 'Cricket',      emoji: '🏏'),
                SportTile(label: 'Football',     emoji: '⚽'),
                SportTile(label: 'Basketball',   emoji: '🏀'),
                SportTile(label: 'Badminton',    emoji: '🏸'),
                SportTile(label: 'Tennis',       emoji: '🎾'),
                SportTile(label: 'Volleyball',   emoji: '🏐'),
                SportTile(label: 'Table Tennis', emoji: '🏓'),
                SportTile(label: 'Boxing',       emoji: '🥊'),
                SportTile(label: 'More',         emoji: '➕', isMore: true),
              ],
            ),
          ),

          // Bottom padding accounts for nav bar + system nav
          SizedBox(
            height: MediaQuery.of(context).padding.bottom + 80,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatefulWidget {
  const _HeroBanner();

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  late PageController _pageCtrl;
  late Timer _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_page + 1) % 2;
      _pageCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
      setState(() => _page = next);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cycling background images
          PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              Image(image: AssetImage('assets/1.jpg'), fit: BoxFit.cover),
              Image(image: AssetImage('assets/2.jpg'), fit: BoxFit.cover),
            ],
          ),

          // Subtle bottom gradient for dots visibility
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Dot indicators only
          Positioned(
            bottom: 12, left: 16,
            child: Row(
              children: List.generate(2, (i) {
                final active = _page == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 5),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPORT TILE
// ─────────────────────────────────────────────────────────────────────────────

class SportTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isMore;

  const SportTile({
    super.key,
    required this.label,
    required this.emoji,
    this.isMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;

    return GestureDetector(
      onTap: () {
        if (isMore) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AllSportsScreen()));
        } else {
          Navigator.of(context).push(PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, _, _) => SportActionGlassScreen(sport: label),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isMore
                  ? null
                  : LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF2A0000), const Color(0xFF120000)]
                          : [
                              primary.withValues(alpha: 0.12),
                              primary.withValues(alpha: 0.06)
                            ],
                    ),
              color: isMore
                  ? (isDark ? AppColors.card : AppColorsLight.card)
                  : null,
              border: Border.all(
                color: primary.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// BANNER SLIDER (kept for potential reuse)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// RESUME SCOREBOARD BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ResumeScoreboardBanner extends StatelessWidget {
  final LiveMatch match;
  const _ResumeScoreboardBanner({required this.match});

  String get _scoreLabel {
    switch (match.sport) {
      case MatchSport.cricket:
        final inn = match.cricket?.currentInnings;
        if (inn == null) return '0/0';
        return '${inn.runs}/${inn.wickets} (${inn.oversStr})';
      case MatchSport.football:
        return '${match.football?.teamAGoals ?? 0} – ${match.football?.teamBGoals ?? 0}';
      case MatchSport.basketball:
        return '${match.basketball?.teamATotal ?? 0} – ${match.basketball?.teamBTotal ?? 0}';
      default:
        final g = match.genericScore;
        if (g != null) return '${g.teamAScore} – ${g.teamBScore}';
        return '–';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveScoreboardScreen(
            matchId: match.id,
            isScorer: true,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primary.withValues(alpha: 0.18),
              primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: primary.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(
          children: [
            _PulseDot(color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.teamA} vs ${match.teamB}',
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${match.sportDisplayName}  •  $_scoreLabel',
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Resume',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

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
        width: 10, height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
