import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/models/match_score.dart';
import 'notification_service.dart';
import 'stats_service.dart';
import 'tournament_service.dart';
import 'user_service.dart';

/// Singleton ChangeNotifier — source of truth for all live scoreboards.
///
/// Firebase Firestore is connected when google-services.json / GoogleService-Info.plist
/// are present. Until then, everything runs in-memory.
///
/// To enable Firebase persistence:
///   1. Add google-services.json to android/app/
///   2. Add GoogleService-Info.plist to ios/Runner/
///   3. Run: flutter pub get
class ScoreboardService extends ChangeNotifier {
  static final ScoreboardService _instance = ScoreboardService._();
  factory ScoreboardService() => _instance;
  ScoreboardService._();

  final List<LiveMatch> _matches = [];
  Timer? _clockTimer;

  // ── Firestore ────────────────────────────────────────────────────────────
  static const _col = 'matches';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Fire-and-forget save — never blocks the UI. Safe to call with null.
  void _persist(LiveMatch? m) {
    if (m == null) return;
    _db.collection(_col).doc(m.id).set(m.toMap()).catchError(
      (dynamic e) => debugPrint('Firestore save error: $e'),
    );
  }

  /// Load all matches from Firestore on app start.
  Future<void> loadFromFirestore() async {
    try {
      final snap = await _db.collection(_col).get();
      for (final doc in snap.docs) {
        try {
          final m = LiveMatch.fromMap(doc.data());
          if (!_matches.any((x) => x.id == m.id)) _matches.add(m);
        } catch (e) {
          debugPrint('Match parse error ${doc.id}: $e');
        }
      }
      if (_matches.any((m) => m.status == MatchStatus.live)) _ensureClock();
      notifyListeners();
    } catch (e) {
      debugPrint('Firestore load error: $e');
    }
  }

  /// Real-time listener — keeps My Matches screen always up-to-date.
  void listenToFirestore() {
    _db.collection(_col).snapshots().listen((snap) {
      for (final doc in snap.docs) {
        try {
          final m = LiveMatch.fromMap(doc.data());
          final idx = _matches.indexWhere((x) => x.id == m.id);
          if (idx >= 0) {
            _matches[idx] = m;
          } else {
            _matches.add(m);
          }
        } catch (e) {
          debugPrint('ScoreboardService.listenToFirestore parse error: $e');
        }
      }
      notifyListeners();
    }, onError: (e) => debugPrint('ScoreboardService.listenToFirestore error: $e'));
  }

  // ── Undo stack (per match, max 20 entries) ───────────────────────────────
  final Map<String, List<Map<String, dynamic>>> _undoStacks = {};

  void _pushUndo(String matchId, CricketScore score) {
    _undoStacks.putIfAbsent(matchId, () => []);
    final stack = _undoStacks[matchId]!;
    stack.add(score.captureSnapshot());
    if (stack.length > 20) stack.removeAt(0);
  }

  void _pushRallyUndo(String matchId, RallyScore score) {
    _undoStacks.putIfAbsent(matchId, () => []);
    final stack = _undoStacks[matchId]!;
    stack.add(score.captureSnapshot());
    if (stack.length > 20) stack.removeAt(0);
  }

  void _pushUndoFor(String matchId, LiveMatch m) {
    _undoStacks.putIfAbsent(matchId, () => []);
    final stack = _undoStacks[matchId]!;
    Map<String, dynamic>? snap;
    if (m.football    != null) snap = m.football!.captureSnapshot();
    if (m.basketball  != null) snap = m.basketball!.captureSnapshot();
    if (m.hockey      != null) snap = m.hockey!.captureSnapshot();
    if (m.combat      != null) snap = m.combat!.captureSnapshot();
    if (m.esports     != null) snap = m.esports!.captureSnapshot();
    if (m.genericScore != null) snap = m.genericScore!.captureSnapshot();
    if (snap == null) return;
    stack.add(snap);
    if (stack.length > 20) stack.removeAt(0);
  }

  bool canUndo(String matchId) =>
      (_undoStacks[matchId]?.isNotEmpty) ?? false;

  void undo(String matchId) {
    final m = byId(matchId);
    if (m == null) return;
    final stack = _undoStacks[matchId];
    if (stack == null || stack.isEmpty) return;
    final snap = stack.removeLast();
    if (m.rally        != null) {
      m.rally!.restoreSnapshot(snap);
    } else if (m.cricket != null) m.cricket!.restoreSnapshot(snap);
    else if (m.football    != null) m.football!.restoreSnapshot(snap);
    else if (m.basketball  != null) m.basketball!.restoreSnapshot(snap);
    else if (m.hockey      != null) m.hockey!.restoreSnapshot(snap);
    else if (m.combat      != null) m.combat!.restoreSnapshot(snap);
    else if (m.esports     != null) m.esports!.restoreSnapshot(snap);
    else if (m.genericScore != null) m.genericScore!.restoreSnapshot(snap);
    _persist(m);
    notifyListeners();
  }

  // ── Read ────────────────────────────────────────────────────────────────
  List<LiveMatch> get all => List.unmodifiable(_matches);

  List<LiveMatch> bySport(String sportName) {
    final sport = sportFromName(sportName);
    return _matches
        .where((m) =>
            m.sport == sport ||
            m.sportDisplayName.toLowerCase() == sportName.toLowerCase())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  LiveMatch? byId(String id) =>
      _matches.where((m) => m.id == id).firstOrNull;

  // ── Match lifecycle ──────────────────────────────────────────────────────
  void addMatch(LiveMatch match) {
    _matches.add(match);
    _ensureClock();
    _persist(match);
    notifyListeners();
  }

  void removeMatch(String id) {
    _matches.removeWhere((m) => m.id == id);
    _undoStacks.remove(id);
    _db.collection(_col).doc(id).delete().catchError(
      (dynamic e) => debugPrint('Firestore delete error: $e'),
    );
    notifyListeners();
  }

  void endMatch(String id, String result) {
    final m = byId(id);
    if (m == null) return;
    m.status = MatchStatus.completed;
    m.cricket?.isMatchOver = true;
    m.cricket?.matchResult = result;
    m.football?.isFullTime = true;
    m.football?.timer.pause();
    m.basketball?.isMatchOver = true;
    m.basketball?.timer.pause();
    m.hockey?.isMatchOver = true;
    m.hockey?.timer.pause();
    m.combat?.isMatchOver = true;
    m.combat?.timer.pause();
    m.genericScore?.isMatchOver = true;
    m.genericScore?.timer.pause();
    _persist(m);
    StatsService().updateFromMatch(m, isCareer: m.isTournamentMatch);
    _syncResultToTournament(m);
    _notifyMatchPlayers(m, result);
    notifyListeners();
  }

  // ── Sync live result back to TournamentService ───────────────────────────

  /// Called whenever a tournament scoreboard reaches MatchStatus.completed.
  /// Reads the final score from whichever sport sub-object is active and
  /// calls TournamentService.updateMatchResult() so that:
  ///   • Points table / standings is updated
  ///   • Bracket / knockout advancement fires
  ///   • League+KO group winners are seeded into the knockout stage
  void _syncResultToTournament(LiveMatch m) {
    final tid  = m.tournamentId;
    final tmid = m.tournamentMatchId;
    if (tid == null || tmid == null) {
      debugPrint('[scoreboard] _syncResultToTournament: no tournamentId/matchId stored — skipping');
      return;
    }

    // Extract final scores — no cache lookup needed
    int sA = 0, sB = 0;
    if (m.rally != null) {
      sA = m.rally!.setsWonA;
      sB = m.rally!.setsWonB;
    } else if (m.football != null) {
      sA = m.football!.teamAGoals;
      sB = m.football!.teamBGoals;
    } else if (m.basketball != null) {
      sA = m.basketball!.teamATotal;
      sB = m.basketball!.teamBTotal;
    } else if (m.hockey != null) {
      sA = m.hockey!.teamAGoals;
      sB = m.hockey!.teamBGoals;
    } else if (m.combat != null) {
      sA = m.combat!.winner == 'A' ? 1 : 0;
      sB = m.combat!.winner == 'B' ? 1 : 0;
    } else if (m.esports != null) {
      sA = m.esports!.teamARounds;
      sB = m.esports!.teamBRounds;
    } else if (m.genericScore != null) {
      sA = m.genericScore!.teamAScore;
      sB = m.genericScore!.teamBScore;
    } else if (m.cricket != null) {
      final cr = m.cricket!;
      if (cr.innings.isNotEmpty) sA = cr.innings[0].runs;
      if (cr.innings.length > 1) sB = cr.innings[1].runs;
    }

    // Use team IDs stored directly on the LiveMatch (set by _buildLiveMatchFromTournament)
    final String winnerId;
    final String winnerName;
    if (sA > sB) {
      winnerId   = m.teamAId ?? '';
      winnerName = m.teamA;
    } else if (sB > sA) {
      winnerId   = m.teamBId ?? '';
      winnerName = m.teamB;
    } else {
      winnerId   = '';
      winnerName = 'Draw';
    }

    debugPrint('[scoreboard] syncing result → tournament $tid match $tmid  $sA-$sB  winner=$winnerName');
    TournamentService().updateMatchResult(
      tournamentId: tid,
      matchId:      tmid,
      scoreA:       sA,
      scoreB:       sB,
      winnerId:     winnerId,
      winnerName:   winnerName,
    ).catchError((dynamic e) => debugPrint('[scoreboard] sync to tournament FAILED: $e'));
  }

  /// Notify all tagged players that a match they were in has ended.
  void _notifyMatchPlayers(LiveMatch m, String result) {
    final myUid = UserService().userId ?? '';
    final allPlayerIds = <String>{
      ...m.teamAPlayerUserIds,
      ...m.teamBPlayerUserIds,
    }..remove(myUid); // don't notify the scorer

    final sport = m.sportDisplayName;
    for (final uid in allPlayerIds) {
      if (uid.isEmpty) continue;
      NotificationService.send(
        toUserId: uid,
        type:     NotifType.matchResult,
        title:    '$sport Match Ended',
        body:     '${m.teamA} vs ${m.teamB} — $result',
        targetId: m.id,
      );
    }
  }

  void setManOfMatch(String matchId, String playerName) {
    final m = byId(matchId);
    if (m?.cricket == null) return;
    m!.cricket!.manOfMatch = playerName;
    _persist(m);
    notifyListeners();
  }

  // ── Global 1-second clock ────────────────────────────────────────────────
  void _ensureClock() {
    _clockTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRICKET — International standard scoring with correct strike rotation
  // ══════════════════════════════════════════════════════════════════════════

  /// Add runs to the innings.
  ///
  /// [extraType] = '' (regular) | 'wide' | 'nob' | 'bye' | 'legbye'
  /// [nobBatRuns] = runs the batsman ACTUALLY RAN off a No Ball (excluding the
  ///   penalty run). Pass this explicitly when NB + batsman scored runs.
  void cricketAddRuns(String id, int runs,
      {String extraType = '', int nobBatRuns = 0}) {
    final m = byId(id);
    if (m?.cricket == null) return;
    final inn = m!.cricket!.currentInnings;
    if (inn.isComplete) return;

    _pushUndo(id, m.cricket!);

    // Capture striker BEFORE any strike rotation so stats go to the right batsman
    final bat = inn.striker;

    inn.runs += runs;

    final isWide = extraType == 'wide';
    final isNob = extraType == 'nob';
    final isBye = extraType == 'bye';
    final isLegBye = extraType == 'legbye';

    if (isWide) {
      inn.wides++;
      inn.extras++;
      // Wide: no ball to over, no strike rotation
    } else if (isNob) {
      inn.noBalls++;
      inn.extras++;
      // NB: no ball to over.
      // Strike rotates if batsman ran an ODD number of runs.
      if (nobBatRuns % 2 == 1) {
        _swapStrike(inn);
      }
    } else {
      // Legal delivery — count the ball
      final overCompleted = _addBall(m.cricket!, inn);

      // Mid-over strike rotation: odd runs → swap
      if (!overCompleted) {
        if (runs % 2 == 1) {
          _swapStrike(inn);
        }
      }
      // If overCompleted, _addBall already swapped strike
    }

    if (isBye) {
      inn.byes += runs;
      inn.extras += runs;
    }
    if (isLegBye) {
      inn.legByes += runs;
      inn.extras += runs;
    }

    // Batsman stats — only for deliveries they faced
    if (bat != null && extraType.isEmpty) {
      bat.runs += runs;
      bat.balls++;
      if (runs == 4) bat.fours++;
      if (runs == 6) bat.sixes++;
    } else if (bat != null && (isBye || isLegBye)) {
      bat.balls++;
    } else if (bat != null && isNob) {
      // Batsman faced the NB delivery
      bat.balls++;
      bat.runs += nobBatRuns;
      if (nobBatRuns == 4) bat.fours++;
      if (nobBatRuns == 6) bat.sixes++;
    }

    // Bowler concedes runs (not byes/legbyes)
    final bowl = inn.currentBowler;
    if (bowl != null) {
      if (isWide || isNob) {
        bowl.runs += 1; // penalty run only
      } else if (!isBye && !isLegBye) {
        bowl.runs += runs;
      }
    }

    _checkInningsEnd(m, m.cricket!);
    _persist(m);
    notifyListeners();
  }

  // Returns true if an over was completed (already swapped strike internally)
  bool _addBall(CricketScore score, CricketInnings inn) {
    inn.balls++;
    inn.currentBowler?.balls++;
    if (inn.balls >= 6) {
      inn.completedOvers++;
      inn.balls = 0;
      inn.currentBowler?.onOverComplete();
      // End-of-over always swaps strike
      _swapStrike(inn);
      inn.needsNewBowler = true;
      if (score.format != 'Test' && inn.completedOvers >= inn.totalOvers) {
        inn.isComplete = true;
      }
      return true;
    }
    return false;
  }

  /// Look up the Firestore userId for [name] from the match's roster lists.
  /// Returns null if the player was manually entered (not a registered user).
  String? _userIdForPlayer(LiveMatch match, String name) {
    final n = name.trim();
    if (n.isEmpty) return null;
    for (int i = 0; i < match.teamAPlayers.length; i++) {
      if (match.teamAPlayers[i] == n && i < match.teamAPlayerUserIds.length) {
        final uid = match.teamAPlayerUserIds[i];
        return uid.isNotEmpty ? uid : null;
      }
    }
    for (int i = 0; i < match.teamBPlayers.length; i++) {
      if (match.teamBPlayers[i] == n && i < match.teamBPlayerUserIds.length) {
        final uid = match.teamBPlayerUserIds[i];
        return uid.isNotEmpty ? uid : null;
      }
    }
    return null;
  }

  void _swapStrike(CricketInnings inn) {
    final s = inn.striker;
    final ns = inn.nonStriker;
    if (s != null) s.isStriker = false;
    if (ns != null) ns.isStriker = true;
  }

  /// Manually swap striker and non-striker (e.g. after a misfield, running mix-up)
  void cricketSwapBatsmen(String id) {
    final m = byId(id);
    if (m?.cricket == null) return;
    _swapStrike(m!.cricket!.currentInnings);
    _persist(m);
    notifyListeners();
  }

  /// Replace an injured batsman (Retired Hurt) with a substitute.
  void cricketInjuredReplace(
      String id, String injuredName, String replacementName) {
    final m = byId(id);
    if (m == null || m.cricket == null) return;
    _pushUndo(id, m.cricket!);
    final inn = m.cricket!.currentInnings;
    final injured =
        inn.batsmen.where((b) => b.name == injuredName && !b.isOut).firstOrNull;
    final wasStriker = injured?.isStriker ?? false;
    if (injured != null) {
      injured.isOut = true;
      injured.dismissal = 'Retired Hurt';
    }
    inn.batsmen.add(CricketBatsman(
      name: replacementName.trim(),
      order: inn.batsmen.length + 1,
      isStriker: wasStriker,
      userId: _userIdForPlayer(m, replacementName),
    ));
    _persist(m);
    notifyListeners();
  }

  /// Declare current innings (Test cricket).
  void cricketDeclare(String id) {
    final m = byId(id);
    if (m == null || m.cricket == null) return;
    _pushUndo(id, m.cricket!);
    m.cricket!.currentInnings.isComplete = true;
    _persist(m);
    notifyListeners();
  }

  void cricketWicket(
      String id, String dismissal, String outBatsman, String newBatsman) {
    final m = byId(id);
    if (m == null || m.cricket == null) return;
    _pushUndo(id, m.cricket!);
    final inn = m.cricket!.currentInnings;
    if (inn.isComplete) return;

    final bat = inn.batsmen
            .where((b) => b.name == outBatsman && !b.isOut)
            .firstOrNull ??
        inn.striker;
    if (bat != null) {
      bat.isOut = true;
      bat.dismissal = dismissal;
      final wasStriker = bat.isStriker;
      bat.isStriker = false;
      inn.fow.add(FowEntry(
        wicketNum: inn.wickets + 1,
        runs: inn.runs,
        oversStr: inn.oversStr,
        batsmanName: bat.name,
      ));
      // New batsman comes in as striker if the out-batsman was striker
      if (newBatsman.trim().isNotEmpty) {
        inn.batsmen.add(CricketBatsman(
          name: newBatsman.trim(),
          order: inn.batsmen.length + 1,
          isStriker: wasStriker,
          userId: _userIdForPlayer(m, newBatsman),
        ));
      }
    }

    inn.wickets++;
    _addBall(m.cricket!, inn);
    // No mid-over rotation on wicket — new batsman faces next ball

    _checkInningsEnd(m, m.cricket!);
    _persist(m);
    notifyListeners();
  }

  void cricketNewBowler(String id, String bowlerName) {
    final m = byId(id);
    if (m == null || m.cricket == null) return;
    final inn = m.cricket!.currentInnings;
    inn.needsNewBowler = false;

    final existing =
        inn.bowlers.where((b) => b.name == bowlerName.trim()).firstOrNull;
    if (existing != null) {
      existing.isCurrent = true;
    } else {
      inn.bowlers.add(CricketBowler(
        name: bowlerName.trim(),
        isCurrent: true,
        userId: _userIdForPlayer(m, bowlerName),
      ));
    }
    _persist(m);
    notifyListeners();
  }

  /// Set up openers + opening bowler for the FIRST innings.
  void cricketSetupOpeners(String id, String bat1, String bat2, String bowler,
      {String? battingTeamName}) {
    final m = byId(id);
    if (m == null || m.cricket == null) return;
    final cr = m.cricket!;
    // Apply toss result: swap batting/bowling teams in the first innings if needed
    if (battingTeamName != null &&
        battingTeamName.isNotEmpty &&
        battingTeamName != cr.innings[0].battingTeam) {
      cr.innings[0].battingTeam =
          battingTeamName == m.teamA ? m.teamA : m.teamB;
      cr.innings[0].bowlingTeam =
          battingTeamName == m.teamA ? m.teamB : m.teamA;
    }
    final inn = cr.currentInnings;
    if (inn.batsmen.isNotEmpty) return; // already set up
    inn.batsmen.addAll([
      CricketBatsman(name: bat1.trim(), order: 1, isStriker: true,
          userId: _userIdForPlayer(m, bat1)),
      CricketBatsman(name: bat2.trim(), order: 2, isStriker: false,
          userId: _userIdForPlayer(m, bat2)),
    ]);
    inn.bowlers.add(CricketBowler(name: bowler.trim(), isCurrent: true,
        userId: _userIdForPlayer(m, bowler)));
    _persist(m);
    notifyListeners();
  }

  void cricketStartSecondInnings(
      String id, String bat1, String bat2, String bowler) {
    final m = byId(id);
    if (m == null || m.cricket == null) return;
    _pushUndo(id, m.cricket!);
    m.cricket!.startSecondInnings();
    final inn = m.cricket!.currentInnings;
    inn.batsmen.addAll([
      CricketBatsman(name: bat1.trim(), order: 1, isStriker: true,
          userId: _userIdForPlayer(m, bat1)),
      CricketBatsman(name: bat2.trim(), order: 2, isStriker: false,
          userId: _userIdForPlayer(m, bat2)),
    ]);
    inn.bowlers.add(CricketBowler(name: bowler.trim(), isCurrent: true,
        userId: _userIdForPlayer(m, bowler)));
    _persist(m);
    notifyListeners();
  }

  void _checkInningsEnd(LiveMatch m, CricketScore score) {
    final inn = score.currentInnings;
    inn.checkEnd();

    if (inn.isComplete && score.currentInningsNum == 2) {
      if (inn.target != null) {
        if (inn.runs >= inn.target!) {
          score.isMatchOver = true;
          score.matchResult =
              '${inn.battingTeam} won by ${inn.remainingWickets} wicket${inn.remainingWickets == 1 ? '' : 's'}';
          m.status = MatchStatus.completed;
          StatsService().updateFromMatch(m, isCareer: m.isTournamentMatch);
        } else if (inn.wickets >= inn.playersPerSide - 1 ||
            (score.totalOvers < 999 &&
                inn.completedOvers >= score.totalOvers)) {
          final margin = inn.target! - 1 - inn.runs;
          score.isMatchOver = true;
          score.matchResult =
              '${inn.bowlingTeam} won by $margin run${margin == 1 ? '' : 's'}';
          m.status = MatchStatus.completed;
          StatsService().updateFromMatch(m, isCareer: m.isTournamentMatch);
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FOOTBALL (and all goal-based sports)
  // ══════════════════════════════════════════════════════════════════════════

  void footballGoal(String id, String team, String player,
      {bool isOwnGoal = false, bool isPenalty = false}) {
    final m = byId(id);
    if (m?.football == null) return;
    _pushUndoFor(id, m!);
    final f = m.football!;
    final scoringTeam = isOwnGoal ? (team == 'A' ? 'B' : 'A') : team;
    if (scoringTeam == 'A') {
      f.teamAGoals++;
    } else {
      f.teamBGoals++;
    }
    f.events.add(FootballEvent(
      type: isOwnGoal ? 'own_goal' : isPenalty ? 'penalty' : 'goal',
      team: team,
      player: player,
      minute: f.minute,
    ));
    _persist(m);
    notifyListeners();
  }

  void footballCard(String id, String team, String player, String cardType) {
    final m = byId(id);
    if (m?.football == null) return;
    _pushUndoFor(id, m!);
    final f = m.football!;
    if (cardType == 'yellow') {
      if (team == 'A') {
        f.teamAYellow++;
      } else {
        f.teamBYellow++;
      }
    } else {
      if (team == 'A') {
        f.teamARed++;
      } else {
        f.teamBRed++;
      }
    }
    f.events.add(FootballEvent(
      type: '${cardType}_card',
      team: team,
      player: player,
      minute: f.minute,
    ));
    _persist(m);
    notifyListeners();
  }

  void footballHalfTime(String id) {
    final m = byId(id);
    if (m?.football == null) return;
    final f = m!.football!;
    f.isHalfTime = true;
    f.htA = f.teamAGoals;
    f.htB = f.teamBGoals;
    f.timer.pause();
    _persist(m);
    notifyListeners();
  }

  void footballSecondHalf(String id) {
    final m = byId(id);
    if (m?.football == null) return;
    m!.football!.isHalfTime = false;
    m.football!.timer.start();
    _persist(m);
    notifyListeners();
  }

  void footballToggleTimer(String id) {
    final m = byId(id);
    if (m?.football == null) return;
    final f = m!.football!;
    if (f.timer.isRunning) {
      f.timer.pause();
    } else {
      f.timer.start();
    }
    _persist(m);
    notifyListeners();
  }

  void footballFullTime(String id) {
    final m = byId(id);
    if (m?.football == null) return;
    m!.football!.isFullTime = true;
    m.football!.timer.pause();
    m.status = MatchStatus.completed;
    _persist(m);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BASKETBALL
  // ══════════════════════════════════════════════════════════════════════════

  void basketballPoints(String id, String team, int pts) {
    final m = byId(id);
    if (m?.basketball == null) return;
    _pushUndoFor(id, m!);
    final b = m.basketball!;
    final qi = b.currentQuarter - 1;
    if (team == 'A') {
      b.teamAQtr[qi] += pts;
    } else {
      b.teamBQtr[qi] += pts;
    }
    _persist(m);
    notifyListeners();
  }

  void basketballFoul(String id, String team) {
    final m = byId(id);
    if (m?.basketball == null) return;
    final mb = m!;
    _pushUndoFor(id, mb);
    if (team == 'A') {
      mb.basketball!.teamAFouls++;
    } else {
      mb.basketball!.teamBFouls++;
    }
    _persist(mb);
    notifyListeners();
  }

  void basketballTimeout(String id, String team) {
    final m = byId(id);
    if (m?.basketball == null) return;
    final b = m!.basketball!;
    if (team == 'A' && b.teamATimeouts > 0) {
      b.teamATimeouts--;
    } else if (team == 'B' && b.teamBTimeouts > 0) {
      b.teamBTimeouts--;
    }
    b.timer.pause();
    _persist(m);
    notifyListeners();
  }

  void basketballNextQuarter(String id) {
    final m = byId(id);
    if (m?.basketball == null) return;
    final b = m!.basketball!;
    b.timer.pause();
    b.timer.reset();
    b.currentQuarter++;
    b.teamAQtr.add(0);
    b.teamBQtr.add(0);
    _persist(m);
    notifyListeners();
  }

  void basketballToggleTimer(String id) {
    final m = byId(id);
    if (m?.basketball == null) return;
    final b = m!.basketball!;
    if (b.timer.isRunning) {
      b.timer.pause();
    } else {
      b.timer.start();
    }
    _persist(m);
    notifyListeners();
  }

  void basketballEndMatch(String id) {
    final m = byId(id);
    if (m?.basketball == null) return;
    final b = m!.basketball!;
    b.timer.pause();
    b.isMatchOver = true;
    final aT = b.teamATotal;
    final bT = b.teamBTotal;
    b.matchResult =
        aT > bT ? '${m.teamA} wins!' : bT > aT ? '${m.teamB} wins!' : 'Draw!';
    m.status = MatchStatus.completed;
    _persist(m);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RALLY (Badminton, TT, Volleyball, Tennis, Squash, Padel, Beach VB, Netball)
  // ══════════════════════════════════════════════════════════════════════════

  void rallyPoint(String id, String team) {
    final m = byId(id);
    if (m?.rally == null) return;
    final r = m!.rally!;
    if (r.isMatchOver) return;
    _pushRallyUndo(id, r);

    if (r.isTennis) {
      _tennisPt(r, team, m);
      notifyListeners();
      return;
    }

    final set = r.currentSet;
    if (team == 'A') {
      set.scoreA++;
    } else {
      set.scoreB++;
    }
    r.serverIsA = team == 'A';

    final target = r.effectiveTarget;
    final a = set.scoreA;
    final b = set.scoreB;

    bool aWins = a >= target && (!r.winByTwo || a - b >= 2);
    bool bWins = b >= target && (!r.winByTwo || b - a >= 2);
    if (r.maxPointCap != null) {
      if (a >= r.maxPointCap!) aWins = true;
      if (b >= r.maxPointCap!) bWins = true;
    }

    if (aWins || bWins) {
      set.isComplete = true;
      set.winner = aWins ? 'A' : 'B';
      if (aWins) {
        r.setsWonA++;
      } else {
        r.setsWonB++;
      }
      _checkRallyWin(r, m);
      if (!r.isMatchOver) r.sets.add(RallySet());
    }
    _persist(m);
    notifyListeners();
  }

  void _tennisPt(RallyScore r, String team, LiveMatch m) {
    if (team == 'A') {
      r.tennisPtsA++;
    } else {
      r.tennisPtsB++;
    }
    final a = r.tennisPtsA;
    final b = r.tennisPtsB;

    bool gameOver = false;
    bool aWins = false;

    if (a >= 3 && b >= 3) {
      if (a - b >= 2) { gameOver = true; aWins = true; }
      if (b - a >= 2) { gameOver = true; aWins = false; }
    } else {
      if (a >= 4) { gameOver = true; aWins = true; }
      if (b >= 4) { gameOver = true; aWins = false; }
    }

    if (!gameOver) return;

    r.tennisPtsA = 0;
    r.tennisPtsB = 0;
    if (aWins) {
      r.gamesWonA++;
    } else {
      r.gamesWonB++;
    }

    final ga = r.gamesWonA;
    final gb = r.gamesWonB;
    bool aSetWin = false, bSetWin = false;
    if (ga >= 6 && ga - gb >= 2) aSetWin = true;
    if (gb >= 6 && gb - ga >= 2) bSetWin = true;
    if (ga == 7 && gb == 6) aSetWin = true;
    if (gb == 7 && ga == 6) bSetWin = true;

    if (aSetWin || bSetWin) {
      r.currentSet.scoreA = r.gamesWonA;
      r.currentSet.scoreB = r.gamesWonB;
      r.currentSet.isComplete = true;
      r.currentSet.winner = aSetWin ? 'A' : 'B';
      if (aSetWin) {
        r.setsWonA++;
      } else {
        r.setsWonB++;
      }
      r.gamesWonA = 0;
      r.gamesWonB = 0;
      _checkRallyWin(r, m);
      if (!r.isMatchOver) r.sets.add(RallySet());
    }
  }

  void _checkRallyWin(RallyScore r, LiveMatch m) {
    if (r.setsWonA >= r.setsToWin || r.setsWonB >= r.setsToWin) {
      r.isMatchOver = true;
      r.matchWinner = r.setsWonA >= r.setsToWin ? 'A' : 'B';
      m.status = MatchStatus.completed;
      StatsService().updateFromMatch(m, isCareer: m.isTournamentMatch);
      _syncResultToTournament(m);
    }
  }

  void rallyToggleServer(String id) {
    final m = byId(id);
    if (m?.rally == null) return;
    m!.rally!.serverIsA = !m.rally!.serverIsA;
    _persist(m);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HOCKEY (Field & Ice)
  // ══════════════════════════════════════════════════════════════════════════

  void hockeyGoal(String id, String team, String player) {
    final m = byId(id);
    if (m?.hockey == null) return;
    _pushUndoFor(id, m!);
    final h = m.hockey!;
    final qi = h.currentQuarter - 1;
    if (team == 'A') {
      h.teamAGoals++;
      if (qi < h.teamAQtrGoals.length) h.teamAQtrGoals[qi]++;
    } else {
      h.teamBGoals++;
      if (qi < h.teamBQtrGoals.length) h.teamBQtrGoals[qi]++;
    }
    h.events.add(HockeyEvent(
      type: 'goal',
      team: team,
      player: player,
      quarter: h.currentQuarter,
      timeStr: h.timerStr,
    ));
    _persist(m);
    notifyListeners();
  }

  void hockeyPenaltyCorner(String id, String team) {
    final m = byId(id);
    if (m?.hockey == null) return;
    if (team == 'A') {
      m!.hockey!.teamAPenaltyCorners++;
    } else {
      m!.hockey!.teamBPenaltyCorners++;
    }
    _persist(m);
    notifyListeners();
  }

  void hockeyCard(String id, String team, String player, String cardType) {
    final m = byId(id);
    if (m?.hockey == null) return;
    _pushUndoFor(id, m!);
    final h = m.hockey!;
    if (cardType == 'green') {
      if (team == 'A') { h.teamAGreenCards++; } else { h.teamBGreenCards++; }
    } else if (cardType == 'yellow') {
      if (team == 'A') { h.teamAYellowCards++; } else { h.teamBYellowCards++; }
    } else {
      if (team == 'A') { h.teamARedCards++; } else { h.teamBRedCards++; }
    }
    h.events.add(HockeyEvent(
      type: '${cardType}_card',
      team: team,
      player: player,
      quarter: h.currentQuarter,
      timeStr: h.timerStr,
    ));
    _persist(m);
    notifyListeners();
  }

  void hockeyNextPeriod(String id) {
    final m = byId(id);
    if (m?.hockey == null) return;
    final h = m!.hockey!;
    h.timer.pause();
    h.timer.reset();
    if (h.currentQuarter < h.totalPeriods) {
      h.currentQuarter++;
      // Extend goal arrays if needed
      while (h.teamAQtrGoals.length < h.currentQuarter) {
        h.teamAQtrGoals.add(0);
        h.teamBQtrGoals.add(0);
      }
    } else {
      h.isMatchOver = true;
      m.status = MatchStatus.completed;
    }
    _persist(m);
    notifyListeners();
  }

  void hockeyToggleTimer(String id) {
    final m = byId(id);
    if (m?.hockey == null) return;
    final h = m!.hockey!;
    if (h.timer.isRunning) {
      h.timer.pause();
    } else {
      h.timer.start();
    }
    _persist(m);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOXING / COMBAT SPORTS (Boxing, MMA, Wrestling, Fencing)
  // ══════════════════════════════════════════════════════════════════════════

  void boxingKnockdown(String id, String team) {
    final m = byId(id);
    if (m?.combat == null) return;
    _pushUndoFor(id, m!);
    final r = m.combat!.currentRoundData;
    if (team == 'A') {
      r.knockdownsA++;
    } else {
      r.knockdownsB++;
    }
    _persist(m);
    notifyListeners();
  }

  void boxingEndRound(String id,
      {required List<int?> judgesA, required List<int?> judgesB}) {
    final m = byId(id);
    if (m?.combat == null) return;
    _pushUndoFor(id, m!);
    final c = m.combat!;
    c.timer.pause();
    c.timer.reset();
    final r = c.currentRoundData;
    r.judge1A = judgesA[0]; r.judge1B = judgesB[0];
    r.judge2A = judgesA[1]; r.judge2B = judgesB[1];
    r.judge3A = judgesA[2]; r.judge3B = judgesB[2];
    if (c.currentRound < c.totalRounds) {
      c.currentRound++;
      c.rounds.add(CombatRound(roundNum: c.currentRound));
    } else {
      final totalA = c.cardTotalA;
      final totalB = c.cardTotalB;
      c.isMatchOver = true;
      c.result = 'Decision';
      c.winner = totalA > totalB ? 'A' : totalB > totalA ? 'B' : 'Draw';
      m.status = MatchStatus.completed;
    }
    _persist(m);
    notifyListeners();
  }

  void boxingStoppage(String id, String winner, String result) {
    final m = byId(id);
    if (m?.combat == null) return;
    m!.combat!
      ..isMatchOver = true
      ..result = result
      ..winner = winner
      ..timer.pause();
    m.status = MatchStatus.completed;
    _persist(m);
    notifyListeners();
  }

  void boxingToggleTimer(String id) {
    final m = byId(id);
    if (m?.combat == null) return;
    final c = m!.combat!;
    if (c.timer.isRunning) {
      c.timer.pause();
    } else {
      c.timer.start();
    }
    _persist(m);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // E-SPORTS (CS:GO, Valorant, LoL, Dota2, FIFA)
  // ══════════════════════════════════════════════════════════════════════════

  void esportsRoundWon(String id, String team) {
    final m = byId(id);
    if (m?.esports == null) return;
    _pushUndoFor(id, m!);
    final e = m.esports!;
    if (e.isMatchOver) return;
    if (team == 'A') {
      e.teamARounds++;
    } else {
      e.teamBRounds++;
    }
    e.roundHistory.add(team);
    e.currentRound++;
    final halfPoint = e.maxRounds ~/ 2;
    if (e.teamARounds + e.teamBRounds == halfPoint) e.isHalfTime = true;
    if (e.teamARounds >= e.roundsToWin || e.teamBRounds >= e.roundsToWin) {
      e.isMatchOver = true;
      e.matchWinner = e.teamARounds >= e.roundsToWin ? 'A' : 'B';
      m.status = MatchStatus.completed;
      StatsService().updateFromMatch(m, isCareer: m.isTournamentMatch);
      _syncResultToTournament(m);
    }
    _persist(m);
    notifyListeners();
  }

  void esportsHalfTimeSwitch(String id) {
    final m = byId(id);
    if (m?.esports == null) return;
    m!.esports!.isHalfTime = false;
    _persist(m);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERIC SCORE — all other sports (rugby, handball, golf, etc.)
  // ══════════════════════════════════════════════════════════════════════════

  /// Add [pts] points to [team] ('A' or 'B'). [note] describes the score event.
  void genericAddPoints(String id, String team, int pts, {String note = ''}) {
    final m = byId(id);
    if (m?.genericScore == null) return;
    _pushUndoFor(id, m!);
    final g = m.genericScore!;
    if (g.isMatchOver) return;
    if (team == 'A') {
      g.teamAScore += pts;
    } else {
      g.teamBScore += pts;
    }
    g.events.add(GenericEvent(
      team: team,
      pts: pts,
      note: note.isEmpty ? '+$pts' : note,
      timeStr: '${g.timer.elapsed.inMinutes}\'',
    ));
    // Auto-end with deuce support: when both reach target-1, need 2-point lead
    if (g.pointsToWin > 0 && !g.isMatchOver) {
      final a      = g.teamAScore;
      final b      = g.teamBScore;
      final target = g.pointsToWin;
      final inDeuce = a >= target - 1 && b >= target - 1;
      if (inDeuce) {
        if (a - b >= 2)      { g.isMatchOver = true; g.winner = 'A'; m.status = MatchStatus.completed; }
        else if (b - a >= 2) { g.isMatchOver = true; g.winner = 'B'; m.status = MatchStatus.completed; }
      } else {
        if (a >= target)      { g.isMatchOver = true; g.winner = 'A'; m.status = MatchStatus.completed; }
        else if (b >= target) { g.isMatchOver = true; g.winner = 'B'; m.status = MatchStatus.completed; }
      }
      if (g.isMatchOver) {
        StatsService().updateFromMatch(m, isCareer: m.isTournamentMatch);
        _syncResultToTournament(m);
      }
    }
    _persist(m);
    notifyListeners();
  }

  void genericToggleTimer(String id) {
    final m = byId(id);
    if (m?.genericScore == null) return;
    final g = m!.genericScore!;
    if (g.timer.isRunning) {
      g.timer.pause();
    } else {
      g.timer.start();
    }
    _persist(m);
    notifyListeners();
  }

  void genericEndMatch(String id) {
    final m = byId(id);
    if (m?.genericScore == null) return;
    final g = m!.genericScore!;
    g.isMatchOver = true;
    g.timer.pause();
    if (g.teamAScore > g.teamBScore) {
      g.winner = 'A';
    } else if (g.teamBScore > g.teamAScore) {
      g.winner = 'B';
    } else {
      g.winner = 'Draw';
    }
    m.status = MatchStatus.completed;
    _persist(m);
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }
}
