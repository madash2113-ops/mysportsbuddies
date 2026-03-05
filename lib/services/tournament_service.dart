import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/models/tournament.dart';
import 'user_service.dart';

class PremiumRequiredException implements Exception {
  @override
  String toString() => 'Premium required to host a tournament with more than 4 teams.';
}

class TournamentService extends ChangeNotifier {
  TournamentService._();
  static final TournamentService _instance = TournamentService._();
  factory TournamentService() => _instance;

  final _db = FirebaseFirestore.instance;
  static const _col = 'tournaments';

  List<Tournament>                    _tournaments = [];
  final Map<String, List<TournamentTeam>>  _teams   = {};
  final Map<String, List<TournamentMatch>> _matches = {};
  List<String>                        _myEnrolledIds = [];
  final Map<String, TournamentTeam>   _myTeamMap     = {};

  List<Tournament>      get tournaments    => List.unmodifiable(_tournaments);
  List<TournamentTeam>  teamsFor(String id)   => List.unmodifiable(_teams[id]   ?? []);
  List<TournamentMatch> matchesFor(String id) => List.unmodifiable(_matches[id] ?? []);
  List<String>          get myEnrolledIds  => List.unmodifiable(_myEnrolledIds);
  TournamentTeam?       myTeamIn(String id) => _myTeamMap[id];

  // ── Real-time listener ──────────────────────────────────────────────────

  void listenToTournaments() {
    // No server-side orderBy — sort in memory to avoid index requirement.
    _db.collection(_col)
        .snapshots()
        .listen((snap) {
      _tournaments = snap.docs.map(Tournament.fromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }, onError: (e) => debugPrint('TournamentService listener error: $e'));
  }

  // ── One-time fetch (fallback for first load) ────────────────────────────

  Future<void> loadTournaments() async {
    try {
      final snap = await _db.collection(_col).get();
      _tournaments = snap.docs.map(Tournament.fromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService.loadTournaments error: $e');
    }
  }

  // ── My enrollments ───────────────────────────────────────────────────────

  Future<void> loadMyEnrollments(String userId) async {
    if (userId.isEmpty) return;
    try {
      final snap = await _db
          .collectionGroup('teams')
          .where('enrolledBy', isEqualTo: userId)
          .get();
      _myTeamMap.clear();
      _myEnrolledIds = [];
      for (final doc in snap.docs) {
        final team = TournamentTeam.fromFirestore(doc);
        if (team.tournamentId.isNotEmpty) {
          _myTeamMap[team.tournamentId] = team;
          _myEnrolledIds.add(team.tournamentId);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService.loadMyEnrollments error: $e');
    }
  }

  // ── Load detail (teams + matches) ───────────────────────────────────────

  Future<void> loadDetail(String tournamentId) async {
    try {
      final results = await Future.wait([
        _db.collection(_col).doc(tournamentId).collection('teams').get(),
        _db.collection(_col).doc(tournamentId).collection('matches').get(),
      ]);

      _teams[tournamentId] = (results[0] as QuerySnapshot)
          .docs.map(TournamentTeam.fromFirestore).toList();

      // Sort matches in memory — avoids composite index requirement
      _matches[tournamentId] = ((results[1] as QuerySnapshot)
          .docs.map(TournamentMatch.fromFirestore).toList())
        ..sort((a, b) {
          final r = a.round.compareTo(b.round);
          return r != 0 ? r : a.matchIndex.compareTo(b.matchIndex);
        });

      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService.loadDetail error: $e');
    }
  }

  // ── Create tournament ───────────────────────────────────────────────────

  Future<String> createTournament({
    required String           name,
    required String           sport,
    required TournamentFormat format,
    required DateTime         startDate,
    required String           location,
    required int              maxTeams,
    required double           entryFee,
    required double           serviceFee,
    required ScheduleMode     scheduleMode,
    String?                   prizePool,
    int                       playersPerTeam = 0,
    DateTime?                 endDate,
    String?                   rules,
    String?                   bannerUrl,
  }) async {
    final isPremium = UserService().profile?.isPremium == true;
    if (maxTeams > 4 && !isPremium) throw PremiumRequiredException();

    final userId   = UserService().userId ?? '';
    final userName = UserService().profile?.name ?? 'Unknown';

    final ref = _db.collection(_col).doc();
    final tournament = Tournament(
      id:               ref.id,
      name:             name,
      sport:            sport,
      format:           format,
      status:           TournamentStatus.open,
      startDate:        startDate,
      location:         location,
      maxTeams:         maxTeams,
      entryFee:         entryFee,
      serviceFee:       serviceFee,
      createdBy:        userId,
      createdByName:    userName,
      createdAt:        DateTime.now(),
      scheduleMode:     scheduleMode,
      bracketGenerated: false,
      prizePool:        prizePool,
      registeredTeams:  0,
      playersPerTeam:   playersPerTeam,
      endDate:          endDate,
      rules:            rules,
      bannerUrl:        bannerUrl,
    );

    await ref.set(tournament.toMap());
    return ref.id;
  }

  // ── Upload banner image ──────────────────────────────────────────────────

  Future<String> uploadBanner(String tournamentId, File image) async {
    final ref = FirebaseStorage.instance
        .ref('tournament_banners/$tournamentId.jpg');
    await ref.putFile(image);
    final url = await ref.getDownloadURL();
    await _db.collection(_col).doc(tournamentId).update({'bannerUrl': url});
    return url;
  }

  // ── Enroll team ─────────────────────────────────────────────────────────

  Future<void> enrollTeam({
    required String       tournamentId,
    required String       teamName,
    required String       captainName,
    required String       captainPhone,
    required List<String> players,
  }) async {
    final userId   = UserService().userId ?? '';
    final teamsRef = _db.collection(_col).doc(tournamentId).collection('teams');
    final existing = await teamsRef.get();
    final seed     = existing.docs.length + 1;

    final ref  = teamsRef.doc();
    final team = TournamentTeam(
      id:               ref.id,
      tournamentId:     tournamentId,
      teamName:         teamName,
      captainName:      captainName,
      captainPhone:     captainPhone,
      players:          players,
      enrolledBy:       userId,
      enrolledAt:       DateTime.now(),
      paymentConfirmed: true,
      seed:             seed,
    );

    await ref.set(team.toMap());

    // Increment registeredTeams counter
    await _db.collection(_col).doc(tournamentId).update({
      'registeredTeams': FieldValue.increment(1),
    });

    // Refresh local cache
    await loadDetail(tournamentId);
    await loadMyEnrollments(userId);
  }

  // ── Generate schedule (auto) ────────────────────────────────────────────

  Future<void> generateSchedule(String tournamentId) async {
    await loadDetail(tournamentId);
    final teams = _teams[tournamentId] ?? [];
    if (teams.length < 2) throw Exception('Need at least 2 teams to generate schedule.');

    final tournDoc = _tournaments.firstWhere(
      (t) => t.id == tournamentId,
      orElse: () => throw Exception('Tournament not found'),
    );

    final matchesRef = _db.collection(_col).doc(tournamentId).collection('matches');

    // Clear existing matches
    final existing = await matchesRef.get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    switch (tournDoc.format) {
      case TournamentFormat.knockout:
        await _generateKnockout(tournamentId, teams, matchesRef);
      case TournamentFormat.roundRobin:
        await _generateRoundRobin(tournamentId, teams, matchesRef);
      case TournamentFormat.leagueKnockout:
        await _generateRoundRobin(tournamentId, teams, matchesRef);
    }

    // Mark bracket as generated
    await _db.collection(_col).doc(tournamentId).update({'bracketGenerated': true});
    await loadDetail(tournamentId);
  }

  Future<void> _generateKnockout(
    String tournamentId,
    List<TournamentTeam> teams,
    CollectionReference matchesRef,
  ) async {
    final n = teams.length;
    final bracketSize = _nextPowerOf2(n);

    // Seed teams: top seeds get byes
    final seeded = [...teams]..sort((a, b) => a.seed.compareTo(b.seed));

    final batch = _db.batch();

    // Round 1: pair seeds
    final slots = List<TournamentTeam?>.filled(bracketSize, null);
    for (int i = 0; i < seeded.length; i++) {
      slots[i] = seeded[i];
    }

    // Standard bracket seeding: 1 vs N, 2 vs N-1, ...
    final paired = <List<TournamentTeam?>>[];
    for (int i = 0; i < bracketSize ~/ 2; i++) {
      paired.add([slots[i], slots[bracketSize - 1 - i]]);
    }

    for (int i = 0; i < paired.length; i++) {
      final a = paired[i][0];
      final b = paired[i][1];
      final isBye = b == null;

      final ref = matchesRef.doc();
      final match = TournamentMatch(
        id:          ref.id,
        tournamentId: tournamentId,
        round:       1,
        matchIndex:  i,
        teamAId:     a?.id,
        teamBId:     isBye ? null : b.id,
        teamAName:   a?.teamName,
        teamBName:   isBye ? null : b.teamName,
        isBye:       isBye,
        result:      isBye ? TournamentMatchResult.bye : TournamentMatchResult.pending,
        winnerId:    isBye ? a?.id : null,
        winnerName:  isBye ? a?.teamName : null,
      );
      batch.set(ref, match.toMap());
    }

    // Generate subsequent empty rounds
    final totalRounds = _log2(bracketSize).toInt();
    for (int r = 2; r <= totalRounds; r++) {
      final matchCount = bracketSize ~/ math.pow(2, r).toInt();
      for (int i = 0; i < matchCount; i++) {
        final ref = matchesRef.doc();
        final match = TournamentMatch(
          id:          ref.id,
          tournamentId: tournamentId,
          round:       r,
          matchIndex:  i,
          result:      TournamentMatchResult.pending,
        );
        batch.set(ref, match.toMap());
      }
    }

    await batch.commit();

    // Auto-advance byes
    await loadDetail(tournamentId);
    final allMatches = _matches[tournamentId] ?? [];
    for (final m in allMatches.where((m) => m.isBye && m.winnerId != null)) {
      await _advanceWinner(tournamentId, m);
    }
  }

  Future<void> _generateRoundRobin(
    String tournamentId,
    List<TournamentTeam> teams,
    CollectionReference matchesRef,
  ) async {
    final n      = teams.length;
    final rounds = n.isEven ? n - 1 : n;
    final batch  = _db.batch();

    // Circle method
    final rotation = List<TournamentTeam?>.from(teams);
    if (n.isOdd) rotation.add(null); // null = bye

    final fixed = rotation[0];
    final rotate = rotation.sublist(1);

    for (int r = 0; r < rounds; r++) {
      final current = [fixed, ...rotate];
      int mi = 0;
      for (int i = 0; i < current.length ~/ 2; i++) {
        final a = current[i];
        final b = current[current.length - 1 - i];
        if (a == null || b == null) continue;

        final ref = matchesRef.doc();
        final match = TournamentMatch(
          id:          ref.id,
          tournamentId: tournamentId,
          round:       r + 1,
          matchIndex:  mi++,
          teamAId:     a.id,
          teamBId:     b.id,
          teamAName:   a.teamName,
          teamBName:   b.teamName,
          result:      TournamentMatchResult.pending,
        );
        batch.set(ref, match.toMap());
      }

      // Rotate (fix first element, rotate rest)
      rotate.insert(0, rotate.removeLast());
    }

    await batch.commit();
  }

  // ── Update match result ─────────────────────────────────────────────────

  Future<void> updateMatchResult({
    required String tournamentId,
    required String matchId,
    required int    scoreA,
    required int    scoreB,
    required String winnerId,
    required String winnerName,
  }) async {
    final result = scoreA > scoreB
        ? TournamentMatchResult.teamAWin
        : scoreB > scoreA
            ? TournamentMatchResult.teamBWin
            : TournamentMatchResult.draw;

    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .update({
      'scoreA':     scoreA,
      'scoreB':     scoreB,
      'winnerId':   winnerId,
      'winnerName': winnerName,
      'result':     result.name,
    });

    await loadDetail(tournamentId);

    final match = (_matches[tournamentId] ?? [])
        .firstWhere((m) => m.id == matchId, orElse: () => throw Exception('Match not found'));

    // Update Round Robin stats
    final tournDoc = _tournaments.firstWhere(
      (t) => t.id == tournamentId,
      orElse: () => throw Exception('Tournament not found'),
    );
    if (tournDoc.format == TournamentFormat.roundRobin ||
        tournDoc.format == TournamentFormat.leagueKnockout) {
      await _updateRRStats(tournamentId, match, scoreA, scoreB);
    }

    // Advance winner to next bracket slot (Knockout only)
    if (tournDoc.format == TournamentFormat.knockout ||
        tournDoc.format == TournamentFormat.leagueKnockout) {
      await _advanceWinner(tournamentId, match);
    }
  }

  Future<void> _advanceWinner(String tournamentId, TournamentMatch match) async {
    final nextRound      = match.round + 1;
    final nextMatchIndex = match.matchIndex ~/ 2;
    final isTeamASlot    = match.matchIndex.isEven;

    final allMatches = _matches[tournamentId] ?? [];
    final nextMatch  = allMatches.where(
      (m) => m.round == nextRound && m.matchIndex == nextMatchIndex,
    );
    if (nextMatch.isEmpty) return; // Final round — no next match

    final nextId = nextMatch.first.id;
    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches')
        .doc(nextId)
        .update({
      if (isTeamASlot) 'teamAId':   match.winnerId,
      if (isTeamASlot) 'teamAName': match.winnerName,
      if (!isTeamASlot) 'teamBId':   match.winnerId,
      if (!isTeamASlot) 'teamBName': match.winnerName,
    });

    await loadDetail(tournamentId);
  }

  Future<void> _updateRRStats(
    String tournamentId,
    TournamentMatch match,
    int scoreA,
    int scoreB,
  ) async {
    if (match.teamAId == null || match.teamBId == null) return;

    final Map<String, dynamic> updateA = {'played': FieldValue.increment(1)};
    final Map<String, dynamic> updateB = {'played': FieldValue.increment(1)};

    if (scoreA > scoreB) {
      updateA['wins']   = FieldValue.increment(1);
      updateA['points'] = FieldValue.increment(3);
      updateB['losses'] = FieldValue.increment(1);
    } else if (scoreB > scoreA) {
      updateB['wins']   = FieldValue.increment(1);
      updateB['points'] = FieldValue.increment(3);
      updateA['losses'] = FieldValue.increment(1);
    } else {
      updateA['draws']  = FieldValue.increment(1);
      updateA['points'] = FieldValue.increment(1);
      updateB['draws']  = FieldValue.increment(1);
      updateB['points'] = FieldValue.increment(1);
    }

    final teamsRef = _db.collection(_col).doc(tournamentId).collection('teams');
    await Future.wait([
      teamsRef.doc(match.teamAId).update(updateA),
      teamsRef.doc(match.teamBId).update(updateB),
    ]);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static int _nextPowerOf2(int n) {
    if (n <= 0) return 1;
    int p = 1;
    while (p < n) { p <<= 1; }
    return p;
  }

  static double _log2(int n) => math.log(n) / math.log(2);

  static String roundLabel(int matchCount) {
    switch (matchCount) {
      case 1:  return 'Final';
      case 2:  return 'Semi-finals';
      case 4:  return 'Quarter-finals';
      case 8:  return 'Round of 16';
      case 16: return 'Round of 32';
      default: return 'Round of ${matchCount * 2}';
    }
  }

  /// Converts a flat match list into structured TournamentRound list
  List<TournamentRound> buildRounds(String tournamentId) {
    final matches = _matches[tournamentId] ?? [];
    if (matches.isEmpty) return [];

    final Map<int, List<TournamentMatch>> byRound = {};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }

    final rounds = <TournamentRound>[];
    for (final entry in byRound.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))) {
      final sorted = [...entry.value]..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
      rounds.add(TournamentRound(
        roundNumber: entry.key,
        label:       roundLabel(sorted.length),
        matches:     sorted,
      ));
    }
    return rounds;
  }
}
