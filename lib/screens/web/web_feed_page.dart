import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/feed_post.dart';
import '../../services/feed_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../tournaments/tournament_detail_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg = Color(0xFF080808);
const _card = Color(0xFF111111);
const _panel = Color(0xFF0E0E0E);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} days ago';
}

Color _sportColor(String? sport) {
  const m = {
    'Cricket': Color(0xFF4CAF50),
    'Football': Color(0xFF66BB6A),
    'Basketball': Color(0xFFFF9800),
    'Badminton': Color(0xFF42A5F5),
    'Tennis': Color(0xFFCDDC39),
    'Volleyball': Color(0xFF7E57C2),
  };
  return m[sport] ?? _m1;
}

// ── Page ───────────────────────────────────────────────────────────────────────

class WebFeedPage extends StatefulWidget {
  const WebFeedPage({super.key});

  @override
  State<WebFeedPage> createState() => _WebFeedPageState();
}

class _WebFeedPageState extends State<WebFeedPage> {
  final _postCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await FeedService().createPost(text: text);
      _postCtrl.clear();
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main feed ─────────────────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildComposer(context)),
                _FeedList(),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
          // ── Right sidebar ─────────────────────────────────────────────────
          _RightSidebar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Feed', style: _t(size: 26, weight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'Stay updated with the latest from your sports community.',
            style: _t(size: 14, color: _m1),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final profile = context.watch<UserService>().profile;
    final initials = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red,
                    image: profile?.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(profile!.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: profile?.imageUrl == null
                      ? Text(
                          initials,
                          style: _t(
                            size: 14,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _postCtrl,
                    maxLines: 3,
                    minLines: 1,
                    style: _t(size: 14),
                    decoration: InputDecoration(
                      hintText: 'Share an update, result, or event...',
                      hintStyle: _t(size: 14, color: _m1),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Quick action chips
                _QuickActionChip(
                  icon: Icons.image_outlined,
                  label: 'Photo / Video',
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: Icons.emoji_events_outlined,
                  label: 'Tournament',
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: Icons.scoreboard_outlined,
                  label: 'Match Result',
                ),
                const Spacer(),
                // Post button
                _PostBtn(loading: _posting, onTap: _createPost),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  const _QuickActionChip({required this.icon, required this.label});

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .06)
                : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: _m1),
              const SizedBox(width: 6),
              Text(widget.label, style: _t(size: 12, color: _m1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _PostBtn({required this.loading, required this.onTap});

  @override
  State<_PostBtn> createState() => _PostBtnState();
}

class _PostBtnState extends State<_PostBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _hover ? .4 : .2),
                blurRadius: 12,
              ),
            ],
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Post',
                  style: _t(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Feed list ──────────────────────────────────────────────────────────────────

class _FeedList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FeedService>(
      builder: (context, svc, _) {
        if (svc.loading) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFDE313B)),
              ),
            ),
          );
        }
        final posts = svc.posts;
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dynamic_feed_outlined, color: _m2, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Nothing here yet',
                      style: _t(size: 15, color: _m1, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Be the first to share something with the community',
                      style: _t(size: 13, color: _m2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FeedCard(post: posts[i]),
              ),
              childCount: posts.length,
            ),
          ),
        );
      },
    );
  }
}

class _FeedCard extends StatefulWidget {
  final FeedPost post;
  const _FeedCard({required this.post});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _hover = false;
  bool _liking = false;

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    try {
      await FeedService().toggleLike(widget.post.id);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final initials = p.userName.trim().isNotEmpty
        ? p.userName.trim()[0].toUpperCase()
        : '?';
    final accent = _sportColor(p.sport);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFF131313) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hover
                ? Colors.white.withValues(alpha: .09)
                : Colors.white.withValues(alpha: .06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red,
                    image: p.userImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(p.userImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: p.userImageUrl == null
                      ? Text(
                          initials,
                          style: _t(
                            size: 14,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.userName,
                        style: _t(size: 13, weight: FontWeight.w700),
                      ),
                      Text(
                        _timeAgo(p.createdAt),
                        style: _t(size: 11, color: _m1),
                      ),
                    ],
                  ),
                ),
                if (p.sport != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withValues(alpha: .3)),
                    ),
                    child: Text(
                      p.sport!,
                      style: _t(
                        size: 10,
                        weight: FontWeight.w700,
                        color: accent,
                        height: 1,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.more_horiz_rounded, color: _m2, size: 18),
              ],
            ),

            const SizedBox(height: 12),

            // Post text
            Text(p.text, style: _t(size: 14, height: 1.6)),

            // Media
            if (p.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  p.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                _ActionBtn(
                  icon: p.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${p.likes}',
                  active: p.likedByMe,
                  activeColor: _red,
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 16),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${p.commentCount}',
                  active: false,
                  activeColor: _m1,
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                _ActionBtn(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  active: false,
                  activeColor: _m1,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.activeColor : (_hover ? _tx : _m1);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: _t(size: 12, color: color, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Right sidebar ──────────────────────────────────────────────────────────────

class _RightSidebar extends StatelessWidget {
  static const _trending = [
    ('Football', Icons.sports_soccer_rounded, '1,284 posts'),
    ('Basketball', Icons.sports_basketball_rounded, '876 posts'),
    ('Cricket', Icons.sports_cricket_rounded, '642 posts'),
    ('Badminton', Icons.sports_tennis_rounded, '421 posts'),
    ('Tennis', Icons.sports_tennis_rounded, '318 posts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _border, width: .8)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trending sports
            Row(
              children: [
                Text(
                  'Trending Sports',
                  style: _t(size: 15, weight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  'View All',
                  style: _t(size: 12, weight: FontWeight.w600, color: _red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: _trending.asMap().entries.map((e) {
                  final (sport, icon, count) = e.value;
                  return Column(
                    children: [
                      if (e.key > 0) Container(height: .8, color: _border),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(icon, color: _red, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sport,
                                style: _t(size: 13, weight: FontWeight.w600),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(count, style: _t(size: 11, color: _m1)),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  color: _red,
                                  size: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Suggested Groups (active tournaments)
            Row(
              children: [
                Text(
                  'Suggested Groups',
                  style: _t(size: 15, weight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  'View All',
                  style: _t(size: 12, weight: FontWeight.w600, color: _red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SuggestedGroups(),

            const SizedBox(height: 24),

            // Upcoming events
            Row(
              children: [
                Text(
                  'Upcoming Community Events',
                  style: _t(size: 15, weight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  'View All',
                  style: _t(size: 12, weight: FontWeight.w600, color: _red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EventsPlaceholder(),
          ],
        ),
      ),
    );
  }
}

// ── Suggested groups ───────────────────────────────────────────────────────────

class _SuggestedGroups extends StatelessWidget {
  static const _groups = [
    (
      'Cricket Fans',
      Icons.sports_cricket_rounded,
      '2.4k members',
      Color(0xFF4CAF50),
    ),
    (
      'Football Club',
      Icons.sports_soccer_rounded,
      '1.8k members',
      Color(0xFF66BB6A),
    ),
    (
      'Hoops Nation',
      Icons.sports_basketball_rounded,
      '956 members',
      Color(0xFFFF9800),
    ),
    (
      'Badminton League',
      Icons.sports_tennis_rounded,
      '621 members',
      Color(0xFF42A5F5),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final tours = TournamentService().tournaments.take(2).toList();
        final items = <Widget>[];

        // Real tournament groups
        for (final t in tours) {
          final accent = _sportColor(t.sport);
          items.add(
            _GroupRow(
              icon: _sportIcon(t.sport),
              name: t.name,
              sub: '${t.registeredTeams} teams · ${t.sport}',
              accentColor: accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TournamentDetailScreen(tournamentId: t.id),
                ),
              ),
            ),
          );
        }

        // Static group suggestions padded to 4
        final needed = (4 - items.length).clamp(0, _groups.length);
        for (final g in _groups.take(needed)) {
          final (name, icon, sub, color) = g;
          items.add(
            _GroupRow(
              icon: icon,
              name: name,
              sub: sub,
              accentColor: color,
              onTap: () {},
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: items
                .asMap()
                .entries
                .map(
                  (e) => Column(
                    children: [
                      if (e.key > 0) Container(height: .8, color: _border),
                      e.value,
                    ],
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

IconData _sportIcon(String sport) {
  const m = {
    'Cricket': Icons.sports_cricket_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Basketball': Icons.sports_basketball_rounded,
    'Badminton': Icons.sports_tennis_rounded,
    'Tennis': Icons.sports_tennis_rounded,
    'Volleyball': Icons.sports_volleyball_rounded,
    'Hockey': Icons.sports_hockey_rounded,
    'Boxing': Icons.sports_mma_rounded,
    'Kabaddi': Icons.sports_kabaddi_rounded,
    'Table Tennis': Icons.sports_tennis_rounded,
    'Rugby': Icons.sports_rugby_rounded,
    'Golf': Icons.sports_golf_rounded,
    'Swimming': Icons.pool_rounded,
    'Athletics': Icons.directions_run_rounded,
    'Esports': Icons.sports_esports_rounded,
  };
  return m[sport] ?? Icons.groups_rounded;
}

class _GroupRow extends StatefulWidget {
  final IconData icon;
  final String name, sub;
  final Color accentColor;
  final VoidCallback onTap;
  const _GroupRow({
    required this.icon,
    required this.name,
    required this.sub,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _hover = false;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: _hover
              ? Colors.white.withValues(alpha: .03)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: widget.accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 13, weight: FontWeight.w600, height: 1.2),
                    ),
                    Text(widget.sub, style: _t(size: 11, color: _m1)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _red.withValues(alpha: .3)),
                ),
                child: Text(
                  'Join',
                  style: _t(size: 11, weight: FontWeight.w700, color: _red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Events placeholder ─────────────────────────────────────────────────────────

class _EventsPlaceholder extends StatelessWidget {
  static const _events = [
    ('MAY', '10', 'Spring Cup 2026', 'Tournament · Multi-Sport', '128'),
    ('MAY', '17', '5v5 Sunday League', 'Football · League', '32'),
    ('MAY', '24', '3x3 Hoops Showdown', 'Basketball · Tournament', '16'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _events.map((e) {
        final (month, day, title, sub, count) = e;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: _t(
                        size: 9,
                        weight: FontWeight.w800,
                        color: _red,
                        height: 1,
                      ),
                    ),
                    Text(
                      day,
                      style: _t(
                        size: 16,
                        weight: FontWeight.w900,
                        color: _red,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _t(size: 13, weight: FontWeight.w700, height: 1.2),
                    ),
                    Text(sub, style: _t(size: 11, color: _m1)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded, size: 12, color: _m2),
                  const SizedBox(width: 4),
                  Text(count, style: _t(size: 11, color: _m2)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
