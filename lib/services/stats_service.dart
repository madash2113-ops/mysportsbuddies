import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'user_service.dart';
import '../core/models/match_score.dart';

/// Reads and writes per-player sport statistics.
///
/// Stats are stored directly inside each user document under:
///   users/{userId}.sportStats.{Sport}.{ batting / bowling / formats }
///   users/{userId}.defaultSport
///
/// ICC-standard stats tracked:
///   Batting  — innings, runs, balls, 4s, 6s, HS, 50s, 100s, notOuts, ducks
///   Bowling  — innings, wickets, runs, overs, extraBalls, maidens, bestFigure, 5W
///   Both     — matches (incremented ONCE per player per match, not per innings)
class StatsService extends ChangeNotifier {
  static final StatsService _i = StatsService._();
  factory StatsService() => _i;
  StatsService._();

  static const _col = 'users';
  final _db = FirebaseFirestore.instance;

  // ── In-memory cache ────────────────────────────────────────────────────────
  Map<String, Map<String, dynamic>> _stats = {};
  String? _defaultSport;

  Map<String, Map<String, dynamic>> get allStats   => _stats;
  String?                           get defaultSport => _defaultSport;

  /// List of sports for which this player has at least one recorded stat.
  List<String> get activeSports => _stats.keys.toList()..sort();

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final uid = UserService().userId;
    if (uid == null) return;

    final snap = await _db.doc('$_col/$uid').get();
    final data = snap.data();
    if (data == null) return;

    _defaultSport = data['defaultSport'] as String?;
    final raw = data['sportStats'] as Map<String, dynamic>?;
    if (raw == null) {
      _stats = {};
      notifyListeners();
      return;
    }

    _stats = raw.map((sport, v) {
      final sportMap = Map<String, dynamic>.from(v as Map);
      // ── Backward-compat: old stats stored directly at sport level ──────
      // If the map has 'batting' or 'bowling' but NOT 'regular'/'career',
      // it was written before the split — treat it as 'regular'.
      if ((sportMap.containsKey('batting') || sportMap.containsKey('bowling') ||
              sportMap.containsKey('matches')) &&
          !sportMap.containsKey('regular') &&
          !sportMap.containsKey('career')) {
        return MapEntry(sport, <String, dynamic>{'regular': sportMap});
      }
      return MapEntry(sport, sportMap);
    });

    notifyListeners();
  }

  // ── Default sport ─────────────────────────────────────────────────────────

  Future<void> setDefaultSport(String sport) async {
    final uid = UserService().userId;
    if (uid == null) return;
    _defaultSport = sport;
    notifyListeners();
    await _db.doc('$_col/$uid').update({'defaultSport': sport});
  }

  // ── Stats accessor ────────────────────────────────────────────────────────

  Map<String, dynamic>? statsForSport(String sport) => _stats[sport];

  // ── Update from a completed match ─────────────────────────────────────────

  Future<void> updateFromMatch(LiveMatch match, {bool isCareer = false}) async {
    if (match.sport == MatchSport.cricket && match.cricket != null) {
      await _updateCricket(match, isCareer: isCareer);
    }
    // Future sports: football goals, etc.
    await load(); // Refresh cache
  }

  // ── Cricket ───────────────────────────────────────────────────────────────

  Future<void> _updateCricket(LiveMatch match, {bool isCareer = false}) async {
    final format   = match.format.isEmpty ? 'Other' : match.format;
    final statsKey = isCareer ? 'career' : 'regular';
    final cricket  = match.cricket!;

    // ── 1. Collect ALL registered player IDs ─────────────────────────────
    // Start from the full roster lists so players who played but didn't
    // bat or bowl still get their match count incremented.
    final allUserIds = <String>{};
    for (final uid in [
      ...match.teamAPlayerUserIds,
      ...match.teamBPlayerUserIds,
    ]) {
      if (uid.isNotEmpty) allUserIds.add(uid);
    }
    // Also capture any userId tracked on in-game batsmen/bowlers that might
    // not be in the roster lists (e.g., sub fielders, last-minute additions).
    for (final inn in cricket.innings) {
      for (final bat in inn.batsmen) {
        if (bat.userId != null && bat.userId!.isNotEmpty) {
          allUserIds.add(bat.userId!);
        }
      }
      for (final bowl in inn.bowlers) {
        if (bowl.userId != null && bowl.userId!.isNotEmpty) {
          allUserIds.add(bowl.userId!);
        }
      }
    }

    // ── 2. Increment match count ONCE per registered player ───────────────
    for (final uid in allUserIds) {
      await _incrementMatch(userId: uid, format: format, statsKey: statsKey);
    }

    // ── 3. Batting & bowling performance stats ────────────────────────────
    for (final inn in cricket.innings) {
      for (final bat in inn.batsmen) {
        final uid = bat.userId;
        if (uid == null || uid.isEmpty) continue;
        if (bat.balls == 0 && !bat.isOut) continue;
        await _updateBatting(
          userId:   uid,
          format:   format,
          statsKey: statsKey,
          runs:     bat.runs,
          balls:    bat.balls,
          fours:    bat.fours,
          sixes:    bat.sixes,
          isOut:    bat.isOut,
        );
      }

      for (final bowl in inn.bowlers) {
        final uid = bowl.userId;
        if (uid == null || uid.isEmpty) continue;
        final totalBalls = bowl.completedOvers * 6 + bowl.balls;
        if (totalBalls == 0) continue;
        await _updateBowling(
          userId:         uid,
          format:         format,
          statsKey:       statsKey,
          wickets:        bowl.wickets,
          runs:           bowl.runs,
          completedOvers: bowl.completedOvers,
          extraBalls:     bowl.balls,
          maidens:        bowl.maidens,
        );
      }
    }
  }

  // ── Increment match counter (one call per player per match) ───────────────

  Future<void> _incrementMatch({
    required String userId,
    required String format,
    required String statsKey,
  }) async {
    try {
      await _db.doc('$_col/$userId').update({
        'sportStats.Cricket.$statsKey.matches':                  FieldValue.increment(1),
        'sportStats.Cricket.$statsKey.formats.$format.matches': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('StatsService._incrementMatch error [$userId]: $e');
    }
  }

  // ── ICC-standard batting update ───────────────────────────────────────────

  Future<void> _updateBatting({
    required String userId,
    required String format,
    required String statsKey,
    required int    runs,
    required int    balls,
    required int    fours,
    required int    sixes,
    required bool   isOut,
  }) async {
    final isHundred = runs >= 100;
    final isFifty   = !isHundred && runs >= 50;
    final isDuck    = isOut && runs == 0;
    final ref       = _db.doc('$_col/$userId');
    final sk        = statsKey;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};

        final curHS    = _deepInt(data, ['sportStats', 'Cricket', sk, 'batting', 'highestScore']) ?? 0;
        final newHS    = runs > curHS ? runs : curHS;
        final curFmtHS = _deepInt(data, ['sportStats', 'Cricket', sk, 'formats', format, 'highestScore']) ?? 0;
        final newFmtHS = runs > curFmtHS ? runs : curFmtHS;

        tx.update(ref, {
          'sportStats.Cricket.$sk.batting.innings':      FieldValue.increment(1),
          'sportStats.Cricket.$sk.batting.runs':         FieldValue.increment(runs),
          'sportStats.Cricket.$sk.batting.balls':        FieldValue.increment(balls),
          'sportStats.Cricket.$sk.batting.fours':        FieldValue.increment(fours),
          'sportStats.Cricket.$sk.batting.sixes':        FieldValue.increment(sixes),
          'sportStats.Cricket.$sk.batting.highestScore': newHS,
          if (isHundred) 'sportStats.Cricket.$sk.batting.hundreds': FieldValue.increment(1),
          if (isFifty)   'sportStats.Cricket.$sk.batting.fifties':  FieldValue.increment(1),
          if (!isOut)    'sportStats.Cricket.$sk.batting.notOuts':  FieldValue.increment(1),
          if (isDuck)    'sportStats.Cricket.$sk.batting.ducks':    FieldValue.increment(1),

          'sportStats.Cricket.$sk.formats.$format.batting.innings':      FieldValue.increment(1),
          'sportStats.Cricket.$sk.formats.$format.batting.runs':         FieldValue.increment(runs),
          'sportStats.Cricket.$sk.formats.$format.batting.balls':        FieldValue.increment(balls),
          'sportStats.Cricket.$sk.formats.$format.batting.fours':        FieldValue.increment(fours),
          'sportStats.Cricket.$sk.formats.$format.batting.sixes':        FieldValue.increment(sixes),
          'sportStats.Cricket.$sk.formats.$format.highestScore':         newFmtHS,
          if (isHundred) 'sportStats.Cricket.$sk.formats.$format.batting.hundreds': FieldValue.increment(1),
          if (isFifty)   'sportStats.Cricket.$sk.formats.$format.batting.fifties':  FieldValue.increment(1),
          if (!isOut)    'sportStats.Cricket.$sk.formats.$format.batting.notOuts':  FieldValue.increment(1),
          if (isDuck)    'sportStats.Cricket.$sk.formats.$format.batting.ducks':    FieldValue.increment(1),
        });
      });
    } catch (e) {
      debugPrint('StatsService._updateBatting error [$userId]: $e');
    }
  }

  // ── ICC-standard bowling update ───────────────────────────────────────────

  Future<void> _updateBowling({
    required String userId,
    required String format,
    required String statsKey,
    required int    wickets,
    required int    runs,
    required int    completedOvers,
    required int    extraBalls,
    required int    maidens,
  }) async {
    final isFiveWickets = wickets >= 5;
    final ref = _db.doc('$_col/$userId');
    final sk  = statsKey;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data  = snap.data() ?? {};

        final bestW    = _deepInt(data, ['sportStats', 'Cricket', sk, 'bowling', 'bestWickets']) ?? 0;
        final bestR    = _deepInt(data, ['sportStats', 'Cricket', sk, 'bowling', 'bestRuns'])    ?? 9999;
        final isBetter = wickets > bestW || (wickets == bestW && runs < bestR);

        tx.update(ref, {
          'sportStats.Cricket.$sk.bowling.innings':        FieldValue.increment(1),
          'sportStats.Cricket.$sk.bowling.wickets':        FieldValue.increment(wickets),
          'sportStats.Cricket.$sk.bowling.runs':           FieldValue.increment(runs),
          'sportStats.Cricket.$sk.bowling.completedOvers': FieldValue.increment(completedOvers),
          'sportStats.Cricket.$sk.bowling.extraBalls':     FieldValue.increment(extraBalls),
          'sportStats.Cricket.$sk.bowling.maidens':        FieldValue.increment(maidens),
          if (isBetter)      'sportStats.Cricket.$sk.bowling.bestWickets':  wickets,
          if (isBetter)      'sportStats.Cricket.$sk.bowling.bestRuns':     runs,
          if (isFiveWickets) 'sportStats.Cricket.$sk.bowling.fiveWickets': FieldValue.increment(1),

          'sportStats.Cricket.$sk.formats.$format.bowling.innings':        FieldValue.increment(1),
          'sportStats.Cricket.$sk.formats.$format.bowling.wickets':        FieldValue.increment(wickets),
          'sportStats.Cricket.$sk.formats.$format.bowling.runs':           FieldValue.increment(runs),
          'sportStats.Cricket.$sk.formats.$format.bowling.completedOvers': FieldValue.increment(completedOvers),
          'sportStats.Cricket.$sk.formats.$format.bowling.extraBalls':     FieldValue.increment(extraBalls),
          'sportStats.Cricket.$sk.formats.$format.bowling.maidens':        FieldValue.increment(maidens),
          if (isFiveWickets) 'sportStats.Cricket.$sk.formats.$format.bowling.fiveWickets': FieldValue.increment(1),
        });
      });
    } catch (e) {
      debugPrint('StatsService._updateBowling error [$userId]: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int? _deepInt(Map<String, dynamic> data, List<String> path) {
    dynamic cur = data;
    for (final key in path) {
      if (cur is! Map) return null;
      cur = cur[key];
    }
    return (cur as num?)?.toInt();
  }
}
