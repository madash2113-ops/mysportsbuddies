import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';

import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/scoreboard_service.dart';
import '../../services/user_service.dart';
import '../community/community_feed_screen.dart';
import '../nearby/nearby_games_screen.dart';
import '../scoreboard/live_matches_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../sports/all_sports_screen.dart';
import '../tournaments/tournaments_list_screen.dart';
import '../common/app_drawer.dart';
import '../games/create_game_screen.dart';
import '../games/game_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../venues/venue_detail_screen.dart';

import '../../services/game_listing_service.dart';
import '../../services/stats_service.dart';
import '../../services/venue_service.dart';
import 'notifications_screen.dart';

/// All sports with emojis. Keys must match stats_service storage keys.
const Map<String, String> _kSportEmoji = {
  'Cricket':      '🏏',
  'Football':     '⚽',
  'Basketball':   '🏀',
  'Badminton':    '🏸',
  'Tennis':       '🎾',
  'Table Tennis': '🏓',
  'Volleyball':   '🏐',
  'Beach Volleyball': '🏖️',
  'Hockey':       '🏑',
  'Ice Hockey':   '🏒',
  'Baseball':     '⚾',
  'Softball':     '🥎',
  'Rugby':        '🏉',
  'American Football': '🏈',
  'Handball':     '🤾',
  'Netball':      '🥅',
  'Boxing':       '🥊',
  'MMA':          '🥋',
  'Wrestling':    '🤼',
  'Fencing':      '🤺',
  'Swimming':     '🏊',
  'Water Polo':   '🤽',
  'Rowing':       '🚣',
  'Athletics':    '🏃',
  'Cycling':      '🚴',
  'Triathlon':    '🏊',
  'Formula One':  '🏎️',
  'Golf':         '⛳',
  'Lacrosse':     '🥍',
  'Polo':         '🐴',
  'Curling':      '🥌',
  'Archery':      '🏹',
  'Shooting':     '🎯',
  'Darts':        '🎯',
  'Snooker':      '🎱',
  'Gymnastics':   '🤸',
  'Weightlifting':'🏋️',
  'Squash':       '🎾',
  'Padel':        '🎾',
  'Kabaddi':      '🤼',
  'Kho Kho':      '🏃',
  'Esports':      '🎮',
};

List<String> get _kAllSports => _kSportEmoji.keys.toList();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Consistent horizontal page padding used by all home-tab sections.
const double _kPageH = 20.0;

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
      _requestInitialPermissions();
    });
  }

  Future<void> _requestInitialPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('permissions_requested') == true) return;

    // Short delay so the home screen renders first
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PermissionDialog(),
    );

    if (accepted == true) {
      await Permission.locationWhenInUse.request();
      await Permission.notification.request();
    }

    await prefs.setBool('permissions_requested', true);
  }

  // 0 = Home, 1 = Tournaments, 2 = Feed, 3 = Scorecard, 4 = Profile
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
      icon: Icon(Icons.scoreboard_outlined),
      activeIcon: Icon(Icons.scoreboard),
      label: 'Scorecard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const TournamentsListScreen(),
      const CommunityFeedScreen(),
      const LiveMatchesScreen(showBackButton: false),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppC.bg(context),
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context),
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
          selectedItemColor: AppC.primary(context),
          unselectedItemColor: AppC.navUnselected(context),
          backgroundColor: AppC.navBar(context),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 12,
          items: _navItems,
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final iconColor = AppC.text(context);
    final primary   = AppC.primary(context);

    return AppBar(
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
        ListenableBuilder(
          listenable: NotificationService(),
          builder: (context, _) {
            final hasUnread = NotificationService().unreadCount > 0;
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none, color: iconColor),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                ),
                if (hasUnread)
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
            );
          },
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

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool    _idCopied      = false;
  String? _selectedSport;          // currently viewed sport in stats section
  bool    _statsLoaded   = false;
  // 'regular' or 'career' — only relevant when Cricket is selected
  String  _cricketMode   = 'regular';
  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await StatsService().load();
    if (!mounted) return;
    final svc = StatsService();
    setState(() {
      _statsLoaded   = true;
      _selectedSport = svc.defaultSport ?? svc.activeSports.firstOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([UserService(), StatsService()]),
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildModeTab(String mode, String label, Color primary) {
    final selected = _cricketMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cricketMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.18)
                : AppC.text(context).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.6)
                  : AppC.border(context),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? primary : AppC.muted(context),
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(
      String sport, StatsService statsSvc, Color primary, bool isDark) {
    final rawStats = statsSvc.statsForSport(sport);
    final Map<String, dynamic>? stats = sport == 'Cricket'
        ? (rawStats?[_cricketMode] as Map?)?.cast<String, dynamic>()
        : (rawStats?[_cricketMode] as Map?)?.cast<String, dynamic>()
          ?? rawStats;

    if (stats != null && stats.isNotEmpty) {
      return _SportStatsCard(
          sport: sport, stats: stats, primary: primary, isDark: isDark);
    }

    final modeLabel = _cricketMode == 'career' ? 'Career' : 'Regular';
    final label = 'No $modeLabel $sport stats yet';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppC.text(context).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppC.border(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.sports_outlined, size: 36, color: AppC.hint(context)),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: AppC.muted(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            sport == 'Cricket' && _cricketMode == 'career'
                ? 'Play tournament matches to build\nyour career stats.'
                : 'Play a scoreboard match in this sport\nand stats will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppC.hint(context), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final primary = AppC.primary(context);
    final isDark  = AppC.isDark(context);
    final profile = UserService().profile;

    final name              = profile?.name     ?? 'Your Name';
    final email             = profile?.email    ?? '';
    final location          = profile?.location ?? '';
    final bio               = profile?.bio      ?? '';
    final numId             = profile?.numericId;
    final statsSvc     = StatsService();
    final activeSports = statsSvc.activeSports;

    // Sync selected sport if it was never set but stats loaded
    if (_statsLoaded && _selectedSport == null && activeSports.isNotEmpty) {
      _selectedSport = statsSvc.defaultSport ?? activeSports.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name centred ──────────────────────────────────────
          Center(
            child: Column(
              children: [
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
                Text(
                  name,
                  style: TextStyle(
                    color: AppC.text(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                // Player ID
                if (numId != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: $numId',
                        style: TextStyle(
                            color: primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: '$numId'));
                          await HapticFeedback.lightImpact();
                          if (!mounted) return;
                          setState(() => _idCopied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _idCopied = false);
                          });
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _idCopied
                              ? Text('Copied!',
                                  key: const ValueKey('copied'),
                                  style: TextStyle(
                                      color: primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600))
                              : Icon(Icons.copy_rounded,
                                  key: const ValueKey('icon'),
                                  size: 14,
                                  color: primary),
                        ),
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
                        color: AppC.muted(context),
                        fontSize: 13),
                  ),
                ],
                // Email / location chips
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
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
              ],
            ),
          ),

          const SizedBox(height: 24),

          const SizedBox(height: 28),

          // ── Sport Stats section ───────────────────────────────────────
          Row(
            children: [
              Text(
                'Sport Stats',
                style: TextStyle(
                    color: AppC.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              if (_selectedSport != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    if (_selectedSport == null) return;
                    final messenger = ScaffoldMessenger.of(context);
                    await StatsService().setDefaultSport(_selectedSport!);
                    if (mounted) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                            '$_selectedSport set as default sport'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: primary,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statsSvc.defaultSport == _selectedSport
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 16,
                        color: statsSvc.defaultSport == _selectedSport
                            ? AppC.warning(context)
                            : AppC.hint(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Set Default',
                        style: TextStyle(
                            color: AppC.hint(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Sport picker button — opens searchable sheet
          GestureDetector(
            onTap: () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _SportPickerSheet(
                  selected: _selectedSport,
                  statsSvc: statsSvc,
                ),
              );
              if (picked != null && mounted) {
                setState(() => _selectedSport = picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppC.text(context).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  if (_selectedSport != null) ...[
                    Text(
                      _kSportEmoji[_selectedSport] ?? '🏅',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedSport!,
                      style: TextStyle(
                          color: AppC.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ] else
                    Text('Select a sport',
                        style: TextStyle(
                            color: AppC.hint(context), fontSize: 14)),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: primary, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Regular / Career toggle — only for Cricket
          if (_selectedSport == 'Cricket') ...[
            Row(children: [
              _buildModeTab('regular', '🏏 Regular', primary),
              const SizedBox(width: 8),
              _buildModeTab('career', '🏆 Career', primary),
            ]),
            const SizedBox(height: 12),
          ],

          // Stats card — or empty state
          if (_selectedSport != null)
            _buildStatsSection(_selectedSport!, statsSvc, primary, isDark),

          const SizedBox(height: 24),

          // ── Edit Profile button ───────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// SPORT STATS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SportStatsCard extends StatefulWidget {
  final String                sport;
  final Map<String, dynamic>  stats;
  final Color                 primary;
  final bool                  isDark;

  const _SportStatsCard({
    required this.sport,
    required this.stats,
    required this.primary,
    required this.isDark,
  });

  @override
  State<_SportStatsCard> createState() => _SportStatsCardState();
}

class _SportStatsCardState extends State<_SportStatsCard> {
  String? _selectedFormat;

  // ── Cricket helper getters ────────────────────────────────────────────────

  Map<String, dynamic> get _bat =>
      (widget.stats['batting'] as Map?)
          ?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _bowl =>
      (widget.stats['bowling'] as Map?)
          ?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> get _formats =>
      (widget.stats['formats'] as Map?)
          ?.cast<String, dynamic>() ?? {};

  int _i(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toInt() ?? 0;

  String _avg(int runs, int innings, int notOuts) {
    final outs = innings - notOuts;
    if (outs == 0) return '-';
    return (runs / outs).toStringAsFixed(1);
  }

  String _sr(int runs, int balls) {
    if (balls == 0) return '-';
    return (runs / balls * 100).toStringAsFixed(1);
  }

  String _eco(int runs, int overs, int balls) {
    final total = overs * 6 + balls;
    if (total == 0) return '-';
    return (runs / total * 6).toStringAsFixed(2);
  }

  // Bowling average = runs conceded / wickets taken
  String _bowlAvg(int runs, int wickets) {
    if (wickets == 0) return '-';
    return (runs / wickets).toStringAsFixed(1);
  }

  // Bowling strike rate = balls bowled / wickets taken
  String _bowlSR(int overs, int balls, int wickets) {
    if (wickets == 0) return '-';
    final totalBalls = overs * 6 + balls;
    return (totalBalls / wickets).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sport == 'Cricket') return _cricketCard();
    // Generic fallback for other sports
    return _genericCard();
  }

  // ── Cricket card ─────────────────────────────────────────────────────────

  Widget _cricketCard() {
    final formatKeys = _formats.keys.toList()..sort();
    _selectedFormat ??= formatKeys.firstOrNull;

    final runs      = _i(_bat, 'runs');
    final balls     = _i(_bat, 'balls');
    final fours     = _i(_bat, 'fours');
    final sixes     = _i(_bat, 'sixes');
    final fifties   = _i(_bat, 'fifties');
    final hundreds  = _i(_bat, 'hundreds');
    final hs        = _i(_bat, 'highestScore');
    final innings   = _i(_bat, 'innings');
    final notOuts   = _i(_bat, 'notOuts');
    final ducks     = _i(_bat, 'ducks');

    final wickets     = _i(_bowl, 'wickets');
    final wRuns       = _i(_bowl, 'runs');
    final wOvers      = _i(_bowl, 'completedOvers');
    final wBalls      = _i(_bowl, 'extraBalls');
    final maidens     = _i(_bowl, 'maidens');
    final bestW       = _i(_bowl, 'bestWickets');
    final bestR       = _i(_bowl, 'bestRuns');
    final fiveWickets = _i(_bowl, 'fiveWickets');

    final cardBg = AppC.card(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Batting summary ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.sports_cricket,
                    size: 14, color: widget.primary),
                const SizedBox(width: 6),
                Text('Batting',
                    style: TextStyle(
                        color: widget.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _CricStat(label: 'Runs',  value: '$runs'),
                _CricStat(label: 'HS',    value: '$hs'),
                _CricStat(label: '50s',   value: '$fifties'),
                _CricStat(label: '100s',  value: '$hundreds'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _CricStat(label: 'Innings', value: '$innings'),
                _CricStat(label: 'Avg',     value: _avg(runs, innings, notOuts)),
                _CricStat(label: 'SR',      value: _sr(runs, balls)),
                _CricStat(label: 'Ducks',   value: '$ducks'),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _CricStat(label: '4s',      value: '$fours'),
                _CricStat(label: '6s',      value: '$sixes'),
                _CricStat(label: 'NO',      value: '$notOuts'),
                const Expanded(child: SizedBox()),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Bowling summary ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.sports_baseball_outlined,
                    size: 14, color: widget.primary),
                const SizedBox(width: 6),
                Text('Bowling',
                    style: TextStyle(
                        color: widget.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _CricStat(label: 'Wickets', value: '$wickets'),
                _CricStat(label: 'Best',    value: wickets == 0 ? '-' : '$bestW/$bestR'),
                _CricStat(label: 'Avg',     value: _bowlAvg(wRuns, wickets)),
                _CricStat(label: 'Economy', value: _eco(wRuns, wOvers, wBalls)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _CricStat(label: 'SR',      value: _bowlSR(wOvers, wBalls, wickets)),
                _CricStat(label: 'Maidens', value: '$maidens'),
                _CricStat(label: '5W',      value: fiveWickets == 0 ? '-' : '$fiveWickets'),
                const Expanded(child: SizedBox()),
              ]),
            ],
          ),
        ),

        // ── Per-format breakdown ─────────────────────────────────────────
        if (formatKeys.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('By Format',
              style: TextStyle(
                  color: AppC.text(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // Format tabs
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: formatKeys.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final fmt = formatKeys[i];
                final isSel = fmt == _selectedFormat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFormat = fmt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSel
                          ? widget.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                          color: isSel
                              ? widget.primary
                              : AppC.border(context)),
                    ),
                    child: Text(fmt,
                        style: TextStyle(
                          color: isSel
                              ? widget.primary
                              : AppC.muted(context),
                          fontSize: 12,
                          fontWeight: isSel
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Format stats
          if (_selectedFormat != null)
            _FormatStatsRow(
              fmtData: (_formats[_selectedFormat!] as Map?)
                      ?.cast<String, dynamic>() ??
                  {},
              primary: widget.primary,
              isDark:  widget.isDark,
            ),
        ],
      ],
    );
  }

  Widget _genericCard() {
    final s = widget.stats;
    final matches = (s['matches'] as num?)?.toInt() ?? 0;
    final wins    = (s['wins']    as num?)?.toInt() ?? 0;
    final losses  = (s['losses']  as num?)?.toInt() ?? 0;
    final draws   = (s['draws']   as num?)?.toInt() ?? 0;
    final winPct  = matches > 0
        ? '${(wins / matches * 100).toStringAsFixed(0)}%'
        : '-';

    // Detect engine type from stored keys to show appropriate detail row.
    final bool isRally   = s.containsKey('setsWon');
    final bool isEsports = s.containsKey('roundsWon');
    final bool isCombat  = !s.containsKey('scored') &&
        !s.containsKey('conceded') &&
        !s.containsKey('points') &&
        !isRally &&
        !isEsports;
    // Basketball uses 'points', football/hockey/generic use 'scored'.
    final bool isBasketball = s.containsKey('points') && !s.containsKey('scored');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppC.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.sports_outlined, size: 14, color: widget.primary),
            const SizedBox(width: 6),
            Text('Overview',
                style: TextStyle(
                    color: widget.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          // Row 1 — always: Played / Won / Lost / Drawn (or Win%)
          Row(children: [
            _CricStat(label: 'Played', value: '$matches'),
            _CricStat(label: 'Won',    value: '$wins'),
            _CricStat(label: 'Lost',   value: '$losses'),
            if (isCombat || isRally || isEsports)
              _CricStat(label: 'Win %', value: winPct)
            else
              _CricStat(label: 'Drawn', value: '$draws'),
          ]),
          // Row 2 — engine-specific detail
          if (!isCombat) ...[
            const SizedBox(height: 10),
            if (isRally)
              Row(children: [
                _CricStat(label: 'Sets Won',  value: '${(s['setsWon'] as num?)?.toInt() ?? 0}'),
                _CricStat(label: 'Sets Lost', value: '${(s['setsLost'] as num?)?.toInt() ?? 0}'),
                _CricStat(label: 'Pts For',   value: '${(s['pointsFor'] as num?)?.toInt() ?? 0}'),
                _CricStat(label: 'Pts Agst',  value: '${(s['pointsAgainst'] as num?)?.toInt() ?? 0}'),
              ])
            else if (isEsports)
              Row(children: [
                _CricStat(label: 'Win %',      value: winPct),
                _CricStat(label: 'Rnds Won',   value: '${(s['roundsWon'] as num?)?.toInt() ?? 0}'),
                _CricStat(label: 'Rnds Lost',  value: '${(s['roundsLost'] as num?)?.toInt() ?? 0}'),
                const Expanded(child: SizedBox()),
              ])
            else if (isBasketball)
              Row(children: [
                _CricStat(label: 'Win %',    value: winPct),
                _CricStat(label: 'Points',   value: '${(s['points'] as num?)?.toInt() ?? 0}'),
                _CricStat(label: 'Conceded', value: '${(s['conceded'] as num?)?.toInt() ?? 0}'),
                const Expanded(child: SizedBox()),
              ])
            else
              // Football, Hockey, Generic — scored/conceded
              Row(children: [
                _CricStat(label: 'Win %',    value: winPct),
                _CricStat(label: 'Scored',   value: '${(s['scored'] as num?)?.toInt() ?? 0}'),
                _CricStat(label: 'Conceded', value: '${(s['conceded'] as num?)?.toInt() ?? 0}'),
                const Expanded(child: SizedBox()),
              ]),
          ],
        ],
      ),
    );
  }
}

// ── Per-format row ────────────────────────────────────────────────────────────

class _FormatStatsRow extends StatelessWidget {
  final Map<String, dynamic> fmtData;
  final Color primary;
  final bool  isDark;

  const _FormatStatsRow({
    required this.fmtData,
    required this.primary,
    required this.isDark,
  });

  int _i(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final bat = (fmtData['batting'] as Map?)?.cast<String, dynamic>() ?? {};
    final bowl= (fmtData['bowling'] as Map?)?.cast<String, dynamic>() ?? {};
    final matches = _i(fmtData, 'matches');
    final hs      = _i(fmtData, 'highestScore');

    final runs        = _i(bat, 'runs');
    final balls       = _i(bat, 'balls');
    final fifties     = _i(bat, 'fifties');
    final hundreds    = _i(bat, 'hundreds');
    final innings     = _i(bat, 'innings');
    final notOuts     = _i(bat, 'notOuts');
    final fours       = _i(bat, 'fours');
    final sixes       = _i(bat, 'sixes');
    final ducks       = _i(bat, 'ducks');

    final wickets     = _i(bowl, 'wickets');
    final wRuns       = _i(bowl, 'runs');
    final wOvers      = _i(bowl, 'completedOvers');
    final wBalls      = _i(bowl, 'extraBalls');
    final maidens     = _i(bowl, 'maidens');
    final fiveWickets = _i(bowl, 'fiveWickets');

    String avg() {
      final outs = innings - notOuts;
      return outs == 0 ? '-' : (runs / outs).toStringAsFixed(1);
    }

    String sr() =>
        balls == 0 ? '-' : (runs / balls * 100).toStringAsFixed(1);

    String eco() {
      final t = wOvers * 6 + wBalls;
      return t == 0 ? '-' : (wRuns / t * 6).toStringAsFixed(2);
    }

    String bowlAvg() =>
        wickets == 0 ? '-' : (wRuns / wickets).toStringAsFixed(1);

    String bowlSR() {
      final t = wOvers * 6 + wBalls;
      return wickets == 0 ? '-' : (t / wickets).toStringAsFixed(1);
    }

    final cardBg = AppC.card(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(children: [
            _CricStat(label: 'Matches', value: '$matches'),
            _CricStat(label: 'Innings', value: '$innings'),
            _CricStat(label: 'Runs',    value: '$runs'),
            _CricStat(label: 'HS',      value: '$hs'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _CricStat(label: '50s',   value: '$fifties'),
            _CricStat(label: '100s',  value: '$hundreds'),
            _CricStat(label: 'Avg',   value: avg()),
            _CricStat(label: 'SR',    value: sr()),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _CricStat(label: '4s',    value: '$fours'),
            _CricStat(label: '6s',    value: '$sixes'),
            _CricStat(label: 'Ducks', value: '$ducks'),
            _CricStat(label: 'NO',    value: '$notOuts'),
          ]),
          if (wickets > 0 || wOvers > 0) ...[
            Divider(
                height: 16,
                color: primary.withValues(alpha: 0.12)),
            Row(children: [
              _CricStat(label: 'Wkts', value: '$wickets'),
              _CricStat(label: 'Avg',  value: bowlAvg()),
              _CricStat(label: 'Eco',  value: eco()),
              _CricStat(label: 'SR',   value: bowlSR()),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _CricStat(label: 'Maidens', value: '$maidens'),
              _CricStat(label: '5W',      value: fiveWickets == 0 ? '-' : '$fiveWickets'),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Single stat cell ──────────────────────────────────────────────────────────

class _CricStat extends StatelessWidget {
  final String label;
  final String value;
  const _CricStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
                color: AppC.text(context),
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                color: AppC.hint(context),
                fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    primary;
  const _InfoChip(
      {required this.icon, required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primary, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    color: AppC.text(context),
                    fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
    final primary = AppC.primary(context);
    final textCol = AppC.text(context);
    final cardBg  = AppC.card(context);
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
            padding: const EdgeInsets.fromLTRB(_kPageH, 10, _kPageH, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: TextStyle(
                        color: AppC.muted(context),
                        fontSize: 13)),
                const SizedBox(height: AppSpacing.xs),
                Text(name.isNotEmpty ? name : 'Athlete',
                    style: TextStyle(
                        color: textCol,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => _openLocationPicker(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14,
                          color: AppC.hint(context)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          location.isNotEmpty
                              ? location.split(',').take(2).join(',').trim()
                              : 'Set your location',
                          style: TextStyle(
                              color: AppC.hint(context),
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: AppC.hint(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sports | Venues toggle ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kPageH),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _ToggleTab(
                    label: 'Sports',
                    icon: Icons.sports_outlined,
                    active: _showSports,
                    primary: primary,
                    onTap: () => setState(() => _showSports = true),
                  ),
                  _ToggleTab(
                    label: 'Venues',
                    icon: Icons.stadium_outlined,
                    active: !_showSports,
                    primary: primary,
                    onTap: () => setState(() => _showSports = false),
                  ),
                ],
              ),
            ),
          ),

          // ── Context banners (live / tournament / next game) ─────────────
          if (_showSports) const _ContextBanners(),

          const SizedBox(height: AppSpacing.md),

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
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                  size: 22,
                  color: active
                      ? AppC.onPrimary(context)
                      : AppC.hint(context)),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: active
                        ? AppC.onPrimary(context)
                        : AppC.muted(context),
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
    final primary = AppC.primary(context);
    final textCol = AppC.text(context);
    final isDark  = AppC.isDark(context);
    final ordered = _orderedSports();

    return RefreshIndicator(
      color: AppC.primary(context),
      backgroundColor: AppC.card(context),
      onRefresh: () async {
        // Data is kept live via Firestore listeners — just re-trigger them
        GameListingService().listenToOpenGames();
        VenueService().listenToVenues();
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Sports" label + See All ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(_kPageH, 0, _kPageH, 10),
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
              padding: const EdgeInsets.symmetric(horizontal: _kPageH),
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
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => NearbyGamesScreen(sport: label),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                color: textCol,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Sports Near You header
          Padding(
            padding: const EdgeInsets.fromLTRB(_kPageH, 0, _kPageH, 10),
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
          const SizedBox(height: AppSpacing.lg),
        ],
        ),
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
    final primary = AppC.primary(context);
    final cardBg  = AppC.card(context);
    final textCol = AppC.text(context);

    return ListenableBuilder(
      listenable: GameListingService(),
      builder: (context, _) {
        final games = [...GameListingService().openGames]
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        if (games.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kPageH),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(_kPageH),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
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
                          color: AppC.hint(context),
                          fontSize: 12)),
                ],
              ),
            ),
          );
        }

        // 2-column grid rendered inside SingleChildScrollView parent
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPageH),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppC.border(context)),
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
                    color: AppC.hint(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(timeStr,
                      style: TextStyle(
                          color: AppC.muted(context),
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
                      color: AppC.hint(context)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(game.venueName as String,
                        style: TextStyle(
                            color: AppC.muted(context),
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
                    : AppC.error(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                spots > 0 ? '$spots spot${spots == 1 ? '' : 's'} left' : 'Full',
                style: TextStyle(
                    color: spots > 0 ? primary : AppC.error(context),
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
    final primary = AppC.primary(context);
    final isDark  = AppC.isDark(context);

    return ListenableBuilder(
      listenable: VenueService(),
      builder: (context, _) {
        final venues = VenueService().venues;

        return RefreshIndicator(
          color: AppC.primary(context),
          backgroundColor: AppC.card(context),
          onRefresh: () async {
            VenueService().listenToVenues();
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                            color: AppC.hint(context)),
                        const SizedBox(height: 12),
                        Text('No venues nearby yet',
                            style: TextStyle(
                                color: AppC.muted(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Check back soon!',
                            style: TextStyle(
                                color: AppC.hint(context),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: _kPageH),
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
                            color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                      color: AppC.text(context),
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
    final bg      = AppC.surface(context);
    final cardBg  = AppC.card(context);
    final textCol = AppC.text(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppC.border(context),
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
                    icon: Icon(Icons.close, color: AppC.hint(context)),
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
                Expanded(child: Divider(color: AppC.border(context))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or search',
                      style: TextStyle(
                          color: AppC.hint(context),
                          fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppC.border(context))),
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
                      color: AppC.hint(context),
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: AppC.hint(context)),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: AppC.hint(context),
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
                            color: AppC.hint(context),
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
                          color: AppC.border(context)),
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
        // Live scoreboard banner — only shown when the current user is the active scorer
        Consumer<ScoreboardService>(
          builder: (context, svc, _) {
            final uid  = UserService().userId;
            final live = svc.all.where((m) =>
                m.status == MatchStatus.live &&
                m.createdByUserId == uid).toList();
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
    final isDark = AppC.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(_kPageH, 6, _kPageH, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
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
                  color: AppC.text(context),
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
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(actionLabel,
                  style: TextStyle(
                      color: AppC.onPrimary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Permission request dialog (first launch) ─────────────────────────────────

class _PermissionDialog extends StatelessWidget {
  const _PermissionDialog();

  @override
  Widget build(BuildContext context) {
    final primary = AppC.primary(context);
    final textCol = AppC.text(context);
    final cardBg  = AppC.card(context);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sports_rounded, color: primary, size: 28),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Enhance Your Experience',
              style: TextStyle(
                color: textCol,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'MySportsBuddies needs a couple of permissions to work best for you:',
              style: TextStyle(color: AppC.muted(context), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            const _PermItem(
              icon: Icons.location_on_outlined,
              title: 'Location',
              subtitle: 'Find games and players near you',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _PermItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Get updates on games, scores & messages',
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Allow',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Not Now',
                  style: TextStyle(
                    color: AppC.muted(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppC.primary(context);
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                color: AppC.text(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
              Text(subtitle, style: TextStyle(
                color: AppC.muted(context), fontSize: 12)),
            ],
          ),
        ),
      ],
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

// ── Sport picker bottom sheet ─────────────────────────────────────────────────

class _SportPickerSheet extends StatefulWidget {
  final String?      selected;
  final StatsService statsSvc;
  const _SportPickerSheet({this.selected, required this.statsSvc});

  @override
  State<_SportPickerSheet> createState() => _SportPickerSheetState();
}

class _SportPickerSheetState extends State<_SportPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _kAllSports
        : _kAllSports
            .where((s) => s.toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppC.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppC.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Select Sport',
                      style: TextStyle(
                          color: AppC.text(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: AppC.muted(context), size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: AppC.text(context), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search sport…',
                  hintStyle: TextStyle(color: AppC.hint(context), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppC.hint(context), size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: AppC.hint(context), size: 16),
                          onPressed: () => _searchCtrl.clear(),
                          padding: EdgeInsets.zero,
                        )
                      : null,
                  filled: true,
                  fillColor: AppC.card(context),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppC.border(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppC.border(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: AppC.primary(context)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: AppC.border(context), height: 1),
            // Sports list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No sport matching "$_query"',
                          style: TextStyle(
                              color: AppC.hint(context), fontSize: 13)),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final sport    = filtered[i];
                        final emoji    = _kSportEmoji[sport] ?? '🏅';
                        final hasStats = widget.statsSvc.statsForSport(sport) != null;
                        final isSelected = sport == widget.selected;

                        return ListTile(
                          onTap: () => Navigator.pop(context, sport),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppC.primary(context).withValues(alpha: 0.2)
                                  : AppC.text(context).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: isSelected
                                  ? Border.all(
                                      color: AppC.primary(context).withValues(alpha: 0.5))
                                  : null,
                            ),
                            child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          title: Text(
                            sport,
                            style: TextStyle(
                              color: isSelected
                                  ? AppC.primary(context)
                                  : AppC.text(context),
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: hasStats
                              ? Text('Stats available',
                                  style: TextStyle(
                                      color: AppC.success(context),
                                      fontSize: 11))
                              : null,
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: AppC.primary(context), size: 20)
                              : null,
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

class BannerImage extends StatelessWidget {
  final String imagePath;
  const BannerImage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
