import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/game_listing.dart';
import '../../core/models/tournament.dart';
import '../../services/game_listing_service.dart';
import '../../services/tournament_service.dart';
import '../games/game_detail_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../venues/venues_list_screen.dart';
import 'web_shell.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg     = Color(0xFF080808);
const _card   = Color(0xFF111111);
const _panel  = Color(0xFF0E0E0E);
const _tx     = Color(0xFFF2F2F2);
const _m1     = Color(0xFF888888);
const _m2     = Color(0xFF444444);
const _red    = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);

// ── Sport themes for game cards ────────────────────────────────────────────────
const _kSportThemes = <String, (List<Color>, Color)>{
  'Cricket':     ([Color(0xFF1E3A1A), Color(0xFF0A1A08)], Color(0xFF4CAF50)),
  'Football':    ([Color(0xFF1A3520), Color(0xFF0A1810)], Color(0xFF66BB6A)),
  'Basketball':  ([Color(0xFF3A1F00), Color(0xFF180D00)], Color(0xFFFF9800)),
  'Badminton':   ([Color(0xFF002040), Color(0xFF000A18)], Color(0xFF42A5F5)),
  'Tennis':      ([Color(0xFF1A3000), Color(0xFF0A1400)], Color(0xFFCDDC39)),
  'Volleyball':  ([Color(0xFF1A1A40), Color(0xFF080816)], Color(0xFF7E57C2)),
  'Hockey':      ([Color(0xFF2A1000), Color(0xFF100600)], Color(0xFFFF7043)),
  'Kabaddi':     ([Color(0xFF2A0020), Color(0xFF100010)], Color(0xFFEC407A)),
  'Boxing':      ([Color(0xFF3A0A0A), Color(0xFF180404)], Color(0xFFEF5350)),
  'Table Tennis':([Color(0xFF002030), Color(0xFF000A14)], Color(0xFF26C6DA)),
  'Swimming':    ([Color(0xFF003040), Color(0xFF001018)], Color(0xFF29B6F6)),
  'Rugby':       ([Color(0xFF2A1800), Color(0xFF100A00)], Color(0xFFFFCA28)),
};

(List<Color>, Color) _sportTheme(String sport) =>
    _kSportThemes[sport] ??
    ([const Color(0xFF1A1A2A), const Color(0xFF080810)], _m1);

String _emojiFor(String sport) {
  const m = {
    'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
    'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
    'Hockey': '🏑', 'Boxing': '🥊', 'Kabaddi': '🤼',
    'Handball': '🤾', 'Throwball': '🏐', 'Swimming': '🏊',
    'Rugby': '🏉', 'Golf': '⛳', 'Table Tennis': '🏓',
    'MMA': '🥋', 'Wrestling': '🤼', 'Esports': '🎮',
  };
  return m[sport] ?? '🏅';
}

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

const _kSports = [
  'All Sports', 'Cricket', 'Football', 'Basketball',
  'Badminton', 'Tennis', 'Volleyball', 'Hockey',
  'Kabaddi', 'Boxing', 'Table Tennis', 'Rugby',
];

// ── Root widget ────────────────────────────────────────────────────────────────

class WebHomeDashboard extends StatefulWidget {
  const WebHomeDashboard({super.key});

  @override
  State<WebHomeDashboard> createState() => _WebHomeDashboardState();
}

class _WebHomeDashboardState extends State<WebHomeDashboard> {
  int _tabIndex = 0; // 0 = Sports, 1 = Venues
  String? _sport;    // null = All Sports
  int _panelTab = 0; // 0 = Upcoming Matches, 1 = My Schedule

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sports | Venues tab switch
                _SportsVenuesSwitch(
                  index: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
                // Content
                Expanded(
                  child: _tabIndex == 0
                      ? _SportsModeContent(
                          sport: _sport,
                          onSportChange: (s) => setState(() => _sport = s),
                        )
                      : _VenuesModeContent(),
                ),
              ],
            ),
          ),

          // ── Right panel ───────────────────────────────────────────────────
          _RightPanel(
            activeTab: _panelTab,
            sport: _sport,
            onTabChange: (t) => setState(() => _panelTab = t),
          ),
        ],
      ),
    );
  }
}

// ── Sports | Venues switch ─────────────────────────────────────────────────────

class _SportsVenuesSwitch extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _SportsVenuesSwitch({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(label: 'Sports',  active: index == 0, onTap: () => onChanged(0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(width: 1, height: 18, color: _border),
          ),
          _Tab(label: 'Venues',  active: index == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: _t(
                size: 14,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _tx : _m1,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: active ? 32 : 0,
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sports mode content ────────────────────────────────────────────────────────

class _SportsModeContent extends StatelessWidget {
  final String? sport;
  final ValueChanged<String?> onSportChange;
  const _SportsModeContent({required this.sport, required this.onSportChange});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: _SportDropdown(
            selected: sport,
            onSelect: onSportChange,
          ),
        ),
        // Nearby games
        Expanded(
          child: ListenableBuilder(
            listenable: GameListingService(),
            builder: (context, _) {
              final all = GameListingService().openGames;
              final games = [
                ...(sport == null ? all : all.where((g) => g.sport == sport)),
              ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nearby Games',
                        style: _t(size: 22, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Games near you based on your location and selected sport.',
                        style: _t(size: 13, color: _m1)),
                    const SizedBox(height: 20),
                    if (games.isEmpty)
                      _EmptyState(
                        icon: Icons.sports_soccer_outlined,
                        message: 'No games available right now',
                        sub: 'Check back later or create your own game',
                      )
                    else
                      _NearbyGameGrid(games: games.take(4).toList()),
                    const SizedBox(height: 20),
                    _ViewMoreBtn(
                      label: 'View More Games',
                      onTap: () {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Sport filter dropdown ──────────────────────────────────────────────────────

class _SportDropdown extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _SportDropdown({required this.selected, required this.onSelect});

  @override
  State<_SportDropdown> createState() => _SportDropdownState();
}

class _SportDropdownState extends State<_SportDropdown> {
  final _layerLink = LayerLink();
  final _controller = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final label = widget.selected ?? 'All Sports';
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (_) => CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: _SportDropdownPopover(
            selected: widget.selected,
            onSelect: (s) {
              _controller.hide();
              widget.onSelect(s);
            },
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (_controller.isShowing) {
                _controller.hide();
              } else {
                _controller.show();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sports_rounded, color: _m1, size: 16),
                const SizedBox(width: 8),
                Text(label, style: _t(size: 13, weight: FontWeight.w600)),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SportDropdownPopover extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _SportDropdownPopover({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _kSports.map((s) {
            final isAll = s == 'All Sports';
            final active = isAll ? selected == null : selected == s;
            return _DropdownItem(
              label: isAll ? 'All Sports' : s,
              emoji: isAll ? '🏅' : _emojiFor(s),
              active: active,
              onTap: () => onSelect(isAll ? null : s),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget {
  final String label;
  final String emoji;
  final bool active;
  final VoidCallback onTap;
  const _DropdownItem({
    required this.label, required this.emoji,
    required this.active, required this.onTap,
  });

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: _hover ? Colors.white.withValues(alpha: .04) : Colors.transparent,
          child: Row(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: _t(
                    size: 13,
                    weight: widget.active ? FontWeight.w700 : FontWeight.w500,
                    color: widget.active ? _tx : _m1,
                  )),
            ),
            if (widget.active)
              Icon(Icons.check_rounded, color: _red, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ── 2×2 game card grid ─────────────────────────────────────────────────────────

class _NearbyGameGrid extends StatelessWidget {
  final List<GameListing> games;
  const _NearbyGameGrid({required this.games});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 600 ? 2 : 1;
      final rows = (games.length / cols).ceil();
      return Column(
        children: List.generate(rows, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row < rows - 1 ? 16 : 0),
            child: Row(
              children: List.generate(cols, (col) {
                final idx = row * cols + col;
                if (idx >= games.length) {
                  return const Expanded(child: SizedBox());
                }
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: col > 0 ? 16 : 0),
                    child: _NearbyGameCard(game: games[idx]),
                  ),
                );
              }),
            ),
          );
        }),
      );
    });
  }
}

class _NearbyGameCard extends StatefulWidget {
  final GameListing game;
  const _NearbyGameCard({required this.game});

  @override
  State<_NearbyGameCard> createState() => _NearbyGameCardState();
}

class _NearbyGameCardState extends State<_NearbyGameCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final theme = _sportTheme(g.sport);
    final gradColors = theme.$1;
    final accentColor = theme.$2;
    final spots = g.spotsLeft;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GameDetailScreen(listing: g))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 230,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? accentColor.withValues(alpha: .4)
                  : Colors.white.withValues(alpha: .06),
            ),
            boxShadow: _hover
                ? [BoxShadow(
                    color: gradColors[0].withValues(alpha: .5),
                    blurRadius: 20,
                    offset: const Offset(0, 6))]
                : null,
          ),
          child: Stack(children: [
            // Sport emoji watermark
            Positioned(
              right: -10, bottom: -20,
              child: Opacity(
                opacity: .12,
                child: Text(_emojiFor(g.sport),
                    style: const TextStyle(fontSize: 120)),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sport badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: accentColor.withValues(alpha: .4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_emojiFor(g.sport),
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(g.sport,
                            style: _t(
                              size: 11,
                              weight: FontWeight.w700,
                              color: accentColor,
                            )),
                      ]),
                    ),
                    const Spacer(),
                    // Spots badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: spots <= 3
                            ? const Color(0xFFFF9500).withValues(alpha: .2)
                            : Colors.black.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: spots <= 3
                              ? const Color(0xFFFF9500).withValues(alpha: .5)
                              : Colors.white.withValues(alpha: .15),
                        ),
                      ),
                      child: Text(
                        '$spots Spots Left',
                        style: _t(
                          size: 11,
                          weight: FontWeight.w700,
                          color: spots <= 3
                              ? const Color(0xFFFF9500)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ]),
                  const Spacer(),
                  // Match title — use sport as the "match title" since
                  // GameListing doesn't have team names
                  Text(
                    '${g.sport} · Open Game',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: _t(size: 18, weight: FontWeight.w800, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  // Meta
                  _CardMeta(Icons.calendar_today_outlined,
                      _fmtDate(g.scheduledAt)),
                  const SizedBox(height: 5),
                  _CardMeta(Icons.access_time_rounded,
                      _fmtTime(g.scheduledAt)),
                  if (g.address.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _CardMeta(Icons.location_on_outlined, g.address),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CardMeta(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 12, color: Colors.white60),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: _t(size: 12, color: Colors.white70),
        ),
      ),
    ]);
  }
}

class _ViewMoreBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ViewMoreBtn({required this.label, required this.onTap});

  @override
  State<_ViewMoreBtn> createState() => _ViewMoreBtnState();
}

class _ViewMoreBtnState extends State<_ViewMoreBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .05)
                : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(widget.label,
                style: _t(size: 13, weight: FontWeight.w600, color: _m1)),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: _m1, size: 15),
          ]),
        ),
      ),
    );
  }
}

// ── Venues mode content ────────────────────────────────────────────────────────

class _VenuesModeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VenuesListScreen())),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded, color: _red, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Browse Venues',
                  style: _t(size: 20, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Discover and book the best sports venues near you',
                  style: _t(size: 14, color: _m1)),
              const SizedBox(height: 24),
              _WebBtn(
                label: 'Explore Venues',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const VenuesListScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _WebBtn({required this.label, required this.onTap});

  @override
  State<_WebBtn> createState() => _WebBtnState();
}

class _WebBtnState extends State<_WebBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
              color: _red.withValues(alpha: _hover ? .4 : .25),
              blurRadius: 16,
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label,
                style: _t(size: 14, weight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ── Right slide-out panel ──────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final int activeTab;
  final String? sport;
  final ValueChanged<int> onTabChange;

  const _RightPanel({
    required this.activeTab,
    required this.sport,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _border, width: .8)),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _border, width: .8)),
            ),
            child: Text(
              activeTab == 0 ? 'Upcoming Matches' : 'My Schedule',
              style: _t(size: 16, weight: FontWeight.w800),
            ),
          ),
          // Panel content — list on left, vertical tab buttons on right
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: animated content area
                  Expanded(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        GameListingService(),
                        TournamentService(),
                      ]),
                      builder: (context, _) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Container(
                            key: ValueKey(activeTab),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E0E0E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            child: activeTab == 0
                                ? _UpcomingMatchesContent(sport: sport)
                                : _MyScheduleContent(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right: vertical tab buttons column
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        _PanelTabBtn(
                          label: 'Upcoming',
                          active: activeTab == 0,
                          onTap: () => onTabChange(0),
                        ),
                        const SizedBox(height: 8),
                        _PanelTabBtn(
                          label: 'Schedule',
                          active: activeTab == 1,
                          onTap: () => onTabChange(1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border, width: .8)),
            ),
            child: _ViewMoreBtn(
              label: activeTab == 0
                  ? 'View All Matches'
                  : 'View Full Schedule',
              onTap: () => WebShellController().navigateTo(2), // → Scorecard
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTabBtn extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PanelTabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  State<_PanelTabBtn> createState() => _PanelTabBtnState();
}

class _PanelTabBtnState extends State<_PanelTabBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? _red
                : (_hover
                    ? Colors.white.withValues(alpha: .06)
                    : Colors.white.withValues(alpha: .03)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.active
                  ? _red
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: _t(
              size: 11,
              weight: FontWeight.w600,
              color: widget.active ? Colors.white : _m1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Upcoming matches panel content ─────────────────────────────────────────────

class _UpcomingMatchesContent extends StatelessWidget {
  final String? sport;
  const _UpcomingMatchesContent({this.sport});

  @override
  Widget build(BuildContext context) {
    final all = GameListingService().openGames;
    final filtered = sport == null
        ? all
        : all.where((g) => g.sport == sport).toList();
    final sorted = [...filtered]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    if (sorted.isEmpty) {
      return _EmptyState(
        icon: Icons.calendar_today_outlined,
        message: 'No upcoming matches',
        sub: sport != null ? 'Try selecting a different sport' : '',
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      separatorBuilder: (_, _) =>
          Container(height: .8, color: _border, margin:
              const EdgeInsets.symmetric(horizontal: 4)),
      itemBuilder: (context, i) => _UpcomingRow(game: sorted[i]),
    );
  }
}

class _UpcomingRow extends StatefulWidget {
  final GameListing game;
  const _UpcomingRow({required this.game});

  @override
  State<_UpcomingRow> createState() => _UpcomingRowState();
}

class _UpcomingRowState extends State<_UpcomingRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final theme = _sportTheme(g.sport);
    final accent = theme.$2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GameDetailScreen(listing: g))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? Colors.white.withValues(alpha: .03) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            // Sport icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(_emojiFor(g.sport),
                  style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${g.sport} · Open Game',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: _t(size: 13, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtDate(g.scheduledAt)} · ${_fmtTime(g.scheduledAt)}',
                    style: _t(size: 11, color: _m1),
                  ),
                  Text(
                    g.address.isNotEmpty ? g.address : 'Location TBD',
                    overflow: TextOverflow.ellipsis,
                    style: _t(size: 11, color: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${g.spotsLeft}',
                style: _t(size: 11, weight: FontWeight.w700, color: accent),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── My Schedule panel content ──────────────────────────────────────────────────

class _MyScheduleContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tours = TournamentService().tournaments
        .where((t) => t.status != TournamentStatus.completed)
        .take(8)
        .toList();

    if (tours.isEmpty) {
      return _EmptyState(
        icon: Icons.event_outlined,
        message: 'No scheduled events',
        sub: 'Join a tournament to see your schedule',
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: tours.length,
      separatorBuilder: (_, _) =>
          Container(height: .8, color: _border,
              margin: const EdgeInsets.symmetric(horizontal: 4)),
      itemBuilder: (context, i) => _TournamentRow(tour: tours[i]),
    );
  }
}

class _TournamentRow extends StatefulWidget {
  final Tournament tour;
  const _TournamentRow({required this.tour});

  @override
  State<_TournamentRow> createState() => _TournamentRowState();
}

class _TournamentRowState extends State<_TournamentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tour;
    final accent = _sportTheme(t.sport).$2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => TournamentDetailScreen(tournamentId: t.id))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? Colors.white.withValues(alpha: .03) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(_emojiFor(t.sport),
                  style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: _t(size: 13, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(t.sport,
                      style: _t(size: 11, color: accent,
                          weight: FontWeight.w600)),
                  Text(t.location,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 11, color: _m1)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Shared empty state ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState(
      {required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _m2, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: _t(size: 14, weight: FontWeight.w600, color: _m1),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: _t(size: 12, color: _m2)),
          ],
        ]),
      ),
    );
  }
}
