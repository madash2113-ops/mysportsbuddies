import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/models/player_entry.dart';
import '../../core/search/player_search_service.dart';
import '../../controllers/profile_controller.dart';
import '../../services/game_listing_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../community/user_profile_screen.dart';
import '../home/notifications_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import 'web_avatar.dart';
import 'web_game_detail_dialog.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg = Color(0xFF080808);
const _sidebar = Color(0xFF0C0C0C);
const _header = Color(0xFF0A0A0A);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);

const _sidebarW = 210.0;
const _headerH = 64.0;

// ── Cross-page navigation controller ──────────────────────────────────────────

class WebShellController extends ValueNotifier<int> {
  WebShellController._() : super(0);
  static final WebShellController _i = WebShellController._();
  factory WebShellController() => _i;

  void navigateTo(int index) => value = index;
}

// ── Shell ──────────────────────────────────────────────────────────────────────

class WebShell extends StatefulWidget {
  final List<Widget> pages;
  const WebShell({super.key, required this.pages});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  @override
  void initState() {
    super.initState();
    WebShellController().addListener(_onNav);
  }

  @override
  void dispose() {
    WebShellController().removeListener(_onNav);
    super.dispose();
  }

  void _onNav() => setState(() {});
  int get _index => WebShellController().value;

  static const _navItems = <(IconData, IconData, String)>[
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Tournaments'),
    (Icons.leaderboard_rounded, Icons.leaderboard_outlined, 'Scorecard'),
    (Icons.article_rounded, Icons.article_outlined, 'Feed'),
    (Icons.location_on_rounded, Icons.location_on_outlined, 'Venues'),
    (Icons.person_rounded, Icons.person_outlined, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _index,
            navItems: _navItems,
            onSelect: WebShellController().navigateTo,
          ),
          Container(width: .8, color: _border),
          Expanded(
            child: Column(
              children: [
                _TopHeader(
                  onProfileTap: () => WebShellController().navigateTo(5),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index.clamp(0, widget.pages.length - 1),
                    children: widget.pages,
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

// ── Sidebar ────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<(IconData, IconData, String)> navItems;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _sidebarW,
      color: _sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarLogo(),
          Container(height: .8, color: _border),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  for (int i = 0; i < navItems.length; i++)
                    _SideNavItem(
                      filledIcon: navItems[i].$1,
                      outlinedIcon: navItems[i].$2,
                      label: navItems[i].$3,
                      active: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),
          Container(height: .8, color: _border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'MySportsBuddies v1.0',
              style: GoogleFonts.inter(fontSize: 10, color: _m2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(color: _red.withValues(alpha: .30), blurRadius: 12),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _tx,
                letterSpacing: -.3,
              ),
              children: const [
                TextSpan(text: 'My'),
                TextSpan(
                  text: 'Sports',
                  style: TextStyle(color: _red),
                ),
                TextSpan(text: 'Buddies'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.filledIcon,
    required this.outlinedIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? _red
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                active ? widget.filledIcon : widget.outlinedIcon,
                size: 18,
                color: active ? Colors.white : (_hover ? _tx : _m1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : (_hover ? _tx : _m1),
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

// ── Top header ─────────────────────────────────────────────────────────────────

class _TopHeader extends StatefulWidget {
  final VoidCallback onProfileTap;
  const _TopHeader({required this.onProfileTap});

  @override
  State<_TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<_TopHeader> {
  bool _searchHover = false;

  Future<void> _openGlobalSearch() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (_) => const _WebGlobalSearchDialog(),
    );
  }

  Future<void> _openLocationSearch() async {
    final selected = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .55),
      builder: (_) => const _WebLocationSearchDialog(),
    );
    if (selected == null || selected.isEmpty) return;
    final profile = UserService().profile;
    if (profile != null) {
      await UserService().saveProfile(profile.copyWith(location: selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserService>().profile;
    return Container(
      height: _headerH,
      decoration: BoxDecoration(
        color: _header,
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _searchHover = true),
              onExit: (_) => setState(() => _searchHover = false),
              child: GestureDetector(
                onTap: _openGlobalSearch,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _searchHover
                          ? _red.withValues(alpha: .55)
                          : _border,
                    ),
                    boxShadow: _searchHover
                        ? [
                            BoxShadow(
                              color: _red.withValues(alpha: .12),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: _red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search players, tournaments, or games...',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, color: _m1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _LocationPill(
            location: profile?.location.isNotEmpty == true
                ? profile!.location
                : 'Set location',
            onTap: _openLocationSearch,
          ),
          const SizedBox(width: 12),
          const _NotifBell(),
          const SizedBox(width: 12),
          _UserAvatar(
            name: profile?.name ?? '',
            imageUrl: profile?.imageUrl,
            onTap: widget.onProfileTap,
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  final String location;
  final VoidCallback onTap;
  const _LocationPill({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, color: _red, size: 13),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  location,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: _m1, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  const _NotifBell();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService(),
      builder: (context, _) {
        final unread = NotificationService().unreadCount;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Icon(
                    unread > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    size: 19,
                    color: unread > 0 ? _red : _m1,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
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

class _UserAvatar extends StatefulWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  const _UserAvatar({required this.name, this.imageUrl, required this.onTap});

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  bool _hover = false;

  Future<void> _logout() async {
    final nav = Navigator.of(context, rootNavigator: true);
    await AuthService().signOut();
    if (!mounted) return;
    nav.pushNamedAndRemoveUntil('/web-landing', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name.trim().isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : '?';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'profile') widget.onTap();
          if (v == 'logout') _logout();
        },
        offset: const Offset(0, 46),
        color: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, color: _m1, size: 16),
                const SizedBox(width: 10),
                Text(
                  'My Profile',
                  style: GoogleFonts.inter(color: _tx, fontSize: 13),
                ),
              ],
            ),
          ),
          PopupMenuDivider(height: .8),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: _red, size: 16),
                const SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: GoogleFonts.inter(
                    color: _red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        child: Builder(
          builder: (ctx) {
            final controller = ctx.watch<ProfileController>();
            final imageUrl = controller.networkImageUrl ?? widget.imageUrl;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _hover
                    ? [
                        BoxShadow(
                          color: _red.withValues(alpha: .35),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: WebAvatar(
                imageUrl: imageUrl,
                displayName: widget.name.isNotEmpty ? widget.name : initials,
                size: 38,
                backgroundColor: _red,
                textColor: Colors.white,
                borderColor: Colors.white.withValues(alpha: .12),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WebGlobalSearchDialog extends StatefulWidget {
  const _WebGlobalSearchDialog();

  @override
  State<_WebGlobalSearchDialog> createState() => _WebGlobalSearchDialogState();
}

class _WebGlobalSearchDialogState extends State<_WebGlobalSearchDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loadingPlayers = false;
  List<PlayerSearchResult> _players = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value.trim());
    _debounce?.cancel();
    if (_query.length < 2) {
      setState(() {
        _players = [];
        _loadingPlayers = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), _searchPlayers);
  }

  Future<void> _searchPlayers() async {
    final query = _query;
    setState(() => _loadingPlayers = true);
    try {
      final results = await PlayerSearchService().search(
        query,
        includeManual: false,
      );
      if (!mounted || query != _query) return;
      setState(() {
        _players = results.take(4).toList();
        _loadingPlayers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlayers = false);
    }
  }

  bool _matches(String text) =>
      text.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.length >= 2;
    final games = hasQuery
        ? GameListingService().openGames
              .where(
                (g) =>
                    _matches(g.sport) ||
                    _matches(g.venueName) ||
                    _matches(g.address) ||
                    _matches(g.organizerName),
              )
              .take(4)
              .toList()
        : const [];
    final tournaments = hasQuery
        ? TournamentService().tournaments
              .where(
                (t) =>
                    _matches(t.name) ||
                    _matches(t.sport) ||
                    _matches(t.location),
              )
              .take(4)
              .toList()
        : const [];

    return Dialog(
      backgroundColor: const Color(0xFF101010),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: SizedBox(
        width: 640,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Search',
                    style: GoogleFonts.inter(
                      color: _tx,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _m1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: GoogleFonts.inter(color: _tx, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search player, tournament, or game...',
                  hintStyle: GoogleFonts.inter(color: _m1, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _m1),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _red),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _SearchSection(
                        title: 'Players',
                        loading: _loadingPlayers,
                        empty: hasQuery && !_loadingPlayers && _players.isEmpty,
                        emptyLabel: 'No players found',
                        children: [
                          for (final result in _players)
                            _SearchResultTile(
                              icon: Icons.person_rounded,
                              imageUrl: result.entry.imageUrl,
                              avatarLabel: result.entry.displayName,
                              title: result.entry.displayName,
                              subtitle: _playerSubtitle(result.entry),
                              onTap: result.entry.userId == null
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(
                                            userId: result.entry.userId!,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
                      _SearchSection(
                        title: 'Tournaments',
                        empty: hasQuery && tournaments.isEmpty,
                        emptyLabel: 'No tournaments found',
                        children: [
                          for (final tournament in tournaments)
                            _SearchResultTile(
                              icon: Icons.emoji_events_rounded,
                              title: tournament.name,
                              subtitle:
                                  '${tournament.sport} - ${tournament.location}',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TournamentDetailScreen(
                                      tournamentId: tournament.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      _SearchSection(
                        title: 'Games',
                        empty: hasQuery && games.isEmpty,
                        emptyLabel: 'No games found',
                        children: [
                          for (final game in games)
                            _SearchResultTile(
                              icon: Icons.sports_rounded,
                              title: game.venueName.isNotEmpty
                                  ? game.venueName
                                  : '${game.sport} Game',
                              subtitle: '${game.sport} - ${game.organizerName}',
                              onTap: () {
                                Navigator.pop(context);
                                openWebGameDetail(context, listing: game);
                              },
                            ),
                        ],
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

  String _playerSubtitle(PlayerEntry entry) {
    final parts = <String>[];
    final numericId = entry.numericId;
    final details = entry.subtitle;
    if (numericId != null) parts.add('Player ID $numericId');
    if (details.isNotEmpty) parts.add(details);
    return parts.isEmpty ? 'Player' : parts.join('  ·  ');
  }
}

class _SearchSection extends StatelessWidget {
  final String title;
  final bool loading;
  final bool empty;
  final String emptyLabel;
  final List<Widget> children;

  const _SearchSection({
    required this.title,
    this.loading = false,
    this.empty = false,
    required this.emptyLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && !empty && children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _m1,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _red),
                ),
              ),
            )
          else if (empty)
            _SearchEmpty(label: emptyLabel)
          else
            ...children,
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;
  final String? avatarLabel;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.icon,
    this.imageUrl,
    this.avatarLabel,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              if (imageUrl != null || avatarLabel != null)
                WebAvatar(
                  imageUrl: imageUrl,
                  displayName: avatarLabel ?? title,
                  size: 34,
                  backgroundColor: _red.withValues(alpha: .22),
                  textColor: Colors.white,
                  borderColor: _red.withValues(alpha: .25),
                )
              else
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _red, size: 18),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _tx,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: _m1, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: _m1, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  final String label;
  const _SearchEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Text(label, style: GoogleFonts.inter(color: _m1, fontSize: 12)),
    );
  }
}

class _WebLocationSearchDialog extends StatefulWidget {
  const _WebLocationSearchDialog();

  @override
  State<_WebLocationSearchDialog> createState() =>
      _WebLocationSearchDialogState();
}

class _WebLocationSearchDialogState extends State<_WebLocationSearchDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  bool _detecting = false;
  List<String> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'limit': '6',
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MySportsBuddies/1.0', 'Accept-Language': 'en'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _results = data.map(_shortPlaceName).toSet().toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _shortPlaceName(dynamic item) {
    final address = item['address'] as Map<String, dynamic>?;
    if (address == null) return item['display_name'] as String? ?? '';
    final parts = <String>[];
    for (final key in [
      'suburb',
      'city',
      'town',
      'village',
      'state',
      'country',
    ]) {
      final value = address[key];
      if (value is String && value.isNotEmpty && !parts.contains(value)) {
        parts.add(value);
      }
      if (parts.length >= 3) break;
    }
    return parts.isEmpty
        ? item['display_name'] as String? ?? ''
        : parts.join(', ');
  }

  Future<void> _detectLocation() async {
    setState(() => _detecting = true);
    try {
      final position = await LocationService().getCurrentPosition();
      if (position == null) {
        if (mounted) setState(() => _detecting = false);
        return;
      }
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': position.latitude.toString(),
        'lon': position.longitude.toString(),
        'addressdetails': '1',
      });
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MySportsBuddies/1.0', 'Accept-Language': 'en'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final location = _shortPlaceName(data);
        if (location.isNotEmpty && mounted) Navigator.pop(context, location);
      } else {
        setState(() => _detecting = false);
      }
    } catch (_) {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101010),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Set Location',
                    style: GoogleFonts.inter(
                      color: _tx,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _m1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: GoogleFonts.inter(color: _tx, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search city, area, or address...',
                  hintStyle: GoogleFonts.inter(color: _m1, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _m1),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _red,
                            ),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _red),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _detecting ? null : _detectLocation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withValues(alpha: .30)),
                    ),
                    child: Row(
                      children: [
                        _detecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _red,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: _red,
                                size: 18,
                              ),
                        const SizedBox(width: 10),
                        Text(
                          _detecting
                              ? 'Detecting your location...'
                              : 'Auto-detect my location',
                          style: GoogleFonts.inter(
                            color: _red,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        Container(height: .8, color: _border),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: _red,
                          size: 18,
                        ),
                        title: Text(
                          result,
                          style: GoogleFonts.inter(color: _tx, fontSize: 13),
                        ),
                        onTap: () => Navigator.pop(context, result),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
