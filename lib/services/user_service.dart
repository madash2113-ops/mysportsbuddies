import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/user_profile.dart';
import '../core/config/app_config.dart';

/// Manages profile persistence using Firestore (text) and Firebase Storage (image).
///
/// Signs in with Firebase Anonymous Auth on first launch so that:
///  - Firebase Storage rules can require `request.auth != null`
///  - Firestore rules can require `request.auth != null`
///  - The anonymous UID is stable across restarts (Firebase persists it)
///
/// Recommended Firebase rules:
///   Firestore:  allow read, write: if request.auth != null;
///   Storage:    allow read, write: if request.auth != null;
class UserService extends ChangeNotifier {
  UserService._();
  static final UserService _instance = UserService._();
  factory UserService() => _instance;

  static const _col     = 'users';
  static const _prefKey = 'msb_user_id';   // kept for migration fallback

  FirebaseFirestore  get _db      => FirebaseFirestore.instance;
  FirebaseStorage    get _storage => FirebaseStorage.instance;
  FirebaseAuth       get _auth    => FirebaseAuth.instance;

  String?      _userId;
  UserProfile? _profile;
  bool         _initialized = false;

  String?      get userId      => _userId;
  UserProfile? get profile     => _profile;
  bool         get initialized => _initialized;

  /// True when the user may access all premium features.
  /// In dev mode (kDevMode = true) this is always true.
  /// In production it is true for owner UIDs and paid users.
  bool get hasFullAccess {
    if (kDevMode) return true;
    if (_userId != null && kOwnerUserIds.contains(_userId)) return true;
    return _profile?.isPremium == true;
  }

  // ── Numeric ID generation ─────────────────────────────────────────────────

  /// Generates a unique 6-digit integer player ID (100000–999999).
  /// Retries on the extremely rare collision.
  Future<int> _generateUniqueNumericId() async {
    final rand = Random.secure();
    while (true) {
      final candidate = 100000 + rand.nextInt(900000); // 100000–999999
      final snap = await _db
          .collection(_col)
          .where('numericId', isEqualTo: candidate)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return candidate;
      // Collision — retry (extremely rare)
    }
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  /// Call once after Firebase.initializeApp().
  /// Signs in anonymously to obtain a Firebase Auth token, then loads profile.
  Future<void> init() async {
    _userId = await _signInAndGetId();
    await _loadProfile();
    await _ensureNumericId();
    _initialized = true;
    notifyListeners();
  }

  /// If the current user has no numericId yet, generate a unique one and
  /// persist it to Firestore. This runs once on first app launch.
  Future<void> _ensureNumericId() async {
    if (_profile?.numericId != null) return;
    if (_userId == null) return;
    try {
      final newId = await _generateUniqueNumericId();
      await _db
          .collection(_col)
          .doc(_userId)
          .set({'numericId': newId}, SetOptions(merge: true));
      final base = _profile ?? UserProfile(id: _userId!, updatedAt: DateTime.now());
      _profile = base.copyWith(numericId: newId);
    } catch (e) {
      debugPrint('UserService._ensureNumericId error: $e');
    }
  }

  /// Signs in anonymously (or reuses existing session) and returns the UID.
  Future<String> _signInAndGetId() async {
    try {
      // Reuse existing session if already signed in
      User? user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
      }
      if (user != null) {
        debugPrint('✅ Firebase anonymous auth UID: ${user.uid}');
        // Migrate old device-ID based data if needed
        await _migrateOldId(user.uid);
        return user.uid;
      }
    } catch (e) {
      debugPrint('UserService._signInAndGetId error: $e');
    }
    // Fallback: use SharedPreferences-based device ID
    return _loadOrCreateDeviceId();
  }

  /// If the user had an old random device ID, save it as an alias so
  /// their old data is not lost (best-effort).
  Future<void> _migrateOldId(String authUid) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final oldId   = prefs.getString(_prefKey);
      if (oldId != null && oldId.isNotEmpty && oldId != authUid) {
        // Store old→new mapping (fire-and-forget)
        _db.collection('id_migrations').doc(oldId).set({
          'newId':     authUid,
          'migratedAt': FieldValue.serverTimestamp(),
        }).catchError((dynamic _) {});
        // Clear old pref so we don't migrate again
        await prefs.remove(_prefKey);
      }
    } catch (_) {}
  }

  Future<String> _loadOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id  = prefs.getString(_prefKey);
      if (id == null || id.isEmpty) {
        id = _auth.currentUser?.uid ??
            DateTime.now().millisecondsSinceEpoch.toRadixString(16);
        await prefs.setString(_prefKey, id);
      }
      return id;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    }
  }

  // ── Auth transition ───────────────────────────────────────────────────────

  /// Called by AuthService after a real (non-anonymous) sign-in.
  /// Switches the service to use [uid] and creates the Firestore profile if
  /// it does not exist yet.
  Future<void> reloadForUser(
    String uid, {
    String? name,
    String? email,
    String? phone,
  }) async {
    _userId = uid;
    await _loadProfile();

    if (_profile == null) {
      // First sign-in with this account — create an initial profile
      final newProfile = UserProfile(
        id:        uid,
        name:      name  ?? '',
        email:     email ?? '',
        phone:     phone ?? '',
        updatedAt: DateTime.now(),
      );
      await saveProfile(newProfile);
    } else if (_profile!.name.isEmpty && (name?.isNotEmpty == true)) {
      // Profile exists but has no name yet (e.g. migrated from anonymous)
      await saveProfile(_profile!.copyWith(
        name:  name,
        email: email ?? _profile!.email,
        phone: phone ?? _profile!.phone,
      ));
    }

    await _ensureNumericId();
    _initialized = true;
    notifyListeners();
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    if (_userId == null) return;
    try {
      final doc = await _db.collection(_col).doc(_userId).get();
      if (doc.exists) {
        _profile = UserProfile.fromFirestore(doc);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('UserService._loadProfile error: $e');
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  /// Saves profile data to Firestore using merge (only writes changed fields).
  Future<void> saveProfile(UserProfile profile) async {
    if (_userId == null) return;
    try {
      await _db
          .collection(_col)
          .doc(_userId)
          .set(profile.toMap(), SetOptions(merge: true));
      _profile = profile;
      notifyListeners();
    } catch (e) {
      debugPrint('UserService.saveProfile error: $e');
      rethrow;
    }
  }

  /// Loads any user's public profile by their userId.
  Future<UserProfile?> loadProfileById(String userId) async {
    try {
      final doc = await _db.collection(_col).doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      debugPrint('UserService.loadProfileById error: $e');
      return null;
    }
  }

  /// Uploads profile image to Firebase Storage and returns the download URL.
  Future<String> uploadProfileImage(File imageFile) async {
    final id  = _userId ?? _auth.currentUser?.uid ?? 'unknown';
    final ref = _storage.ref('profile_images/$id.jpg');
    await ref.putFile(imageFile).timeout(const Duration(seconds: 60));
    return ref.getDownloadURL();
  }

  // ── Player search ─────────────────────────────────────────────────────────

  /// Look up a registered player by their 6-digit numeric ID.
  /// Returns null if not found or on error.
  Future<UserProfile?> searchByNumericId(int numericId) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('numericId', isEqualTo: numericId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return UserProfile.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('UserService.searchByNumericId error: $e');
      return null;
    }
  }

  /// Search registered players by name prefix.
  /// Returns up to [limit] results.
  Future<List<UserProfile>> searchByName(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final snap = await _db
          .collection(_col)
          .where('name', isGreaterThanOrEqualTo: q)
          .where('name', isLessThan: '${q}z')
          .limit(limit)
          .get();
      return snap.docs.map(UserProfile.fromFirestore).toList();
    } catch (e) {
      debugPrint('UserService.searchByName error: $e');
      return [];
    }
  }

  /// Search by email — exact match (used in player lookup).
  Future<UserProfile?> searchByEmail(String email) async {
    final q = email.trim().toLowerCase();
    if (q.isEmpty) return null;
    try {
      final snap = await _db
          .collection(_col)
          .where('email', isEqualTo: q)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return UserProfile.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('UserService.searchByEmail error: $e');
      return null;
    }
  }
}
