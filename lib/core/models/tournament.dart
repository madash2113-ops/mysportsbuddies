import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum TournamentStatus  { open, ongoing, completed, cancelled }
enum TournamentFormat  { knockout, roundRobin, leagueKnockout }
enum ScheduleMode      { auto, manual }
enum TournamentMatchResult { pending, teamAWin, teamBWin, draw, bye }

enum AdminPermission {
  scheduleMatches,
  updateScores,
  editSquads,
  manageVenues,
  editMatchInfo,
}

// ── Tournament ─────────────────────────────────────────────────────────────

class Tournament {
  final String           id;
  final String           name;
  final String           sport;
  final TournamentFormat format;
  final TournamentStatus status;
  final DateTime         startDate;
  final String           location;
  final int              maxTeams;       // 0 = unlimited
  final double           entryFee;
  final double           serviceFee;
  final String           createdBy;      // userId
  final String           createdByName;
  final DateTime         createdAt;
  final ScheduleMode     scheduleMode;
  final bool             bracketGenerated;
  final String?          prizePool;
  final int              registeredTeams;
  final int              playersPerTeam;   // 0 = no limit / not specified
  final DateTime?        endDate;
  final String?          rules;
  final String?          bannerUrl;
  final String?          description;
  final List<String>     adminIds;         // userIds of assigned admins
  final bool             hasGroups;        // true once groups have been created
  final int              groupCount;       // number of groups (0 = no groups)

  const Tournament({
    required this.id,
    required this.name,
    required this.sport,
    required this.format,
    required this.status,
    required this.startDate,
    required this.location,
    required this.maxTeams,
    required this.entryFee,
    required this.serviceFee,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.scheduleMode,
    required this.bracketGenerated,
    this.prizePool,
    required this.registeredTeams,
    this.playersPerTeam = 0,
    this.endDate,
    this.rules,
    this.bannerUrl,
    this.description,
    this.adminIds = const [],
    this.hasGroups = false,
    this.groupCount = 0,
  });

  double get totalFee => entryFee + serviceFee;

  Map<String, dynamic> toMap() => {
    'name':             name,
    'sport':            sport,
    'format':           format.name,
    'status':           status.name,
    'startDate':        Timestamp.fromDate(startDate),
    'location':         location,
    'maxTeams':         maxTeams,
    'entryFee':         entryFee,
    'serviceFee':       serviceFee,
    'createdBy':        createdBy,
    'createdByName':    createdByName,
    'createdAt':        Timestamp.fromDate(createdAt),
    'scheduleMode':     scheduleMode.name,
    'bracketGenerated': bracketGenerated,
    'prizePool':        prizePool,
    'registeredTeams':  registeredTeams,
    'playersPerTeam':   playersPerTeam,
    'endDate':          endDate != null ? Timestamp.fromDate(endDate!) : null,
    'rules':            rules,
    'bannerUrl':        bannerUrl,
    'description':      description,
    'adminIds':         adminIds,
    'hasGroups':        hasGroups,
    'groupCount':       groupCount,
  };

  static Tournament fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static Tournament fromMap(String id, Map<String, dynamic> m) => Tournament(
    id:               id,
    name:             m['name']          as String,
    sport:            m['sport']         as String,
    format:           TournamentFormat.values.firstWhere(
                        (e) => e.name == m['format'],
                        orElse: () => TournamentFormat.knockout),
    status:           TournamentStatus.values.firstWhere(
                        (e) => e.name == m['status'],
                        orElse: () => TournamentStatus.open),
    startDate:        (m['startDate'] as Timestamp).toDate(),
    location:         m['location']      as String,
    maxTeams:         (m['maxTeams']     as num).toInt(),
    entryFee:         (m['entryFee']     as num).toDouble(),
    serviceFee:       (m['serviceFee']   as num).toDouble(),
    createdBy:        m['createdBy']     as String,
    createdByName:    m['createdByName'] as String? ?? '',
    createdAt:        (m['createdAt']    as Timestamp).toDate(),
    scheduleMode:     ScheduleMode.values.firstWhere(
                        (e) => e.name == m['scheduleMode'],
                        orElse: () => ScheduleMode.auto),
    bracketGenerated: m['bracketGenerated'] as bool? ?? false,
    prizePool:        m['prizePool']     as String?,
    registeredTeams:  (m['registeredTeams'] as num?)?.toInt() ?? 0,
    playersPerTeam:   (m['playersPerTeam']  as num?)?.toInt() ?? 0,
    endDate:          m['endDate'] != null
                        ? (m['endDate'] as Timestamp).toDate() : null,
    rules:            m['rules']        as String?,
    bannerUrl:        m['bannerUrl']    as String?,
    description:      m['description'] as String?,
    adminIds:         List<String>.from(m['adminIds'] as List? ?? []),
    hasGroups:        m['hasGroups']  as bool? ?? false,
    groupCount:       (m['groupCount'] as num?)?.toInt() ?? 0,
  );

  Tournament copyWith({
    TournamentStatus? status,
    bool? bracketGenerated,
    int? registeredTeams,
    int? playersPerTeam,
    List<String>? adminIds,
    String? description,
    bool? hasGroups,
    int? groupCount,
  }) => Tournament(
    id:               id,
    name:             name,
    sport:            sport,
    format:           format,
    status:           status           ?? this.status,
    startDate:        startDate,
    location:         location,
    maxTeams:         maxTeams,
    entryFee:         entryFee,
    serviceFee:       serviceFee,
    createdBy:        createdBy,
    createdByName:    createdByName,
    createdAt:        createdAt,
    scheduleMode:     scheduleMode,
    bracketGenerated: bracketGenerated ?? this.bracketGenerated,
    prizePool:        prizePool,
    registeredTeams:  registeredTeams  ?? this.registeredTeams,
    playersPerTeam:   playersPerTeam   ?? this.playersPerTeam,
    endDate:          endDate,
    rules:            rules,
    bannerUrl:        bannerUrl,
    description:      description      ?? this.description,
    adminIds:         adminIds         ?? this.adminIds,
    hasGroups:        hasGroups        ?? this.hasGroups,
    groupCount:       groupCount       ?? this.groupCount,
  );
}

// ── TournamentTeam ─────────────────────────────────────────────────────────

class TournamentTeam {
  final String       id;
  final String       tournamentId;
  final String       teamName;
  final String       captainName;
  final String       captainPhone;
  final List<String> players;
  final List<String> playerUserIds; // parallel to players; '' if unregistered
  final String       enrolledBy;
  final DateTime     enrolledAt;
  final bool         paymentConfirmed;
  final int          seed;
  // Round Robin stats (mutable for local updates)
  int played  = 0;
  int wins    = 0;
  int draws   = 0;
  int losses  = 0;
  int points  = 0;

  TournamentTeam({
    required this.id,
    required this.tournamentId,
    required this.teamName,
    required this.captainName,
    required this.captainPhone,
    required this.players,
    this.playerUserIds = const [],
    required this.enrolledBy,
    required this.enrolledAt,
    required this.paymentConfirmed,
    required this.seed,
    this.played  = 0,
    this.wins    = 0,
    this.draws   = 0,
    this.losses  = 0,
    this.points  = 0,
  });

  Map<String, dynamic> toMap() => {
    'tournamentId':     tournamentId,
    'teamName':         teamName,
    'captainName':      captainName,
    'captainPhone':     captainPhone,
    'players':          players,
    'playerUserIds':    playerUserIds,
    'enrolledBy':       enrolledBy,
    'enrolledAt':       Timestamp.fromDate(enrolledAt),
    'paymentConfirmed': paymentConfirmed,
    'seed':             seed,
    'played':           played,
    'wins':             wins,
    'draws':            draws,
    'losses':           losses,
    'points':           points,
  };

  static TournamentTeam fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static TournamentTeam fromMap(String id, Map<String, dynamic> m) {
    final t = TournamentTeam(
      id:               id,
      tournamentId:     m['tournamentId']     as String? ?? '',
      teamName:         m['teamName']         as String,
      captainName:      m['captainName']      as String,
      captainPhone:     m['captainPhone']     as String,
      players:          List<String>.from(m['players']       as List? ?? []),
      playerUserIds:    List<String>.from(m['playerUserIds'] as List? ?? []),
      enrolledBy:       m['enrolledBy'] as String? ?? '',
      enrolledAt:       m['enrolledAt'] != null
                          ? (m['enrolledAt'] as Timestamp).toDate()
                          : DateTime.now(),
      paymentConfirmed: m['paymentConfirmed'] as bool? ?? false,
      seed:             (m['seed']            as num?)?.toInt() ?? 0,
    );
    t.played  = (m['played']  as num?)?.toInt() ?? 0;
    t.wins    = (m['wins']    as num?)?.toInt() ?? 0;
    t.draws   = (m['draws']   as num?)?.toInt() ?? 0;
    t.losses  = (m['losses']  as num?)?.toInt() ?? 0;
    t.points  = (m['points']  as num?)?.toInt() ?? 0;
    return t;
  }
}

// ── TournamentMatch ────────────────────────────────────────────────────────

class TournamentMatch {
  final String      id;
  final String      tournamentId;
  final int         round;        // 1-indexed; higher = later stage
  final int         matchIndex;   // position within round (0-indexed)
  String?           teamAId;
  String?           teamBId;
  String?           teamAName;
  String?           teamBName;
  String?           winnerId;
  String?           winnerName;
  int?              scoreA;
  int?              scoreB;
  DateTime?         scheduledAt;
  final bool        isBye;
  TournamentMatchResult result;
  final String?     note;         // e.g. "Group A", "Semi-Final"
  final String?     groupId;      // non-null = group-stage match
  final String?     venueId;
  final String?     venueName;
  bool              isLive;
  final String?     liveStreamUrl;
  final Map<String, dynamic>? scorecardData;

  TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchIndex,
    this.teamAId,
    this.teamBId,
    this.teamAName,
    this.teamBName,
    this.winnerId,
    this.winnerName,
    this.scoreA,
    this.scoreB,
    this.scheduledAt,
    this.isBye = false,
    this.result = TournamentMatchResult.pending,
    this.note,
    this.groupId,
    this.venueId,
    this.venueName,
    this.isLive = false,
    this.liveStreamUrl,
    this.scorecardData,
  });

  bool get isPlayed => result != TournamentMatchResult.pending;
  bool get isTBD    => teamAId == null || teamBId == null;

  Map<String, dynamic> toMap() => {
    'tournamentId':   tournamentId,
    'round':          round,
    'matchIndex':     matchIndex,
    'teamAId':        teamAId,
    'teamBId':        teamBId,
    'teamAName':      teamAName,
    'teamBName':      teamBName,
    'winnerId':       winnerId,
    'winnerName':     winnerName,
    'scoreA':         scoreA,
    'scoreB':         scoreB,
    'scheduledAt':    scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
    'isBye':          isBye,
    'result':         result.name,
    if (note != null)    'note':    note,
    if (groupId != null) 'groupId': groupId,
    'venueId':        venueId,
    'venueName':      venueName,
    'isLive':         isLive,
    'liveStreamUrl':  liveStreamUrl,
    if (scorecardData != null) 'scorecardData': scorecardData,
  };

  static TournamentMatch fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static TournamentMatch fromMap(String id, Map<String, dynamic> m) => TournamentMatch(
    id:            id,
    tournamentId:  m['tournamentId']  as String? ?? '',
    round:         (m['round']        as num).toInt(),
    matchIndex:    (m['matchIndex']   as num).toInt(),
    teamAId:       m['teamAId']       as String?,
    teamBId:       m['teamBId']       as String?,
    teamAName:     m['teamAName']     as String?,
    teamBName:     m['teamBName']     as String?,
    winnerId:      m['winnerId']      as String?,
    winnerName:    m['winnerName']    as String?,
    scoreA:        (m['scoreA']       as num?)?.toInt(),
    scoreB:        (m['scoreB']       as num?)?.toInt(),
    scheduledAt:   m['scheduledAt'] != null
                     ? (m['scheduledAt'] as Timestamp).toDate()
                     : null,
    isBye:         m['isBye']         as bool? ?? false,
    result:        TournamentMatchResult.values.firstWhere(
                     (e) => e.name == m['result'],
                     orElse: () => TournamentMatchResult.pending),
    note:          m['note']          as String?,
    groupId:       m['groupId']       as String?,
    venueId:       m['venueId']       as String?,
    venueName:     m['venueName']     as String?,
    isLive:        m['isLive']        as bool? ?? false,
    liveStreamUrl: m['liveStreamUrl'] as String?,
    scorecardData: m['scorecardData'] != null
                     ? Map<String, dynamic>.from(m['scorecardData'] as Map)
                     : null,
  );
}

// ── TournamentRound (in-memory only) ──────────────────────────────────────

class TournamentRound {
  final int                   roundNumber;
  final String                label;
  final List<TournamentMatch> matches;

  const TournamentRound({
    required this.roundNumber,
    required this.label,
    required this.matches,
  });
}

// ── TournamentVenue ────────────────────────────────────────────────────────

class TournamentVenue {
  final String  id;
  final String  tournamentId;
  final String  name;
  final String  address;
  final String  city;
  final int     capacity;    // 0 = unknown
  final String  pitchType;   // e.g. Grass, Turf, Indoor, Hard Court
  final bool    hasFloodlights;
  final String? imageUrl;

  const TournamentVenue({
    required this.id,
    required this.tournamentId,
    required this.name,
    required this.address,
    required this.city,
    this.capacity = 0,
    this.pitchType = '',
    this.hasFloodlights = false,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
    'tournamentId':    tournamentId,
    'name':            name,
    'address':         address,
    'city':            city,
    'capacity':        capacity,
    'pitchType':       pitchType,
    'hasFloodlights':  hasFloodlights,
    'imageUrl':        imageUrl,
  };

  static TournamentVenue fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static TournamentVenue fromMap(String id, Map<String, dynamic> m) => TournamentVenue(
    id:             id,
    tournamentId:   m['tournamentId']   as String? ?? '',
    name:           m['name']           as String,
    address:        m['address']        as String? ?? '',
    city:           m['city']           as String? ?? '',
    capacity:       (m['capacity']      as num?)?.toInt() ?? 0,
    pitchType:      m['pitchType']      as String? ?? '',
    hasFloodlights: m['hasFloodlights'] as bool? ?? false,
    imageUrl:       m['imageUrl']       as String?,
  );
}

// ── TournamentAdmin ────────────────────────────────────────────────────────

class TournamentAdmin {
  final String               userId;
  final String               userName;
  final String               numericId;   // 6-digit string for display
  final List<AdminPermission> permissions;
  final DateTime             assignedAt;

  const TournamentAdmin({
    required this.userId,
    required this.userName,
    required this.numericId,
    required this.permissions,
    required this.assignedAt,
  });

  Map<String, dynamic> toMap() => {
    'userId':      userId,
    'userName':    userName,
    'numericId':   numericId,
    'permissions': permissions.map((p) => p.name).toList(),
    'assignedAt':  Timestamp.fromDate(assignedAt),
  };

  static TournamentAdmin fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.data() as Map<String, dynamic>);

  static TournamentAdmin fromMap(Map<String, dynamic> m) => TournamentAdmin(
    userId:      m['userId']    as String,
    userName:    m['userName']  as String? ?? '',
    numericId:   m['numericId'] as String? ?? '',
    permissions: (m['permissions'] as List? ?? [])
        .map((p) => AdminPermission.values.firstWhere(
              (e) => e.name == p,
              orElse: () => AdminPermission.updateScores,
            ))
        .toList(),
    assignedAt:  m['assignedAt'] != null
                   ? (m['assignedAt'] as Timestamp).toDate()
                   : DateTime.now(),
  );
}

// ── TournamentSquadPlayer ──────────────────────────────────────────────────

class TournamentSquadPlayer {
  final String  id;           // doc id
  final String  teamId;
  final String  tournamentId;
  final String  playerId;     // numericId as string (6-digit)
  final String  userId;       // Firebase Auth UID (may be empty if not registered)
  final String  playerName;
  final String  role;         // Batsman, Bowler, All-rounder, Goalkeeper, etc.
  final bool    isCaptain;
  final bool    isViceCaptain;
  final int     jerseyNumber; // 0 = not assigned

  const TournamentSquadPlayer({
    required this.id,
    required this.teamId,
    required this.tournamentId,
    required this.playerId,
    this.userId = '',
    required this.playerName,
    this.role = '',
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.jerseyNumber = 0,
  });

  Map<String, dynamic> toMap() => {
    'teamId':        teamId,
    'tournamentId':  tournamentId,
    'playerId':      playerId,
    'userId':        userId,
    'playerName':    playerName,
    'role':          role,
    'isCaptain':     isCaptain,
    'isViceCaptain': isViceCaptain,
    'jerseyNumber':  jerseyNumber,
  };

  static TournamentSquadPlayer fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static TournamentSquadPlayer fromMap(String id, Map<String, dynamic> m) => TournamentSquadPlayer(
    id:            id,
    teamId:        m['teamId']        as String? ?? '',
    tournamentId:  m['tournamentId']  as String? ?? '',
    playerId:      m['playerId']      as String? ?? '',
    userId:        m['userId']        as String? ?? '',
    playerName:    m['playerName']    as String? ?? '',
    role:          m['role']          as String? ?? '',
    isCaptain:     m['isCaptain']     as bool? ?? false,
    isViceCaptain: m['isViceCaptain'] as bool? ?? false,
    jerseyNumber:  (m['jerseyNumber'] as num?)?.toInt() ?? 0,
  );

  TournamentSquadPlayer copyWith({
    bool? isCaptain,
    bool? isViceCaptain,
    String? role,
    int? jerseyNumber,
  }) => TournamentSquadPlayer(
    id:            id,
    teamId:        teamId,
    tournamentId:  tournamentId,
    playerId:      playerId,
    userId:        userId,
    playerName:    playerName,
    role:          role          ?? this.role,
    isCaptain:     isCaptain     ?? this.isCaptain,
    isViceCaptain: isViceCaptain ?? this.isViceCaptain,
    jerseyNumber:  jerseyNumber  ?? this.jerseyNumber,
  );
}

// ── TournamentGroup ────────────────────────────────────────────────────────

class TournamentGroup {
  final String              id;
  final String              tournamentId;
  final String              name;       // "Group A", "Group B", …
  final List<String>        teamIds;
  final Map<String, String> teamNames;  // teamId → teamName
  final DateTime            createdAt;

  const TournamentGroup({
    required this.id,
    required this.tournamentId,
    required this.name,
    required this.teamIds,
    required this.teamNames,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'tournamentId': tournamentId,
    'name':         name,
    'teamIds':      teamIds,
    'teamNames':    teamNames,
    'createdAt':    Timestamp.fromDate(createdAt),
  };

  static TournamentGroup fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static TournamentGroup fromMap(String id, Map<String, dynamic> m) =>
      TournamentGroup(
        id:           id,
        tournamentId: m['tournamentId'] as String? ?? '',
        name:         m['name']         as String,
        teamIds:      List<String>.from(m['teamIds'] as List? ?? []),
        teamNames:    Map<String, String>.from(
          ((m['teamNames'] as Map?) ?? {})
              .map((k, v) => MapEntry(k.toString(), v.toString())),
        ),
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  TournamentGroup copyWith({
    List<String>?        teamIds,
    Map<String, String>? teamNames,
  }) =>
      TournamentGroup(
        id:           id,
        tournamentId: tournamentId,
        name:         name,
        teamIds:      teamIds    ?? this.teamIds,
        teamNames:    teamNames  ?? this.teamNames,
        createdAt:    createdAt,
      );
}
