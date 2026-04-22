import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/search_service.dart';
import '../../services/user_service.dart';
import '../home/notifications_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg      = Color(0xFF080808);
const _sidebar = Color(0xFF0C0C0C);
const _header  = Color(0xFF0A0A0A);
const _tx      = Color(0xFFF2F2F2);
const _m1      = Color(0xFF888888);
const _m2      = Color(0xFF3A3A3A);
const _red     = Color(0xFFDE313B);
const _border  = Color(0xFF1C1C1C);

const _sidebarW = 210.0;
const _headerH  = 64.0;

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
    (Icons.home_rounded,          Icons.home_outlined,          'Home'),
    (Icons.emoji_events_rounded,  Icons.emoji_events_outlined,  'Tournaments'),
    (Icons.scoreboard_rounded,    Icons.scoreboard_outlined,    'Scorecard'),
    (Icons.dynamic_feed_rounded,  Icons.dynamic_feed_outlined,  'Feed'),
    (Icons.location_on_rounded,   Icons.location_on_outlined,   'Venues'),
    (Icons.person_rounded,        Icons.person_outlined,        'Profile'),
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
                _TopHeader(onProfileTap: () => WebShellController().navigateTo(5)),
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
                      filledIcon:   navItems[i].$1,
                      outlinedIcon: navItems[i].$2,
                      label:        navItems[i].$3,
                      active:       i == selectedIndex,
                      onTap:        () => onSelect(i),
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
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(color: _red.withValues(alpha: .30), blurRadius: 12)],
            ),
            alignment: Alignment.center,
            child: const Text('🏅', style: TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: _tx, letterSpacing: -.3,
              ),
              children: const [
                TextSpan(text: 'My'),
                TextSpan(text: 'Sports', style: TextStyle(color: _red)),
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
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? _red
                : (_hover ? Colors.white.withValues(alpha: .05) : Colors.transparent),
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
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : (_hover ? _tx : _m1),
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
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchLayerLink = LayerLink();
  final _overlayController = OverlayPortalController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
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
            child: OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: (context) => CompositedTransformFollower(
                link: _searchLayerLink,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 6),
                child: _SearchDropdown(
                  onClose: () {
                    _overlayController.hide();
                    _searchController.clear();
                    SearchService().clear();
                  },
                ),
              ),
              child: CompositedTransformTarget(
                link: _searchLayerLink,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _searchHover = true),
                  onExit:  (_) => setState(() => _searchHover = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _searchHover
                            ? const Color(0xFF3A3A3A)
                            : _border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(children: [
                      Icon(Icons.search_rounded, color: _m1, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFF2F2F2)),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Search players, tournaments, venues...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF888888)),
                          ),
                          onChanged: (value) {
                            _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 400), () {
                              if (value.trim().length >= 2) {
                                _overlayController.show();
                                SearchService().search(value);
                              } else {
                                _overlayController.hide();
                                SearchService().clear();
                              }
                            });
                          },
                          onTap: () {
                            if (_searchController.text.trim().length >= 2) {
                              _overlayController.show();
                            }
                          },
                        ),
                      ),
                      // Ctrl K pill badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: _m2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Ctrl K',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _m1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (profile?.location.isNotEmpty == true) ...[
            _LocationPill(location: profile!.location),
            const SizedBox(width: 12),
          ],
          const _NotifBell(),
          const SizedBox(width: 12),
          _UserAvatar(
            name:     profile?.name ?? '',
            imageUrl: profile?.imageUrl,
            onTap:    widget.onProfileTap,
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  final String location;
  const _LocationPill({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
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
      ]),
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
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 38, height: 38,
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
                  right: 6, top: 6,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: _red, shape: BoxShape.circle),
                  ),
                ),
            ]),
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
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name.trim().isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : '?';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'profile') widget.onTap();
          if (v == 'logout')  _logout();
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
            child: Row(children: [
              Icon(Icons.person_outline_rounded, color: _m1, size: 16),
              const SizedBox(width: 10),
              Text('My Profile',
                  style: GoogleFonts.inter(color: _tx, fontSize: 13)),
            ]),
          ),
          PopupMenuDivider(height: .8),
          PopupMenuItem(
            value: 'logout',
            child: Row(children: [
              Icon(Icons.logout_rounded, color: _red, size: 16),
              const SizedBox(width: 10),
              Text('Sign Out',
                  style: GoogleFonts.inter(
                    color: _red, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
        child: Builder(builder: (ctx) {
          final photo = ctx.watch<ProfileController>().avatarImage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: photo == null ? _red : Colors.transparent,
              image: photo != null
                  ? DecorationImage(image: photo, fit: BoxFit.cover)
                  : null,
              boxShadow: _hover
                  ? [BoxShadow(color: _red.withValues(alpha: .35), blurRadius: 12)]
                  : null,
            ),
            alignment: Alignment.center,
            child: photo == null
                ? Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  )
                : null,
          );
        }),
      ),
    );
  }
}

// ── Search Dropdown ────────────────────────────────────────────────────────────

class _SearchDropdown extends StatelessWidget {
  final VoidCallback onClose;
  const _SearchDropdown({required this.onClose});

  static const _typeLabels = {
    'user': 'Players',
    'tournament': 'Tournaments',
    'game': 'Games',
    'venue': 'Venues',
  };

  static const _navIndex = {
    'user': 5,
    'tournament': 1,
    'game': 0,
    'venue': 4,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SearchService(),
      builder: (context, _) {
        final svc = SearchService();
        return Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C1C1C)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: svc.loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFDE313B),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : svc.results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No results found',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    )
                  : _buildResults(context, svc.results),
        );
      },
    );
  }

  Widget _buildResults(BuildContext context, List<SearchResult> results) {
    // Group by type
    final grouped = <String, List<SearchResult>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    final sections = <Widget>[];
    grouped.forEach((type, items) {
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            _typeLabels[type] ?? type,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF888888),
              letterSpacing: .5,
            ),
          ),
        ),
      );
      for (final result in items) {
        sections.add(_ResultRow(
          result: result,
          onTap: () {
            onClose();
            WebShellController().navigateTo(_navIndex[result.type] ?? 0);
          },
        ));
      }
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: sections,
        ),
      ),
    );
  }
}

class _ResultRow extends StatefulWidget {
  final SearchResult result;
  final VoidCallback onTap;
  const _ResultRow({required this.result, required this.onTap});

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  bool _hover = false;

  static const _typeIcons = {
    'user': Icons.person_outline_rounded,
    'tournament': Icons.emoji_events_outlined,
    'game': Icons.sports_outlined,
    'venue': Icons.location_on_outlined,
  };

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
          color: _hover
              ? Colors.white.withValues(alpha: .04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A),
                image: widget.result.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.result.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.result.imageUrl == null
                  ? Icon(
                      _typeIcons[widget.result.type] ?? Icons.circle_outlined,
                      size: 15,
                      color: const Color(0xFF888888),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.result.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFF2F2F2),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.result.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF888888),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
