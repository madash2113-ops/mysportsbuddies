import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/models/tournament.dart';
import 'analytics_service.dart';
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
  // captain photo cache: captainUserId → imageUrl
  final Map<String, String>           _captainPhotoCache = {};

  List<Tournament>          get tournaments    => List.unmodifiable(_tournaments);
  List<TournamentTeam>      teamsFor(String id)   => List.unmodifiable(_teams[id]   ?? []);
  List<TournamentMatch>     matchesFor(String id) => List.unmodifiable(_matches[id] ?? []);
  /// Returns the best available photo for a team's representative.
  /// Pass [captainUserId] and [teamId]; fallback chain is already resolved in loadDetail.
  String? teamRepPhotoFor({required String captainUserId, required String teamId}) {
    if (captainUserId.isNotEmpty && _captainPhotoCache.containsKey(captainUserId)) {
      return _captainPhotoCache[captainUserId];
    }
    return _captainPhotoCache['team:$teamId'];
  }
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

      // ── Pre-fetch captain photos with fallback chain ─────────────────
      // Fallback: captain → vice captain (from squad) → any squad player with photo
      try {
        final teams = _teams[tournamentId]!;

        // Step 1: collect all unique userIds we need to fetch
        // Start with captainUserIds
        final allUserIds = teams
            .map((t) => t.captainUserId)
            .where((uid) => uid.isNotEmpty)
            .toSet();

        // Also load all squads for this tournament to find vice captains
        await Future.wait(teams.map((t) => _loadSquadInternal(tournamentId, t.id)));

        // Add vice captain and squad player userIds
        for (final t in teams) {
          final squad = _squads[tournamentId]?[t.id] ?? [];
          for (final p in squad) {
            if (p.userId.isNotEmpty) allUserIds.add(p.userId);
          }
        }

        // Step 2: fetch all profiles we don't have cached yet
        final toFetch = allUserIds
            .where((uid) => !_captainPhotoCache.containsKey(uid))
            .toList();
        if (toFetch.isNotEmpty) {
          final profiles = await Future.wait(
              toFetch.map((uid) => UserService().loadProfileById(uid)));
          for (var i = 0; i < toFetch.length; i++) {
            final photo = profiles[i]?.imageUrl;
            if (photo != null && photo.isNotEmpty) {
              _captainPhotoCache[toFetch[i]] = photo;
            }
          }
        }

        // Step 3: for each team, resolve the best photo (captain → vc → any)
        for (final t in teams) {
          if (_captainPhotoCache.containsKey(t.captainUserId)) continue;
          // Captain has no photo — try vice captain then any squad player
          final squad = _squads[tournamentId]?[t.id] ?? [];
          String? fallbackPhoto;
          // Vice captain first
          for (final p in squad) {
            if (p.isViceCaptain && p.userId.isNotEmpty &&
                _captainPhotoCache.containsKey(p.userId)) {
              fallbackPhoto = _captainPhotoCache[p.userId];
              break;
            }
          }
          // Any squad player with photo
          if (fallbackPhoto == null) {
            for (final p in squad) {
              if (p.userId.isNotEmpty &&
                  _captainPhotoCache.containsKey(p.userId)) {
                fallbackPhoto = _captainPhotoCache[p.userId];
                break;
              }
            }
          }
          // Store under team's captain key so card lookup still works
          if (fallbackPhoto != null && t.captainUserId.isNotEmpty) {
            _captainPhotoCache[t.captainUserId] = fallbackPhoto;
          } else if (fallbackPhoto != null) {
            // captainUserId empty — store under teamId as key
            _captainPhotoCache['team:${t.id}'] = fallbackPhoto;
          }
        }
      } catch (e) {
        debugPrint('[TournamentService] captain photo prefetch error: $e');
      }

      // ── Self-healing: repair missing bracket advancements ────────────
      try {
        // For League+KO: seed KO bracket from group results if not done yet
        final tourn = _tournaments
            .where((t) => t.id == tournamentId).firstOrNull;
        if (tourn?.format == TournamentFormat.leagueKnockout) {
          await _advanceGroupWinnersToKO(tournamentId);
        }
        await _repairAdvancements(tournamentId);
      } catch (e) {
        debugPrint('[bracket] _repairAdvancements error: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('TournamentService.loadDetail error: $e');
    }
  }

  /// One-pass repair: for every completed match with a winner, ensure
  /// that winner appears in the correct slot of the next-round match.
  /// Reads entirely from Firestore (not in-memory) and uses a single batch.
  Future<void> _repairAdvancements(String tournamentId) async {
    // Read ALL match docs directly from Firestore — single source of truth
    final matchesRef = _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches');
    final allSnap = await matchesRef.get();
    if (allSnap.docs.isEmpty) return;

    debugPrint('[repair] ${allSnap.docs.length} match docs in Firestore');

    // Build map: "round_matchIndex" → (docRef, data)
    final docMap = <String, ({DocumentReference ref, Map<String, dynamic> data})>{};
    for (final d in allSnap.docs) {
      final data = d.data();
      final r  = (data['round']      as num?)?.toInt();
      final mi = (data['matchIndex'] as num?)?.toInt();
      if (r != null && mi != null) {
        docMap['${r}_$mi'] = (ref: d.reference, data: data);
      }
    }

    debugPrint('[repair] Keys: ${docMap.keys.toList()..sort()}');

    final batch = _db.batch();
    int fixes = 0;

    for (final entry in docMap.entries) {
      final data     = entry.value.data;
      final winnerId = data['winnerId'] as String?;
      if (winnerId == null || winnerId.isEmpty) continue;

      // Skip group-stage matches — they don't advance in a knockout tree
      final note = data['note'] as String? ?? '';
      if (note.startsWith('Group')) continue;

      final round      = (data['round']      as num).toInt();
      final matchIndex = (data['matchIndex'] as num).toInt();
      final winnerName = data['winnerName'] as String? ?? '';

      final nextRound      = round + 1;
      final nextMatchIndex = matchIndex ~/ 2;
      final isSlotA        = matchIndex.isEven;
      final nextKey        = '${nextRound}_$nextMatchIndex';

      final next = docMap[nextKey];
      if (next == null) continue; // final round — nowhere to advance

      // Check if already correct
      final slotField = isSlotA ? 'teamAId' : 'teamBId';
      final currentSlot = next.data[slotField] as String?;
      if (currentSlot == winnerId) continue;

      debugPrint('[repair] FIX: $winnerName from '
          'R${round}M$matchIndex → R${nextRound}M$nextMatchIndex '
          '(${isSlotA ? "A" : "B"}) was=$currentSlot');

      final update = isSlotA
          ? {'teamAId': winnerId, 'teamAName': winnerName}
          : {'teamBId': winnerId, 'teamBName': winnerName};
      batch.update(next.ref, update);
      fixes++;
    }

    if (fixes > 0) {
      debugPrint('[repair] Committing $fixes bracket fixes');
      await batch.commit();
      // Re-read into in-memory cache
      final snap = await matchesRef.get();
      _matches[tournamentId] = (snap.docs
          .map(TournamentMatch.fromFirestore)
          .toList())
        ..sort((a, b) {
          final r = a.round.compareTo(b.round);
          return r != 0 ? r : a.matchIndex.compareTo(b.matchIndex);
        });
    } else {
      debugPrint('[repair] All advancements correct');
    }
  }

  // ── Create tournament ───────────────────────────────────────────────────

  static String _generateJoinCode() {
    const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = math.Random.secure();
    return List.generate(6, (_) => charset[rng.nextInt(charset.length)]).join();
  }

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
    ScoringType               scoringType = ScoringType.standard,
    int                       bestOf = 3,
    int                       pointsToWin = 21,
    int                       winPoints = 3,
    int                       drawPoints = 1,
    int                       lossPoints = 0,
    String?                   customScoringLabel,
    bool                      isPrivate = false,
  }) async {
    if (maxTeams > 4 && !UserService().hasFullAccess) {
      throw PremiumRequiredException();
    }

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
      scoringType:      scoringType,
      bestOf:           bestOf,
      pointsToWin:      pointsToWin,
      winPoints:        winPoints,
      drawPoints:       drawPoints,
      lossPoints:       lossPoints,
      customScoringLabel: customScoringLabel,
      isPrivate:        isPrivate,
      joinCode:         isPrivate ? _generateJoinCode() : null,
    );

    await ref.set(tournament.toMap());
    AnalyticsService().logEvent(AnalyticsEvents.tournamentCreated, parameters: {
      'sport':         sport,
      'format':        format.name,
      'is_private':    isPrivate,
      'max_teams':     maxTeams,
      'has_entry_fee': entryFee > 0,
    });

    // Store the location as the primary venue in the venues subcollection
    if (location.trim().isNotEmpty) {
      final venueRef = ref.collection('venues').doc();
      final venue = TournamentVenue(
        id:           venueRef.id,
        tournamentId: ref.id,
        name:         location,
        address:      location,
        city:         location.split(',').last.trim(),
      );
      await venueRef.set(venue.toMap());
    }

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
    String                captainUserId     = '',
    String                viceCaptainName   = '',
    String                viceCaptainUserId = '',
    required List<String> players,
    List<String>          playerUserIds = const [],
  }) async {
    final userId = UserService().userId ?? '';

    // ── Pre-flight checks (read before any write) ────────────────────────
    final tourn = _tournaments.firstWhere(
      (t) => t.id == tournamentId,
      orElse: () => throw Exception('Tournament not found'),
    );

    final teamsRef = _db.collection(_col).doc(tournamentId).collection('teams');
    final existing = await teamsRef.get();

    // Guard: max teams
    if (tourn.maxTeams > 0 && existing.docs.length >= tourn.maxTeams) {
      throw Exception(
          'Tournament is full — maximum ${tourn.maxTeams} teams allowed');
    }

    // Guard: duplicate team name
    final nameLower = teamName.trim().toLowerCase();
    final duplicate = existing.docs.any(
      (d) => (d.data()['teamName'] as String? ?? '').toLowerCase() == nameLower,
    );
    if (duplicate) {
      throw Exception('A team named "$teamName" is already enrolled');
    }

    // Guard: same user already enrolled (hosts can enroll multiple teams)
    final isHostUser = tourn.createdBy == userId;
    if (!isHostUser) {
      final alreadyEnrolled = existing.docs.any(
        (d) => (d.data()['enrolledBy'] as String? ?? '') == userId,
      );
      if (alreadyEnrolled) {
        throw Exception('You have already enrolled a team in this tournament');
      }
    }

    final seed = existing.docs.length + 1;
    final ref  = teamsRef.doc();
    final team = TournamentTeam(
      id:                ref.id,
      tournamentId:      tournamentId,
      teamName:          teamName,
      captainName:       captainName,
      captainPhone:      captainPhone,
      captainUserId:     captainUserId,
      viceCaptainName:   viceCaptainName,
      viceCaptainUserId: viceCaptainUserId,
      players:           players,
      playerUserIds:     playerUserIds,
      enrolledBy:        userId,
      enrolledAt:        DateTime.now(),
      paymentConfirmed:  true,
      seed:              seed,
    );

    // ── Atomic batch: all writes succeed or none do ───────────────────────
    final batch = _db.batch();

    // 1. Team document in subcollection
    batch.set(ref, team.toMap());

    // 2. Mirror to flat enrollments collection
    batch.set(_db.collection('enrollments').doc(ref.id), team.toMap());

    // 3. Increment counter on the parent tournament doc
    batch.update(_db.collection(_col).doc(tournamentId), {
      'registeredTeams': FieldValue.increment(1),
    });

    await batch.commit(); // throws on any permission error — nothing is written
    AnalyticsService().logEvent(AnalyticsEvents.tournamentJoined, parameters: {
      'sport':         tourn.sport,
      'has_entry_fee': tourn.entryFee > 0,
    });

    // Refresh local cache only after successful commit
    await loadDetail(tournamentId);
    await loadMyEnrollments(userId);

    // ── Increment stats for all registered players in the team ───────────────
    final allUserIds = <String>{
      if (userId.isNotEmpty) userId,
      ...playerUserIds.where((id) => id.isNotEmpty),
    };
    for (final uid in allUserIds) {
      await UserService.incrementStats(uid, tournamentsPlayed: 1);
    }

    // ── Notifications ───────────────────────────────────────────────────────
    final enrollerName = UserService().profile?.name ?? 'Someone';

    // Notify the host
    if (tourn.createdBy.isNotEmpty && tourn.createdBy != userId) {
      await NotificationService.send(
        toUserId: tourn.createdBy,
        type:     NotifType.tournamentUpdate,
        title:    '${tourn.name} — New Enrollment',
        body:     '$teamName (captain: $captainName) enrolled in your tournament',
        targetId: tournamentId,
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
        targetId: tournamentId,
      );
    }

    // Notify each player added to this team (except the enrolling user)
    for (final pUid in playerUserIds) {
      if (pUid.isEmpty || pUid == userId) continue;
      await NotificationService.send(
        toUserId: pUid,
        type:     NotifType.tournamentUpdate,
        title:    'You\'ve been added to $teamName',
        body:     '$enrollerName added you to "$teamName" in ${tourn.name}',
        targetId: tournamentId,
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
      case TournamentFormat.league:
        await _generateRoundRobin(tournamentId, teams, matchesRef);
      case TournamentFormat.custom:
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

    // Auto-advance byes: read all match docs, find byes with winners,
    // write each winner into the correct next-round slot.
    final allSnap = await matchesRef.get();
    final docMap = <String, QueryDocumentSnapshot>{};
    for (final d in allSnap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final r  = (data['round'] as num?)?.toInt();
      final mi = (data['matchIndex'] as num?)?.toInt();
      if (r != null && mi != null) docMap['${r}_$mi'] = d;
    }

    final byeBatch = _db.batch();
    bool hasByeWrites = false;
    for (final d in allSnap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final isBye    = data['isBye'] as bool? ?? false;
      final winnerId = data['winnerId'] as String?;
      if (!isBye || winnerId == null || winnerId.isEmpty) continue;

      final round      = (data['round']      as num).toInt();
      final matchIndex = (data['matchIndex'] as num).toInt();
      final nextRound      = round + 1;
      final nextMatchIndex = matchIndex ~/ 2;
      final isSlotA        = matchIndex.isEven;
      final nextKey        = '${nextRound}_$nextMatchIndex';
      final nextDoc        = docMap[nextKey];
      if (nextDoc == null) continue;

      final winnerName = data['winnerName'] as String? ?? '';
      final update = isSlotA
          ? {'teamAId': winnerId, 'teamAName': winnerName}
          : {'teamBId': winnerId, 'teamBName': winnerName};
      byeBatch.update(nextDoc.reference, update);
      hasByeWrites = true;
    }
    if (hasByeWrites) await byeBatch.commit();
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
    ScoringType               scoringType = ScoringType.standard,
    int                       bestOf = 3,
    int                       pointsToWin = 21,
    int                       winPoints = 3,
    int                       drawPoints = 1,
    int                       lossPoints = 0,
    String?                   customScoringLabel,
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
      'scoringType':   scoringType.name,
      'bestOf':        bestOf,
      'pointsToWin':   pointsToWin,
      'winPoints':     winPoints,
      'drawPoints':    drawPoints,
      'lossPoints':    lossPoints,
      'customScoringLabel': customScoringLabel,
    });
    await loadTournaments();
  }

  // ── Update tournament status ─────────────────────────────────────────────

  Future<void> updateTournamentStatus(
      String id, TournamentStatus status) async {
    await _db.collection(_col).doc(id).update({'status': status.name});
    await loadTournaments();
  }

  // ── Clear all teams + matches (reset for fresh registration) ────────────

  Future<void> clearTeamsAndMatches(String tournamentId) async {
    final ref = _db.collection(_col).doc(tournamentId);

    // Delete all team docs (batched in groups of 500)
    Future<void> deleteCollection(String sub) async {
      QuerySnapshot snap;
      do {
        snap = await ref.collection(sub).limit(200).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in snap.docs) { batch.delete(d.reference); }
        await batch.commit();
      } while (snap.docs.length == 200);
    }

    await deleteCollection('teams');
    await deleteCollection('matches');

    // Also clear flat enrollments that point to this tournament
    final enrSnap = await _db
        .collection('enrollments')
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    if (enrSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final d in enrSnap.docs) { batch.delete(d.reference); }
      await batch.commit();
    }

    // Reset team counter on tournament doc
    await ref.update({'registeredTeams': 0});

    // Clear local caches
    _teams.remove(tournamentId);
    _matches.remove(tournamentId);
    _myTeamMap.remove(tournamentId);
    _myEnrolledIds.remove(tournamentId);

    await loadDetail(tournamentId);
  }

  // ── Delete tournament entirely ───────────────────────────────────────────

  Future<void> deleteTournament(String tournamentId) async {
    final ref = _db.collection(_col).doc(tournamentId);

    Future<void> deleteCollection(String sub) async {
      QuerySnapshot snap;
      do {
        snap = await ref.collection(sub).limit(200).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in snap.docs) { batch.delete(d.reference); }
        await batch.commit();
      } while (snap.docs.length == 200);
    }

    // Delete all subcollections first
    await deleteCollection('teams');
    await deleteCollection('matches');
    await deleteCollection('groups');
    await deleteCollection('venues');
    await deleteCollection('admins');
    await deleteCollection('squad');

    // Delete flat enrollments referencing this tournament
    final enrSnap = await _db
        .collection('enrollments')
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    if (enrSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final d in enrSnap.docs) { batch.delete(d.reference); }
      await batch.commit();
    }

    // Delete the tournament document itself
    await ref.delete();

    // Clear local caches
    _tournaments.removeWhere((t) => t.id == tournamentId);
    _teams.remove(tournamentId);
    _matches.remove(tournamentId);
    _groups.remove(tournamentId);
    _venues.remove(tournamentId);
    _admins.remove(tournamentId);
    _myTeamMap.remove(tournamentId);
    _myEnrolledIds.remove(tournamentId);

    notifyListeners();
  }

  // ── Clear matches only (preserves teams) ────────────────────────────────

  Future<void> clearMatchesOnly(String tournamentId) async {
    final ref = _db.collection(_col).doc(tournamentId);
    QuerySnapshot snap;
    do {
      snap = await ref.collection('matches').limit(200).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) { batch.delete(d.reference); }
      await batch.commit();
    } while (snap.docs.length == 200);

    await ref.update({'bracketGenerated': false});
    _matches.remove(tournamentId);
    await loadDetail(tournamentId);
  }

  // ── Seed dummy teams (dev / testing only) ───────────────────────────────

  Future<void> seedDummyTeams(String tournamentId, {int count = 27}) async {
    final teamNames = [
      'Thunder Bolts', 'Iron Eagles', 'Storm Riders', 'Neon Hawks',
      'Dark Wolves', 'Blaze FC', 'Arctic Foxes', 'Shadow Panthers',
      'Royal Strikers', 'Fire Dragons', 'Silver Sharks', 'Cobra Kings',
      'Phantom Squad', 'Golden Lions', 'Red Falcons', 'Night Owls',
      'Blue Bullets', 'Desert Ravens', 'Titan Warriors', 'Rapid Rockets',
      'Cyber Wolves', 'Steel Jaguars', 'Volt Tigers', 'Solar Bears',
      'Crimson Hawks', 'Frost Giants', 'Jade Serpents',
    ];

    final captains = [
      'Arjun Sharma', 'Rahul Mehta', 'Priya Patel', 'Karan Singh',
      'Ananya Gupta', 'Vikram Nair', 'Sneha Joshi', 'Rohit Kumar',
      'Pooja Reddy', 'Aditya Verma', 'Meera Iyer', 'Suresh Pillai',
      'Divya Menon', 'Nikhil Das', 'Kavya Rao', 'Amit Bose',
      'Ritika Shah', 'Sandeep Tiwari', 'Lakshmi Nair', 'Gaurav Jain',
      'Swati Mishra', 'Harish Yadav', 'Nisha Kapoor', 'Rajesh Pandey',
      'Deepa Srinivas', 'Mohit Aggarwal', 'Alka Dubey',
    ];

    final phones = List.generate(27, (i) => '9${(800000000 + i * 1111111) % 1000000000}'.padLeft(10, '9'));

    final teamsRef = _db.collection(_col).doc(tournamentId).collection('teams');
    final existing = await teamsRef.get();
    final existingCount = existing.docs.length;

    final batch = _db.batch();
    for (int i = 0; i < count; i++) {
      final ref = teamsRef.doc();
      final seed = existingCount + i + 1;
      final team = TournamentTeam(
        id:               ref.id,
        tournamentId:     tournamentId,
        teamName:         teamNames[i % teamNames.length],
        captainName:      captains[i % captains.length],
        captainPhone:     phones[i % phones.length],
        captainUserId:    '',
        viceCaptainName:  '',
        viceCaptainUserId: '',
        players:          [],
        playerUserIds:    [],
        enrolledBy:       'dummy_seed',
        enrolledAt:       DateTime.now(),
        paymentConfirmed: true,
        seed:             seed,
      );
      batch.set(ref, team.toMap());
    }

    await batch.commit();
    await _db.collection(_col).doc(tournamentId).update({
      'registeredTeams': FieldValue.increment(count),
    });
    await loadDetail(tournamentId);
    notifyListeners();
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

  // ── Reset match result ──────────────────────────────────────────────────

  /// Wipes score + result for a single match back to pending state.
  /// Also undoes the team stats that were applied when the result was first set.
  /// The caller (UI layer) is responsible for removing the live scoreboard doc
  /// via ScoreboardService to avoid a circular dependency.
  Future<void> resetMatchResult({
    required String tournamentId,
    required String matchId,
  }) async {
    final match = matchesFor(tournamentId).where((m) => m.id == matchId).firstOrNull;
    if (match == null || !match.isPlayed) return;

    final t = _tournaments.where((t) => t.id == tournamentId).firstOrNull;

    // 1. Undo RR/League stats for this match
    if (t != null &&
        (t.format == TournamentFormat.roundRobin ||
         t.format == TournamentFormat.leagueKnockout)) {
      await _undoRRStats(tournamentId, match, t);
    }

    // 2. Reset match document to pending state
    await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId)
        .update({
      'scoreA':     FieldValue.delete(),
      'scoreB':     FieldValue.delete(),
      'winnerId':   FieldValue.delete(),
      'winnerName': FieldValue.delete(),
      'result':     TournamentMatchResult.pending.name,
    });

    // 3. Refresh in-memory cache and notify UI
    await loadDetail(tournamentId);
  }

  /// Reverses the stats that were written by [_updateRRStats] for [match].
  Future<void> _undoRRStats(
    String tournamentId,
    TournamentMatch match,
    Tournament t,
  ) async {
    if (match.teamAId == null || match.teamBId == null) return;

    final wPts = t.winPoints  > 0 ? t.winPoints  : 3;
    final dPts = t.drawPoints > 0 ? t.drawPoints : 1;
    final lPts = t.lossPoints;

    final Map<String, dynamic> updA = {'played': FieldValue.increment(-1)};
    final Map<String, dynamic> updB = {'played': FieldValue.increment(-1)};

    switch (match.result) {
      case TournamentMatchResult.teamAWin:
        updA['wins']   = FieldValue.increment(-1);
        updA['points'] = FieldValue.increment(-wPts);
        updB['losses'] = FieldValue.increment(-1);
        if (lPts != 0) updB['points'] = FieldValue.increment(-lPts);
      case TournamentMatchResult.teamBWin:
        updB['wins']   = FieldValue.increment(-1);
        updB['points'] = FieldValue.increment(-wPts);
        updA['losses'] = FieldValue.increment(-1);
        if (lPts != 0) updA['points'] = FieldValue.increment(-lPts);
      case TournamentMatchResult.draw:
        updA['draws']  = FieldValue.increment(-1);
        updA['points'] = FieldValue.increment(-dPts);
        updB['draws']  = FieldValue.increment(-1);
        updB['points'] = FieldValue.increment(-dPts);
      case TournamentMatchResult.pending:
      case TournamentMatchResult.bye:
        return; // nothing to undo
    }

    final teamsRef = _db.collection(_col).doc(tournamentId).collection('teams');
    await Future.wait([
      teamsRef.doc(match.teamAId!).update(updA),
      teamsRef.doc(match.teamBId!).update(updB),
    ]);
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
    debugPrint('[bracket] updateMatchResult: matchId=$matchId '
        'score=$scoreA-$scoreB winner=$winnerName($winnerId)');

    final result = scoreA > scoreB
        ? TournamentMatchResult.teamAWin
        : scoreB > scoreA
            ? TournamentMatchResult.teamBWin
            : TournamentMatchResult.draw;

    final matchesRef = _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches');

    // 1. Save the score
    await matchesRef.doc(matchId).update({
      'scoreA':     scoreA,
      'scoreB':     scoreB,
      'winnerId':   winnerId,
      'winnerName': winnerName,
      'result':     result.name,
    });

    // 2. Read the match we just updated to get its round/matchIndex
    final matchDoc = await matchesRef.doc(matchId).get();
    final mData = matchDoc.data();
    if (mData == null) {
      debugPrint('[bracket] ERROR: match doc $matchId not found after write');
      await loadDetail(tournamentId);
      return;
    }

    final round      = (mData['round']      as num).toInt();
    final matchIndex = (mData['matchIndex'] as num).toInt();
    final matchNote  = mData['note'] as String? ?? '';
    final isGroupMatch = matchNote.startsWith('Group');

    debugPrint('[bracket] Match is R${round}M$matchIndex note="$matchNote"');

    // 3. Advance winner directly — but ONLY for knockout matches.
    //    Group-stage (RR) matches must NOT trigger knockout advancement.
    if (winnerId.isNotEmpty && !isGroupMatch) {
      final nextRound      = round + 1;
      final nextMatchIndex = matchIndex ~/ 2;
      final isSlotA        = matchIndex.isEven;

      // Fetch ALL match docs to find the next-round match
      final allSnap = await matchesRef.get();
      debugPrint('[bracket] Fetched ${allSnap.docs.length} total match docs');

      // Build a round→matchIndex→docId map for diagnostics
      final docMap = <String, String>{};
      for (final d in allSnap.docs) {
        final dd = d.data();
        final r  = (dd['round'] as num?)?.toInt();
        final mi = (dd['matchIndex'] as num?)?.toInt();
        if (r != null && mi != null) docMap['R${r}M$mi'] = d.id;
      }
      debugPrint('[bracket] All match keys: ${docMap.keys.toList()..sort()}');

      final nextDoc = allSnap.docs.where((d) {
        final dd = d.data();
        return (dd['round']      as num?)?.toInt() == nextRound &&
               (dd['matchIndex'] as num?)?.toInt() == nextMatchIndex;
      }).firstOrNull;

      if (nextDoc != null) {
        final update = isSlotA
            ? {'teamAId': winnerId, 'teamAName': winnerName}
            : {'teamBId': winnerId, 'teamBName': winnerName};
        debugPrint('[bracket] ADVANCING $winnerName → '
            'R${nextRound}M$nextMatchIndex '
            '(${isSlotA ? "slotA" : "slotB"}) docId=${nextDoc.id}');
        await matchesRef.doc(nextDoc.id).update(update);
        debugPrint('[bracket] Advancement write SUCCESS');
      } else {
        debugPrint('[bracket] No next-round match at R${nextRound}M$nextMatchIndex '
            '(this is the final round)');
      }
    }

    // 4. Update RR stats if applicable
    final tournDoc = _tournaments
        .where((t) => t.id == tournamentId).firstOrNull;
    final format = tournDoc?.format;
    if (format == TournamentFormat.roundRobin ||
        format == TournamentFormat.leagueKnockout) {
      final match = TournamentMatch.fromMap(matchId, mData);
      await _updateRRStats(tournamentId, match, scoreA, scoreB);
    }

    // 5. League+KO: check if group stage is done and seed KO bracket
    if (format == TournamentFormat.leagueKnockout) {
      await _advanceGroupWinnersToKO(tournamentId);
    }

    // 6. Reload to refresh UI
    debugPrint('[bracket] Reloading detail...');
    await loadDetail(tournamentId);
  }

  Future<void> _updateRRStats(
    String tournamentId,
    TournamentMatch match,
    int scoreA,
    int scoreB,
  ) async {
    if (match.teamAId == null || match.teamBId == null) return;

    // Use tournament's configured scoring — fall back to standard 3/1/0
    final t = _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    final wPts = t?.winPoints  ?? 3;
    final dPts = t?.drawPoints ?? 1;
    final lPts = t?.lossPoints ?? 0;

    final Map<String, dynamic> updateA = {'played': FieldValue.increment(1)};
    final Map<String, dynamic> updateB = {'played': FieldValue.increment(1)};

    if (scoreA > scoreB) {
      updateA['wins']   = FieldValue.increment(1);
      updateA['points'] = FieldValue.increment(wPts);
      updateB['losses'] = FieldValue.increment(1);
      if (lPts != 0) updateB['points'] = FieldValue.increment(lPts);
    } else if (scoreB > scoreA) {
      updateB['wins']   = FieldValue.increment(1);
      updateB['points'] = FieldValue.increment(wPts);
      updateA['losses'] = FieldValue.increment(1);
      if (lPts != 0) updateA['points'] = FieldValue.increment(lPts);
    } else {
      updateA['draws']  = FieldValue.increment(1);
      updateA['points'] = FieldValue.increment(dPts);
      updateB['draws']  = FieldValue.increment(1);
      updateB['points'] = FieldValue.increment(dPts);
    }

    final teamsRef = _db.collection(_col).doc(tournamentId).collection('teams');
    await Future.wait([
      teamsRef.doc(match.teamAId).update(updateA),
      teamsRef.doc(match.teamBId).update(updateB),
    ]);
  }

  // ── League+KO: advance group winners into knockout bracket ──────────────

  /// After every RR result in a League+KO tournament, check whether ALL
  /// group-stage matches are done. If so, rank teams per group by points
  /// (then wins, then GD) and seed the top 2 from each group into the
  /// empty knockout-round matches.
  Future<void> _advanceGroupWinnersToKO(String tournamentId) async {
    final matchesRef = _db
        .collection(_col)
        .doc(tournamentId)
        .collection('matches');
    final allSnap = await matchesRef.get();
    final allMatches = allSnap.docs
        .map((d) => (doc: d, data: d.data()))
        .toList();

    // Separate group-stage vs knockout matches.
    // Group-stage matches have a note like "Group A", "Group B".
    // Knockout matches have notes like "Semi-finals", "Final", etc.
    final groupMatches = allMatches.where((m) {
      final note = m.data['note'] as String? ?? '';
      return note.startsWith('Group');
    }).toList();

    final koMatches = allMatches.where((m) {
      final note = m.data['note'] as String? ?? '';
      return !note.startsWith('Group') && note.isNotEmpty;
    }).toList();

    if (groupMatches.isEmpty || koMatches.isEmpty) return;

    // Check if ALL group matches are played
    final allGroupDone = groupMatches.every((m) {
      final result = m.data['result'] as String? ?? 'pending';
      return result != 'pending';
    });
    if (!allGroupDone) {
      debugPrint('[leagueKO] Not all group matches done yet');
      return;
    }

    // Check if KO first-round matches already have CORRECT teams seeded.
    // We verify by checking if any first-round KO match has a played result.
    // If KO matches have already been played, don't re-seed.
    final earlyKORound = koMatches
        .map((m) => (m.data['round'] as num).toInt())
        .reduce(math.min);
    final firstRoundKOPlayed = koMatches.any((m) =>
        (m.data['round'] as num).toInt() == earlyKORound &&
        (m.data['result'] as String? ?? 'pending') != 'pending');
    if (firstRoundKOPlayed) {
      debugPrint('[leagueKO] KO matches already played — skipping re-seed');
      return;
    }

    debugPrint('[leagueKO] All group matches done — seeding KO bracket');

    // Group matches by their group label
    final groupMap = <String, List<Map<String, dynamic>>>{};
    for (final m in groupMatches) {
      final group = m.data['note'] as String;
      groupMap.putIfAbsent(group, () => []).add(m.data);
    }

    // Read fresh team stats from Firestore
    final teamsSnap = await _db
        .collection(_col)
        .doc(tournamentId)
        .collection('teams')
        .get();
    final teamById = <String, Map<String, dynamic>>{
      for (final d in teamsSnap.docs) d.id: d.data(),
    };

    // For each group, find which team IDs participated
    final groupTeamIds = <String, Set<String>>{};
    for (final entry in groupMap.entries) {
      final ids = <String>{};
      for (final m in entry.value) {
        final aId = m['teamAId'] as String?;
        final bId = m['teamBId'] as String?;
        if (aId != null) ids.add(aId);
        if (bId != null) ids.add(bId);
      }
      groupTeamIds[entry.key] = ids;
    }

    // Rank teams within each group by: points desc → wins desc → GD desc
    // (GD = goals scored - goals conceded, calculated from match results)
    final qualifiers = <({String teamId, String teamName})>[];
    final sortedGroupNames = groupTeamIds.keys.toList()..sort();

    for (final groupName in sortedGroupNames) {
      final teamIds = groupTeamIds[groupName]!;
      final rankings = <({String id, String name, int pts, int wins, int gd})>[];

      for (final tid in teamIds) {
        final t = teamById[tid];
        if (t == null) continue;
        final pts  = (t['points'] as num?)?.toInt() ?? 0;
        final wins = (t['wins']   as num?)?.toInt() ?? 0;

        // Calculate goal difference from group matches
        int gf = 0, ga = 0;
        for (final m in groupMap[groupName]!) {
          final aId = m['teamAId'] as String?;
          final bId = m['teamBId'] as String?;
          final sA  = (m['scoreA'] as num?)?.toInt() ?? 0;
          final sB  = (m['scoreB'] as num?)?.toInt() ?? 0;
          if (aId == tid) { gf += sA; ga += sB; }
          if (bId == tid) { gf += sB; ga += sA; }
        }

        rankings.add((
          id:   tid,
          name: t['teamName'] as String? ?? 'Unknown',
          pts:  pts,
          wins: wins,
          gd:   gf - ga,
        ));
      }

      // Sort: highest points first, then wins, then GD
      rankings.sort((a, b) {
        int c = b.pts.compareTo(a.pts);
        if (c != 0) return c;
        c = b.wins.compareTo(a.wins);
        if (c != 0) return c;
        return b.gd.compareTo(a.gd);
      });

      debugPrint('[leagueKO] $groupName rankings: '
          '${rankings.map((r) => '${r.name}(${r.pts}pts)').join(', ')}');

      // Top 2 from each group qualify
      for (int i = 0; i < math.min(2, rankings.length); i++) {
        qualifiers.add((teamId: rankings[i].id, teamName: rankings[i].name));
      }
    }

    if (qualifiers.isEmpty) return;

    debugPrint('[leagueKO] Qualifiers: '
        '${qualifiers.map((q) => q.teamName).join(', ')}');

    // Seed qualifiers into KO matches.
    // Standard cross-seeding: Group A #1 vs Group B #2, Group B #1 vs Group A #2
    // For >2 groups, fill bracket slots in order.
    // KO matches sorted by round then matchIndex.
    final firstKORound = koMatches
        .map((m) => (m.data['round'] as num).toInt())
        .reduce(math.min);
    final firstRoundKO = koMatches
        .where((m) => (m.data['round'] as num).toInt() == firstKORound)
        .toList()
      ..sort((a, b) => (a.data['matchIndex'] as num).toInt()
          .compareTo((b.data['matchIndex'] as num).toInt()));

    // Cross-seed: A1 vs B2, B1 vs A2, C1 vs D2, D1 vs C2, ...
    final seeded = <({String teamId, String teamName})>[];
    final groupCount = sortedGroupNames.length;
    for (int g = 0; g < groupCount; g += 2) {
      final g1Top = qualifiers.length > g * 2     ? qualifiers[g * 2]     : null;
      final g1Run = qualifiers.length > g * 2 + 1 ? qualifiers[g * 2 + 1] : null;
      final g2Top = qualifiers.length > g * 2 + 2 ? qualifiers[g * 2 + 2] : null;
      final g2Run = qualifiers.length > g * 2 + 3 ? qualifiers[g * 2 + 3] : null;
      // Match 1: A1 vs B2
      if (g1Top != null) seeded.add(g1Top);
      if (g2Run != null) seeded.add(g2Run);
      // Match 2: B1 vs A2
      if (g2Top != null) seeded.add(g2Top);
      if (g1Run != null) seeded.add(g1Run);
    }

    // Write into KO match docs
    final batch = _db.batch();
    int slotIdx = 0;
    for (final ko in firstRoundKO) {
      final Map<String, dynamic> update = {};
      if (slotIdx < seeded.length) {
        update['teamAId']   = seeded[slotIdx].teamId;
        update['teamAName'] = seeded[slotIdx].teamName;
        slotIdx++;
      }
      if (slotIdx < seeded.length) {
        update['teamBId']   = seeded[slotIdx].teamId;
        update['teamBName'] = seeded[slotIdx].teamName;
        slotIdx++;
      }
      if (update.isNotEmpty) {
        batch.update(ko.doc.reference, update);
        debugPrint('[leagueKO] Seeded KO match ${ko.doc.id}: $update');
      }
    }
    await batch.commit();
    debugPrint('[leagueKO] KO bracket seeding complete');
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

  /// Converts a flat match list into structured TournamentRound list.
  /// Labels rounds from the end: Final, Semi-finals, Quarter-finals, then
  /// generic "Round N" for earlier stages.
  List<TournamentRound> buildRounds(String tournamentId) {
    final matches = _matches[tournamentId] ?? [];
    if (matches.isEmpty) return [];

    final Map<int, List<TournamentMatch>> byRound = {};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }

    final sortedKeys = byRound.keys.toList()..sort();
    final total = sortedKeys.length;

    final rounds = <TournamentRound>[];
    for (int i = 0; i < total; i++) {
      final key    = sortedKeys[i];
      final sorted = [...byRound[key]!]
        ..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));

      // Distance from the last round (1 = Final, 2 = SF, 3 = QF, …)
      final fromEnd = total - i;
      final label = switch (fromEnd) {
        1 => 'Final',
        2 => 'Semi-finals',
        3 => 'Quarter-finals',
        _ => 'Round ${i + 1}',
      };

      rounds.add(TournamentRound(
        roundNumber: key,
        label:       label,
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
      'imageUrl': ?imageUrl,
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

  /// Internal squad loader used during loadDetail — does not call notifyListeners.
  Future<void> _loadSquadInternal(String tournamentId, String teamId) async {
    try {
      if (_squads[tournamentId]?.containsKey(teamId) == true) return;
      final snap = await _db
          .collection(_col).doc(tournamentId)
          .collection('teams').doc(teamId)
          .collection('squad').get();
      _squads.putIfAbsent(tournamentId, () => {});
      _squads[tournamentId]![teamId] =
          snap.docs.map(TournamentSquadPlayer.fromFirestore).toList();
    } catch (e) {
      debugPrint('TournamentService._loadSquadInternal error: $e');
    }
  }

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
      'liveStreamUrl': ?streamUrl,
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

  /// Updates score + scorecard data live (mid-match, no winner set yet).
  Future<void> updateLiveScore(
      String tournamentId,
      String matchId,
      int    scoreA,
      int    scoreB,
      Map<String, dynamic> scorecardData,
  ) async {
    await _db.collection(_col).doc(tournamentId).collection('matches').doc(matchId).update({
      'scoreA':        scoreA,
      'scoreB':        scoreB,
      'scorecardData': scorecardData,
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
