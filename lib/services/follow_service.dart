import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Manages the follow graph for the current user.
///
/// Firestore collection: `follows`
/// Document ID: `{followerId}_{followedId}`
class FollowService extends ChangeNotifier {
  FollowService._();
  static final FollowService _instance = FollowService._();
  factory FollowService() => _instance;

  static const _col = 'follows';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// UIDs that the current user follows
  final Set<String> _following = {};

  /// UIDs that follow the current user
  final Set<String> _followers = {};

  bool _initialized = false;

  Set<String> get following => Set.unmodifiable(_following);
  Set<String> get followers => Set.unmodifiable(_followers);

  bool isFollowing(String uid) => _following.contains(uid);
  bool isFollowedBy(String uid) => _followers.contains(uid);
  bool isMutual(String uid) => isFollowing(uid) && isFollowedBy(uid);

  /// Call once after UserService.init() completes.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final myId = UserService().userId;
    if (myId == null) return;

    try {
      // People I follow
      final followingSnap = await _db
          .collection(_col)
          .where('followerId', isEqualTo: myId)
          .get();
      _following.addAll(
          followingSnap.docs.map((d) => d['followedId'] as String? ?? ''));

      // People who follow me
      final followersSnap = await _db
          .collection(_col)
          .where('followedId', isEqualTo: myId)
          .get();
      _followers.addAll(
          followersSnap.docs.map((d) => d['followerId'] as String? ?? ''));

      notifyListeners();
    } catch (e) { /* ignored */ }
  }

  Future<void> follow(String targetId) async {
    final myId = UserService().userId;
    if (myId == null || myId == targetId) return;
    if (_following.contains(targetId)) return;

    _following.add(targetId);
    notifyListeners();

    try {
      final myName = UserService().profile?.name ?? 'Sports Buddy';
      await _db.collection(_col).doc('${myId}_$targetId').set({
        'followerId': myId,
        'followerName': myName,
        'followedId': targetId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Notify the target user
      await NotificationService.send(
        toUserId: targetId,
        type: NotifType.follow,
        title: 'New Follower',
        body: '$myName started following you',
      );
      AnalyticsService().logEvent(AnalyticsEvents.followUser);
    } catch (e) {
      _following.remove(targetId);
      notifyListeners();
    }
  }

  Future<void> unfollow(String targetId) async {
    final myId = UserService().userId;
    if (myId == null) return;
    if (!_following.contains(targetId)) return;

    _following.remove(targetId);
    notifyListeners();

    try {
      await _db.collection(_col).doc('${myId}_$targetId').delete();
    } catch (e) {
      _following.add(targetId);
      notifyListeners();
    }
  }

  /// Get follower count for any user from Firestore.
  Future<int> followerCount(String userId) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('followedId', isEqualTo: userId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get following count for any user from Firestore.
  Future<int> followingCount(String userId) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('followerId', isEqualTo: userId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Check if [viewerId] follows [ownerId] — used to verify mutual follows
  /// when determining message access.
  Future<bool> checkFollows(String followerId, String followedId) async {
    try {
      final doc = await _db
          .collection(_col)
          .doc('${followerId}_$followedId')
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}
