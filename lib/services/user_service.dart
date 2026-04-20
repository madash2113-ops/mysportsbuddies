import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/user_profile.dart';
import '../core/config/app_config.dart';
import 'analytics_service.dart';

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
  // Explicitly target the new-format bucket (firebasestorage.app).
  // FirebaseStorage.instance can default to the legacy appspot.com bucket
  // which doesn't exist for this project, causing object-not-found errors.
  FirebaseStorage    get _storage => FirebaseStorage.instanceFor(
    bucket: 'gs://mysportsbuddies-4d077.firebasestorage.app',
  );
  FirebaseAuth       get _auth    => FirebaseAuth.instance;

  String?      _userId;
  UserProfile? _profile;
  bool         _initialized = false;
  StreamSubscription<DocumentSnapshot>? _profileSub;

  String?      get userId      => _userId;
  UserProfile? get profile     => _profile;
  bool         get initialized => _initialized;

  /// True when the user may access all premium features.
  /// In dev mode (kDevMode = true) this is always true.
  /// In production it is true for owner UIDs and paid users.
  bool get hasFullAccess {
    if (kDevMode) return true;
    if (_userId != null && kOwnerUserIds.contains(_userId)) return true;
    final nid = _profile?.numericId;
    if (nid != null && kOwnerNumericIds.contains(nid)) return true;
    if (_profile?.isAdmin == true) return true;
    return _profile?.isPremium == true;
  }

  /// Returns true if the current user holds [key] in their entitlements set.
  /// Owners, admins, and dev-mode users are granted every entitlement.
  /// Falls back to [hasFullAccess] so existing `isPremium` grants still work.
  bool hasEntitlement(String key) {
    if (hasFullAccess) return true;
    return _profile?.entitlements.contains(key) ?? false;
  }

  /// Convenience — which plan tier the signed-in user is on.
  PlanTier get planTier => _profile?.planTier ?? PlanTier.free;

  // ── Numeric ID generation ─────────────────────────────────────────────────

  static const _counterDoc = 'config/numericIdCounter';

  /// Atomically claims the next sequential 5-digit player ID (10000–99999).
  /// ID 1 is reserved for the owner via [kReservedNumericIds].
  Future<int> _generateUniqueNumericId() async {
    final counterRef = _db.doc(_counterDoc);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(counterRef);
      final next = (snap.data()?['next'] as int?) ?? 10000; // 5-digit start
      tx.set(counterRef, {'next': next + 1}, SetOptions(merge: true));
      return next;
    });
  }


  // ── Init ─────────────────────────────────────────────────────────────────

  /// Call once after Firebase.initializeApp().
  /// Signs in anonymously to obtain a Firebase Auth token, then loads profile.
  Future<void> init() async {
    _userId = await _signInAndGetId();
    await _loadProfile();
    await _ensureNumericId();
    _backfillSearchFields();       // fire-and-forget: indexes current user
    _globalBackfillSearchFields(); // fire-and-forget: indexes all unindexed users
    _startProfileListener(_userId!); // real-time updates (e.g. admin grants premium)
    _initialized = true;
    notifyListeners();
  }

  /// If the current user has no numericId yet, generate a unique one and
  /// persist it to Firestore. If a reserved ID is configured in
  /// [kReservedNumericIds] for this UID, that ID is used (and enforced even
  /// if a different ID was previously assigned).
  Future<void> _ensureNumericId() async {
    if (_userId == null) return;
    try {
      final reserved = kReservedNumericIds[_userId];
      // If a reserved ID is configured and current ID doesn't match, force it
      if (reserved != null && _profile?.numericId != reserved) {
        await _db
            .collection(_col)
            .doc(_userId)
            .set({'numericId': reserved, 'numericIdStr': reserved.toString()}, SetOptions(merge: true));
        final base = _profile ?? UserProfile(id: _userId!, updatedAt: DateTime.now());
        _profile = base.copyWith(numericId: reserved);
        return;
      }
      // Otherwise generate a new ID only if one isn't already assigned
      if (_profile?.numericId != null) return;
      final newId = await _generateUniqueNumericId();
      await _db
          .collection(_col)
          .doc(_userId)
          .set({'numericId': newId, 'numericIdStr': newId.toString()}, SetOptions(merge: true));
      final base = _profile ?? UserProfile(id: _userId!, updatedAt: DateTime.now());
      _profile = base.copyWith(numericId: newId);
    } catch (e) { /* ignored */ }
  }

  /// Backfills all search index fields for the current user's Firestore doc.
  /// Runs on every app start. Writes only if any field is missing so it is
  /// cheap after the first run, but correctly adds new fields (e.g. searchTokens)
  /// for users who were indexed by an older version of the app.
  Future<void> _backfillSearchFields() async {
    if (_userId == null || _profile == null) return;
    if (_profile!.name.isEmpty) return;
    try {
      final doc  = await _db.collection(_col).doc(_userId).get();
      final data = doc.data() ?? {};
      // Re-index if ANY field is missing (handles incremental schema additions)
      final needsUpdate = !data.containsKey('nameLower')
          || !data.containsKey('nameReversed')
          || !data.containsKey('nameWords')
          || !data.containsKey('searchTokens')
          || !data.containsKey('emailLower')
          || !data.containsKey('numericIdStr');
      if (!needsUpdate) return;
      final p = _profile!;
      await _db.collection(_col).doc(_userId).update({
        'nameLower':    p.nameLower,
        'nameReversed': p.nameReversed,
        'nameWords':    p.nameWords,
        'searchTokens': p.searchTokens,
        'emailLower':   p.emailLower,
        if (p.numericIdStr != null) 'numericIdStr': p.numericIdStr,
      });
    } catch (e) { /* ignored */ }
  }

  /// Global backfill — writes search index fields for all users who are
  /// missing them (nameLower, nameReversed, nameWords, searchTokens,
  /// emailLower, numericIdStr). Does NOT assign numericIds — each user
  /// receives their own ID when they first open the app.
  Future<void> _globalBackfillSearchFields() async {
    if (_userId == null) return;
    try {
      final results = await Future.wait([
        _db.collection(_col).where('searchTokens', isNull: true).limit(100).get(),
        _db.collection(_col).where('emailLower',   isNull: true).limit(100).get(),
      ]);

      final seen    = <String>{};
      final allDocs = results.expand((s) => s.docs)
          .where((d) => seen.add(d.id))
          .toList();

      if (allDocs.isEmpty) return;

      final batch = _db.batch();
      int   count = 0;

      for (final doc in allDocs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        if (name.isEmpty) continue;

        final p      = UserProfile.fromFirestore(doc);
        final update = <String, dynamic>{
          'emailLower': p.emailLower,
        };

        // Write numericIdStr if they already have a numericId but are missing the string form
        if (data.containsKey('numericId') && !data.containsKey('numericIdStr')) {
          update['numericIdStr'] = p.numericId.toString();
        }

        if (!data.containsKey('searchTokens')) {
          update['nameLower']    = p.nameLower;
          update['nameReversed'] = p.nameReversed;
          update['nameWords']    = p.nameWords;
          update['searchTokens'] = p.searchTokens;
        }

        batch.update(doc.reference, update);
        count++;
      }

      if (count > 0) {
        await batch.commit();
      }
    } catch (e) { /* ignored */ }
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
        // Migrate old device-ID based data if needed
        await _migrateOldId(user.uid);
        return user.uid;
      }
    } catch (e) { /* ignored */ }
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
    } catch (_) { /* ignored */ }
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
    _startProfileListener(uid); // real-time updates for this user
    _initialized = true;
    notifyListeners();

    // Set analytics user properties so every subsequent event is segmented
    final p = _profile;
    if (p != null) {
      AnalyticsService().setUserProperties(
        role: p.role.name,
        isPremium: p.isPremium,
        primarySport: p.favoriteSports?.firstOrNull ?? '',
        hasPlayedMatch: p.matchesPlayed > 0,
      );
    }
  }

  // ── Real-time profile listener ────────────────────────────────────────────

  /// Subscribes to real-time updates for the current user's Firestore doc.
  /// Any external write (e.g. admin granting premium) is picked up instantly.
  /// Also auto-generates a membershipId if the user is premium but has none.
  void _startProfileListener(String uid) {
    _profileSub?.cancel();
    _profileSub = _db.collection(_col).doc(uid).snapshots().listen(
      (snap) async {
        if (!snap.exists) return;
        final p = UserProfile.fromFirestore(snap);
        _profile = p;
        notifyListeners();

        // Auto-generate membershipId if premium but none assigned yet
        if (p.isPremium && (p.membershipId == null || p.membershipId!.isEmpty)) {
          final suffix = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
          final mid = p.numericId != null
              ? 'MSB-${p.numericId}-$suffix'
              : 'MSB-${uid.substring(0, 6).toUpperCase()}-$suffix';
          try {
            await _db.collection(_col).doc(uid).set(
              {'membershipId': mid},
              SetOptions(merge: true),
            );
          } catch (e) { /* ignored */ }
        }
      },
      onError: (dynamic e) {
      },
    );
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
    } catch (e) { /* ignored */ }
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
      return null;
    }
  }

  /// Uploads profile image bytes to Firebase Storage and returns the download URL.
  Future<String> uploadProfileImageBytes(Uint8List bytes) async {
    final authUser = _auth.currentUser;
    final id       = _userId ?? authUser?.uid ?? 'unknown';

    // ── Diagnostics ──────────────────────────────────────────────────────────

    if (authUser == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthenticated',
        message: 'Not signed in. Restart the app and try again.',
      );
    }

    if (bytes.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'empty-file',
        message: 'Image has no data. Pick the photo again.',
      );
    }

    final ref = _storage.ref().child('profile_images').child('$id.jpg');

    TaskSnapshot snapshot;
    try {
      snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } catch (e) {
      rethrow;
    }


    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'upload-failed',
        message: 'Upload state: ${snapshot.state}',
      );
    }

    final url = await snapshot.ref.getDownloadURL();
    return url;
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
      return null;
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  /// Atomically increments one or more stat counters for any registered user.
  /// Safe to call with 0 deltas (no-op for that field).
  static Future<void> incrementStats(
    String userId, {
    int tournamentsPlayed = 0,
    int matchesPlayed = 0,
    int matchesWon = 0,
  }) async {
    if (userId.isEmpty) return;
    try {
      final data = <String, dynamic>{};
      if (tournamentsPlayed != 0) {
        data['tournamentsPlayed'] = FieldValue.increment(tournamentsPlayed);
      }
      if (matchesPlayed != 0) {
        data['matchesPlayed'] = FieldValue.increment(matchesPlayed);
      }
      if (matchesWon != 0) {
        data['matchesWon'] = FieldValue.increment(matchesWon);
      }
      if (data.isEmpty) return;
      await FirebaseFirestore.instance
          .collection(_col)
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) { /* ignored */ }
  }

  /// Search registered players by name.
  ///
  /// Uses three parallel Firestore queries so any part of the name matches:
  ///  1. Prefix on `nameLower`    — case-insensitive, e.g. "jesh" → "Jeshwanth Kumar"
  ///  2. Prefix on `nameReversed` — last-name-first,   e.g. "kumar" → "Jeshwanth Kumar"
  ///  3. `nameWords array-contains` — exact individual word, e.g. "kumar"
  ///  4. Fallback prefix on `name` (title-case) — covers unindexed legacy docs
  Future<List<UserProfile>> searchByName(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final qLow   = q.toLowerCase();
    final qTitle = q[0].toUpperCase() +
        (q.length > 1 ? q.substring(1).toLowerCase() : '');
    final qUpper = q.toUpperCase();

    Future<QuerySnapshot> prefixOn(String field, String value) => _db
        .collection(_col)
        .where(field, isGreaterThanOrEqualTo: value)
        .where(field, isLessThan: '$value\uf8ff')
        .limit(limit)
        .get();

    try {
      // Run ALL case variants in parallel — Firestore Unicode ordering means
      // each stored case ('avinash', 'Avinash', 'AVINASH') needs its own query.
      final snaps = await Future.wait([
        prefixOn('nameLower',    qLow),    // indexed lowercase field
        prefixOn('nameReversed', qLow),    // indexed reversed field
        _db.collection(_col)
            .where('nameWords', arrayContains: qLow)
            .limit(limit)
            .get(),
        prefixOn('name', qLow),    // stored as lowercase: "avinash kumar"
        prefixOn('name', qTitle),  // stored as title-case: "Avinash Kumar"
        prefixOn('name', qUpper),  // stored as ALLCAPS:   "AVINASH KUMAR"
      ]);

      final seen = <String>{};
      return snaps
          .expand((s) => s.docs)
          .map(UserProfile.fromFirestore)
          .where((p) => seen.add(p.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Search by email — exact match.
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
      return null;
    }
  }

  /// Cancels the current user's premium subscription.
  Future<void> cancelPremium() async {
    if (_userId == null) return;
    await _db.collection(_col).doc(_userId).set(
      {
        'isPremium': false,
        'planTier': PlanTier.free.name,
        'subscriptionStatus': SubscriptionStatus.cancelled.name,
        'entitlements': <String>[],
      },
      SetOptions(merge: true),
    );
  }

  /// Returns true if [phone] is already stored on a different user's profile.
  /// Pass [excludeUserId] to ignore the current user (for profile edits).
  Future<bool> isPhoneInUse(String phone, {String? excludeUserId}) async {
    final found = await searchByPhone(phone);
    if (found == null) return false;
    if (excludeUserId != null && found.id == excludeUserId) return false;
    return true;
  }

  /// Returns true if [email] is already stored on a different user's profile.
  /// Pass [excludeUserId] to ignore the current user (for profile edits).
  Future<bool> isEmailInUse(String email, {String? excludeUserId}) async {
    final found = await searchByEmail(email);
    if (found == null) return false;
    if (excludeUserId != null && found.id == excludeUserId) return false;
    return true;
  }

  /// Search by phone number — tries all common storage formats in parallel
  /// (+91XXXXXXXXXX, 91XXXXXXXXXX, 0XXXXXXXXXX, XXXXXXXXXX).
  Future<UserProfile?> searchByPhone(String phone) async {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // Build the set of format variants to query
    final variants = <String>{phone.trim(), digits};
    if (digits.length == 10) {
      variants.addAll(['+91$digits', '91$digits', '0$digits']);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      variants.add(digits.substring(2)); // strip country code
      variants.add('+$digits');
    } else if (digits.length == 11 && digits.startsWith('0')) {
      variants.add(digits.substring(1)); // strip leading 0
    }

    try {
      final snaps = await Future.wait(
        variants.map((v) =>
            _db.collection(_col).where('phone', isEqualTo: v).limit(1).get()),
      );
      for (final snap in snaps) {
        if (snap.docs.isNotEmpty) {
          return UserProfile.fromFirestore(snap.docs.first);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
