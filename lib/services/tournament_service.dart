import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/models/tournament.dart';
import 'notification_service.dart';
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
  final Map<String, List<TournamentTeam>>        _teams   = {};
  final Map<String, List<TournamentMatch>>       _matches = {};
  final Map<String, List<TournamentVenue>>       _venues  = {};
  final Map<String, List<TournamentAdmin>>       _admins  = {};
  final Map<String, List<TournamentGroup>>       _groups  = {};
  // squadCache: tournamentId → teamId → players
  final Map<String, Map<String, List<TournamentSquadPlayer>>> _squads = {};
  List<String>                        _myEnrolledIds = [];
  final Map<String, TournamentTeam>   _myTeamMap     = {};

  List<Tournament>          get tournaments    => List.unmodifiable(_tournaments);
  List<TournamentTeam>      teamsFor(String id)   => List.unmodifiable(_teams[id]   ?? []);
  List<TournamentMatch>     matchesFor(String id) => List.unmodifiable(_matches[id] ?? []);
  List<TournamentVenue>     venuesFor(String id)  => List.unmodifiable(_venues[id]  ?? []);
  List<TournamentAdmin>     adminsFor(String id)  => List.unmodifiable(_admins[id]  ?? []);
  List<TournamentGroup>     groupsFor(String id)  => List.unmodifiable(_groups[id]  ?? []);
  List<String>              get myEnrolledIds  => List.unmodifiable(_myEnrolledIds);
  TournamentTeam?           myTeamIn(String id) => _myTeamMap[id];
  List<TournamentSquadPlayer> squadFor(String tournamentId, String teamId) =>
      List.unmodifiable(_squads[tournamentId]?[teamId] ?? []);

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
  // Uses a flat top-level `enrollments` collection (doc ID = teamId) so we
  // can query by `enrolledBy` without needing a collection-group index.

  Future<void> loadMyEnrollments(String userId) async {
    if (userId.isEmpty) return;
    try {
      final snap = await _db
          .collection('enrollments')
          .where('enrolledBy', isEqualTo: userId)
          .get();
      _myTeamMap.clear();
      _myEnrolledIds = [];
      for (final doc in snap.docs) {
        final team = TournamentTeam.fromMap(doc.id, doc.data());
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
      final ref = _db.collection(_col).doc(tournamentId);
      final results = await Future.wait([
        ref.collection('teams').get(),
        ref.collection('matches').get(),
        ref.collection('venues').get(),
        ref.collection('admins').get(),
        ref.collection('groups').get(),
      ]);

      _teams[tournamentId] = (results[0] as QuerySnapshot)
          .docs.map(TournamentTeam.fromFirestore).toList();

      // Derive enrollment for the current user from loaded teams.
      // This covers both new enrollments (in `enrollments` collection) and
      // legacy enrollments that pre-date the top-level collection.
      final currentUserId = UserService().userId ?? '';
      if (currentUserId.isNotEmpty) {
        for (final team in _teams[tournamentId]!) {
          if (team.enrolledBy == currentUserId) {
            _myTeamMap[tournamentId] = team;
            if (!_myEnrolledIds.contains(tournamentId)) {
              _myEnrolledIds.add(tournamentId);
            }
            break;
          }
        }
      }

      // Sort matches in memory — avoids composite index requirement
      _matches[tournamentId] = ((results[1] as QuerySnapshot)
          .docs.map(TournamentMatch.fromFirestore).toList())
        ..sort((a, b) {
          final r = a.round.compareTo(b.round);
          return r != 0 ? r : a.matchIndex.compareTo(b.matchIndex);
        });

      _venues[tournamentId] = (results[2] as QuerySnapshot)
          .docs.map(TournamentVenue.fromFirestore).toList();

      _admins[tournamentId] = (results[3] as QuerySnapshot).docs.map((doc) {
        return TournamentAdmin.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();

      _groups[tournamentId] = ((results[4] as QuerySnapshot)
          .docs.map(TournamentGroup.fromFirestore).toList())
        ..sort((a, b) => a.name.compareTo(b.name));

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

    // Mirror to flat enrollments collection (doc ID = teamId) for index-free queries
    await _db.collection('enrollments').doc(ref.id).set(team.toMap());

    // Increment registeredTeams counter
    await _db.collection(_col).doc(tournamentId).update({
      'registeredTeams': FieldValue.increment(1),
    });

    // Refresh local cache
    await loadDetail(tournamentId);
    await loadMyEnrollments(userId);

    // ── Notifications ───────────────────────────────────────────────────────
    final tourn = _tournaments.firstWhere(
      (t) => t.id == tournamentId,
      orElse: () => throw Exception('Tournament not found'),
    );
    final enrollerName = UserService().profile?.name ?? 'Someone';

    // Notify the host
    if (tourn.createdBy.isNotEmpty && tourn.createdBy != userId) {
      await NotificationService.send(
        toUserId: tourn.createdBy,
        type:     NotifType.tournamentUpdate,
        title:    '${tourn.name} — New Enrollment',
        body:     '$teamName (captain: $captainName) enrolled in your tournament',
      );
    }

    // Notify other enrolled teams' captains
    final enrolled = _teams[tournamentId] ?? [];
    for (final t in enrolled) {
      if (t.enrolledBy == userId || t.enrolledBy == tourn.createdBy) continue;
      if (t.enrolledBy.isEmpty) continue;
      await NotificationService.send(
        toUserId: t.enrolledBy,
        type:     NotifType.tournamentUpdate,
        title:    '${tourn.name} — New Team',
        body:     '$enrollerName\'s team "$teamName" just enrolled',
      );
    }
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
        await _generateLeagueKnockout(tournamentId, teams, matchesRef);
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

  Future<void> _generateLeagueKnockout(
    String tournamentId,
    List<TournamentTeam> teams,
    CollectionReference matchesRef,
  ) async {
    final n = teams.length;
    // Divide into groups of 4 (or 3 if remainder works out)
    final groupSize   = (n % 4 == 3 || n < 5) ? 3 : 4;
    final groupCount  = (n / groupSize).ceil();
    final seeded      = [...teams]..sort((a, b) => a.seed.compareTo(b.seed));

    final batch = _db.batch();
    // Round offset for knockout rounds (comes after all group rounds)
    int rrRounds = 0;

    // ── Group stage ────────────────────────────────────────────────────────
    for (int g = 0; g < groupCount; g++) {
      final groupLabel = String.fromCharCode('A'.codeUnitAt(0) + g);
      final start  = g * groupSize;
      final end    = math.min(start + groupSize, n);
      final group  = seeded.sublist(start, end);
      final gn     = group.length;
      final rounds = gn.isEven ? gn - 1 : gn;

      if (rounds > rrRounds) rrRounds = rounds;

      final rotation = List<TournamentTeam?>.from(group);
      if (gn.isOdd) rotation.add(null);
      final fixed  = rotation[0];
      final rotate = rotation.sublist(1);

      for (int r = 0; r < rounds; r++) {
        final current = [fixed, ...rotate];
        int mi = (g * 10) + r * groupSize; // unique matchIndex per group
        for (int i = 0; i < current.length ~/ 2; i++) {
          final a = current[i];
          final b = current[current.length - 1 - i];
          if (a == null || b == null) continue;

          final ref   = matchesRef.doc();
          final match = TournamentMatch(
            id:           ref.id,
            tournamentId: tournamentId,
            round:        r + 1,
            matchIndex:   mi++,
            teamAId:      a.id,
            teamBId:      b.id,
            teamAName:    a.teamName,
            teamBName:    b.teamName,
            result:       TournamentMatchResult.pending,
            note:         'Group $groupLabel',
          );
          batch.set(ref, match.toMap());
        }
        rotate.insert(0, rotate.removeLast());
      }
    }

    // ── Knockout stage ─────────────────────────────────────────────────────
    // top 2 per group advance → bracket size = groupCount * 2
    final koTeams    = groupCount * 2;
    final bracketSize = _nextPowerOf2(koTeams);
    final totalKORounds = _log2(bracketSize).toInt();
    final koRoundOffset = rrRounds + 1;

    for (int r = 0; r < totalKORounds; r++) {
      final matchCount = bracketSize ~/ math.pow(2, r + 1).toInt();
      final roundNum   = koRoundOffset + r;
      final label      = TournamentService.roundLabel(matchCount);
      for (int i = 0; i < matchCount; i++) {
        final ref   = matchesRef.doc();
        final match = TournamentMatch(
          id:           ref.id,
          tournamentId: tournamentId,
          round:        roundNum,
          matchIndex:   i,
          result:       TournamentMatchResult.pending,
          note:         label,
        );
        batch.set(ref, match.toMap());
      }
    }

    await batch.commit();
  }

  // ── Update tournament ────────────────────────────────────────────────────

  Future<void> updateTournament({
    required String           tournamentId,
    required String           name,
    required String           sport,
    required TournamentFormat format,
    required DateTime         startDate,
    required String           location,
    required int              maxTeams,
    required double           entryFee,
    required double           serviceFee,
    int                       playersPerTeam = 0,
    DateTime?                 endDate,
    String?                   prizePool,
    String?                   rules,
  }) async {
    await _db.collection(_col).doc(tournamentId).update({
      'name':          name,
      'sport':         sport,
      'format':        format.name,
      'startDate':     Timestamp.fromDate(startDate),
      'location':      location,
      'maxTeams':      maxTeams,
      'entryFee':      entryFee,
      'serviceFee':    serviceFee,
      'playersPerTeam': playersPerTeam,
      'endDate':       endDate != null ? Timestamp.fromDate(endDate) : null,
      'prizePool':     prizePool,
      'rules':         rules,
    });
    await loadTournaments();
  }

  // ── Update tournament status ─────────────────────────────────────────────

  Future<void> updateTournamentStatus(
      String id, TournamentStatus status) async {
    await _db.collection(_col).doc(id).update({'status': status.name});
    await loadTournaments();
  }

  // ── Remove team ──────────────────────────────────────────────────────────

  Future<void> removeTeam(String tournamentId, String teamId) async {
    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('teams')
        .doc(teamId)
        .delete();
    // Also remove from flat enrollments collection
    await _db.collection('enrollments').doc(teamId).delete();
    await _db.collection(_col).doc(tournamentId).update({
      'registeredTeams': FieldValue.increment(-1),
    });
    // Also remove from local my-team map if it was my team
    _myTeamMap.remove(tournamentId);
    _myEnrolledIds.remove(tournamentId);
    await loadDetail(tournamentId);
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

  /// Human-readable description of what the auto-schedule will generate.
  static String scheduleRecommendation(
      int teamCount, String sport, TournamentFormat format) {
    if (teamCount < 2) return 'Need at least 2 teams';

    if (format == TournamentFormat.roundRobin) {
      final matches = (teamCount * (teamCount - 1)) ~/ 2;
      final rounds  = teamCount.isEven ? teamCount - 1 : teamCount;
      return 'Round Robin: every team plays each other once '
             '($matches matches, $rounds rounds)';
    }

    if (format == TournamentFormat.leagueKnockout) {
      final groupSize  = (teamCount % 4 == 3 || teamCount < 5) ? 3 : 4;
      final groupCount = (teamCount / groupSize).ceil();
      final koTeams    = groupCount * 2;
      final bracketSize = _nextPowerOf2(koTeams);
      final koRounds   = _log2(bracketSize).toInt();
      final koLabel    = koRounds == 1 ? 'Final'
          : koRounds == 2 ? 'Semi-finals → Final'
          : koRounds == 3 ? 'Quarter-finals → SF → Final'
          : 'R16 → QF → SF → Final';
      return '$groupCount group(s) of $groupSize → top 2 advance → $koLabel';
    }

    // Knockout
    final bracketSize = _nextPowerOf2(teamCount);
    final byeCount    = bracketSize - teamCount;
    final rounds      = _log2(bracketSize).toInt();
    final label       = rounds == 1 ? 'Final'
        : rounds == 2 ? 'Semi-finals → Final'
        : rounds == 3 ? 'Quarter-finals → SF → Final'
        : 'R16 → QF → SF → Final';
    final byeStr = byeCount > 0 ? ' ($byeCount bye${byeCount > 1 ? "s" : ""})' : '';
    return 'Single Elimination: $label$byeStr';
  }

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

  // ── Permission helpers ──────────────────────────────────────────────────

  bool isHost(String tournamentId) {
    final uid = UserService().userId ?? '';
    if (uid.isEmpty) return false;
    try {
      return _tournaments.firstWhere((t) => t.id == tournamentId).createdBy == uid;
    } catch (_) { return false; }
  }

  bool isAdmin(String tournamentId) {
    final uid = UserService().userId ?? '';
    if (uid.isEmpty) return false;
    return _admins[tournamentId]?.any((a) => a.userId == uid) ?? false;
  }

  bool canDo(String tournamentId, AdminPermission permission) {
    if (isHost(tournamentId)) return true;
    final uid = UserService().userId ?? '';
    final admin = _admins[tournamentId]?.where((a) => a.userId == uid).firstOrNull;
    return admin?.permissions.contains(permission) ?? false;
  }

  // ── Venue methods ───────────────────────────────────────────────────────

  Future<TournamentVenue> addVenue({
    required String tournamentId,
    required String name,
    required String address,
    required String city,
    int     capacity       = 0,
    String  pitchType      = '',
    bool    hasFloodlights = false,
    String? imageUrl,
  }) async {
    final ref = _db.collection(_col).doc(tournamentId).collection('venues').doc();
    final venue = TournamentVenue(
      id:             ref.id,
      tournamentId:   tournamentId,
      name:           name,
      address:        address,
      city:           city,
      capacity:       capacity,
      pitchType:      pitchType,
      hasFloodlights: hasFloodlights,
      imageUrl:       imageUrl,
    );
    await ref.set(venue.toMap());
    await loadDetail(tournamentId);
    return venue;
  }

  Future<void> updateVenue({
    required String tournamentId,
    required String venueId,
    required String name,
    required String address,
    required String city,
    int     capacity       = 0,
    String  pitchType      = '',
    bool    hasFloodlights = false,
    String? imageUrl,
  }) async {
    await _db.collection(_col).doc(tournamentId).collection('venues').doc(venueId).update({
      'name':           name,
      'address':        address,
      'city':           city,
      'capacity':       capacity,
      'pitchType':      pitchType,
      'hasFloodlights': hasFloodlights,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
    await loadDetail(tournamentId);
  }

  Future<void> removeVenue(String tournamentId, String venueId) async {
    await _db.collection(_col).doc(tournamentId).collection('venues').doc(venueId).delete();
    _venues[tournamentId]?.removeWhere((v) => v.id == venueId);
    notifyListeners();
  }

  // ── Admin methods ───────────────────────────────────────────────────────

  Future<void> addAdmin({
    required String               tournamentId,
    required String               userId,
    required String               userName,
    required String               numericId,
    required List<AdminPermission> permissions,
  }) async {
    final adminData = TournamentAdmin(
      userId:      userId,
      userName:    userName,
      numericId:   numericId,
      permissions: permissions,
      assignedAt:  DateTime.now(),
    );
    // Use userId as doc ID so duplicates are prevented
    await _db.collection(_col).doc(tournamentId).collection('admins').doc(userId).set(adminData.toMap());
    // Also add userId to tournament.adminIds array
    await _db.collection(_col).doc(tournamentId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
    });
    await loadDetail(tournamentId);
  }

  Future<void> removeAdmin(String tournamentId, String userId) async {
    await _db.collection(_col).doc(tournamentId).collection('admins').doc(userId).delete();
    await _db.collection(_col).doc(tournamentId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
    });
    _admins[tournamentId]?.removeWhere((a) => a.userId == userId);
    notifyListeners();
  }

  // ── Squad methods ───────────────────────────────────────────────────────

  Future<void> loadSquad(String tournamentId, String teamId) async {
    try {
      final snap = await _db
          .collection(_col).doc(tournamentId)
          .collection('teams').doc(teamId)
          .collection('squad').get();
      _squads.putIfAbsent(tournamentId, () => {});
      _squads[tournamentId]![teamId] = snap.docs.map(TournamentSquadPlayer.fromFirestore).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService.loadSquad error: $e');
    }
  }

  Future<void> addPlayerToSquad({
    required String tournamentId,
    required String teamId,
    required String playerId,
    required String userId,
    required String playerName,
    String  role          = '',
    bool    isCaptain     = false,
    bool    isViceCaptain = false,
    int     jerseyNumber  = 0,
  }) async {
    final ref = _db.collection(_col).doc(tournamentId)
        .collection('teams').doc(teamId)
        .collection('squad').doc();
    final player = TournamentSquadPlayer(
      id:            ref.id,
      teamId:        teamId,
      tournamentId:  tournamentId,
      playerId:      playerId,
      userId:        userId,
      playerName:    playerName,
      role:          role,
      isCaptain:     isCaptain,
      isViceCaptain: isViceCaptain,
      jerseyNumber:  jerseyNumber,
    );
    await ref.set(player.toMap());
    await loadSquad(tournamentId, teamId);
  }

  Future<void> removePlayerFromSquad(
      String tournamentId, String teamId, String playerId) async {
    await _db.collection(_col).doc(tournamentId)
        .collection('teams').doc(teamId)
        .collection('squad').doc(playerId).delete();
    _squads[tournamentId]?[teamId]?.removeWhere((p) => p.id == playerId);
    notifyListeners();
  }

  Future<void> updateSquadPlayer({
    required String tournamentId,
    required String teamId,
    required String docId,
    bool?   isCaptain,
    bool?   isViceCaptain,
    String? role,
    int?    jerseyNumber,
  }) async {
    final updates = <String, dynamic>{};
    if (isCaptain     != null) updates['isCaptain']     = isCaptain;
    if (isViceCaptain != null) updates['isViceCaptain'] = isViceCaptain;
    if (role          != null) updates['role']          = role;
    if (jerseyNumber  != null) updates['jerseyNumber']  = jerseyNumber;
    if (updates.isEmpty) return;
    await _db.collection(_col).doc(tournamentId)
        .collection('teams').doc(teamId)
        .collection('squad').doc(docId).update(updates);
    await loadSquad(tournamentId, teamId);
  }

  // ── Live match methods ──────────────────────────────────────────────────

  Future<void> setMatchLive(String tournamentId, String matchId, {String? streamUrl}) async {
    await _db.collection(_col).doc(tournamentId).collection('matches').doc(matchId).update({
      'isLive': true,
      if (streamUrl != null) 'liveStreamUrl': streamUrl,
    });
    await loadDetail(tournamentId);
  }

  Future<void> endMatchLive(String tournamentId, String matchId) async {
    await _db.collection(_col).doc(tournamentId).collection('matches').doc(matchId).update({
      'isLive': false,
    });
    await loadDetail(tournamentId);
  }

  Future<void> updateScorecard(
      String tournamentId, String matchId, Map<String, dynamic> data) async {
    await _db.collection(_col).doc(tournamentId).collection('matches').doc(matchId).update({
      'scorecardData': data,
    });
    await loadDetail(tournamentId);
  }

  // ── Assign venue to match ───────────────────────────────────────────────

  Future<void> assignVenueToMatch({
    required String tournamentId,
    required String matchId,
    required String venueId,
    required String venueName,
  }) async {
    await _db.collection(_col).doc(tournamentId).collection('matches').doc(matchId).update({
      'venueId':   venueId,
      'venueName': venueName,
    });
    await loadDetail(tournamentId);
  }

  // ── Manual scheduling ───────────────────────────────────────────────────

  Future<TournamentMatch> createCustomMatch({
    required String tournamentId,
    required String teamAId,
    required String teamAName,
    required String teamBId,
    required String teamBName,
    DateTime? scheduledAt,
    String?   venueId,
    String?   venueName,
    int       round = 1,
    String?   note,
  }) async {
    final matchesRef = _db.collection(_col).doc(tournamentId).collection('matches');
    final docRef     = matchesRef.doc();
    final matchIndex = _nextMatchIndex(tournamentId, round);
    final match = TournamentMatch(
      id:           docRef.id,
      tournamentId: tournamentId,
      round:        round,
      matchIndex:   matchIndex,
      teamAId:      teamAId,
      teamAName:    teamAName,
      teamBId:      teamBId,
      teamBName:    teamBName,
      scheduledAt:  scheduledAt,
      venueId:      venueId,
      venueName:    venueName,
      note:         note,
    );
    await docRef.set(match.toMap());
    await loadDetail(tournamentId);
    return match;
  }

  Future<void> deleteMatch(String tournamentId, String matchId) async {
    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .delete();
    await loadDetail(tournamentId);
  }

  Future<void> updateMatchSchedule({
    required String tournamentId,
    required String matchId,
    DateTime? scheduledAt,
    String?   venueId,
    String?   venueName,
    String?   note,
    int?      round,
  }) async {
    final data = <String, dynamic>{};
    if (scheduledAt != null) data['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    if (venueId != null)     data['venueId']     = venueId;
    if (venueName != null)   data['venueName']   = venueName;
    if (note != null)        data['note']        = note;
    if (round != null)       data['round']       = round;
    if (data.isEmpty) return;
    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .update(data);
    await loadDetail(tournamentId);
  }

  int _nextMatchIndex(String tournamentId, int round) =>
      (_matches[tournamentId] ?? []).where((m) => m.round == round).length;

  // ── Group management ─────────────────────────────────────────────────────

  /// Create [count] groups (Group A, B, C…), deleting any existing ones.
  Future<void> createGroups(String tournamentId, int count) async {
    assert(count >= 2 && count <= 26, 'Group count must be between 2 and 26');
    final ref = _db.collection(_col).doc(tournamentId);

    // Delete existing groups
    final existingSnap = await ref.collection('groups').get();
    final batch1 = _db.batch();
    for (final doc in existingSnap.docs) {
      batch1.delete(doc.reference);
    }
    await batch1.commit();

    // Delete existing group-stage matches using cached data
    final groupMatchIds = matchesFor(tournamentId)
        .where((m) => m.groupId != null)
        .map((m) => m.id)
        .toList();
    if (groupMatchIds.isNotEmpty) {
      final batch2 = _db.batch();
      for (final id in groupMatchIds) {
        batch2.delete(ref.collection('matches').doc(id));
      }
      await batch2.commit();
    }

    // Create new groups
    final batch3 = _db.batch();
    for (int i = 0; i < count; i++) {
      final groupRef = ref.collection('groups').doc();
      batch3.set(groupRef, {
        'tournamentId': tournamentId,
        'name':         'Group ${String.fromCharCode(65 + i)}',
        'teamIds':      <String>[],
        'teamNames':    <String, String>{},
        'createdAt':    Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch3.commit();

    // Update tournament flags
    await ref.update({'hasGroups': true, 'groupCount': count});

    await loadDetail(tournamentId);
    // Update cached tournament object
    final idx = _tournaments.indexWhere((t) => t.id == tournamentId);
    if (idx != -1) {
      _tournaments[idx] =
          _tournaments[idx].copyWith(hasGroups: true, groupCount: count);
    }
    notifyListeners();
  }

  /// Assign a team to a group (removes from any previous group first).
  Future<void> assignTeamToGroup({
    required String tournamentId,
    required String groupId,
    required String teamId,
    required String teamName,
  }) async {
    final ref = _db.collection(_col).doc(tournamentId);

    // Remove from any current group
    final batch = _db.batch();
    for (final g in groupsFor(tournamentId)) {
      if (g.teamIds.contains(teamId)) {
        batch.update(ref.collection('groups').doc(g.id), {
          'teamIds':             FieldValue.arrayRemove([teamId]),
          'teamNames.$teamId':   FieldValue.delete(),
        });
      }
    }
    // Add to target group
    batch.update(ref.collection('groups').doc(groupId), {
      'teamIds':             FieldValue.arrayUnion([teamId]),
      'teamNames.$teamId':   teamName,
    });
    await batch.commit();
    await loadDetail(tournamentId);
  }

  /// Remove a team from a group (moves it back to the unassigned pool).
  Future<void> removeTeamFromGroup({
    required String tournamentId,
    required String groupId,
    required String teamId,
  }) async {
    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('groups')
        .doc(groupId)
        .update({
      'teamIds':           FieldValue.arrayRemove([teamId]),
      'teamNames.$teamId': FieldValue.delete(),
    });
    await loadDetail(tournamentId);
  }

  /// Generate round-robin matches for a single group, replacing any existing
  /// group matches for that group.
  Future<void> generateGroupMatches(
      String tournamentId, String groupId) async {
    final group =
        groupsFor(tournamentId).firstWhere((g) => g.id == groupId);
    final allTeams  = teamsFor(tournamentId);
    final groupTeams =
        allTeams.where((t) => group.teamIds.contains(t.id)).toList();

    if (groupTeams.length < 2) {
      throw Exception('${group.name} needs at least 2 teams.');
    }

    final ref = _db.collection(_col).doc(tournamentId);

    // Delete existing matches for this group
    final oldIds = matchesFor(tournamentId)
        .where((m) => m.groupId == groupId)
        .map((m) => m.id)
        .toList();
    if (oldIds.isNotEmpty) {
      final del = _db.batch();
      for (final id in oldIds) {
        del.delete(ref.collection('matches').doc(id));
      }
      await del.commit();
    }

    // Circle-method round-robin
    final n = groupTeams.length;
    final pool = [...groupTeams];
    // Pad to even count so every round has n/2 matches
    final needsBye = n % 2 != 0;
    // For odd n we just skip if both indices happen to collide (won't happen
    // with even after padding, handled below)

    final totalRounds = needsBye ? n : n - 1;
    final batch = _db.batch();
    int matchIndex = 0;

    for (int round = 1; round <= totalRounds; round++) {
      final pairsCount = needsBye ? (n - 1) ~/ 2 : n ~/ 2;
      for (int i = 0; i < pairsCount; i++) {
        final a = pool[i];
        final b = pool[n - 1 - i];
        final mRef = ref.collection('matches').doc();
        final match = TournamentMatch(
          id:           mRef.id,
          tournamentId: tournamentId,
          round:        round,
          matchIndex:   matchIndex++,
          teamAId:      a.id,
          teamAName:    a.teamName,
          teamBId:      b.id,
          teamBName:    b.teamName,
          groupId:      groupId,
          note:         '${group.name} · Round $round',
        );
        batch.set(mRef, match.toMap());
      }
      // Rotate all except first element
      if (pool.length > 1) {
        final last = pool.removeLast();
        pool.insert(1, last);
      }
    }
    await batch.commit();
    await loadDetail(tournamentId);
  }

  /// Remove all groups (and their matches) for a tournament.
  Future<void> deleteAllGroups(String tournamentId) async {
    final ref = _db.collection(_col).doc(tournamentId);

    // Delete group-stage matches
    final groupMatchIds = matchesFor(tournamentId)
        .where((m) => m.groupId != null)
        .map((m) => m.id)
        .toList();
    if (groupMatchIds.isNotEmpty) {
      final b1 = _db.batch();
      for (final id in groupMatchIds) {
        b1.delete(ref.collection('matches').doc(id));
      }
      await b1.commit();
    }

    // Delete group docs
    final snap = await ref.collection('groups').get();
    if (snap.docs.isNotEmpty) {
      final b2 = _db.batch();
      for (final doc in snap.docs) {
        b2.delete(doc.reference);
      }
      await b2.commit();
    }

    // Update tournament flags
    await ref.update({'hasGroups': false, 'groupCount': 0});
    _groups[tournamentId] = [];

    final idx = _tournaments.indexWhere((t) => t.id == tournamentId);
    if (idx != -1) {
      _tournaments[idx] =
          _tournaments[idx].copyWith(hasGroups: false, groupCount: 0);
    }
    await loadDetail(tournamentId);
  }
}
