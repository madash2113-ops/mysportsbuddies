import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum TournamentStatus  { open, ongoing, completed, cancelled }
enum TournamentFormat  { knockout, roundRobin, leagueKnockout }
enum ScheduleMode      { auto, manual }
enum TournamentMatchResult { pending, teamAWin, teamBWin, draw, bye }

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
    rules:            m['rules']     as String?,
    bannerUrl:        m['bannerUrl'] as String?,
  );

  Tournament copyWith({
    TournamentStatus? status,
    bool? bracketGenerated,
    int? registeredTeams,
    int? playersPerTeam,
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
      players:          List<String>.from(m['players'] as List? ?? []),
      enrolledBy:       m['enrolledBy']       as String? ?? '',
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
  });

  bool get isPlayed => result != TournamentMatchResult.pending;
  bool get isTBD    => teamAId == null || teamBId == null;

  Map<String, dynamic> toMap() => {
    'tournamentId': tournamentId,
    'round':        round,
    'matchIndex':   matchIndex,
    'teamAId':      teamAId,
    'teamBId':      teamBId,
    'teamAName':    teamAName,
    'teamBName':    teamBName,
    'winnerId':     winnerId,
    'winnerName':   winnerName,
    'scoreA':       scoreA,
    'scoreB':       scoreB,
    'scheduledAt':  scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
    'isBye':        isBye,
    'result':       result.name,
  };

  static TournamentMatch fromFirestore(DocumentSnapshot doc) =>
      fromMap(doc.id, doc.data() as Map<String, dynamic>);

  static TournamentMatch fromMap(String id, Map<String, dynamic> m) => TournamentMatch(
    id:           id,
    tournamentId: m['tournamentId'] as String? ?? '',
    round:        (m['round']       as num).toInt(),
    matchIndex:   (m['matchIndex']  as num).toInt(),
    teamAId:      m['teamAId']      as String?,
    teamBId:      m['teamBId']      as String?,
    teamAName:    m['teamAName']    as String?,
    teamBName:    m['teamBName']    as String?,
    winnerId:     m['winnerId']     as String?,
    winnerName:   m['winnerName']   as String?,
    scoreA:       (m['scoreA']      as num?)?.toInt(),
    scoreB:       (m['scoreB']      as num?)?.toInt(),
    scheduledAt:  m['scheduledAt'] != null
                    ? (m['scheduledAt'] as Timestamp).toDate()
                    : null,
    isBye:        m['isBye']        as bool? ?? false,
    result:       TournamentMatchResult.values.firstWhere(
                    (e) => e.name == m['result'],
                    orElse: () => TournamentMatchResult.pending),
  );
}

// ── TournamentRound (in-memory only) ──────────────────────────────────────

class TournamentRound {
  final int                  roundNumber;
  final String               label;
  final List<TournamentMatch> matches;

  const TournamentRound({
    required this.roundNumber,
    required this.label,
    required this.matches,
  });
}
