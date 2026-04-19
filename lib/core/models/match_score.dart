// ============================================================
// MATCH SCORE MODELS — International Standard Scoreboards
// ============================================================
// All state is Firebase Firestore-ready.
// ScoreboardService writes to Firestore and keeps in-memory mirror.

// ─── Sport enum (Top 50 World Sports) ───────────────────────
enum MatchSport {
  // ── Bat & Ball ──────────────────────────────────────────
  cricket,
  baseball,
  softball,

  // ── Football Family ─────────────────────────────────────
  football,       // Soccer
  futsal,         // Indoor football
  americanFootball,
  rugbyUnion,
  rugbyLeague,
  afl,            // Australian Rules Football
  handball,

  // ── Basketball Family ───────────────────────────────────
  basketball,
  netball,

  // ── Net / Rally ─────────────────────────────────────────
  badminton,
  tennis,
  tableTennis,
  volleyball,
  beachVolleyball,
  squash,
  padel,

  // ── Hockey ──────────────────────────────────────────────
  hockey,         // Field hockey
  iceHockey,

  // ── Aquatic ─────────────────────────────────────────────
  waterPolo,
  swimming,
  rowing,

  // ── Combat ──────────────────────────────────────────────
  boxing,
  mma,
  wrestling,
  fencing,

  // ── Stick & Target ──────────────────────────────────────
  golf,
  lacrosse,
  polo,
  curling,
  archery,
  shooting,
  darts,
  snooker,

  // ── Athletics & Speed ───────────────────────────────────
  athletics,      // Track & Field
  cycling,
  triathlon,
  formulaOne,

  // ── Gym & Physical ──────────────────────────────────────
  gymnastics,
  weightlifting,

  // ── E-Sports ────────────────────────────────────────────
  csgo,
  valorant,
  leagueOfLegends,
  dota2,
  fifaEsports,

  // ── Regional / Traditional ──────────────────────────────
  kabaddi,
  khoKho,

  other,
}

enum MatchStatus { live, paused, completed }

// ─── Pause-capable wall-clock timer ─────────────────────────
class GameTimer {
  int _accMs = 0;
  DateTime? _lastStart;

  bool get isRunning => _lastStart != null;

  Duration get elapsed {
    final base = Duration(milliseconds: _accMs);
    if (_lastStart == null) return base;
    return base + DateTime.now().difference(_lastStart!);
  }

  void start() {
    if (!isRunning) _lastStart = DateTime.now();
  }

  void pause() {
    if (isRunning) {
      _accMs += DateTime.now().difference(_lastStart!).inMilliseconds;
      _lastStart = null;
    }
  }

  void reset() {
    _accMs = 0;
    _lastStart = null;
  }

  Map<String, dynamic> toMap() => {
        'accMs': _accMs +
            (_lastStart != null
                ? DateTime.now().difference(_lastStart!).inMilliseconds
                : 0),
      };

  void restoreFrom(Map<String, dynamic> m) {
    _accMs = (m['accMs'] as num?)?.toInt() ?? 0;
    _lastStart = null; // always restored as paused
  }
}

// ============================================================
// LIVE MATCH — generic container
// ============================================================
class LiveMatch {
  final String id;
  final MatchSport sport;
  final String teamA;
  final String teamB;
  final String venue;
  final String format;
  MatchStatus status;
  final DateTime createdAt;

  /// Full player rosters entered during setup — used for dropdown selection
  /// during scoring (wickets, bowler changes, etc.)
  List<String> teamAPlayers;
  List<String> teamBPlayers;

  /// Parallel to teamAPlayers/teamBPlayers — Firestore userId for registered
  /// players, empty string for manually-entered names.
  List<String> teamAPlayerUserIds;
  List<String> teamBPlayerUserIds;

  /// The Firestore userId of the user who created this scoreboard.
  /// Used to filter "My Scorecards" to matches the user owns or played in.
  String createdByUserId;

  /// True when this scoreboard was started for a tournament match.
  /// Stats from tournament matches go to Career stats; others go to Regular.
  bool isTournamentMatch;

  /// Set when started from a tournament — lets the service sync results back.
  String? tournamentId;
  String? tournamentMatchId;
  String? teamAId;   // Firestore team ID for Team A
  String? teamBId;   // Firestore team ID for Team B

  // Sport-specific score objects — exactly one is non-null
  CricketScore? cricket;
  FootballScore? football;
  BasketballScore? basketball;
  RallyScore? rally;
  HockeyScore? hockey;
  CombatScore? combat;
  EsportsScore? esports;
  GenericScore? genericScore; // all other sports

  LiveMatch({
    required this.id,
    required this.sport,
    required this.teamA,
    required this.teamB,
    this.venue = '',
    this.format = '',
    this.status = MatchStatus.live,
    required this.createdAt,
    List<String>? teamAPlayers,
    List<String>? teamBPlayers,
    List<String>? teamAPlayerUserIds,
    List<String>? teamBPlayerUserIds,
    this.createdByUserId = '',
    this.isTournamentMatch = false,
    this.tournamentId,
    this.tournamentMatchId,
    this.teamAId,
    this.teamBId,
    this.cricket,
    this.football,
    this.basketball,
    this.rally,
    this.hockey,
    this.combat,
    this.esports,
    this.genericScore,
  })  : teamAPlayers = teamAPlayers ?? [],
        teamBPlayers = teamBPlayers ?? [],
        teamAPlayerUserIds = teamAPlayerUserIds ?? [],
        teamBPlayerUserIds = teamBPlayerUserIds ?? [];

  String get sportDisplayName => _sportNames[sport] ?? sport.name;

  static const _sportNames = {
    MatchSport.cricket: 'Cricket',
    MatchSport.baseball: 'Baseball',
    MatchSport.softball: 'Softball',
    MatchSport.football: 'Football',
    MatchSport.futsal: 'Futsal',
    MatchSport.americanFootball: 'American Football',
    MatchSport.rugbyUnion: 'Rugby Union',
    MatchSport.rugbyLeague: 'Rugby League',
    MatchSport.afl: 'AFL',
    MatchSport.handball: 'Handball',
    MatchSport.basketball: 'Basketball',
    MatchSport.netball: 'Netball',
    MatchSport.badminton: 'Badminton',
    MatchSport.tennis: 'Tennis',
    MatchSport.tableTennis: 'Table Tennis',
    MatchSport.volleyball: 'Volleyball',
    MatchSport.beachVolleyball: 'Beach Volleyball',
    MatchSport.squash: 'Squash',
    MatchSport.padel: 'Padel',
    MatchSport.hockey: 'Hockey',
    MatchSport.iceHockey: 'Ice Hockey',
    MatchSport.waterPolo: 'Water Polo',
    MatchSport.swimming: 'Swimming',
    MatchSport.rowing: 'Rowing',
    MatchSport.boxing: 'Boxing',
    MatchSport.mma: 'MMA',
    MatchSport.wrestling: 'Wrestling',
    MatchSport.fencing: 'Fencing',
    MatchSport.golf: 'Golf',
    MatchSport.lacrosse: 'Lacrosse',
    MatchSport.polo: 'Polo',
    MatchSport.curling: 'Curling',
    MatchSport.archery: 'Archery',
    MatchSport.shooting: 'Shooting',
    MatchSport.darts: 'Darts',
    MatchSport.snooker: 'Snooker',
    MatchSport.athletics: 'Athletics',
    MatchSport.cycling: 'Cycling',
    MatchSport.triathlon: 'Triathlon',
    MatchSport.formulaOne: 'Formula 1',
    MatchSport.gymnastics: 'Gymnastics',
    MatchSport.weightlifting: 'Weightlifting',
    MatchSport.csgo: 'CS:GO',
    MatchSport.valorant: 'Valorant',
    MatchSport.leagueOfLegends: 'League of Legends',
    MatchSport.dota2: 'Dota 2',
    MatchSport.fifaEsports: 'FIFA Esports',
    MatchSport.kabaddi: 'Kabaddi',
    MatchSport.khoKho: 'Kho Kho',
  };

  /// Scoring engine group — used by live_scoreboard_screen to pick the right widget
  SportEngine get engine => engineForSport(sport);

  String get scoreDisplay {
    switch (engine) {
      case SportEngine.cricket:
        if (cricket == null) return 'Yet to start';
        final inn = cricket!.currentInnings;
        return '${inn.runs}/${inn.wickets} (${inn.oversStr})';
      case SportEngine.football:
        return '${football?.teamAGoals ?? genericScore?.teamAScore ?? 0} – '
            '${football?.teamBGoals ?? genericScore?.teamBScore ?? 0}';
      case SportEngine.basketball:
        return '${basketball?.teamATotal ?? 0} – ${basketball?.teamBTotal ?? 0}';
      case SportEngine.rally:
        return '${rally?.setsWonA ?? 0} – ${rally?.setsWonB ?? 0} sets';
      case SportEngine.hockey:
        return '${hockey?.teamAGoals ?? 0} – ${hockey?.teamBGoals ?? 0}';
      case SportEngine.combat:
        return 'Rnd ${combat?.currentRound ?? 1} / ${combat?.totalRounds ?? 3}';
      case SportEngine.esports:
        return '${esports?.teamARounds ?? 0} – ${esports?.teamBRounds ?? 0}';
      case SportEngine.generic:
        return '${genericScore?.teamAScore ?? 0} – '
            '${genericScore?.teamBScore ?? 0}';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sport': sport.name,
        'teamA': teamA,
        'teamB': teamB,
        'venue': venue,
        'format': format,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'teamAPlayers': teamAPlayers,
        'teamBPlayers': teamBPlayers,
        'teamAPlayerUserIds': teamAPlayerUserIds,
        'teamBPlayerUserIds': teamBPlayerUserIds,
        'createdByUserId': createdByUserId,
        'isTournamentMatch': isTournamentMatch,
        'tournamentId': ?tournamentId,
        'tournamentMatchId': ?tournamentMatchId,
        'teamAId': ?teamAId,
        'teamBId': ?teamBId,
        if (cricket != null) 'cricket': cricket!.toFirestore(),
        if (football != null) 'football': football!.toMap(),
        if (basketball != null) 'basketball': basketball!.toMap(),
        if (rally != null) 'rally': rally!.toMap(),
        if (hockey != null) 'hockey': hockey!.toMap(),
        if (combat != null) 'combat': combat!.toMap(),
        if (esports != null) 'esports': esports!.toMap(),
        if (genericScore != null) 'genericScore': genericScore!.toMap(),
      };

  factory LiveMatch.fromMap(Map<String, dynamic> m) {
    final sport = MatchSport.values.firstWhere(
      (s) => s.name == m['sport'],
      orElse: () => MatchSport.other,
    );
    final status = MatchStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => MatchStatus.live,
    );
    return LiveMatch(
      id: m['id'] as String? ?? '',
      sport: sport,
      teamA: m['teamA'] as String? ?? '',
      teamB: m['teamB'] as String? ?? '',
      venue: m['venue'] as String? ?? '',
      format: m['format'] as String? ?? '',
      status: status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      teamAPlayers: List<String>.from(m['teamAPlayers'] as List? ?? []),
      teamBPlayers: List<String>.from(m['teamBPlayers'] as List? ?? []),
      teamAPlayerUserIds: List<String>.from(m['teamAPlayerUserIds'] as List? ?? []),
      teamBPlayerUserIds: List<String>.from(m['teamBPlayerUserIds'] as List? ?? []),
      createdByUserId: m['createdByUserId'] as String? ?? '',
      isTournamentMatch: m['isTournamentMatch'] as bool? ?? false,
      tournamentId: m['tournamentId'] as String?,
      tournamentMatchId: m['tournamentMatchId'] as String?,
      teamAId: m['teamAId'] as String?,
      teamBId: m['teamBId'] as String?,
      cricket: m['cricket'] != null
          ? CricketScore.fromFirestore(m['cricket'] as Map<String, dynamic>)
          : null,
      football: m['football'] != null
          ? FootballScore.fromMap(m['football'] as Map<String, dynamic>)
          : null,
      basketball: m['basketball'] != null
          ? BasketballScore.fromMap(m['basketball'] as Map<String, dynamic>)
          : null,
      rally: m['rally'] != null
          ? RallyScore.fromMap(m['rally'] as Map<String, dynamic>)
          : null,
      hockey: m['hockey'] != null
          ? HockeyScore.fromMap(m['hockey'] as Map<String, dynamic>)
          : null,
      combat: m['combat'] != null
          ? CombatScore.fromMap(m['combat'] as Map<String, dynamic>)
          : null,
      esports: m['esports'] != null
          ? EsportsScore.fromMap(m['esports'] as Map<String, dynamic>)
          : null,
      genericScore: m['genericScore'] != null
          ? GenericScore.fromMap(m['genericScore'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Determines which scoring UI to use
enum SportEngine { cricket, football, basketball, rally, hockey, combat, esports, generic }

/// Standalone helper — returns the scoring engine for any sport.
/// Used by both LiveMatch.engine and the setup/scoreboard screens.
SportEngine engineForSport(MatchSport sport) {
  switch (sport) {
    case MatchSport.cricket:
      return SportEngine.cricket;
    case MatchSport.football:
    case MatchSport.futsal:
    case MatchSport.americanFootball:
    case MatchSport.rugbyUnion:
    case MatchSport.rugbyLeague:
    case MatchSport.afl:
    case MatchSport.handball:
    case MatchSport.waterPolo:
    case MatchSport.lacrosse:
    case MatchSport.polo:
      return SportEngine.football;
    case MatchSport.basketball:
    case MatchSport.netball:
      return SportEngine.basketball;
    case MatchSport.badminton:
    case MatchSport.tableTennis:
    case MatchSport.volleyball:
    case MatchSport.beachVolleyball:
    case MatchSport.tennis:
    case MatchSport.squash:
    case MatchSport.padel:
      return SportEngine.rally;
    case MatchSport.hockey:
    case MatchSport.iceHockey:
      return SportEngine.hockey;
    case MatchSport.boxing:
    case MatchSport.mma:
    case MatchSport.wrestling:
    case MatchSport.fencing:
      return SportEngine.combat;
    case MatchSport.csgo:
    case MatchSport.valorant:
    case MatchSport.leagueOfLegends:
    case MatchSport.dota2:
    case MatchSport.fifaEsports:
      return SportEngine.esports;
    default:
      return SportEngine.generic;
  }
}

// ============================================================
// CRICKET
// ============================================================

class CricketBatsman {
  String name;
  String? userId;  // Firestore userId — null for manually-entered players
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  bool isOut = false;
  bool isStriker;
  String dismissal = '';
  int order;

  CricketBatsman({required this.name, required this.order, this.isStriker = false, this.userId});

  double get strikeRate => balls == 0 ? 0 : runs / balls * 100;
  String get srStr => balls == 0 ? '-' : strikeRate.toStringAsFixed(1);

  Map<String, dynamic> snapshot() => {
        'name': name,
        if (userId != null && userId!.isNotEmpty) 'userId': userId,
        'runs': runs, 'balls': balls, 'fours': fours,
        'sixes': sixes, 'isOut': isOut, 'isStriker': isStriker,
        'dismissal': dismissal, 'order': order,
      };

  static CricketBatsman fromSnapshot(Map<String, dynamic> s) =>
      CricketBatsman(
        name: s['name'] as String? ?? '',
        order: s['order'] as int? ?? 0,
        isStriker: s['isStriker'] as bool? ?? false,
        userId: s['userId'] as String?,
      )
        ..runs = s['runs'] as int? ?? 0
        ..balls = s['balls'] as int? ?? 0
        ..fours = s['fours'] as int? ?? 0
        ..sixes = s['sixes'] as int? ?? 0
        ..isOut = s['isOut'] as bool? ?? false
        ..dismissal = s['dismissal'] as String? ?? '';
}

class CricketBowler {
  String name;
  String? userId;  // Firestore userId — null for manually-entered players
  int completedOvers = 0;
  int balls = 0;
  int maidens = 0;
  int runs = 0;
  int wickets = 0;
  bool isCurrent;
  int _runsAtOverStart = 0;

  CricketBowler({required this.name, this.isCurrent = false, this.userId});

  double get economy {
    final total = completedOvers * 6 + balls;
    return total == 0 ? 0.0 : runs / total * 6;
  }

  String get ecoStr => economy.toStringAsFixed(2);
  String get figureStr => '$completedOvers-$maidens-$runs-$wickets';
  String get oversStr => '$completedOvers.$balls';

  void onOverComplete() {
    if (runs == _runsAtOverStart) maidens++;
    _runsAtOverStart = runs;
    completedOvers++;
    balls = 0;
    isCurrent = false;
  }

  Map<String, dynamic> snapshot() => {
        'name': name,
        if (userId != null && userId!.isNotEmpty) 'userId': userId,
        'completedOvers': completedOvers, 'balls': balls,
        'maidens': maidens, 'runs': runs, 'wickets': wickets,
        'isCurrent': isCurrent, 'runsAtOverStart': _runsAtOverStart,
      };

  static CricketBowler fromSnapshot(Map<String, dynamic> s) =>
      CricketBowler(
        name: s['name'] as String? ?? '',
        isCurrent: s['isCurrent'] as bool? ?? false,
        userId: s['userId'] as String?,
      )
        ..completedOvers = s['completedOvers'] as int? ?? 0
        ..balls = s['balls'] as int? ?? 0
        ..maidens = s['maidens'] as int? ?? 0
        ..runs = s['runs'] as int? ?? 0
        ..wickets = s['wickets'] as int? ?? 0
        .._runsAtOverStart = s['runsAtOverStart'] as int? ?? 0;
}

class FowEntry {
  final int wicketNum;
  final int runs;
  final String oversStr;
  final String batsmanName;
  const FowEntry({
    required this.wicketNum,
    required this.runs,
    required this.oversStr,
    required this.batsmanName,
  });

  Map<String, dynamic> toMap() => {
        'wicketNum': wicketNum,
        'runs': runs,
        'oversStr': oversStr,
        'batsmanName': batsmanName,
      };

  factory FowEntry.fromMap(Map<String, dynamic> m) => FowEntry(
        wicketNum: m['wicketNum'] as int? ?? 0,
        runs: m['runs'] as int? ?? 0,
        oversStr: m['oversStr'] as String? ?? '',
        batsmanName: m['batsmanName'] as String? ?? '',
      );
}

class CricketInnings {
  final int inningsNum;
  String battingTeam;
  String bowlingTeam;
  int runs = 0;
  int wickets = 0;
  int completedOvers = 0;
  int balls = 0;
  int extras = 0;
  int wides = 0;
  int noBalls = 0;
  int byes = 0;
  int legByes = 0;
  List<CricketBatsman> batsmen = [];
  List<CricketBowler> bowlers = [];
  List<FowEntry> fow = [];
  bool isComplete = false;
  int? target;
  final int totalOvers;
  final int playersPerSide;
  bool needsNewBowler = false;

  CricketInnings({
    required this.inningsNum,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.totalOvers,
    required this.playersPerSide,
  });

  String get oversStr => '$completedOvers.$balls';
  String get scoreStr => '$runs/$wickets';
  String get fullStr => '$runs/$wickets ($completedOvers.$balls ov)';

  CricketBatsman? get striker =>
      batsmen.where((b) => !b.isOut && b.isStriker).firstOrNull;
  CricketBatsman? get nonStriker =>
      batsmen.where((b) => !b.isOut && !b.isStriker).firstOrNull;
  CricketBowler? get currentBowler =>
      bowlers.where((b) => b.isCurrent).firstOrNull;

  double get currentRunRate {
    final totalBalls = completedOvers * 6 + balls;
    return totalBalls == 0 ? 0 : runs / totalBalls * 6;
  }

  double get requiredRunRate {
    if (target == null) return 0;
    final needed = target! - runs;
    final remaining = totalOvers * 6 - (completedOvers * 6 + balls);
    if (remaining <= 0) return 99.9;
    return needed / remaining * 6;
  }

  int get neededRuns => target != null ? (target! - runs).clamp(0, 9999) : 0;
  int get remainingBalls => totalOvers * 6 - (completedOvers * 6 + balls);
  int get remainingWickets => playersPerSide - 1 - wickets;

  bool checkEnd() {
    if (wickets >= playersPerSide - 1) return isComplete = true;
    if (totalOvers < 999 && completedOvers >= totalOvers) return isComplete = true;
    return false;
  }

  Map<String, dynamic> snapshot() => {
        'runs': runs, 'wickets': wickets, 'completedOvers': completedOvers,
        'balls': balls, 'extras': extras, 'wides': wides, 'noBalls': noBalls,
        'byes': byes, 'legByes': legByes, 'isComplete': isComplete,
        'needsNewBowler': needsNewBowler, 'target': target,
        'batsmen': batsmen.map((b) => b.snapshot()).toList(),
        'bowlers': bowlers.map((b) => b.snapshot()).toList(),
        'fow': fow
            .map((f) => {
                  'wicketNum': f.wicketNum,
                  'runs': f.runs,
                  'oversStr': f.oversStr,
                  'batsmanName': f.batsmanName,
                })
            .toList(),
      };

  void restoreSnapshot(Map<String, dynamic> s) {
    runs = s['runs'] as int? ?? 0;
    wickets = s['wickets'] as int? ?? 0;
    completedOvers = s['completedOvers'] as int? ?? 0;
    balls = s['balls'] as int? ?? 0;
    extras = s['extras'] as int? ?? 0;
    wides = s['wides'] as int? ?? 0;
    noBalls = s['noBalls'] as int? ?? 0;
    byes = s['byes'] as int? ?? 0;
    legByes = s['legByes'] as int? ?? 0;
    isComplete = s['isComplete'] as bool? ?? false;
    needsNewBowler = s['needsNewBowler'] as bool? ?? false;
    target = s['target'] as int?;
    batsmen = (s['batsmen'] as List)
        .map((b) => CricketBatsman.fromSnapshot(b as Map<String, dynamic>))
        .toList();
    bowlers = (s['bowlers'] as List)
        .map((b) => CricketBowler.fromSnapshot(b as Map<String, dynamic>))
        .toList();
    fow = (s['fow'] as List)
        .map((f) => FowEntry(
              wicketNum: f['wicketNum'],
              runs: f['runs'],
              oversStr: f['oversStr'],
              batsmanName: f['batsmanName'],
            ))
        .toList();
  }

  /// Full Firestore document — includes static config AND dynamic state.
  Map<String, dynamic> toFirestore() => {
        'inningsNum': inningsNum,
        'battingTeam': battingTeam,
        'bowlingTeam': bowlingTeam,
        'totalOvers': totalOvers,
        'playersPerSide': playersPerSide,
        ...snapshot(),
      };

  factory CricketInnings.fromFirestore(Map<String, dynamic> m) {
    final inn = CricketInnings(
      inningsNum: m['inningsNum'] as int? ?? 1,
      battingTeam: m['battingTeam'] as String? ?? '',
      bowlingTeam: m['bowlingTeam'] as String? ?? '',
      totalOvers: m['totalOvers'] as int? ?? 20,
      playersPerSide: m['playersPerSide'] as int? ?? 11,
    );
    inn.restoreSnapshot(m);
    return inn;
  }
}

class CricketScore {
  final String format;
  final int totalOvers;
  final int playersPerSide;
  final String teamA;
  final String teamB;
  final bool teamABatFirst;
  List<CricketInnings> innings = [];
  int _currentIdx = 0;
  bool isMatchOver = false;
  String matchResult = '';
  String? manOfMatch;

  CricketScore({
    required this.format,
    required this.totalOvers,
    required this.playersPerSide,
    required this.teamA,
    required this.teamB,
    required this.teamABatFirst,
  }) {
    innings.add(CricketInnings(
      inningsNum: 1,
      battingTeam: teamABatFirst ? teamA : teamB,
      bowlingTeam: teamABatFirst ? teamB : teamA,
      totalOvers: totalOvers,
      playersPerSide: playersPerSide,
    ));
  }

  /// Private constructor used by [fromFirestore] — does NOT auto-create innings.
  CricketScore._raw({
    required this.format,
    required this.totalOvers,
    required this.playersPerSide,
    required this.teamA,
    required this.teamB,
    required this.teamABatFirst,
  });

  CricketInnings get currentInnings => innings[_currentIdx];
  int get currentInningsNum => _currentIdx + 1;

  void startSecondInnings() {
    final firstRuns = innings[0].runs;
    innings.add(CricketInnings(
      inningsNum: 2,
      battingTeam: innings[0].bowlingTeam,
      bowlingTeam: innings[0].battingTeam,
      totalOvers: totalOvers,
      playersPerSide: playersPerSide,
    )..target = firstRuns + 1);
    _currentIdx = 1;
  }

  Map<String, dynamic> captureSnapshot() => {
        'currentIdx': _currentIdx,
        'isMatchOver': isMatchOver,
        'matchResult': matchResult,
        'manOfMatch': manOfMatch,
        'innings': innings.map((inn) => inn.snapshot()).toList(),
      };

  /// Full Firestore document — includes static config AND all dynamic state.
  Map<String, dynamic> toFirestore() => {
        'format': format,
        'totalOvers': totalOvers,
        'playersPerSide': playersPerSide,
        'teamA': teamA,
        'teamB': teamB,
        'teamABatFirst': teamABatFirst,
        'currentIdx': _currentIdx,
        'isMatchOver': isMatchOver,
        'matchResult': matchResult,
        'manOfMatch': manOfMatch,
        'innings': innings.map((inn) => inn.toFirestore()).toList(),
      };

  factory CricketScore.fromFirestore(Map<String, dynamic> m) {
    final score = CricketScore._raw(
      format: m['format'] as String? ?? '',
      totalOvers: m['totalOvers'] as int? ?? 20,
      playersPerSide: m['playersPerSide'] as int? ?? 11,
      teamA: m['teamA'] as String? ?? '',
      teamB: m['teamB'] as String? ?? '',
      teamABatFirst: m['teamABatFirst'] as bool? ?? true,
    );
    score._currentIdx = m['currentIdx'] as int? ?? 0;
    score.isMatchOver = m['isMatchOver'] as bool? ?? false;
    score.matchResult = m['matchResult'] as String? ?? '';
    score.manOfMatch = m['manOfMatch'] as String?;
    score.innings = (m['innings'] as List)
        .map((inn) => CricketInnings.fromFirestore(inn as Map<String, dynamic>))
        .toList();
    return score;
  }

  void restoreSnapshot(Map<String, dynamic> s) {
    _currentIdx = s['currentIdx'];
    isMatchOver = s['isMatchOver'];
    matchResult = s['matchResult'];
    manOfMatch = s['manOfMatch'] as String?;
    final snapInnings = s['innings'] as List;
    // Restore each innings
    for (var i = 0; i < innings.length && i < snapInnings.length; i++) {
      innings[i].restoreSnapshot(snapInnings[i] as Map<String, dynamic>);
    }
    // Drop innings that didn't exist at snapshot time (e.g. undo 2nd innings start)
    while (innings.length > snapInnings.length) {
      innings.removeLast();
    }
  }
}

// ============================================================
// FOOTBALL
// ============================================================

class FootballEvent {
  final String type;
  final String team;
  final String player;
  final int minute;
  const FootballEvent({
    required this.type,
    required this.team,
    required this.player,
    required this.minute,
  });

  String get emoji {
    switch (type) {
      case 'goal':        return '⚽';
      case 'own_goal':    return '⚽ (OG)';
      case 'yellow_card': return '🟡';
      case 'red_card':    return '🔴';
      case 'penalty':     return '⚽ (P)';
      case 'penalty_miss':return '❌ (P)';
      default:            return '•';
    }
  }

  Map<String, dynamic> toMap() => {
        'type': type, 'team': team, 'player': player, 'minute': minute,
      };

  factory FootballEvent.fromMap(Map<String, dynamic> m) => FootballEvent(
        type: m['type'] as String,
        team: m['team'] as String,
        player: m['player'] as String,
        minute: m['minute'] as int,
      );
}

class FootballScore {
  int teamAGoals = 0;
  int teamBGoals = 0;
  int teamAYellow = 0;
  int teamBYellow = 0;
  int teamARed = 0;
  int teamBRed = 0;
  List<FootballEvent> events = [];
  bool isHalfTime = false;
  bool isExtraTime = false;
  bool isFullTime = false;
  int htA = 0;
  int htB = 0;
  final GameTimer timer = GameTimer();
  final int matchDurationMin;

  FootballScore({this.matchDurationMin = 90});

  int get minute => timer.elapsed.inMinutes.clamp(0, matchDurationMin + 15);

  String get minuteStr {
    final m = minute;
    if (m > matchDurationMin) return '$matchDurationMin+${m - matchDurationMin}\'';
    return '$m\'';
  }

  Map<String, dynamic> toMap() => {
        'teamAGoals': teamAGoals, 'teamBGoals': teamBGoals,
        'teamAYellow': teamAYellow, 'teamBYellow': teamBYellow,
        'teamARed': teamARed, 'teamBRed': teamBRed,
        'isHalfTime': isHalfTime, 'isExtraTime': isExtraTime,
        'isFullTime': isFullTime, 'htA': htA, 'htB': htB,
        'matchDurationMin': matchDurationMin,
        'timer': timer.toMap(),
        'events': events.map((e) => e.toMap()).toList(),
      };

  factory FootballScore.fromMap(Map<String, dynamic> m) {
    final s = FootballScore(matchDurationMin: m['matchDurationMin'] as int? ?? 90);
    s.teamAGoals = m['teamAGoals'] as int? ?? 0;
    s.teamBGoals = m['teamBGoals'] as int? ?? 0;
    s.teamAYellow = m['teamAYellow'] as int? ?? 0;
    s.teamBYellow = m['teamBYellow'] as int? ?? 0;
    s.teamARed = m['teamARed'] as int? ?? 0;
    s.teamBRed = m['teamBRed'] as int? ?? 0;
    s.isHalfTime = m['isHalfTime'] as bool? ?? false;
    s.isExtraTime = m['isExtraTime'] as bool? ?? false;
    s.isFullTime = m['isFullTime'] as bool? ?? false;
    s.htA = m['htA'] as int? ?? 0;
    s.htB = m['htB'] as int? ?? 0;
    if (m['timer'] != null) s.timer.restoreFrom(m['timer'] as Map<String, dynamic>);
    s.events = (m['events'] as List? ?? [])
        .map((e) => FootballEvent.fromMap(e as Map<String, dynamic>))
        .toList();
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'teamAGoals': teamAGoals, 'teamBGoals': teamBGoals,
    'teamAYellow': teamAYellow, 'teamBYellow': teamBYellow,
    'teamARed': teamARed, 'teamBRed': teamBRed,
    'htA': htA, 'htB': htB,
    'events': events.map((e) => e.toMap()).toList(),
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    teamAGoals  = s['teamAGoals']  as int? ?? 0;
    teamBGoals  = s['teamBGoals']  as int? ?? 0;
    teamAYellow = s['teamAYellow'] as int? ?? 0;
    teamBYellow = s['teamBYellow'] as int? ?? 0;
    teamARed    = s['teamARed']    as int? ?? 0;
    teamBRed    = s['teamBRed']    as int? ?? 0;
    htA         = s['htA']         as int? ?? 0;
    htB         = s['htB']         as int? ?? 0;
    events = (s['events'] as List? ?? [])
        .map((e) => FootballEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================
// BASKETBALL
// ============================================================

class BasketballScore {
  List<int> teamAQtr = [0];
  List<int> teamBQtr = [0];
  int currentQuarter = 1;
  int teamAFouls = 0;
  int teamBFouls = 0;
  int teamATimeouts;
  int teamBTimeouts;
  bool isMatchOver = false;
  String matchResult = '';
  final GameTimer timer = GameTimer();
  final int quarterMinutes;

  BasketballScore({
    this.quarterMinutes = 10,
    this.teamATimeouts = 5,
    this.teamBTimeouts = 5,
  });

  int get teamATotal => teamAQtr.fold(0, (a, b) => a + b);
  int get teamBTotal => teamBQtr.fold(0, (a, b) => a + b);

  int get timeRemainingSecs {
    final qSecs = quarterMinutes * 60;
    return (qSecs - timer.elapsed.inSeconds).clamp(0, qSecs);
  }

  String get timerStr {
    final s = timeRemainingSecs;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String get quarterLabel {
    if (currentQuarter <= 4) return 'Q$currentQuarter';
    return 'OT${currentQuarter - 4}';
  }

  Map<String, dynamic> toMap() => {
        'teamAQtr': teamAQtr, 'teamBQtr': teamBQtr,
        'currentQuarter': currentQuarter,
        'teamAFouls': teamAFouls, 'teamBFouls': teamBFouls,
        'teamATimeouts': teamATimeouts, 'teamBTimeouts': teamBTimeouts,
        'isMatchOver': isMatchOver, 'matchResult': matchResult,
        'quarterMinutes': quarterMinutes,
        'timer': timer.toMap(),
      };

  factory BasketballScore.fromMap(Map<String, dynamic> m) {
    final s = BasketballScore(
      quarterMinutes: m['quarterMinutes'] as int? ?? 10,
      teamATimeouts: m['teamATimeouts'] as int? ?? 5,
      teamBTimeouts: m['teamBTimeouts'] as int? ?? 5,
    );
    s.teamAQtr = List<int>.from(m['teamAQtr'] as List? ?? [0]);
    s.teamBQtr = List<int>.from(m['teamBQtr'] as List? ?? [0]);
    s.currentQuarter = m['currentQuarter'] as int? ?? 1;
    s.teamAFouls = m['teamAFouls'] as int? ?? 0;
    s.teamBFouls = m['teamBFouls'] as int? ?? 0;
    s.isMatchOver = m['isMatchOver'] as bool? ?? false;
    s.matchResult = m['matchResult'] as String? ?? '';
    if (m['timer'] != null) s.timer.restoreFrom(m['timer'] as Map<String, dynamic>);
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'teamAQtr': List<int>.from(teamAQtr),
    'teamBQtr': List<int>.from(teamBQtr),
    'currentQuarter': currentQuarter,
    'teamAFouls': teamAFouls, 'teamBFouls': teamBFouls,
    'teamATimeouts': teamATimeouts, 'teamBTimeouts': teamBTimeouts,
    'isMatchOver': isMatchOver, 'matchResult': matchResult,
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    teamAQtr       = List<int>.from(s['teamAQtr'] as List? ?? [0]);
    teamBQtr       = List<int>.from(s['teamBQtr'] as List? ?? [0]);
    currentQuarter = s['currentQuarter'] as int?    ?? 1;
    teamAFouls     = s['teamAFouls']     as int?    ?? 0;
    teamBFouls     = s['teamBFouls']     as int?    ?? 0;
    teamATimeouts  = s['teamATimeouts']  as int?    ?? 5;
    teamBTimeouts  = s['teamBTimeouts']  as int?    ?? 5;
    isMatchOver    = s['isMatchOver']    as bool?   ?? false;
    matchResult    = s['matchResult']    as String? ?? '';
  }
}

// ============================================================
// RALLY SPORTS — Badminton, Table Tennis, Volleyball, Tennis,
//                Squash, Padel, Beach Volleyball, Netball
// ============================================================

class RallySet {
  int scoreA = 0;
  int scoreB = 0;
  bool isComplete = false;
  String winner = '';

  RallySet();

  Map<String, dynamic> toMap() => {
        'scoreA': scoreA, 'scoreB': scoreB,
        'isComplete': isComplete, 'winner': winner,
      };

  factory RallySet.fromMap(Map<String, dynamic> m) {
    final s = RallySet();
    s.scoreA = m['scoreA'] as int? ?? 0;
    s.scoreB = m['scoreB'] as int? ?? 0;
    s.isComplete = m['isComplete'] as bool? ?? false;
    s.winner = m['winner'] as String? ?? '';
    return s;
  }
}

class RallyScore {
  List<RallySet> sets = [RallySet()];
  int setsWonA = 0;
  int setsWonB = 0;
  bool isMatchOver = false;
  String matchWinner = '';
  bool serverIsA = true;

  // Tennis-specific
  int tennisPtsA = 0;
  int tennisPtsB = 0;
  int gamesWonA = 0;
  int gamesWonB = 0;

  final int pointsToWin;
  final int setsToWin;
  final bool winByTwo;
  final int? maxPointCap;
  final bool isTennis;
  final int? lastSetPoints;

  RallyScore({
    required this.pointsToWin,
    required this.setsToWin,
    this.winByTwo = true,
    this.maxPointCap,
    this.isTennis = false,
    this.lastSetPoints,
  });

  RallySet get currentSet => sets.last;
  int get currentSetNum => sets.length;
  bool get isFinalSet =>
      sets.length == setsToWin * 2 - 1 && lastSetPoints != null;
  int get effectiveTarget => isFinalSet ? lastSetPoints! : pointsToWin;

  /// Returns 'deuce', 'advantageA', 'advantageB', 'gamePointA', 'gamePointB', or null.
  String? get currentSetStatus {
    if (isTennis || currentSet.isComplete || isMatchOver) return null;
    final a = currentSet.scoreA;
    final b = currentSet.scoreB;
    final target = effectiveTarget;

    if (winByTwo && a >= target - 1 && b >= target - 1) {
      if (a == b) return 'deuce';
      return a > b ? 'advantageA' : 'advantageB';
    }

    // Game point: one more point wins the set for that team
    final aNextWins = (a + 1 >= target) && (!winByTwo || (a + 1) - b >= 2);
    final bNextWins = (b + 1 >= target) && (!winByTwo || (b + 1) - a >= 2);
    if (aNextWins) return 'gamePointA';
    if (bNextWins) return 'gamePointB';
    return null;
  }

  static const _tpts = ['0', '15', '30', '40'];

  String get tennisPtsAStr {
    if (tennisPtsA >= 3 && tennisPtsB >= 3) {
      if (tennisPtsA == tennisPtsB) return 'Deuce';
      return tennisPtsA > tennisPtsB ? 'Adv' : '40';
    }
    return _tpts[tennisPtsA.clamp(0, 3)];
  }

  String get tennisPtsBStr {
    if (tennisPtsA >= 3 && tennisPtsB >= 3) {
      if (tennisPtsA == tennisPtsB) return 'Deuce';
      return tennisPtsB > tennisPtsA ? 'Adv' : '40';
    }
    return _tpts[tennisPtsB.clamp(0, 3)];
  }

  Map<String, dynamic> toMap() => {
        'pointsToWin': pointsToWin, 'setsToWin': setsToWin,
        'winByTwo': winByTwo, 'maxPointCap': maxPointCap,
        'isTennis': isTennis, 'lastSetPoints': lastSetPoints,
        'setsWonA': setsWonA, 'setsWonB': setsWonB,
        'isMatchOver': isMatchOver, 'matchWinner': matchWinner,
        'serverIsA': serverIsA,
        'tennisPtsA': tennisPtsA, 'tennisPtsB': tennisPtsB,
        'gamesWonA': gamesWonA, 'gamesWonB': gamesWonB,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory RallyScore.fromMap(Map<String, dynamic> m) {
    final s = RallyScore(
      pointsToWin: m['pointsToWin'] as int? ?? 21,
      setsToWin: m['setsToWin'] as int? ?? 3,
      winByTwo: m['winByTwo'] as bool? ?? true,
      maxPointCap: m['maxPointCap'] as int?,
      isTennis: m['isTennis'] as bool? ?? false,
      lastSetPoints: m['lastSetPoints'] as int?,
    );
    s.setsWonA = m['setsWonA'] as int? ?? 0;
    s.setsWonB = m['setsWonB'] as int? ?? 0;
    s.isMatchOver = m['isMatchOver'] as bool? ?? false;
    s.matchWinner = m['matchWinner'] as String? ?? '';
    s.serverIsA = m['serverIsA'] as bool? ?? true;
    s.tennisPtsA = m['tennisPtsA'] as int? ?? 0;
    s.tennisPtsB = m['tennisPtsB'] as int? ?? 0;
    s.gamesWonA = m['gamesWonA'] as int? ?? 0;
    s.gamesWonB = m['gamesWonB'] as int? ?? 0;
    final rawSets = m['sets'] as List?;
    if (rawSets != null && rawSets.isNotEmpty) {
      s.sets = rawSets
          .map((st) => RallySet.fromMap(st as Map<String, dynamic>))
          .toList();
    }
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'setsWonA': setsWonA, 'setsWonB': setsWonB,
    'isMatchOver': isMatchOver, 'matchWinner': matchWinner,
    'serverIsA': serverIsA,
    'tennisPtsA': tennisPtsA, 'tennisPtsB': tennisPtsB,
    'gamesWonA': gamesWonA, 'gamesWonB': gamesWonB,
    'sets': sets.map((s) => s.toMap()).toList(),
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    setsWonA    = s['setsWonA']    as int?    ?? 0;
    setsWonB    = s['setsWonB']    as int?    ?? 0;
    isMatchOver = s['isMatchOver'] as bool?   ?? false;
    matchWinner = s['matchWinner'] as String? ?? '';
    serverIsA   = s['serverIsA']   as bool?   ?? true;
    tennisPtsA  = s['tennisPtsA']  as int?    ?? 0;
    tennisPtsB  = s['tennisPtsB']  as int?    ?? 0;
    gamesWonA   = s['gamesWonA']   as int?    ?? 0;
    gamesWonB   = s['gamesWonB']   as int?    ?? 0;
    final rawSets = s['sets'] as List?;
    if (rawSets != null) {
      sets = rawSets
          .map((st) => RallySet.fromMap(st as Map<String, dynamic>))
          .toList();
    }
  }
}

// ============================================================
// HOCKEY (Field / Ice)
// ============================================================

class HockeyEvent {
  final String type;
  final String team;
  final String player;
  final int quarter;
  final String timeStr;
  const HockeyEvent({
    required this.type,
    required this.team,
    required this.player,
    required this.quarter,
    required this.timeStr,
  });

  Map<String, dynamic> toMap() => {
        'type': type, 'team': team, 'player': player,
        'quarter': quarter, 'timeStr': timeStr,
      };

  factory HockeyEvent.fromMap(Map<String, dynamic> m) => HockeyEvent(
        type: m['type'] as String,
        team: m['team'] as String,
        player: m['player'] as String,
        quarter: m['quarter'] as int,
        timeStr: m['timeStr'] as String,
      );
}

class HockeyScore {
  int teamAGoals = 0;
  int teamBGoals = 0;
  List<int> teamAQtrGoals = [0, 0, 0, 0];
  List<int> teamBQtrGoals = [0, 0, 0, 0];
  int currentQuarter = 1;
  int teamAPenaltyCorners = 0;
  int teamBPenaltyCorners = 0;
  int teamAGreenCards = 0;
  int teamBGreenCards = 0;
  int teamAYellowCards = 0;
  int teamBYellowCards = 0;
  int teamARedCards = 0;
  int teamBRedCards = 0;
  List<HockeyEvent> events = [];
  bool isMatchOver = false;
  final GameTimer timer = GameTimer();
  final int quarterMinutes;
  final int totalPeriods; // 4 for field, 3 for ice

  HockeyScore({this.quarterMinutes = 15, this.totalPeriods = 4});

  int get timeRemainingSecs {
    final qSecs = quarterMinutes * 60;
    return (qSecs - timer.elapsed.inSeconds).clamp(0, qSecs);
  }

  String get timerStr {
    final s = timeRemainingSecs;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String get periodLabel => totalPeriods == 3 ? 'P$currentQuarter' : 'Q$currentQuarter';

  Map<String, dynamic> toMap() => {
        'teamAGoals': teamAGoals, 'teamBGoals': teamBGoals,
        'teamAQtrGoals': teamAQtrGoals, 'teamBQtrGoals': teamBQtrGoals,
        'currentQuarter': currentQuarter,
        'teamAPenaltyCorners': teamAPenaltyCorners,
        'teamBPenaltyCorners': teamBPenaltyCorners,
        'teamAGreenCards': teamAGreenCards, 'teamBGreenCards': teamBGreenCards,
        'teamAYellowCards': teamAYellowCards, 'teamBYellowCards': teamBYellowCards,
        'teamARedCards': teamARedCards, 'teamBRedCards': teamBRedCards,
        'isMatchOver': isMatchOver,
        'quarterMinutes': quarterMinutes, 'totalPeriods': totalPeriods,
        'timer': timer.toMap(),
        'events': events.map((e) => e.toMap()).toList(),
      };

  factory HockeyScore.fromMap(Map<String, dynamic> m) {
    final s = HockeyScore(
      quarterMinutes: m['quarterMinutes'] as int? ?? 15,
      totalPeriods: m['totalPeriods'] as int? ?? 4,
    );
    s.teamAGoals = m['teamAGoals'] as int? ?? 0;
    s.teamBGoals = m['teamBGoals'] as int? ?? 0;
    s.teamAQtrGoals = List<int>.from(m['teamAQtrGoals'] as List? ?? [0, 0, 0, 0]);
    s.teamBQtrGoals = List<int>.from(m['teamBQtrGoals'] as List? ?? [0, 0, 0, 0]);
    s.currentQuarter = m['currentQuarter'] as int? ?? 1;
    s.teamAPenaltyCorners = m['teamAPenaltyCorners'] as int? ?? 0;
    s.teamBPenaltyCorners = m['teamBPenaltyCorners'] as int? ?? 0;
    s.teamAGreenCards = m['teamAGreenCards'] as int? ?? 0;
    s.teamBGreenCards = m['teamBGreenCards'] as int? ?? 0;
    s.teamAYellowCards = m['teamAYellowCards'] as int? ?? 0;
    s.teamBYellowCards = m['teamBYellowCards'] as int? ?? 0;
    s.teamARedCards = m['teamARedCards'] as int? ?? 0;
    s.teamBRedCards = m['teamBRedCards'] as int? ?? 0;
    s.isMatchOver = m['isMatchOver'] as bool? ?? false;
    if (m['timer'] != null) s.timer.restoreFrom(m['timer'] as Map<String, dynamic>);
    s.events = (m['events'] as List? ?? [])
        .map((e) => HockeyEvent.fromMap(e as Map<String, dynamic>))
        .toList();
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'teamAGoals': teamAGoals, 'teamBGoals': teamBGoals,
    'teamAQtrGoals': List<int>.from(teamAQtrGoals),
    'teamBQtrGoals': List<int>.from(teamBQtrGoals),
    'currentQuarter': currentQuarter,
    'teamAPenaltyCorners': teamAPenaltyCorners,
    'teamBPenaltyCorners': teamBPenaltyCorners,
    'teamAGreenCards': teamAGreenCards, 'teamBGreenCards': teamBGreenCards,
    'teamAYellowCards': teamAYellowCards, 'teamBYellowCards': teamBYellowCards,
    'teamARedCards': teamARedCards, 'teamBRedCards': teamBRedCards,
    'isMatchOver': isMatchOver,
    'events': events.map((e) => e.toMap()).toList(),
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    teamAGoals           = s['teamAGoals']           as int? ?? 0;
    teamBGoals           = s['teamBGoals']           as int? ?? 0;
    teamAQtrGoals        = List<int>.from(s['teamAQtrGoals'] as List? ?? [0, 0, 0, 0]);
    teamBQtrGoals        = List<int>.from(s['teamBQtrGoals'] as List? ?? [0, 0, 0, 0]);
    currentQuarter       = s['currentQuarter']       as int? ?? 1;
    teamAPenaltyCorners  = s['teamAPenaltyCorners']  as int? ?? 0;
    teamBPenaltyCorners  = s['teamBPenaltyCorners']  as int? ?? 0;
    teamAGreenCards      = s['teamAGreenCards']      as int? ?? 0;
    teamBGreenCards      = s['teamBGreenCards']      as int? ?? 0;
    teamAYellowCards     = s['teamAYellowCards']     as int? ?? 0;
    teamBYellowCards     = s['teamBYellowCards']     as int? ?? 0;
    teamARedCards        = s['teamARedCards']        as int? ?? 0;
    teamBRedCards        = s['teamBRedCards']        as int? ?? 0;
    isMatchOver          = s['isMatchOver']          as bool? ?? false;
    events = (s['events'] as List? ?? [])
        .map((e) => HockeyEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================
// BOXING / COMBAT SPORTS
// ============================================================

class CombatRound {
  final int roundNum;
  int knockdownsA = 0;
  int knockdownsB = 0;
  int? judge1A, judge1B;
  int? judge2A, judge2B;
  int? judge3A, judge3B;

  CombatRound({required this.roundNum});

  int get totalA => (judge1A ?? 0) + (judge2A ?? 0) + (judge3A ?? 0);
  int get totalB => (judge1B ?? 0) + (judge2B ?? 0) + (judge3B ?? 0);

  Map<String, dynamic> toMap() => {
        'roundNum': roundNum,
        'knockdownsA': knockdownsA, 'knockdownsB': knockdownsB,
        'judge1A': judge1A, 'judge1B': judge1B,
        'judge2A': judge2A, 'judge2B': judge2B,
        'judge3A': judge3A, 'judge3B': judge3B,
      };

  factory CombatRound.fromMap(Map<String, dynamic> m) {
    final r = CombatRound(roundNum: m['roundNum'] as int? ?? 1);
    r.knockdownsA = m['knockdownsA'] as int? ?? 0;
    r.knockdownsB = m['knockdownsB'] as int? ?? 0;
    r.judge1A = m['judge1A'] as int?;
    r.judge1B = m['judge1B'] as int?;
    r.judge2A = m['judge2A'] as int?;
    r.judge2B = m['judge2B'] as int?;
    r.judge3A = m['judge3A'] as int?;
    r.judge3B = m['judge3B'] as int?;
    return r;
  }
}

class CombatScore {
  int currentRound = 1;
  List<CombatRound> rounds = [CombatRound(roundNum: 1)];
  bool isMatchOver = false;
  String result = '';
  String winner = '';
  final int totalRounds;
  final int roundDurationMin;
  final GameTimer timer = GameTimer();

  CombatScore({required this.totalRounds, required this.roundDurationMin});

  CombatRound get currentRoundData => rounds[currentRound - 1];

  int get timeRemainingSecs {
    final rSecs = roundDurationMin * 60;
    return (rSecs - timer.elapsed.inSeconds).clamp(0, rSecs);
  }

  String get timerStr {
    final s = timeRemainingSecs;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  int get totalKnockdownsA => rounds.fold(0, (a, r) => a + r.knockdownsA);
  int get totalKnockdownsB => rounds.fold(0, (a, r) => a + r.knockdownsB);
  int get cardTotalA => rounds.fold(0, (a, r) => a + r.totalA);
  int get cardTotalB => rounds.fold(0, (a, r) => a + r.totalB);

  Map<String, dynamic> toMap() => {
        'totalRounds': totalRounds, 'roundDurationMin': roundDurationMin,
        'currentRound': currentRound,
        'isMatchOver': isMatchOver, 'result': result, 'winner': winner,
        'timer': timer.toMap(),
        'rounds': rounds.map((r) => r.toMap()).toList(),
      };

  factory CombatScore.fromMap(Map<String, dynamic> m) {
    final s = CombatScore(
      totalRounds: m['totalRounds'] as int? ?? 12,
      roundDurationMin: m['roundDurationMin'] as int? ?? 3,
    );
    s.currentRound = m['currentRound'] as int? ?? 1;
    s.isMatchOver = m['isMatchOver'] as bool? ?? false;
    s.result = m['result'] as String? ?? '';
    s.winner = m['winner'] as String? ?? '';
    if (m['timer'] != null) s.timer.restoreFrom(m['timer'] as Map<String, dynamic>);
    final rawRounds = m['rounds'] as List?;
    if (rawRounds != null && rawRounds.isNotEmpty) {
      s.rounds = rawRounds
          .map((r) => CombatRound.fromMap(r as Map<String, dynamic>))
          .toList();
    }
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'currentRound': currentRound,
    'isMatchOver': isMatchOver, 'result': result, 'winner': winner,
    'rounds': rounds.map((r) => r.toMap()).toList(),
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    currentRound = s['currentRound'] as int?    ?? 1;
    isMatchOver  = s['isMatchOver']  as bool?   ?? false;
    result       = s['result']       as String? ?? '';
    winner       = s['winner']       as String? ?? '';
    final rawRounds = s['rounds'] as List?;
    if (rawRounds != null) {
      rounds = rawRounds
          .map((r) => CombatRound.fromMap(r as Map<String, dynamic>))
          .toList();
    }
  }
}

// ============================================================
// E-SPORTS (CS:GO, Valorant, LoL, Dota 2, FIFA)
// ============================================================

class EsportsScore {
  int teamARounds = 0;
  int teamBRounds = 0;
  int currentRound = 1;
  bool isHalfTime = false;
  bool isMatchOver = false;
  String matchWinner = '';
  List<String> roundHistory = [];
  final int roundsToWin;
  final int maxRounds;

  EsportsScore({this.roundsToWin = 13, this.maxRounds = 24});

  Map<String, dynamic> toMap() => {
        'roundsToWin': roundsToWin, 'maxRounds': maxRounds,
        'teamARounds': teamARounds, 'teamBRounds': teamBRounds,
        'currentRound': currentRound,
        'isHalfTime': isHalfTime, 'isMatchOver': isMatchOver,
        'matchWinner': matchWinner, 'roundHistory': roundHistory,
      };

  factory EsportsScore.fromMap(Map<String, dynamic> m) {
    final s = EsportsScore(
      roundsToWin: m['roundsToWin'] as int? ?? 13,
      maxRounds: m['maxRounds'] as int? ?? 24,
    );
    s.teamARounds = m['teamARounds'] as int? ?? 0;
    s.teamBRounds = m['teamBRounds'] as int? ?? 0;
    s.currentRound = m['currentRound'] as int? ?? 1;
    s.isHalfTime = m['isHalfTime'] as bool? ?? false;
    s.isMatchOver = m['isMatchOver'] as bool? ?? false;
    s.matchWinner = m['matchWinner'] as String? ?? '';
    s.roundHistory = List<String>.from(m['roundHistory'] as List? ?? []);
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'teamARounds': teamARounds, 'teamBRounds': teamBRounds,
    'currentRound': currentRound,
    'isHalfTime': isHalfTime, 'isMatchOver': isMatchOver,
    'matchWinner': matchWinner,
    'roundHistory': List<String>.from(roundHistory),
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    teamARounds  = s['teamARounds']  as int?    ?? 0;
    teamBRounds  = s['teamBRounds']  as int?    ?? 0;
    currentRound = s['currentRound'] as int?    ?? 1;
    isHalfTime   = s['isHalfTime']   as bool?   ?? false;
    isMatchOver  = s['isMatchOver']  as bool?   ?? false;
    matchWinner  = s['matchWinner']  as String? ?? '';
    roundHistory = List<String>.from(s['roundHistory'] as List? ?? []);
  }
}

// ============================================================
// GENERIC SCORE — used for all remaining sports
// ============================================================

class GenericEvent {
  final String team;  // 'A' or 'B'
  final int pts;
  final String note;
  final String timeStr;
  const GenericEvent({
    required this.team,
    required this.pts,
    required this.note,
    required this.timeStr,
  });

  Map<String, dynamic> toMap() => {
        'team': team, 'pts': pts, 'note': note, 'timeStr': timeStr,
      };

  factory GenericEvent.fromMap(Map<String, dynamic> m) => GenericEvent(
        team: m['team'] as String,
        pts: m['pts'] as int,
        note: m['note'] as String,
        timeStr: m['timeStr'] as String,
      );
}

class GenericScore {
  int teamAScore = 0;
  int teamBScore = 0;
  List<GenericEvent> events = [];
  bool isMatchOver = false;
  String winner = '';  // 'A', 'B', or 'Draw'
  String currentPeriod = '1';
  final GameTimer timer = GameTimer();
  /// First to reach this score wins. 0 = no automatic limit (manual end only).
  final int pointsToWin;

  GenericScore({this.pointsToWin = 0});

  /// Returns 'deuce', 'matchPointA', 'matchPointB', or null.
  String? get currentStatus {
    if (pointsToWin <= 0 || isMatchOver) return null;
    final a      = teamAScore;
    final b      = teamBScore;
    final target = pointsToWin;
    final inDeuce = a >= target - 1 && b >= target - 1;
    if (!inDeuce) {
      if (a + 1 >= target) return 'matchPointA';
      if (b + 1 >= target) return 'matchPointB';
      return null;
    }
    if (a == b) return 'deuce';
    return a > b ? 'matchPointA' : 'matchPointB';
  }

  Map<String, dynamic> toMap() => {
        'teamAScore': teamAScore, 'teamBScore': teamBScore,
        'isMatchOver': isMatchOver, 'winner': winner,
        'currentPeriod': currentPeriod,
        'pointsToWin': pointsToWin,
        'timer': timer.toMap(),
        'events': events.map((e) => e.toMap()).toList(),
      };

  factory GenericScore.fromMap(Map<String, dynamic> m) {
    final s = GenericScore(pointsToWin: m['pointsToWin'] as int? ?? 0);
    s.teamAScore = m['teamAScore'] as int? ?? 0;
    s.teamBScore = m['teamBScore'] as int? ?? 0;
    s.isMatchOver = m['isMatchOver'] as bool? ?? false;
    s.winner = m['winner'] as String? ?? '';
    s.currentPeriod = m['currentPeriod'] as String? ?? '1';
    if (m['timer'] != null) s.timer.restoreFrom(m['timer'] as Map<String, dynamic>);
    s.events = (m['events'] as List? ?? [])
        .map((e) => GenericEvent.fromMap(e as Map<String, dynamic>))
        .toList();
    return s;
  }

  Map<String, dynamic> captureSnapshot() => {
    'teamAScore': teamAScore, 'teamBScore': teamBScore,
    'isMatchOver': isMatchOver, 'winner': winner,
    'currentPeriod': currentPeriod,
    'pointsToWin': pointsToWin,
    'events': events.map((e) => e.toMap()).toList(),
  };

  void restoreSnapshot(Map<String, dynamic> s) {
    teamAScore    = s['teamAScore']    as int?    ?? 0;
    teamBScore    = s['teamBScore']    as int?    ?? 0;
    isMatchOver   = s['isMatchOver']   as bool?   ?? false;
    winner        = s['winner']        as String? ?? '';
    currentPeriod = s['currentPeriod'] as String? ?? '1';
    events = (s['events'] as List? ?? [])
        .map((e) => GenericEvent.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

// ============================================================
// UTILITY — convert sport name string → MatchSport enum
// ============================================================
MatchSport sportFromName(String name) {
  switch (name.toLowerCase().trim()) {
    case 'cricket':           return MatchSport.cricket;
    case 'baseball':          return MatchSport.baseball;
    case 'softball':          return MatchSport.softball;
    case 'football':
    case 'soccer':            return MatchSport.football;
    case 'futsal':            return MatchSport.futsal;
    case 'american football': return MatchSport.americanFootball;
    case 'rugby union':
    case 'rugby':             return MatchSport.rugbyUnion;
    case 'rugby league':      return MatchSport.rugbyLeague;
    case 'afl':
    case 'australian football':
    case 'aussie rules':      return MatchSport.afl;
    case 'handball':          return MatchSport.handball;
    case 'basketball':        return MatchSport.basketball;
    case 'netball':           return MatchSport.netball;
    case 'badminton':         return MatchSport.badminton;
    case 'tennis':            return MatchSport.tennis;
    case 'table tennis':
    case 'ping pong':         return MatchSport.tableTennis;
    case 'volleyball':        return MatchSport.volleyball;
    case 'beach volleyball':  return MatchSport.beachVolleyball;
    case 'squash':            return MatchSport.squash;
    case 'padel':             return MatchSport.padel;
    case 'hockey':
    case 'field hockey':      return MatchSport.hockey;
    case 'ice hockey':        return MatchSport.iceHockey;
    case 'water polo':        return MatchSport.waterPolo;
    case 'swimming':          return MatchSport.swimming;
    case 'rowing':            return MatchSport.rowing;
    case 'boxing':            return MatchSport.boxing;
    case 'mma':               return MatchSport.mma;
    case 'wrestling':         return MatchSport.wrestling;
    case 'fencing':           return MatchSport.fencing;
    case 'golf':              return MatchSport.golf;
    case 'lacrosse':          return MatchSport.lacrosse;
    case 'polo':              return MatchSport.polo;
    case 'curling':           return MatchSport.curling;
    case 'archery':           return MatchSport.archery;
    case 'shooting':          return MatchSport.shooting;
    case 'darts':             return MatchSport.darts;
    case 'snooker':
    case 'billiards':         return MatchSport.snooker;
    case 'athletics':
    case 'track and field':   return MatchSport.athletics;
    case 'cycling':           return MatchSport.cycling;
    case 'triathlon':         return MatchSport.triathlon;
    case 'formula 1':
    case 'formula one':
    case 'f1':                return MatchSport.formulaOne;
    case 'gymnastics':        return MatchSport.gymnastics;
    case 'weightlifting':     return MatchSport.weightlifting;
    case 'cs:go':
    case 'csgo':              return MatchSport.csgo;
    case 'valorant':          return MatchSport.valorant;
    case 'league of legends':
    case 'lol':               return MatchSport.leagueOfLegends;
    case 'dota 2':
    case 'dota2':             return MatchSport.dota2;
    case 'fifa esports':
    case 'fifa':              return MatchSport.fifaEsports;
    case 'kabaddi':           return MatchSport.kabaddi;
    case 'kho kho':           return MatchSport.khoKho;
    default:                  return MatchSport.other;
  }
}
