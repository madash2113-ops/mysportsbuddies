import 'dart:io' as dart_io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/feed_post.dart';
import '../../design/colors.dart';
import '../../services/feed_service.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import 'comments_screen.dart';
import 'create_post_sheet.dart';
import 'create_story_sheet.dart';
import 'messages_screen.dart';
import 'story_viewer_screen.dart';
import 'user_profile_screen.dart';

class CommunityFeedScreen extends StatefulWidget {
  /// Set to true when pushed as a route (e.g. from notifications) so the
  /// back button works normally. Defaults to false (tab mode — back blocked).
  final bool allowBack;
  const CommunityFeedScreen({super.key, this.allowBack = false});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FeedService>().loadPosts();
      MessageService().listenToConversations();
    });
  }

  /// Shows the "Create" chooser — lets user pick Status (story) or Post.
  void _openCreateChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateChooserSheet(
        onPost:   _openCreatePost,
        onStatus: _openCreateStory,
      ),
    );
  }

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(),
    );
  }

  void _openCreateStory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateStorySheet(),
    );
  }

  void _openMessages() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const MessagesScreen()));
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: _UserSearchDelegate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.allowBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: widget.allowBack,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'SportsClub',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.5,
            ),
          ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 26),
            onPressed: _openSearch,
            tooltip: 'Search people',
          ),
          // DM button with unread badge — uses singleton directly to avoid
          // Provider-not-found errors when screen is pushed from different contexts
          ListenableBuilder(
            listenable: MessageService(),
            builder: (ctx, child) {
              final unread = MessageService().totalUnread;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.near_me_outlined,
                        color: Colors.white, size: 26),
                    onPressed: _openMessages,
                    tooltip: 'Messages',
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined,
                color: Colors.white, size: 26),
            onPressed: _openCreateChooser,
            tooltip: 'Create',
          ),
        ],
      ),
      body: Consumer<FeedService>(
        builder: (ctx, feedSvc, _) {
          if (feedSvc.loading && feedSvc.posts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (feedSvc.posts.isEmpty) {
            return _EmptyState(onCreatePost: _openCreatePost);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: const Color(0xFF1A1A1A),
            onRefresh: () => feedSvc.loadPosts(),
            child: ListView.builder(
              itemCount: feedSvc.posts.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _StoriesBar(
                    feedSvc: feedSvc,
                    onAddStory: _openCreateStory,
                  );
                }
                return _PostCard(post: feedSvc.posts[i - 1]);
              },
            ),
          );
        },
      ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreatePost;
  const _EmptyState({required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.photo_camera_outlined,
                color: Colors.white38, size: 38),
          ),
          const SizedBox(height: 20),
          const Text('Share Your Moments',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'When you or others share moments and scores, they\'ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onCreatePost,
            child: const Text('+ Create First Post',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Instagram gradient constant ───────────────────────────────────────────────

const _igGradient = LinearGradient(
  colors: [
    Color(0xFFF58529),
    Color(0xFFDD2A7B),
    Color(0xFF8134AF),
    Color(0xFF515BD4),
  ],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

// ── Stories Bar ───────────────────────────────────────────────────────────────

class _StoriesBar extends StatelessWidget {
  final FeedService feedSvc;
  final VoidCallback onAddStory;

  const _StoriesBar({
    required this.feedSvc,
    required this.onAddStory,
  });

  @override
  Widget build(BuildContext context) {
    final myId        = UserService().userId ?? '';
    final groups      = feedSvc.groupedStories;           // List<List<Story>>
    final myStories   = feedSvc.storiesByUser(myId);
    final hasMyStory  = myStories.isNotEmpty;

    // Build story circles: "Your Story" first, then other users
    final otherGroups = groups.where((g) => g.first.userId != myId).toList();

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // ── Your Story ──
                // Tapping the circle opens your stories if you have any,
                // or goes straight to create a story if you don't yet.
                _StoryCircle(
                  label: 'Your Story',
                  imageUrl: UserService().profile?.imageUrl,
                  initials: '',
                  isOwn: true,
                  hasOwnStory: hasMyStory,
                  isViewed: false,
                  onTap: hasMyStory
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoryViewerScreen(
                                storyGroups: [myStories, ...otherGroups],
                                initialGroupIndex: 0,
                              ),
                            ),
                          )
                      : onAddStory,
                  onPlusTap: onAddStory,
                ),
                const SizedBox(width: 18),

                // ── Other users' stories ──
                ...otherGroups.asMap().entries.map((entry) {
                  final idx     = entry.key;
                  final grp     = entry.value;
                  final first   = grp.first;
                  final name    = first.userName;
                  final initials =
                      name.isNotEmpty ? name[0].toUpperCase() : 'U';
                  final isViewed =
                      grp.every((s) => s.isViewedBy(myId));

                  return Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: _StoryCircle(
                      label: name.length > 9
                          ? '${name.substring(0, 9)}…'
                          : name,
                      imageUrl: first.userImageUrl,
                      initials: initials,
                      isOwn: false,
                      isViewed: isViewed,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(
                            storyGroups: hasMyStory
                                ? [myStories, ...otherGroups]
                                : otherGroups,
                            initialGroupIndex:
                                hasMyStory ? idx + 1 : idx,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // ── If no stories yet, show demo circles from posts ──
                if (groups.isEmpty)
                  ..._demoCircles(context, feedSvc),
              ],
            ),
          ),
          const Divider(
              height: 0.5,
              color: Color(0xFF262626),
              thickness: 0.5),
        ],
      ),
    );
  }

  // Fallback story circles derived from post authors when no real stories exist.
  // These people have no active story — show plain ring (isViewed: true = grey).
  List<Widget> _demoCircles(BuildContext context, FeedService feedSvc) {
    final seen  = <String>{};
    final items = <Widget>[];
    for (final p in feedSvc.posts) {
      if (seen.contains(p.userId)) continue;
      seen.add(p.userId);
      final name     = p.userName;
      final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
      items.add(Padding(
        padding: const EdgeInsets.only(right: 18),
        child: _StoryCircle(
          label: name.length > 9 ? '${name.substring(0, 9)}…' : name,
          imageUrl: p.userImageUrl,
          initials: initials,
          isOwn: false,
          isViewed: true,   // no real story → plain grey ring, not gradient
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: p.userId),
            ),
          ),
        ),
      ));
      if (items.length >= 8) break;
    }
    return items;
  }
}

// ── Story Circle ──────────────────────────────────────────────────────────────

class _StoryCircle extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final String initials;
  final bool isOwn;
  final bool hasOwnStory; // only relevant when isOwn=true; shows gradient ring
  final bool isViewed;
  final VoidCallback onTap;
  final VoidCallback? onPlusTap;

  const _StoryCircle({
    required this.label,
    required this.imageUrl,
    required this.initials,
    required this.isOwn,
    this.hasOwnStory = false,
    required this.isViewed,
    required this.onTap,
    this.onPlusTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // Ring logic:
              //   own + has story  → IG gradient ring
              //   own + no story   → dashed grey ring (add placeholder)
              //   other + unviewed → IG gradient ring
              //   other + viewed   → solid grey ring
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: (isOwn && !hasOwnStory) || isViewed
                      ? null
                      : _igGradient,
                  color: (isOwn && !hasOwnStory) || isViewed
                      ? Colors.transparent
                      : null,
                  border: (isOwn && !hasOwnStory)
                      ? Border.all(
                          color: Colors.white24,
                          width: 1.5,
                        )
                      : isViewed
                          ? Border.all(
                              color: Colors.white24,
                              width: 1.5,
                            )
                          : null,
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.black),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF2A2A2A),
                    backgroundImage: imageUrl != null
                        ? NetworkImage(imageUrl!)
                        : null,
                    child: imageUrl == null
                        ? Icon(
                            isOwn
                                ? Icons.person_outline
                                : Icons.person,
                            color: Colors.white54,
                            size: 26,
                          )
                        : null,
                  ),
                ),
              ),
              // Blue "+" badge for own story — taps directly open Add Status
              if (isOwn)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onPlusTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0095F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 13),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isOwn ? Colors.white60 : Colors.white,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final FeedPost post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> with TickerProviderStateMixin {
  bool _bookmarked = false;
  bool _showHeart  = false;
  late AnimationController _heartCtrl;
  late Animation<double>   _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _heartAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    if (!widget.post.likedByMe) {
      context.read<FeedService>().toggleLike(widget.post.id);
    }
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CommentsScreen(post: widget.post)),
    );
  }

  void _openShare() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ShareSheet(post: widget.post),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            UserProfileScreen(userId: post.userId))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with IG-gradient ring
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, gradient: _igGradient),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.black),
                        padding: const EdgeInsets.all(1.5),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2A2A2A),
                          backgroundImage: post.userImageUrl != null
                              ? NetworkImage(post.userImageUrl!)
                              : null,
                          child: post.userImageUrl == null
                              ? Text(
                                  post.userName.isNotEmpty
                                      ? post.userName[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        if (post.sport != null)
                          Text(post.sport!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showOptions(context, post),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),

        // ── Image with double-tap like ───────────────────────────────────
        if (post.imageUrl != null)
          GestureDetector(
            onDoubleTap: _doubleTapLike,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NetworkImageSafe(url: post.imageUrl!),
                  if (_showHeart)
                    IgnorePointer(
                      child: FadeTransition(
                        opacity: _heartAnim,
                        child: const Center(
                          child: Icon(Icons.favorite,
                              color: Colors.white,
                              size: 96,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 18)
                              ]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // ── Action Row ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
          child: Row(
            children: [
              _AnimatedLikeButton(post: post),
              const SizedBox(width: 4),
              // Comment
              GestureDetector(
                onTap: _openComments,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 4),
              // Share
              GestureDetector(
                onTap: _openShare,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.near_me_outlined,
                      color: Colors.white, size: 24),
                ),
              ),
              const Spacer(),
              if (post.type == FeedPostType.scoreCard)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.scoreboard_outlined,
                      color: Colors.white30, size: 18),
                ),
              // Bookmark
              GestureDetector(
                onTap: () =>
                    setState(() => _bookmarked = !_bookmarked),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    _bookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Likes count ──────────────────────────────────────────────────
        if (post.likes > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text(
              '${post.likes} ${post.likes == 1 ? 'like' : 'likes'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          )
        else
          const SizedBox(height: 4),

        // ── Caption ──────────────────────────────────────────────────────
        if (post.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
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
                        height: 1.45,
                        fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),

        // ── View all comments ────────────────────────────────────────────
        GestureDetector(
          onTap: _openComments,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 1),
            child: Text(
              post.commentCount > 0
                  ? 'View all ${post.commentCount} comments'
                  : 'View all comments',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13),
            ),
          ),
        ),

        // ── Add a comment ────────────────────────────────────────────────
        GestureDetector(
          onTap: _openComments,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(14, 1, 14, 2),
            child: Text('Add a comment…',
                style: TextStyle(
                    color: Colors.white24, fontSize: 13)),
          ),
        ),

        // ── Timestamp ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
          child: Text(
            _timeAgo(post.createdAt).toUpperCase(),
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 0.4),
          ),
        ),

        const Divider(
            height: 1, color: Color(0xFF262626), thickness: 0.5),
      ],
    );
  }

  void _showOptions(BuildContext context, FeedPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: Colors.white, size: 22),
              title: const Text('View Profile',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            UserProfileScreen(userId: post.userId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined,
                  color: Colors.white, size: 22),
              title: const Text('Copy Caption',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: post.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Caption copied'),
                    backgroundColor: Color(0xFF1A1A1A),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined,
                  color: Colors.white, size: 22),
              title: const Text('Report',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post reported'),
                    backgroundColor: Color(0xFF1A1A1A),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Share Sheet ───────────────────────────────────────────────────────────────

class _ShareSheet extends StatelessWidget {
  final FeedPost post;
  const _ShareSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Share',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Share via DM
          ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.near_me_outlined,
                  color: AppColors.primary, size: 22),
            ),
            title: const Text('Send as Message',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Share with a follower via DM',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()));
            },
          ),

          // Copy link
          ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.link_outlined,
                  color: Colors.white, size: 22),
            ),
            title: const Text('Copy Link',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Copy post ID to clipboard',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(
                  ClipboardData(text: 'sportsbuddies://post/${post.id}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard'),
                  backgroundColor: Color(0xFF1A1A1A),
                ),
              );
            },
          ),

          // Share as story
          ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.auto_stories_outlined,
                  color: Colors.white, size: 22),
            ),
            title: const Text('Add to Your Story',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Reshare this post in your story',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const CreateStorySheet(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Network image (fills parent) ──────────────────────────────────────────────

class _NetworkImageSafe extends StatelessWidget {
  final String url;
  const _NetworkImageSafe({required this.url});

  bool get _isAsset => url.startsWith('assets/');
  bool get _isLocal => !url.startsWith('http') && !url.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    if (_isAsset) {
      return Image.asset(url, fit: BoxFit.cover, width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _broken());
    }
    if (_isLocal) {
      // Local file path — shown while upload is in progress
      return Image.file(
        dart_io.File(url),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _broken(),
      );
    }
    return Image.network(
      url, fit: BoxFit.cover, width: double.infinity,
      loadingBuilder: (_, child, p) {
        if (p == null) return child;
        return Container(
          color: const Color(0xFF111111),
          child: Center(
            child: CircularProgressIndicator(
              value: p.expectedTotalBytes != null
                  ? p.cumulativeBytesLoaded / p.expectedTotalBytes!
                  : null,
              color: AppColors.primary, strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _broken(),
    );
  }

  Widget _broken() => Container(
        color: const Color(0xFF111111),
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 40),
        ),
      );
}

// ── Animated Like Button ──────────────────────────────────────────────────────

class _AnimatedLikeButton extends StatefulWidget {
  final FeedPost post;
  const _AnimatedLikeButton({required this.post});

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.forward(from: 0);
    context.read<FeedService>().toggleLike(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            widget.post.likedByMe
                ? Icons.favorite
                : Icons.favorite_border,
            color: widget.post.likedByMe
                ? AppColors.primary
                : Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ── Create chooser sheet ───────────────────────────────────────────────────
/// Bottom sheet asking "What do you want to create?" — Post or Status.
class _CreateChooserSheet extends StatelessWidget {
  final VoidCallback onPost;
  final VoidCallback onStatus;
  const _CreateChooserSheet({required this.onPost, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text('Create',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _CreateOption(
                  icon: Icons.grid_on_rounded,
                  label: 'Post',
                  subtitle: 'Share a photo or thought',
                  gradient: const [Color(0xFF8B0000), Color(0xFFD32F2F)],
                  onTap: () { Navigator.pop(context); onPost(); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CreateOption(
                  icon: Icons.auto_stories_outlined,
                  label: 'Status',
                  subtitle: 'Disappears in 24 hours',
                  gradient: const [Color(0xFF1A0050), Color(0xFF5C00CC)],
                  onTap: () { Navigator.pop(context); onStatus(); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _CreateOption({
    required this.icon, required this.label, required this.subtitle,
    required this.gradient, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── User Search Delegate ───────────────────────────────────────────────────────
/// Full-screen search for sports buddies by name.
/// Searches Firestore `users` collection with a prefix match on `name`.
class _UserSearchDelegate extends SearchDelegate<void> {
  _UserSearchDelegate() : super(searchFieldLabel: 'Search people…');

  @override
  ThemeData appBarTheme(BuildContext context) => ThemeData.dark().copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white38),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final q = query.trim();

    // Show quick results from already-loaded posts (no network call needed)
    final localUsers = <String, String?>{};
    for (final p in FeedService().posts) {
      if (!localUsers.containsKey(p.userId) &&
          (q.isEmpty ||
              p.userName.toLowerCase().contains(q.toLowerCase()))) {
        localUsers[p.userId] = p.userImageUrl;
      }
    }

    if (q.isEmpty) {
      if (localUsers.isEmpty) {
        return _hint('Search for sports buddies by name');
      }
      return _userList(context, localUsers.entries
          .map((e) => _UserResult(
                userId: e.key,
                name: FeedService()
                    .posts
                    .firstWhere((p) => p.userId == e.key)
                    .userName,
                imageUrl: e.value,
              ))
          .toList());
    }

    // For typed queries, also hit Firestore prefix search
    return FutureBuilder<List<_UserResult>>(
      future: _searchFirestore(q, localUsers),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final results = snap.data ?? [];
        if (results.isEmpty) {
          return _hint('No people found for "$q"');
        }
        return _userList(context, results);
      },
    );
  }

  Future<List<_UserResult>> _searchFirestore(
      String q, Map<String, String?> localUsers) async {
    final results = <_UserResult>[];
    final seen    = <String>{};

    // Local results first (instant)
    for (final e in localUsers.entries) {
      final name = FeedService()
          .posts
          .firstWhere((p) => p.userId == e.key)
          .userName;
      if (name.toLowerCase().contains(q.toLowerCase())) {
        results.add(_UserResult(userId: e.key, name: name, imageUrl: e.value));
        seen.add(e.key);
      }
    }

    // Firestore prefix query on `name`
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThan: '${q}z')
          .limit(20)
          .get();

      for (final doc in snap.docs) {
        if (seen.contains(doc.id)) continue;
        final data = doc.data();
        results.add(_UserResult(
          userId: doc.id,
          name: (data['name'] as String?) ?? 'Sports Buddy',
          imageUrl: data['imageUrl'] as String?,
        ));
        seen.add(doc.id);
      }
    } catch (_) {}

    return results;
  }

  Widget _userList(BuildContext context, List<_UserResult> users) {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (_, i) {
          final u = users[i];
          return ListTile(
            onTap: () {
              close(context, null);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: u.userId)),
              );
            },
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2A2A2A),
              backgroundImage:
                  u.imageUrl != null ? NetworkImage(u.imageUrl!) : null,
              child: u.imageUrl == null
                  ? Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    )
                  : null,
            ),
            title: Text(u.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            subtitle: const Text('Sports Buddy',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          );
        },
      ),
    );
  }

  Widget _hint(String text) => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_search_outlined,
                  color: Colors.white24, size: 56),
              const SizedBox(height: 16),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
        ),
      );
}

class _UserResult {
  final String userId, name;
  final String? imageUrl;
  const _UserResult(
      {required this.userId, required this.name, required this.imageUrl});
}
