import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/feed_post.dart';
import '../../core/models/user_profile.dart';
import '../../design/colors.dart';
import '../../services/feed_service.dart';
import '../../services/follow_service.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  List<FeedPost> _posts = [];
  bool _loading = true;
  int _followerCount  = 0;
  int _followingCount = 0;

  bool get _isMe => widget.userId == (UserService().userId ?? '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final followSvc = FollowService();
    final feedSvc   = context.read<FeedService>();

    final results = await Future.wait([
      UserService().loadProfileById(widget.userId),
      feedSvc.postsByUser(widget.userId),
      followSvc.followerCount(widget.userId),
      followSvc.followingCount(widget.userId),
    ]);

    if (!mounted) return;
    setState(() {
      _profile        = results[0] as UserProfile?;
      _posts          = results[1] as List<FeedPost>;
      _followerCount  = results[2] as int;
      _followingCount = results[3] as int;
      _loading        = false;
    });
  }

  List<FeedPost> get _imagePosts =>
      _posts.where((p) => p.imageUrl != null).toList();

  List<String> get _sportTags {
    final seen = <String>{};
    return _posts
        .where((p) => p.sport != null)
        .map((p) => p.sport!)
        .where(seen.add)
        .toList();
  }

  Future<void> _openChat() async {
    final otherName   = _profile?.name.isNotEmpty == true ? _profile!.name : 'User';
    final otherImgUrl = _profile?.imageUrl;

    final conversationId = await MessageService().getOrCreateConversation(
      otherId: widget.userId,
      otherName: otherName,
      otherImageUrl: otherImgUrl,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherId: widget.userId,
          otherName: otherName,
          otherImageUrl: otherImgUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _profile?.name.isNotEmpty == true
        ? _profile!.name
        : 'Sports Buddy';
    final username = '@${displayName.toLowerCase().replaceAll(' ', '_')}';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.black,
            leading: const BackButton(color: Colors.white),
            title: Text(username,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            actions: [
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.more_vert, color: Colors.white),
              ),
            ],
          ),

          // ── Profile Header ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + Stats row
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white24, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFF6A0000),
                                backgroundImage: _profile?.imageUrl != null
                                    ? NetworkImage(_profile!.imageUrl!)
                                    : null,
                                child: _profile?.imageUrl == null
                                    ? Text(initials,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold))
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _StatCol('Posts', _posts.length),
                                  GestureDetector(
                                    onTap: () => _showFollowList(
                                        context, 'Followers', false),
                                    child: _StatCol(
                                        'Followers', _followerCount),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showFollowList(
                                        context, 'Following', true),
                                    child: _StatCol(
                                        'Following', _followingCount),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Text(displayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),

                        if (_profile?.bio.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(_profile!.bio,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4)),
                        ],

                        if (_profile?.location.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: AppColors.primary, size: 13),
                              const SizedBox(width: 3),
                              Text(_profile!.location,
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12)),
                            ],
                          ),
                        ],

                        if (_sportTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _sportTags
                                .map((s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Text(s,
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                          ),
                        ],

                        const SizedBox(height: 14),

                        // ── Action Buttons ───────────────────────────────
                        if (!_isMe)
                          Consumer<FollowService>(
                            builder: (ctx, followSvc, child) {
                              final following =
                                  followSvc.isFollowing(widget.userId);
                              final mutual =
                                  followSvc.isMutual(widget.userId);

                              return Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (following) {
                                          await followSvc
                                              .unfollow(widget.userId);
                                          if (mounted) {
                                            setState(() => _followerCount =
                                                (_followerCount - 1)
                                                    .clamp(0, 999999));
                                          }
                                        } else {
                                          await followSvc
                                              .follow(widget.userId);
                                          if (mounted) {
                                            setState(
                                                () => _followerCount++);
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: following
                                            ? const Color(0xFF1A1A1A)
                                            : AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          side: following
                                              ? const BorderSide(
                                                  color: Colors.white24)
                                              : BorderSide.none,
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        mutual
                                            ? 'Friends ✓'
                                            : following
                                                ? 'Following'
                                                : 'Follow',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _openChat,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white38),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Message',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        if (_isMe)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/edit-profile'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Edit Profile',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),

                        const SizedBox(height: 16),
                        _SportStatsRow(userId: widget.userId),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFF222222)),
                      ],
                    ),
                  ),
          ),

          // ── 3-Column Image Grid ────────────────────────────────────────
          if (!_loading)
            _imagePosts.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined,
                                color: Colors.white24, size: 48),
                            SizedBox(height: 12),
                            Text('No posts yet',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _GridTile(post: _imagePosts[i]),
                      childCount: _imagePosts.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1.5,
                      mainAxisSpacing: 1.5,
                    ),
                  ),
        ],
      ),
    );
  }

  void _showFollowList(
      BuildContext context, String title, bool isFollowing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (ctx, ctrl) => Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        color: Colors.white24, size: 48),
                    SizedBox(height: 12),
                    Text('Follow list coming soon',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sport Stats Row ───────────────────────────────────────────────────────────

class _SportStatsRow extends StatelessWidget {
  final String userId;
  const _SportStatsRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _loadStats(),
      builder: (context, snap) {
        final games       = snap.data?[0] ?? 0;
        final tournaments = snap.data?[1] ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              _SportStat(
                icon: Icons.sports_outlined,
                label: 'Games\nJoined',
                value: games,
                color: Colors.green,
              ),
              _divider(),
              _SportStat(
                icon: Icons.emoji_events_outlined,
                label: 'Tournaments\nPlayed',
                value: tournaments,
                color: Colors.amber,
              ),
              _divider(),
              _SportStat(
                icon: Icons.star_outline_rounded,
                label: 'Sports\nActive',
                value: snap.data?[2] ?? 0,
                color: AppColors.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Container(
        width: 1, height: 36,
        color: Colors.white12,
      );

  Future<List<int>> _loadStats() async {
    final db = FirebaseFirestore.instance;

    // Games joined (inGame RSVPs across all games)
    final rsvpSnap = await db
        .collectionGroup('rsvps')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'inGame')
        .get();
    final gamesJoined = rsvpSnap.docs.length;

    // Tournaments: teams enrolled by this user
    final tournSnap = await db
        .collectionGroup('teams')
        .where('enrolledBy', isEqualTo: userId)
        .get();
    final tournamentsPlayed = tournSnap.docs.length;

    // Unique sports from their games
    final sportsSet = <String>{};
    for (final doc in rsvpSnap.docs) {
      // The game doc ID is the parent's parent
      final gameId = doc.reference.parent.parent?.id;
      if (gameId != null) {
        final gameDoc = await db.collection('games').doc(gameId).get();
        final sport = gameDoc.data()?['sport'] as String?;
        if (sport != null) sportsSet.add(sport);
      }
    }

    return [gamesJoined, tournamentsPlayed, sportsSet.length];
  }
}

class _SportStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _SportStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ── Stat Column ───────────────────────────────────────────────────────────────

class _StatCol extends StatelessWidget {
  final String label;
  final int count;
  const _StatCol(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

// ── Grid Tile ─────────────────────────────────────────────────────────────────

class _GridTile extends StatelessWidget {
  final FeedPost post;
  const _GridTile({required this.post});

  bool get _isAsset => post.imageUrl!.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: _isAsset
          ? Image.asset(post.imageUrl!, fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => _broken())
          : Image.network(post.imageUrl!, fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => _broken()),
    );
  }

  Widget _broken() => Container(
        color: const Color(0xFF111111),
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 28),
        ),
      );

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PostDetailSheet(post: post),
    );
  }
}

// ── Post Detail Sheet ─────────────────────────────────────────────────────────

class _PostDetailSheet extends StatefulWidget {
  final FeedPost post;
  const _PostDetailSheet({required this.post});

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  bool _bookmarked = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, controller) => Column(
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                if (post.imageUrl != null)
                  post.imageUrl!.startsWith('assets/')
                      ? Image.asset(post.imageUrl!,
                          width: double.infinity, height: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => const SizedBox())
                      : Image.network(post.imageUrl!,
                          width: double.infinity, height: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => const SizedBox()),

                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.likedByMe
                            ? AppColors.primary
                            : Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text('${post.likes}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 6),
                      Text('${post.commentCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.near_me_outlined,
                          color: Colors.white, size: 22),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _bookmarked = !_bookmarked),
                        child: Icon(
                          _bookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: Colors.white, size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                if (post.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: post.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(
                              text: '  ',
                              style: TextStyle(color: Colors.white)),
                          TextSpan(
                            text: post.text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: Row(
                    children: [
                      if (post.sport != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(post.sport!,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(_timeAgo(post.createdAt).toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 4, 14, 20),
                  child: Text('Comments — coming soon',
                      style:
                          TextStyle(color: Colors.white24, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
