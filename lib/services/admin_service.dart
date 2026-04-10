import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/models/user_profile.dart';
import 'user_service.dart';

// ── AdminService ──────────────────────────────────────────────────────────────
//
// Singleton ChangeNotifier. Manages the admin roster stored at:
//   Firestore → config/admins  { adminUserIds: [...] }
//
// Numeric ID 517913 is the hardcoded superadmin and cannot be revoked.
// Any Firebase UID listed in config/admins also has full admin access.
// ─────────────────────────────────────────────────────────────────────────────

class AdminService extends ChangeNotifier {
  AdminService._();
  static final AdminService _instance = AdminService._();
  factory AdminService() => _instance;

  static const _adminDoc = 'config/admins';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Set<String> _adminUserIds = {};
  bool        _loaded       = false;

  // ── Public getters ──────────────────────────────────────────────────────────

  bool get isCurrentUserAdmin {
    final svc = UserService();
    // Numeric superadmin
    final nid = svc.profile?.numericId;
    if (nid != null && kOwnerNumericIds.contains(nid)) return true;
    // Firebase UID admins
    final uid = svc.userId;
    if (uid != null && _adminUserIds.contains(uid)) return true;
    return false;
  }

  bool isAdmin(String userId) =>
      _adminUserIds.contains(userId) ||
      // also treat numeric superadmin as admin when we only have a UID
      kOwnerNumericIds.contains(UserService().profile?.numericId);

  Set<String> get adminUserIds => Set.unmodifiable(_adminUserIds);

  // ── Init / listen ───────────────────────────────────────────────────────────

  /// Call once at startup. Subscribes to real-time updates of config/admins.
  void listen() {
    _db.doc(_adminDoc).snapshots().listen((snap) {
      if (!snap.exists) {
        _adminUserIds = {};
      } else {
        final raw = (snap.data()?['adminUserIds'] as List<dynamic>?) ?? [];
        _adminUserIds = raw.cast<String>().toSet();
      }
      _loaded = true;
      notifyListeners();
    }, onError: (dynamic e) {
      debugPrint('AdminService.listen error: $e');
    });
  }

  bool get loaded => _loaded;

  // ── Grant / revoke admin ────────────────────────────────────────────────────

  /// Adds [userId] to the Firestore admin list.
  Future<void> grantAdmin(String userId) async {
    _requireAdmin();
    await Future.wait([
      _db.doc(_adminDoc).set({
        'adminUserIds': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true)),
      _db.collection('users').doc(userId).set(
        {'isAdmin': true},
        SetOptions(merge: true),
      ),
    ]);
    debugPrint('AdminService: granted admin to $userId');
  }

  /// Removes [userId] from the Firestore admin list.
  /// Superadmin numeric IDs cannot be revoked this way.
  Future<void> revokeAdmin(String userId) async {
    _requireAdmin();
    await Future.wait([
      _db.doc(_adminDoc).set({
        'adminUserIds': FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true)),
      _db.collection('users').doc(userId).set(
        {'isAdmin': false},
        SetOptions(merge: true),
      ),
    ]);
    debugPrint('AdminService: revoked admin from $userId');
  }

  // ── Grant / revoke premium ─────────────────────────────────────────────────

  /// Sets isPremium = true and generates a unique membershipId if not already set.
  Future<void> grantPremium(String userId) async {
    _requireAdmin();
    final doc  = await _db.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final existingMid = data['membershipId'] as String?;

    final fields = <String, dynamic>{'isPremium': true};
    if (existingMid == null || existingMid.isEmpty) {
      final numericId = data['numericId'];
      final suffix = (math.Random().nextInt(9000) + 1000).toString();
      fields['membershipId'] = numericId != null
          ? 'MSB-$numericId-$suffix'
          : 'MSB-${DateTime.now().millisecondsSinceEpoch % 999999 + 100000}-$suffix';
    }

    await _db.collection('users').doc(userId).set(
      fields,
      SetOptions(merge: true),
    );
    debugPrint('AdminService: granted premium to $userId');
  }

  /// Sets isPremium = false on any user's Firestore doc.
  Future<void> revokePremium(String userId) async {
    _requireAdmin();
    await _db.collection('users').doc(userId).set(
      {'isPremium': false},
      SetOptions(merge: true),
    );
    debugPrint('AdminService: revoked premium from $userId');
  }

  // ── User search / load ──────────────────────────────────────────────────────

  /// Loads the most recently updated users (up to [limit]).
  Future<List<UserProfile>> loadRecentUsers({int limit = 50}) async {
    _requireAdmin();
    try {
      final snap = await _db
          .collection('users')
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(UserProfile.fromFirestore).toList();
    } catch (e) {
      debugPrint('AdminService.loadRecentUsers error: $e');
      return [];
    }
  }

  /// Searches users by name prefix (case-insensitive).
  Future<List<UserProfile>> searchUsers(String query) async {
    _requireAdmin();
    return UserService().searchByName(query, limit: 20);
  }

  /// Searches users by exact numeric ID.
  Future<UserProfile?> searchByNumericId(int id) async {
    _requireAdmin();
    return UserService().searchByNumericId(id);
  }

  /// Searches users by exact email (case-insensitive).
  Future<UserProfile?> searchByEmail(String email) async {
    _requireAdmin();
    return UserService().searchByEmail(email);
  }

  // ── Edit any user ───────────────────────────────────────────────────────────

  /// Writes arbitrary field updates to any user document.
  Future<void> updateUserFields(
      String userId, Map<String, dynamic> fields) async {
    _requireAdmin();
    await _db
        .collection('users')
        .doc(userId)
        .set(fields, SetOptions(merge: true));
    debugPrint('AdminService: updated fields for $userId: ${fields.keys}');
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _requireAdmin() {
    if (!isCurrentUserAdmin) {
      throw StateError('AdminService: caller is not an admin');
    }
  }
}
