import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/models/comment.dart';
import '../core/models/feed_post.dart';
import '../core/models/story.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Manages the community feed, stories, and comments using Firestore.
///
/// Collections:
///   feed/                          — posts
///   feed/{postId}/comments/        — comments subcollection
///   stories/                       — 24-hour stories
class FeedService extends ChangeNotifier {
  FeedService._();
  static final FeedService _instance = FeedService._();
  factory FeedService() => _instance;

  static const _feedCol    = 'feed';
  static const _storiesCol = 'stories';

  FirebaseFirestore get _db      => FirebaseFirestore.instance;
  FirebaseStorage   get _storage => FirebaseStorage.instance;

  // ── State ─────────────────────────────────────────────────────────────────

  final List<FeedPost> _posts   = [];
  final List<Story>    _stories = [];
  bool _loading = false;

  List<FeedPost> get posts         => List.unmodifiable(_posts);
  List<Story>    get activeStories => _stories.where((s) => s.isActive).toList();
  bool           get loading       => _loading;

  // ── Demo / sample posts ───────────────────────────────────────────────────

  static List<FeedPost> _demoPosts() => [
        FeedPost(
          id: 'demo_1',
          userId: 'demo_user_1',
          userName: 'MySportsBuddies',
          text:
              'Welcome to SportsBuddies! Share your sports moments with the community. 🏏⚽🏀',
          imageUrl: 'assets/1.jpg',
          sport: 'Cricket',
          likes: 24,
          commentCount: 5,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        FeedPost(
          id: 'demo_2',
          userId: 'demo_user_2',
          userName: 'Sports Community',
          text:
              'Amazing match today! Connect with sports lovers near you and track live scores.',
          imageUrl: 'assets/2.jpg',
          sport: 'Football',
          likes: 18,
          commentCount: 3,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];

  void _mergeWithDemos(List<FeedPost> firestorePosts) {
    final firestoreIds = firestorePosts.map((p) => p.id).toSet();

    // Keep any optimistic (non-demo) posts that haven't made it to Firestore yet
    final optimistic = _posts
        .where((p) => !p.id.startsWith('demo_') && !firestoreIds.contains(p.id))
        .toList();

    _posts.clear();
    _posts.addAll(optimistic); // newest optimistic posts first
    _posts.addAll(firestorePosts);

    // Append demo posts that aren't already covered
    for (final d in _demoPosts()) {
      if (!firestoreIds.contains(d.id)) _posts.add(d);
    }
  }

  // ── Real-time feed listener ───────────────────────────────────────────────

  void listenToFeed() {
    _db
        .collection(_feedCol)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snap) {
        _mergeWithDemos(snap.docs.map(FeedPost.fromFirestore).toList());
        notifyListeners();
      },
      onError: (e) => debugPrint('FeedService.listenToFeed error: $e'),
    );
  }

  // ── Real-time stories listener ────────────────────────────────────────────

  void listenToStories() {
    _db
        .collection(_storiesCol)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        _stories
          ..clear()
          ..addAll(snap.docs
              .map(Story.fromFirestore)
              .where((s) => s.isActive));
        notifyListeners();
      },
      onError: (e) => debugPrint('FeedService.listenToStories error: $e'),
    );
  }

  // ── One-shot load ─────────────────────────────────────────────────────────

  Future<void> loadPosts() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final snap = await _db
          .collection(_feedCol)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      _mergeWithDemos(snap.docs.map(FeedPost.fromFirestore).toList());
    } catch (e) {
      debugPrint('FeedService.loadPosts error: $e');
      if (_posts.isEmpty) _posts.addAll(_demoPosts());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Create post ───────────────────────────────────────────────────────────

  Future<void> createPost({
    required String text,
    File? imageFile,
    String? sport,
  }) async {
    final svc        = UserService();
    final userId     = svc.userId ?? 'anonymous';
    final userName   = svc.profile?.name.isNotEmpty == true ? svc.profile!.name : 'Sports Buddy';
    final userImgUrl = svc.profile?.imageUrl;

    // Upload image with a 30-second timeout — never blocks forever
    String? imageUrl;
    if (imageFile != null) {
      try {
        final ref = _storage
            .ref('feed_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(imageFile).timeout(const Duration(seconds: 10));
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('FeedService.createPost upload error: $e');
        // Continue without image rather than blocking the post
      }
    }

    final id   = DateTime.now().millisecondsSinceEpoch.toString();
    final post = FeedPost(
      id: id,
      userId: userId,
      userName: userName,
      userImageUrl: userImgUrl,
      text: text,
      imageUrl: imageUrl,
      sport: sport,
      createdAt: DateTime.now(),
    );

    // Optimistic update — UI responds immediately, sheet can close
    _posts.insert(0, post);
    notifyListeners();

    // Firestore write in background — does NOT block the caller.
    // We do NOT roll back on failure so the post stays visible even if
    // Firestore rules are not yet configured (anonymous auth pending setup).
    _db.collection(_feedCol).doc(id).set({
      ...post.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }).catchError((dynamic e) {
      debugPrint('FeedService.createPost Firestore error (post kept locally): $e');
    });
  }

  // ── Like post ─────────────────────────────────────────────────────────────

  Future<void> likePost(String id) async {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final post = _posts[idx];
    if (post.likedByMe) return;

    _posts[idx] = post.copyWith(likes: post.likes + 1, likedByMe: true);
    notifyListeners();

    if (id.startsWith('demo_')) return;

    try {
      await _db
          .collection(_feedCol)
          .doc(id)
          .update({'likes': FieldValue.increment(1)});

      // Notify post owner if it's not my own post
      final myId   = UserService().userId;
      final myName = UserService().profile?.name ?? 'Someone';
      if (post.userId != myId) {
        await NotificationService.send(
          toUserId: post.userId,
          type:     NotifType.like,
          title:    'New Like',
          body:     '$myName liked your post',
        );
      }
    } catch (e) {
      debugPrint('FeedService.likePost error: $e');
      _posts[idx] = post;
      notifyListeners();
    }
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  /// Real-time stream of comments for a post.
  Stream<List<Comment>> commentsStream(String postId) {
    if (postId.startsWith('demo_')) {
      return Stream.value(_demoComments(postId));
    }
    return _db
        .collection(_feedCol)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Comment.fromFirestore).toList());
  }

  /// Add a comment to a post. Updates [commentCount] atomically.
  Future<void> addComment(String postId, String text) async {
    final svc      = UserService();
    final userId   = svc.userId ?? 'anonymous';
    final userName = svc.profile?.name.isNotEmpty == true ? svc.profile!.name : 'Sports Buddy';
    final imgUrl   = svc.profile?.imageUrl;

    // Demo posts: optimistic local commentCount only
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      _posts[idx] = _posts[idx]
          .copyWith(commentCount: _posts[idx].commentCount + 1);
      notifyListeners();
    }

    if (postId.startsWith('demo_')) return;

    final commentId = DateTime.now().millisecondsSinceEpoch.toString();
    final comment = Comment(
      id: commentId,
      postId: postId,
      userId: userId,
      userName: userName,
      userImageUrl: imgUrl,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      final batch = _db.batch();
      batch.set(
        _db.collection(_feedCol).doc(postId).collection('comments').doc(commentId),
        comment.toMap(),
      );
      batch.update(
        _db.collection(_feedCol).doc(postId),
        {'commentCount': FieldValue.increment(1)},
      );
      await batch.commit();

      // Notify post owner if it's not my own comment
      final post = idx >= 0 ? _posts[idx] : null;
      if (post != null && post.userId != userId) {
        await NotificationService.send(
          toUserId: post.userId,
          type:     NotifType.comment,
          title:    'New Comment',
          body:     '$userName commented: ${text.trim()}',
        );
      }
    } catch (e) {
      debugPrint('FeedService.addComment error: $e');
      if (idx >= 0) {
        _posts[idx] = _posts[idx]
            .copyWith(commentCount: _posts[idx].commentCount - 1);
        notifyListeners();
      }
    }
  }

  static List<Comment> _demoComments(String postId) => [
        Comment(
          id: 'dc_1',
          postId: postId,
          userId: 'demo_user_2',
          userName: 'Sports Community',
          text: 'Great post! Love seeing this. 🔥',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        Comment(
          id: 'dc_2',
          postId: postId,
          userId: 'demo_user_1',
          userName: 'MySportsBuddies',
          text: 'Thanks everyone! See you on the field! ⚽',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];

  // ── Stories ───────────────────────────────────────────────────────────────

  Future<void> createStory({File? imageFile, String? text}) async {
    final svc      = UserService();
    final userId   = svc.userId ?? 'anonymous';
    final userName = svc.profile?.name.isNotEmpty == true ? svc.profile!.name : 'Sports Buddy';
    final imgUrl   = svc.profile?.imageUrl;

    if ((text == null || text.trim().isEmpty) && imageFile == null) return;

    String? imageUrl;
    if (imageFile != null) {
      try {
        final ref = _storage
            .ref('story_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(imageFile).timeout(const Duration(seconds: 10));
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('FeedService.createStory upload error: $e');
      }
    }

    final id  = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final story = Story(
      id: id,
      userId: userId,
      userName: userName,
      userImageUrl: imgUrl,
      imageUrl: imageUrl,
      text: text?.trim(),
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );

    // Optimistic local add — UI updates immediately
    _stories.insert(0, story);
    notifyListeners();

    // Firestore write in background — story stays locally even if write fails.
    _db.collection(_storiesCol).doc(id).set(story.toMap()).catchError((dynamic e) {
      debugPrint('FeedService.createStory Firestore error (story kept locally): $e');
    });
  }

  Future<void> markStoryViewed(String storyId, String viewerId) async {
    if (storyId.startsWith('demo_')) return;
    try {
      await _db.collection(_storiesCol).doc(storyId).update({
        'viewedBy': FieldValue.arrayUnion([viewerId]),
      });
      final idx = _stories.indexWhere((s) => s.id == storyId);
      if (idx >= 0) {
        final s = _stories[idx];
        if (!s.viewedBy.contains(viewerId)) {
          _stories[idx] = Story(
            id: s.id,
            userId: s.userId,
            userName: s.userName,
            userImageUrl: s.userImageUrl,
            imageUrl: s.imageUrl,
            text: s.text,
            createdAt: s.createdAt,
            expiresAt: s.expiresAt,
            viewedBy: [...s.viewedBy, viewerId],
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('FeedService.markStoryViewed error: $e');
    }
  }

  // ── Posts by user ─────────────────────────────────────────────────────────

  Future<List<FeedPost>> postsByUser(String userId) async {
    final localDemos =
        _posts.where((p) => p.userId == userId && p.id.startsWith('demo_')).toList();
    try {
      final snap = await _db
          .collection(_feedCol)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      return [
        ...snap.docs.map((d) => FeedPost.fromFirestore(d)),
        ...localDemos,
      ];
    } catch (e) {
      debugPrint('FeedService.postsByUser error (index missing?): $e');
      return _posts.where((p) => p.userId == userId).toList();
    }
  }

  // ── Stories by user ───────────────────────────────────────────────────────

  List<Story> storiesByUser(String userId) =>
      _stories.where((s) => s.userId == userId && s.isActive).toList();

  /// Grouped stories for the stories bar:
  /// returns a list where each element = all active stories by one user.
  List<List<Story>> get groupedStories {
    final seen  = <String>[];
    final groups = <String, List<Story>>{};
    for (final s in _stories.where((s) => s.isActive)) {
      if (!groups.containsKey(s.userId)) {
        seen.add(s.userId);
        groups[s.userId] = [];
      }
      groups[s.userId]!.add(s);
    }
    return seen.map((uid) => groups[uid]!).toList();
  }

  // ── Share match result ────────────────────────────────────────────────────

  Future<void> shareMatchResult({
    required String matchSummary,
    required String sport,
  }) async {
    await createPost(text: matchSummary, sport: sport);
  }
}
