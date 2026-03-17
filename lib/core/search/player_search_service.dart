import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/player_entry.dart';
import '../models/user_profile.dart';

/// Ranked wrapper around a search result.
class PlayerSearchResult {
  final PlayerEntry entry;

  /// Lower = better rank.
  ///  0 = exact name / ID match
  ///  1 = starts-with name / exact ID
  ///  2 = contains or word-prefix
  ///  3 = phone / email / indirect
  ///  4 = manual "add new" entry
  final int rank;

  const PlayerSearchResult({required this.entry, required this.rank});
}

// ── LRU cache entry ─────────────────────────────────────────────────────────

class _CacheEntry {
  final List<PlayerSearchResult> results;
  final DateTime ts;
  _CacheEntry(this.results, this.ts);
  bool get isExpired =>
      DateTime.now().difference(ts) > PlayerSearchService._cacheTtl;
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Singleton service that powers ALL player search in the app.
///
/// Features:
///  - Parallel Firestore queries (name, ID, phone, email) — results stream in
///  - Client-side relevance ranking
///  - LRU cache (40 entries, 5-min TTL) — no repeat round-trips
///  - Progressive callbacks: [onPartialResults] fires as each query returns
///  - Always appends "Add new player" option for name queries
class PlayerSearchService {
  PlayerSearchService._();
  static final PlayerSearchService _instance = PlayerSearchService._();
  factory PlayerSearchService() => _instance;

  static const _col       = 'users';
  static const _cacheTtl  = Duration(minutes: 5);
  static const _cacheSize = 40;
  static const _limit     = 10;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final _cache = <String, _CacheEntry>{};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Full search — returns when ALL parallel queries complete.
  /// Results are deduplicated, ranked, and include a "manual" entry when
  /// the query looks like a name.
  Future<List<PlayerSearchResult>> search(
    String rawQuery, {
    bool includeManual = true,
  }) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return [];

    final cached = _cache[q];
    if (cached != null && !cached.isExpired) return cached.results;

    final seen    = <String>{};
    final profiles = <UserProfile>[];

    await _runAll(q, (incoming) {
      for (final p in incoming) {
        if (seen.add(p.id)) profiles.add(p);
      }
    });

    final results = _rank(profiles, q);

    if (includeManual && _isNameQuery(q)) {
      results.add(PlayerSearchResult(
        entry: PlayerEntry.manual(q),
        rank: 4,
      ));
    }

    _putCache(q, results);
    return results;
  }

  /// Streaming search — [onResults] is called progressively each time any
  /// parallel query returns. Use this for the live dropdown experience.
  Future<void> searchStreaming(
    String rawQuery, {
    required void Function(List<PlayerSearchResult>) onResults,
    bool includeManual = true,
  }) async {
    final q = rawQuery.trim();
    if (q.isEmpty) {
      onResults([]);
      return;
    }

    // Cache hit — emit immediately
    final cached = _cache[q];
    if (cached != null && !cached.isExpired) {
      onResults(cached.results);
      return;
    }

    final seen     = <String>{};
    final profiles = <UserProfile>[];

    await _runAll(q, (incoming) {
      bool changed = false;
      for (final p in incoming) {
        if (seen.add(p.id)) {
          profiles.add(p);
          changed = true;
        }
      }
      if (!changed) return;

      final partial = _rank(List.of(profiles), q);
      if (includeManual && _isNameQuery(q)) {
        partial.add(PlayerSearchResult(
          entry: PlayerEntry.manual(q),
          rank: 4,
        ));
      }
      onResults(partial);
    });

    // Final emit after all queries done (de-duped / sorted)
    final final_ = _rank(profiles, q);
    if (includeManual && _isNameQuery(q)) {
      final_.add(PlayerSearchResult(
        entry: PlayerEntry.manual(q),
        rank: 4,
      ));
    }
    _putCache(q, final_);
    onResults(final_);
  }

  /// Clears the cache — call after profile saves or enrollments.
  void invalidate() => _cache.clear();

  // ── Query execution ────────────────────────────────────────────────────────

  /// Fires all applicable Firestore queries in parallel and calls [absorb]
  /// each time any query returns results.
  Future<void> _runAll(
    String q,
    void Function(List<UserProfile>) absorb,
  ) async {
    final qLow    = q.toLowerCase();
    final qTitle  = q[0].toUpperCase() +
        (q.length > 1 ? q.substring(1).toLowerCase() : '');
    final digits  = q.replaceAll(RegExp(r'\D'), '');

    Future<void> prefixQuery(String field, String value) async {
      try {
        final snap = await _db
            .collection(_col)
            .where(field, isGreaterThanOrEqualTo: value)
            .where(field, isLessThan: '$value\uf8ff')
            .limit(_limit)
            .get();
        absorb(snap.docs.map(UserProfile.fromFirestore).toList());
      } catch (e) {
        debugPrint('PlayerSearchService prefix($field) error: $e');
      }
    }

    Future<void> exactQuery(String field, Object value) async {
      try {
        final snap = await _db
            .collection(_col)
            .where(field, isEqualTo: value)
            .limit(1)
            .get();
        absorb(snap.docs.map(UserProfile.fromFirestore).toList());
      } catch (e) {
        debugPrint('PlayerSearchService exact($field) error: $e');
      }
    }

    Future<void> arrayQuery(String field, String value) async {
      try {
        final snap = await _db
            .collection(_col)
            .where(field, arrayContains: value)
            .limit(_limit)
            .get();
        absorb(snap.docs.map(UserProfile.fromFirestore).toList());
      } catch (e) {
        debugPrint('PlayerSearchService array($field) error: $e');
      }
    }

    final qUpper = q.toUpperCase();

    final futures = <Future<void>>[
      // ── Indexed fields (users who have logged in after backfill) ──────────
      prefixQuery('nameLower',    qLow),    // case-insensitive prefix
      prefixQuery('nameReversed', qLow),    // last-name-first prefix
      arrayQuery ('nameWords',    qLow),    // exact word in name

      // ── Legacy `name` field — ALL case variants in parallel ───────────────
      // Firestore string order is Unicode code-point order, so:
      //   'A'(65) < 'a'(97)  →  "Avinas\uf8ff" < "avinash"
      // We must query each stored-case variant separately.
      prefixQuery('name', qLow),    // stored lowercase: "avinash kumar maddini"
      prefixQuery('name', qTitle),  // stored title-case: "Avinash Kumar Maddini"
      prefixQuery('name', qUpper),  // stored ALL-CAPS:   "AVINASH KUMAR MADDINI"
      if (q != qLow && q != qTitle && q != qUpper)
        prefixQuery('name', q),     // original typed case if none of the above
    ];

    // ── Numeric ID — exactly 6 digits ────────────────────────────────────────
    if (digits == q && q.length == 6) {
      final asNum = int.tryParse(q);
      if (asNum != null) {
        futures.add(exactQuery('numericId', asNum));
      }
    }

    // ── Phone — 10+ consecutive digits ───────────────────────────────────────
    if (digits.length >= 10) {
      final variants = <String>{q, digits};
      if (digits.length == 10) {
        variants.addAll(['+91$digits', '91$digits', '0$digits']);
      } else if (digits.length == 12 && digits.startsWith('91')) {
        variants.addAll([digits.substring(2), '+$digits']);
      } else if (digits.length == 11 && digits.startsWith('0')) {
        variants.add(digits.substring(1));
      }
      for (final v in variants) {
        futures.add(exactQuery('phone', v));
      }
    }

    // ── Email ─────────────────────────────────────────────────────────────────
    if (q.contains('@')) {
      futures.add(exactQuery('email', qLow));
    }

    await Future.wait(futures);
  }

  // ── Ranking ────────────────────────────────────────────────────────────────

  List<PlayerSearchResult> _rank(List<UserProfile> profiles, String q) {
    final qLow = q.toLowerCase();

    int score(UserProfile p) {
      final name = p.nameLower;
      final idStr = p.numericId?.toString() ?? '';

      if (name == qLow || idStr == q)               return 0; // exact
      if (name.startsWith(qLow) || idStr.startsWith(q)) return 1; // prefix
      if (name.contains(qLow))                      return 2; // substring
      if (p.nameWords.any((w) => w.startsWith(qLow))) return 2; // word prefix
      if ((p.phone.contains(q)) || (p.email.toLowerCase().contains(qLow))) {
        return 3; // contact match
      }
      return 4;
    }

    final results = profiles
        .map((p) => PlayerSearchResult(
              entry: PlayerEntry.fromProfile(p),
              rank:  score(p),
            ))
        .toList()
      ..sort((a, b) {
        final r = a.rank.compareTo(b.rank);
        if (r != 0) return r;
        return a.entry.displayName
            .toLowerCase()
            .compareTo(b.entry.displayName.toLowerCase());
      });

    return results;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns true when the query looks like a plain name (not ID/phone/email).
  bool _isNameQuery(String q) {
    if (q.contains('@')) return false;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits == q && q.length >= 6) return false; // all-digit query
    return true;
  }

  void _putCache(String key, List<PlayerSearchResult> results) {
    if (_cache.length >= _cacheSize) _cache.remove(_cache.keys.first);
    _cache[key] = _CacheEntry(results, DateTime.now());
  }
}
