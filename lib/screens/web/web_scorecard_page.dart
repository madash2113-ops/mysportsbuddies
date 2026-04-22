import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/match_score.dart';
import '../../services/scoreboard_service.dart';
import '../../services/user_service.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../scoreboard/scoreboard_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg     = Color(0xFF080808);
const _card   = Color(0xFF111111);
const _panel  = Color(0xFF0E0E0E);
const _tx     = Color(0xFFF2F2F2);
const _m1     = Color(0xFF888888);
const _m2     = Color(0xFF3A3A3A);
const _red    = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _green  = Color(0xFF30D158);
const _orange = Color(0xFFFF9F0A);
const _blue   = Color(0xFF0A84FF);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

String _emojiFor(String sport) {
  const m = {
    'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
    'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
    'Hockey': '🏑', 'Boxing': '🥊', 'Kabaddi': '🤼',
    'Table Tennis': '🏓', 'Rugby Union': '🏉', 'Rugby League': '🏉',
  };
  return m[sport] ?? '🏅';
}

Color _sportAccent(String sport) {
  const m = {
    'Cricket': Color(0xFF4CAF50), 'Football': Color(0xFF66BB6A),
    'Basketball': Color(0xFFFF9800), 'Badminton': Color(0xFF42A5F5),
    'Tennis': Color(0xFFCDDC39), 'Volleyball': Color(0xFF7E57C2),
    'Hockey': Color(0xFFFF7043), 'Boxing': Color(0xFFEF5350),
  };
  return m[sport] ?? _red;
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24)   return '${diff.inHours} hr ago';
  return '${diff.inDays} days ago';
}

bool _isLive(LiveMatch m)      => m.status == MatchStatus.live;
bool _isCompleted(LiveMatch m) => m.status == MatchStatus.completed;

// ── Page ───────────────────────────────────────────────────────────────────────

class WebScorecardPage extends StatefulWidget {
  const WebScorecardPage({super.key});

  @override
  State<WebScorecardPage> createState() => _WebScorecardPageState();
}

class _WebScorecardPageState extends State<WebScorecardPage> {
  String? _sport;
  // 'live' | 'completed' | 'scheduled' | null=all
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Consumer<ScoreboardService>(
              builder: (context, svc, _) {
                final uid = UserService().userId ?? '';
                final all = uid.isEmpty
                    ? (svc.all.toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                    : (svc.all
                        .where((m) =>
                            m.createdByUserId == uid ||
                            m.teamAPlayerUserIds.contains(uid) ||
                            m.teamBPlayerUserIds.contains(uid))
                        .toList()
                      ..sort(
                          (a, b) => b.createdAt.compareTo(a.createdAt)));

                var filtered = List<LiveMatch>.from(all);
                if (_sport != null) {
                  filtered = filtered
                      .where((m) => m.sportDisplayName == _sport)
                      .toList();
                }
                if (_statusFilter != null) {
                  filtered = filtered.where((m) {
                    if (_statusFilter == 'live')      return _isLive(m);
                    if (_statusFilter == 'completed') return _isCompleted(m);
                    if (_statusFilter == 'scheduled') return !_isLive(m) && !_isCompleted(m);
                    return true;
                  }).toList();
                }

                final liveMatches = filtered.where(_isLive).toList();
                final featuredLive =
                    liveMatches.isNotEmpty ? liveMatches.first : null;

                final sports = <String>{};
                for (final m in all) {
                  if (m.sportDisplayName.isNotEmpty) {
                    sports.add(m.sportDisplayName);
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(context)),
                    SliverToBoxAdapter(
                        child: _buildFilterRow(sports.toList()..sort())),
                    if (featuredLive != null)
                      SliverToBoxAdapter(
                          child: _FeaturedLiveBanner(match: featuredLive)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(children: [
                          Text('All Scoreboards',
                              style: _t(size: 16, weight: FontWeight.w800)),
                          const Spacer(),
                          _SortPill(),
                        ]),
                      ),
                    ),
                    _ScorecardGrid(matches: filtered),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                  ],
                );
              },
            ),
          ),
          _RightStatsPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scorecard', style: _t(size: 26, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Live scores, match updates and results.',
                    style: _t(size: 14, color: _m1)),
              ],
            ),
          ),
          _RedBtn(
            icon: Icons.add_rounded,
            label: '+ Create Scoreboard',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScoreboardScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(List<String> sports) {
    const statuses = <(String?, String)>[
      (null, 'All Status'),
      ('live', 'Live'),
      ('completed', 'Completed'),
      ('scheduled', 'Scheduled'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _FilterDropdown(
            label: _sport ?? 'All Sports',
            icon: Icons.sports_rounded,
            items: [
              const ('All Sports', null),
              for (final s in sports) (s, s),
            ],
            onSelect: (v) => setState(() => _sport = v),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            label: statuses
                .firstWhere((s) => s.$1 == _statusFilter,
                    orElse: () => const (null, 'All Status'))
                .$2,
            icon: Icons.radio_button_checked_rounded,
            items: statuses.map((s) => (s.$2, s.$1)).toList(),
            onSelect: (v) => setState(() => _statusFilter = v),
          ),
        ]),
      ),
    );
  }
}

// ── Filter dropdown ────────────────────────────────────────────────────────────

class _FilterDropdown extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<(String, String?)> items;
  final ValueChanged<String?> onSelect;

  const _FilterDropdown({
    required this.label, required this.icon,
    required this.items, required this.onSelect,
  });

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  final _link = LayerLink();
  final _ctrl = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _ctrl,
        overlayChildBuilder: (_) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints:
                  const BoxConstraints(maxWidth: 200, maxHeight: 300),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .5),
                    blurRadius: 16, offset: const Offset(0, 6),
                  )
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: widget.items.map((item) {
                  return _DropdownItem(
                    label: item.$1,
                    onTap: () {
                      _ctrl.hide();
                      widget.onSelect(item.$2);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () =>
                _ctrl.isShowing ? _ctrl.hide() : _ctrl.show(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: _m1, size: 15),
                const SizedBox(width: 7),
                Text(widget.label,
                    style: _t(size: 13, weight: FontWeight.w600)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: _m1, size: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _DropdownItem({required this.label, required this.onTap});

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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: _hover
              ? Colors.white.withValues(alpha: .04)
              : Colors.transparent,
          child: Text(widget.label,
              style: _t(
                size: 13,
                color: _hover ? _tx : _m1,
                weight: FontWeight.w500,
              )),
        ),
      ),
    );
  }
}

// ── Featured live banner ───────────────────────────────────────────────────────

class _FeaturedLiveBanner extends StatelessWidget {
  final LiveMatch match;
  const _FeaturedLiveBanner({required this.match});

  @override
  Widget build(BuildContext context) {
    final accent = _sportAccent(match.sportDisplayName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => LiveScoreboardScreen(matchId: match.id))),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_red.withValues(alpha: .2), Colors.transparent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _red.withValues(alpha: .25)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _red.withValues(alpha: .5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: _red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('LIVE NOW',
                      style: _t(size: 10, weight: FontWeight.w800,
                          color: _red, height: 1)),
                ]),
              ),
              const SizedBox(width: 20),
              Text(_emojiFor(match.sportDisplayName),
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.sportDisplayName,
                        style: _t(size: 11, color: accent,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(
                          match.teamA.isNotEmpty ? match.teamA : 'Team A',
                          style: _t(size: 16, weight: FontWeight.w800,
                              height: 1.2),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('VS',
                            style: _t(size: 14, weight: FontWeight.w800,
                                color: _red)),
                      ),
                      Expanded(
                        child: Text(
                          match.teamB.isNotEmpty ? match.teamB : 'Team B',
                          textAlign: TextAlign.right,
                          style: _t(size: 16, weight: FontWeight.w800,
                              height: 1.2),
                        ),
                      ),
                    ]),
                    if (match.format.isNotEmpty)
                      Text(match.format,
                          style: _t(size: 12, color: _m1)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _RedBtn(
                label: 'View Scoreboard',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LiveScoreboardScreen(matchId: match.id))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Scoreboard grid ────────────────────────────────────────────────────────────

class _ScorecardGrid extends StatelessWidget {
  final List<LiveMatch> matches;
  const _ScorecardGrid({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.scoreboard_outlined, color: _m2, size: 48),
              const SizedBox(height: 12),
              Text('No scoreboards found',
                  style: _t(size: 15, color: _m1, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Create a scoreboard to track your matches',
                  style: _t(size: 13, color: _m2)),
            ]),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.55,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _ScorecardCard(match: matches[i]),
          childCount: matches.length,
        ),
      ),
    );
  }
}

class _ScorecardCard extends StatefulWidget {
  final LiveMatch match;
  const _ScorecardCard({required this.match});

  @override
  State<_ScorecardCard> createState() => _ScorecardCardState();
}

class _ScorecardCardState extends State<_ScorecardCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final accent = _sportAccent(m.sportDisplayName);
    final live      = _isLive(m);
    final completed = _isCompleted(m);
    final statusLabel =
        live ? 'Live' : completed ? 'Completed' : 'Scheduled';
    final statusColor =
        live ? _red : completed ? _green : _blue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => LiveScoreboardScreen(matchId: m.id))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? (live
                      ? _red.withValues(alpha: .4)
                      : accent.withValues(alpha: .3))
                  : Colors.white.withValues(alpha: .06),
            ),
            boxShadow: _hover && live
                ? [BoxShadow(
                    color: _red.withValues(alpha: .1),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Text(_emojiFor(m.sportDisplayName),
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(m.sportDisplayName,
                    style: _t(size: 12, color: accent,
                        weight: FontWeight.w600)),
                if (m.format.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(m.format,
                      style: _t(size: 11, color: _m2)),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: statusColor.withValues(alpha: .4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (live)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                              color: _red, shape: BoxShape.circle),
                        ),
                      ),
                    Text(statusLabel,
                        style: _t(size: 10, weight: FontWeight.w700,
                            color: statusColor, height: 1)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              // Teams vs
              Row(children: [
                Expanded(
                  child: Text(
                    m.teamA.isNotEmpty ? m.teamA : 'Team A',
                    style: _t(size: 15, weight: FontWeight.w800, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: live
                          ? _red.withValues(alpha: .12)
                          : Colors.white.withValues(alpha: .04),
                      border: Border.all(
                        color: live
                            ? _red.withValues(alpha: .3)
                            : _border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text('VS',
                        style: _t(size: 9, weight: FontWeight.w800,
                            color: live ? _red : _m1)),
                  ),
                ),
                Expanded(
                  child: Text(
                    m.teamB.isNotEmpty ? m.teamB : 'Team B',
                    textAlign: TextAlign.right,
                    style: _t(size: 15, weight: FontWeight.w800, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              const Spacer(),
              // Footer
              Row(children: [
                if (m.venue.isNotEmpty) ...[
                  Icon(Icons.location_on_outlined, size: 11, color: _m2),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(m.venue,
                        overflow: TextOverflow.ellipsis,
                        style: _t(size: 11, color: _m2)),
                  ),
                ] else
                  Expanded(
                    child: Text(_timeAgo(m.createdAt),
                        style: _t(size: 11, color: _m2)),
                  ),
                Text('View →',
                    style: _t(size: 11, weight: FontWeight.w600,
                        color: live ? _red : _m1)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Right stats panel ──────────────────────────────────────────────────────────

class _RightStatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _border, width: .8)),
      ),
      child: Consumer<ScoreboardService>(
        builder: (context, svc, _) {
          final all      = svc.all.toList();
          final live      = all.where(_isLive).length;
          final completed = all.where(_isCompleted).length;
          final recent    = [...all]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scorecard Overview',
                    style: _t(size: 15, weight: FontWeight.w800)),
                const SizedBox(height: 14),
                _OverviewCard(
                  icon: Icons.wifi_rounded, iconColor: _red,
                  label: 'Live Matches', value: '$live',
                  sub: 'Across all sports',
                ),
                const SizedBox(height: 8),
                _OverviewCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: _green,
                  label: 'Completed', value: '$completed',
                  sub: 'Matches played',
                ),
                const SizedBox(height: 8),
                _OverviewCard(
                  icon: Icons.scoreboard_outlined, iconColor: _orange,
                  label: 'Total Matches', value: '${all.length}',
                  sub: 'All time',
                ),
                const SizedBox(height: 24),
                Text('Recently Updated',
                    style: _t(size: 14, weight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No matches yet',
                          style: _t(size: 13, color: _m1)),
                    ),
                  )
                else
                  for (final m in recent.take(5)) _RecentRow(match: m),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  const _OverviewCard({
    required this.icon, required this.iconColor,
    required this.label, required this.value, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: _t(size: 20, weight: FontWeight.w900, height: 1.1)),
              Text(label, style: _t(size: 12, weight: FontWeight.w600)),
              Text(sub, style: _t(size: 11, color: _m1)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RecentRow extends StatefulWidget {
  final LiveMatch match;
  const _RecentRow({required this.match});

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final accent    = _sportAccent(m.sportDisplayName);
    final live      = _isLive(m);
    final completed = _isCompleted(m);
    final statusColor = live ? _red : completed ? _green : _blue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => LiveScoreboardScreen(matchId: m.id))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .03)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(_emojiFor(m.sportDisplayName),
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m.teamA.isNotEmpty ? m.teamA : 'Team A'} vs '
                    '${m.teamB.isNotEmpty ? m.teamB : 'Team B'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(size: 12, weight: FontWeight.w700, height: 1.2),
                  ),
                  Text(m.sportDisplayName,
                      style: _t(size: 11, color: accent,
                          weight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_timeAgo(m.createdAt),
                  style: _t(size: 10, color: _m2)),
              Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Sort pill + Red button ─────────────────────────────────────────────────────

class _SortPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Sort by: Most Recent', style: _t(size: 12, color: _m1)),
        const SizedBox(width: 6),
        Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 16),
      ]),
    );
  }
}

class _RedBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _RedBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_RedBtn> createState() => _RedBtnState();
}

class _RedBtnState extends State<_RedBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _hover ? .4 : .2),
                blurRadius: 12,
              )
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
            ],
            Text(widget.label,
                style: _t(size: 13, weight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
