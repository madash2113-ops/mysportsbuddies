import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/match_score.dart';
import '../../core/models/player_entry.dart';
import '../../core/search/player_search_service.dart';
import '../../core/models/tournament.dart';
import '../../services/scoreboard_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../tournaments/enroll_team_sheet.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg = Color(0xFF080808);
const _card = Color(0xFF111111);
const _panel = Color(0xFF0E0E0E);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _orange = Color(0xFFFF9F0A);
const _kActiveScoringKey = 'active_tournament_scoring';
const double _kWebBracketCardH = 164;
const double _kWebBracketGap = 18;
const double _kWebBracketConnectorW = 44;

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

int _defaultRallyPts(MatchSport sport) {
  if (sport == MatchSport.tableTennis) return 11;
  return 21;
}

int _normalizeBestOfValue(int value) {
  if (value <= 0) return 3;
  if (value.isEven) return value + 1;
  return value;
}

int _uiSetsToWinFromStoredBestOf(int value) {
  final normalized = _normalizeBestOfValue(value);
  return ((normalized + 1) / 2).floor().clamp(1, 99);
}

int _storedBestOfFromUiSetsToWin(int value) {
  final safe = value < 1 ? 1 : value;
  return _normalizeBestOfValue((safe * 2) - 1);
}

String? _roundConfigKeyForMatch(Tournament tournament, TournamentMatch match) {
  if (tournament.sameScoreAllRounds) return null;
  final rounds =
      TournamentService()
          .matchesFor(tournament.id)
          .map((m) => m.round)
          .toSet()
          .toList()
        ..sort();
  final roundIndex = rounds.indexOf(match.round);
  if (roundIndex == -1) return null;

  final fromEnd = rounds.length - roundIndex;
  switch (fromEnd) {
    case 3:
      return 'quarterFinal';
    case 2:
      return 'semiFinal';
    case 1:
      return 'final';
    default:
      return null;
  }
}

Map<String, dynamic> _effectiveScoreConfigForMatch(
  Tournament tournament,
  TournamentMatch match,
) {
  final config = <String, dynamic>{
    'bestOf': tournament.bestOf,
    'pointsToWin': tournament.pointsToWin,
    'scoringType': tournament.scoringType.name,
  };
  if (tournament.sameScoreAllRounds) return config;

  final roundKey = _roundConfigKeyForMatch(tournament, match);
  if (roundKey == null) return config;
  final override = (tournament.roundScoringConfig?[roundKey] as Map?)
      ?.cast<String, dynamic>();
  if (override == null) return config;
  return {...config, ...override};
}

int _effectiveBestOfForMatch(Tournament tournament, TournamentMatch match) {
  final config = _effectiveScoreConfigForMatch(tournament, match);
  return _normalizeBestOfValue(
    (config['bestOf'] as num?)?.toInt() ?? tournament.bestOf,
  );
}

int _effectivePointsToWinForMatch(
  Tournament tournament,
  TournamentMatch match,
) {
  final config = _effectiveScoreConfigForMatch(tournament, match);
  return (config['pointsToWin'] as num?)?.toInt() ?? tournament.pointsToWin;
}

String _scoringStageLabelForMatch(
  Tournament tournament,
  TournamentMatch match,
) {
  switch (_roundConfigKeyForMatch(tournament, match)) {
    case 'quarterFinal':
      return 'Quarterfinal scoring';
    case 'semiFinal':
      return 'Semifinal scoring';
    case 'final':
      return 'Final scoring';
    default:
      return 'Default scoring';
  }
}

LiveMatch _buildLiveMatchFromTournament({
  required String id,
  required TournamentMatch match,
  required Tournament tourn,
}) {
  final sport = sportFromName(tourn.sport);
  final teamA = match.teamAName ?? 'Team A';
  final teamB = match.teamBName ?? 'Team B';
  final venue = _resolvedMatchVenueName(tourn, match) ?? tourn.location;
  final effectiveBestOf = _effectiveBestOfForMatch(tourn, match);
  final effectivePointsToWin = _effectivePointsToWinForMatch(tourn, match);
  final bestOf = effectiveBestOf > 0 ? effectiveBestOf : 3;
  final format = '${tourn.sport} · Best of $bestOf';
  final myUid = UserService().userId ?? '';
  final now = DateTime.now();

  switch (engineForSport(sport)) {
    case SportEngine.rally:
      final setsToWin = (bestOf / 2).ceil();
      final pointsToWin = effectivePointsToWin > 0
          ? effectivePointsToWin
          : _defaultRallyPts(sport);
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        rally: RallyScore(
          pointsToWin: pointsToWin,
          setsToWin: setsToWin,
          winByTwo: true,
          maxPointCap: sport == MatchSport.badminton ? 30 : null,
          isTennis: sport == MatchSport.tennis || sport == MatchSport.padel,
          lastSetPoints:
              (sport == MatchSport.volleyball ||
                  sport == MatchSport.beachVolleyball)
              ? 15
              : null,
        ),
      );
    case SportEngine.cricket:
      final allTeams = TournamentService().teamsFor(tourn.id);
      final teamAObj = allTeams.where((t) => t.id == match.teamAId).firstOrNull;
      final teamBObj = allTeams.where((t) => t.id == match.teamBId).firstOrNull;
      final perSide = tourn.playersPerTeam > 0 ? tourn.playersPerTeam : 11;
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        teamAPlayers: teamAObj?.players ?? [],
        teamBPlayers: teamBObj?.players ?? [],
        cricket: CricketScore(
          format: 'T20',
          totalOvers: 20,
          playersPerSide: perSide,
          teamA: teamA,
          teamB: teamB,
          teamABatFirst: true,
        ),
      );
    case SportEngine.football:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        football: FootballScore(matchDurationMin: 90),
      );
    case SportEngine.basketball:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        basketball: BasketballScore(quarterMinutes: 10),
      );
    case SportEngine.hockey:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        hockey: HockeyScore(),
      );
    case SportEngine.combat:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        combat: CombatScore(
          totalRounds: tourn.bestOf > 0 ? tourn.bestOf : 3,
          roundDurationMin: 3,
        ),
      );
    case SportEngine.esports:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        esports: EsportsScore(
          roundsToWin: effectiveBestOf > 0 ? effectiveBestOf : 13,
        ),
      );
    case SportEngine.generic:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: format,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        genericScore: GenericScore(
          pointsToWin: effectivePointsToWin > 0 ? effectivePointsToWin : 0,
        ),
      );
  }
}

Future<void> _launchWebScoring(
  BuildContext context,
  String tournamentId,
  String matchId,
) async {
  final tourn = TournamentService().tournaments
      .where((t) => t.id == tournamentId)
      .firstOrNull;
  final match = TournamentService()
      .matchesFor(tournamentId)
      .where((m) => m.id == matchId)
      .firstOrNull;
  if (tourn == null || match == null) return;

  final scoreboardId = 'tourn_${tournamentId}_$matchId';
  final svc = context.read<ScoreboardService>();
  final expectedSport = sportFromName(tourn.sport);
  final existing = svc.byId(scoreboardId);
  var needsRecreate = existing == null || existing.sport != expectedSport;
  final expectedBestOf = _effectiveBestOfForMatch(tourn, match);
  final expectedSetsToWin = (expectedBestOf / 2).ceil();

  if (!needsRecreate) {
    final current = existing;
    if (current.isTournamentMatch &&
        (current.tournamentId == null || current.teamAId == null)) {
      needsRecreate = true;
    }
    if (!needsRecreate && current.rally != null) {
      final expectedPts = _effectivePointsToWinForMatch(tourn, match) > 0
          ? _effectivePointsToWinForMatch(tourn, match)
          : _defaultRallyPts(expectedSport);
      if (current.rally!.pointsToWin != expectedPts) needsRecreate = true;
      if (current.rally!.setsToWin != expectedSetsToWin) needsRecreate = true;
    }
    if (!needsRecreate && current.genericScore != null) {
      final expectedPts = _effectivePointsToWinForMatch(tourn, match) > 0
          ? _effectivePointsToWinForMatch(tourn, match)
          : 0;
      if (current.genericScore!.pointsToWin != expectedPts) {
        needsRecreate = true;
      }
    }
  }

  if (needsRecreate) {
    if (existing != null) svc.removeMatch(scoreboardId);
    svc.addMatch(
      _buildLiveMatchFromTournament(
        id: scoreboardId,
        match: match,
        tourn: tourn,
      ),
    );
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kActiveScoringKey,
    jsonEncode({
      'tournamentId': tournamentId,
      'matchId': matchId,
      'scoreboardId': scoreboardId,
    }),
  );

  if (context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LiveScoreboardScreen(matchId: scoreboardId, isScorer: true),
      ),
    );
  }
}

IconData _sportIcon(String sport) {
  const m = {
    'Cricket': Icons.sports_cricket_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Basketball': Icons.sports_basketball_rounded,
    'Badminton': Icons.sports_tennis_rounded,
    'Tennis': Icons.sports_tennis_rounded,
    'Volleyball': Icons.sports_volleyball_rounded,
    'Hockey': Icons.sports_hockey_rounded,
    'Boxing': Icons.sports_mma_rounded,
    'Kabaddi': Icons.sports_kabaddi_rounded,
    'Table Tennis': Icons.sports_tennis_rounded,
    'Rugby': Icons.sports_rugby_rounded,
    'Golf': Icons.sports_golf_rounded,
    'Esports': Icons.sports_esports_rounded,
    'Swimming': Icons.pool_rounded,
    'Athletics': Icons.directions_run_rounded,
  };
  return m[sport] ?? Icons.emoji_events_rounded;
}

String _monthShort(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

bool _isUserRegisteredForTournament(
  String userId,
  String tournamentId,
  List<TournamentTeam> teams,
) {
  if (userId.isEmpty) return false;
  if (TournamentService().myEnrolledIds.contains(tournamentId)) return true;
  return teams.any((team) {
    if (team.enrolledBy == userId) return true;
    if (team.captainUserId == userId) return true;
    if (team.viceCaptainUserId == userId) return true;
    return team.playerUserIds.contains(userId);
  });
}

Color _sportAccent(String sport) {
  const m = {
    'Cricket': Color(0xFF4CAF50),
    'Football': Color(0xFF66BB6A),
    'Basketball': Color(0xFFFF9800),
    'Badminton': Color(0xFF42A5F5),
    'Tennis': Color(0xFFCDDC39),
    'Volleyball': Color(0xFF7E57C2),
    'Hockey': Color(0xFFFF7043),
    'Boxing': Color(0xFFEF5350),
    'Table Tennis': Color(0xFF26C6DA),
    'Rugby': Color(0xFFFFCA28),
    'Kabaddi': Color(0xFFEC407A),
    'Swimming': Color(0xFF29B6F6),
  };
  return m[sport] ?? _red;
}

String _fmtDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String? _sanitizeVenueLabel(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (!trimmed.contains(r'${')) return trimmed;
  final base = trimmed.split(r'${').first.trim();
  if (base.isNotEmpty) return base;
  return 'Venue';
}

String? _resolvedMatchVenueName(Tournament tournament, TournamentMatch match) {
  if ((match.venueId ?? '').isNotEmpty) {
    final venue = TournamentService()
        .venuesFor(tournament.id)
        .where((v) => v.id == match.venueId)
        .firstOrNull;
    final byIdName = _sanitizeVenueLabel(venue?.name);
    if ((byIdName ?? '').isNotEmpty) return byIdName;
  }
  return _sanitizeVenueLabel(match.venueName);
}

String _formatLabel(TournamentFormat format) {
  switch (format) {
    case TournamentFormat.knockout:
      return 'No Groups - Knockout';
    case TournamentFormat.roundRobin:
      return 'No Groups - Round Robin';
    case TournamentFormat.leagueKnockout:
      return 'Groups + Knockout';
    case TournamentFormat.league:
      return 'No Groups - League';
    case TournamentFormat.custom:
      return 'Custom';
  }
}

String _statusLabel(TournamentStatus status) {
  switch (status) {
    case TournamentStatus.open:
      return 'Open';
    case TournamentStatus.ongoing:
      return 'Ongoing';
    case TournamentStatus.completed:
      return 'Completed';
    case TournamentStatus.cancelled:
      return 'Cancelled';
  }
}

Future<void> _openWebTournamentDetail(
  BuildContext context, {
  required String tournamentId,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .62),
    builder: (_) => _WebTournamentDetailDialog(tournamentId: tournamentId),
  );
}

// ── Page ───────────────────────────────────────────────────────────────────────

class WebTournamentsPage extends StatefulWidget {
  const WebTournamentsPage({super.key});

  @override
  State<WebTournamentsPage> createState() => _WebTournamentsPageState();
}

class _WebTournamentsPageState extends State<WebTournamentsPage> {
  int _filterTab = 0; // 0=All 1=Ongoing 2=Upcoming 3=Completed
  String? _sport;

  @override
  void initState() {
    super.initState();
    TournamentService().loadTournaments();
    final uid = UserService().userId ?? '';
    TournamentService().loadMyEnrollments(uid);
  }

  Future<void> _openCreateTournament() async {
    final created = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .62),
      builder: (_) => const _WebCreateTournamentDialog(),
    );
    if (created == true && mounted) {
      await TournamentService().loadTournaments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildFilterRow()),
                SliverToBoxAdapter(child: _buildFeaturedBanner()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Row(
                      children: [
                        Text(
                          'All Tournaments',
                          style: _t(size: 16, weight: FontWeight.w800),
                        ),
                        const Spacer(),
                        _SortPill(),
                      ],
                    ),
                  ),
                ),
                _TournamentGrid(filterTab: _filterTab, sport: _sport),
                const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
              ],
            ),
          ),
          // ── Right stats panel ─────────────────────────────────────────────
          _RightStatsPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tournaments',
                  style: _t(size: 26, weight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compete. Connect. Win together.',
                  style: _t(size: 14, color: _m1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _RedBtn(
            icon: Icons.add_rounded,
            label: 'Create Tournament',
            onTap: _openCreateTournament,
          ),
          const SizedBox(width: 10),
          _OutlineBtn(
            icon: Icons.group_add_outlined,
            label: 'Join Tournament',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    const tabs = ['All', 'Ongoing', 'Upcoming', 'Completed'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          // Filter tabs
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: tabs.asMap().entries.map((e) {
                final active = e.key == _filterTab;
                return GestureDetector(
                  onTap: () => setState(() => _filterTab = e.key),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _red : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        e.value,
                        style: _t(
                          size: 12,
                          weight: FontWeight.w600,
                          color: active ? Colors.white : _m1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
          // Sport filter
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _SportFilterChips(
                selected: _sport,
                onSelect: (s) => setState(() => _sport = s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final tours = TournamentService().tournaments;
        if (tours.isEmpty) return const SizedBox(height: 20);
        final featured = tours.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: _FeaturedBanner(tournament: featured),
        );
      },
    );
  }
}

// ── Featured banner ────────────────────────────────────────────────────────────

class _FeaturedBanner extends StatelessWidget {
  final Tournament tournament;
  const _FeaturedBanner({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final accent = _sportAccent(tournament.sport);
    final alreadyRegistered = _isUserRegisteredForTournament(
      UserService().userId ?? '',
      tournament.id,
      TournamentService().teamsFor(tournament.id),
    );
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: .25), const Color(0xFF0A0A0A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Stack(
        children: [
          // Watermark icon
          Positioned(
            right: 30,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: .10,
              child: Center(
                child: Icon(
                  _sportIcon(tournament.sport),
                  color: accent,
                  size: 140,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _red.withValues(alpha: .4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: _red, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'FEATURED',
                        style: _t(
                          size: 10,
                          weight: FontWeight.w800,
                          color: _red,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tournament.name,
                  style: _t(size: 24, weight: FontWeight.w900, height: 1.2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(_sportIcon(tournament.sport), color: accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      tournament.sport,
                      style: _t(
                        size: 13,
                        color: accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_outlined, size: 13, color: _m1),
                    const SizedBox(width: 5),
                    Text(
                      tournament.endDate != null
                          ? '${_fmtDate(tournament.startDate)} – ${_fmtDate(tournament.endDate!)}'
                          : _fmtDate(tournament.startDate),
                      style: _t(size: 13, color: _m1),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on_outlined, size: 13, color: _m1),
                    const SizedBox(width: 5),
                    Text(tournament.location, style: _t(size: 13, color: _m1)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    alreadyRegistered
                        ? _OutlineBtn(
                            label: 'Already Registered',
                            icon: Icons.check_circle_rounded,
                            onTap: null,
                          )
                        : _RedBtn(
                            label: 'Register Now',
                            onTap: () => EnrollTeamSheet.show(
                              context,
                              tournamentId: tournament.id,
                              entryFee: tournament.entryFee,
                              serviceFee: tournament.serviceFee,
                              playersPerTeam: tournament.playersPerTeam,
                              sport: tournament.sport,
                            ),
                          ),
                    const SizedBox(width: 10),
                    _OutlineBtn(
                      label: 'View Details',
                      onTap: () => _openWebTournamentDetail(
                        context,
                        tournamentId: tournament.id,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tournament grid ────────────────────────────────────────────────────────────

class _TournamentGrid extends StatelessWidget {
  final int filterTab;
  final String? sport;
  const _TournamentGrid({required this.filterTab, required this.sport});

  List<Tournament> _filter(List<Tournament> all) {
    var list = all;
    if (filterTab == 1) {
      list = list.where((t) => t.status == TournamentStatus.ongoing).toList();
    } else if (filterTab == 2) {
      list = list.where((t) => t.status == TournamentStatus.open).toList();
    } else if (filterTab == 3) {
      list = list.where((t) => t.status == TournamentStatus.completed).toList();
    }
    if (sport != null) {
      list = list.where((t) => t.sport == sport).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final items = _filter(TournamentService().tournaments);
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, color: _m2, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No tournaments found',
                      style: _t(size: 15, color: _m1, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try a different filter or check back later',
                      style: _t(size: 13, color: _m2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: .85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _TournamentCard(tournament: items[i]),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

class _TournamentCard extends StatefulWidget {
  final Tournament tournament;
  const _TournamentCard({required this.tournament});

  @override
  State<_TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<_TournamentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final accent = _sportAccent(t.sport);
    final statusLabel = t.status == TournamentStatus.ongoing
        ? 'ONGOING'
        : t.status == TournamentStatus.open
        ? 'UPCOMING'
        : 'COMPLETED';
    final statusColor = t.status == TournamentStatus.ongoing
        ? _red
        : t.status == TournamentStatus.open
        ? _orange
        : _m1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _openWebTournamentDetail(context, tournamentId: t.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .06),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sport header
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: .3),
                      accent.withValues(alpha: .05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: .18,
                        child: Center(
                          child: Icon(
                            _sportIcon(t.sport),
                            color: accent,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withValues(alpha: .5),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: _t(
                            size: 9,
                            weight: FontWeight.w800,
                            color: statusColor,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(
                          size: 14,
                          weight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(_sportIcon(t.sport), color: accent, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            t.sport,
                            style: _t(
                              size: 11,
                              color: accent,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.format.name,
                              style: _t(size: 10, color: _m1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MetaRow(
                        Icons.people_outline_rounded,
                        '${t.maxTeams} Teams',
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(
                        Icons.calendar_today_outlined,
                        t.endDate != null
                            ? '${_fmtDate(t.startDate)} – ${_fmtDate(t.endDate!)}'
                            : _fmtDate(t.startDate),
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(Icons.location_on_outlined, t.location),
                      const Spacer(),
                      _CardCTA(
                        label: 'View Details  →',
                        onTap: () => _openWebTournamentDetail(
                          context,
                          tournamentId: t.id,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: _m2),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: _t(size: 11, color: _m1),
          ),
        ),
      ],
    );
  }
}

class _CardCTA extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _CardCTA({required this.label, required this.onTap});

  @override
  State<_CardCTA> createState() => _CardCTAState();
}

class _CardCTAState extends State<_CardCTA> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .06)
                : Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: _t(size: 12, weight: FontWeight.w600, color: _m1),
          ),
        ),
      ),
    );
  }
}

// ── Web create tournament dialog ───────────────────────────────────────────────

class _WebCreateTournamentDialog extends StatefulWidget {
  const _WebCreateTournamentDialog();

  @override
  State<_WebCreateTournamentDialog> createState() =>
      _WebCreateTournamentDialogState();
}

class _WebCreateTournamentDialogState
    extends State<_WebCreateTournamentDialog> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _entryFee = TextEditingController();
  final _prize = TextEditingController();
  final _rules = TextEditingController();
  String _sport = 'Cricket';
  TournamentFormat _format = TournamentFormat.leagueKnockout;
  DateTime? _startDate;
  DateTime? _endDate;
  int _maxTeams = 4;
  int _playersPerTeam = 11;
  bool _freeEntry = true;
  bool _private = false;
  bool _saving = false;
  String? _error;

  static const _sports = [
    'Cricket',
    'Football',
    'Basketball',
    'Badminton',
    'Tennis',
    'Volleyball',
    'Hockey',
    'Kabaddi',
    'Boxing',
    'Table Tennis',
    'Throwball',
    'Handball',
  ];

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _entryFee.dispose();
    _prize.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _red,
            surface: Color(0xFF111111),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final location = _location.text.trim();
    if (name.isEmpty || location.isEmpty || _startDate == null) {
      setState(
        () =>
            _error = 'Tournament name, location, and start date are required.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await TournamentService().createTournament(
        name: name,
        sport: _sport,
        format: _format,
        startDate: _startDate!,
        location: location,
        maxTeams: _maxTeams,
        entryFee: _freeEntry
            ? 0
            : (double.tryParse(_entryFee.text.trim()) ?? 0),
        serviceFee: 0,
        scheduleMode: ScheduleMode.auto,
        prizePool: _prize.text.trim().isEmpty ? null : _prize.text.trim(),
        playersPerTeam: _playersPerTeam,
        endDate: _endDate,
        rules: _rules.text.trim().isEmpty ? null : _rules.text.trim(),
        isPrivate: _private,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101010),
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Column(
          children: [
            _DialogHeader(
              icon: Icons.emoji_events_rounded,
              title: 'Create Tournament',
              subtitle: 'Build a tournament for teams on the web dashboard.',
              onClose: _saving ? null : () => Navigator.pop(context, false),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _WebTextField(
                                controller: _name,
                                label: 'Tournament Name',
                                hint: 'Nashville Cricket League',
                                icon: Icons.emoji_events_outlined,
                              ),
                              const SizedBox(height: 14),
                              _WebTextField(
                                controller: _location,
                                label: 'Location',
                                hint: 'Hendersonville, Tennessee',
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PickBox(
                                      label: 'Start Date',
                                      value: _startDate == null
                                          ? 'Select date'
                                          : _fmtDate(_startDate!),
                                      icon: Icons.calendar_today_outlined,
                                      onTap: () => _pickDate(start: true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PickBox(
                                      label: 'End Date',
                                      value: _endDate == null
                                          ? 'Optional'
                                          : _fmtDate(_endDate!),
                                      icon: Icons.event_available_outlined,
                                      onTap: () => _pickDate(start: false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 2,
                          child: _CreateSummaryCard(
                            sport: _sport,
                            format: _format,
                            maxTeams: _maxTeams,
                            playersPerTeam: _playersPerTeam,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Sport',
                      style: _t(size: 12, color: _red, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sport in _sports)
                          _ChoicePill(
                            label: sport,
                            icon: _sportIcon(sport),
                            active: _sport == sport,
                            color: _sportAccent(sport),
                            onTap: () => setState(() => _sport = sport),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Tournament Format',
                      style: _t(size: 12, color: _red, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final format in TournamentFormat.values)
                          _ChoicePill(
                            label: _formatLabel(format),
                            icon: Icons.account_tree_outlined,
                            active: _format == format,
                            color: _red,
                            onTap: () => setState(() => _format = format),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberStepper(
                            label: 'Max Teams',
                            value: _maxTeams,
                            min: 2,
                            max: 64,
                            onChanged: (v) => setState(() => _maxTeams = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberStepper(
                            label: 'Players / Team',
                            value: _playersPerTeam,
                            min: 1,
                            max: 30,
                            onChanged: (v) =>
                                setState(() => _playersPerTeam = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleRow(
                            title: 'Free Entry',
                            subtitle: 'No registration fee',
                            value: _freeEntry,
                            onChanged: (v) => setState(() => _freeEntry = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ToggleRow(
                            title: 'Private Tournament',
                            subtitle: 'Invite-only with join code',
                            value: _private,
                            onChanged: (v) => setState(() => _private = v),
                          ),
                        ),
                      ],
                    ),
                    if (!_freeEntry) ...[
                      const SizedBox(height: 14),
                      _WebTextField(
                        controller: _entryFee,
                        label: 'Entry Fee',
                        hint: '25',
                        icon: Icons.attach_money_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _WebTextField(
                      controller: _prize,
                      label: 'Prize Pool',
                      hint: 'Optional prize details',
                      icon: Icons.workspace_premium_outlined,
                    ),
                    const SizedBox(height: 14),
                    _WebTextField(
                      controller: _rules,
                      label: 'Rules',
                      hint: 'Add rules, schedule notes, or eligibility details',
                      icon: Icons.rule_outlined,
                      maxLines: 3,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: _t(size: 12, color: _red)),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border, width: .8)),
              ),
              child: Row(
                children: [
                  Text(
                    'The tournament will appear on the web tournaments page.',
                    style: _t(size: 12, color: _m1),
                  ),
                  const Spacer(),
                  _OutlineBtn(
                    label: 'Cancel',
                    onTap: _saving ? null : () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: 10),
                  _RedBtn(
                    label: _saving ? 'Creating...' : 'Create Tournament',
                    icon: Icons.add_rounded,
                    onTap: _saving ? null : _create,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Web tournament detail dialog ───────────────────────────────────────────────

class _WebTournamentDetailDialog extends StatefulWidget {
  final String tournamentId;
  const _WebTournamentDetailDialog({required this.tournamentId});

  @override
  State<_WebTournamentDetailDialog> createState() =>
      _WebTournamentDetailDialogState();
}

class _WebTournamentDetailDialogState
    extends State<_WebTournamentDetailDialog> {
  int _tab = 0;
  int _tableTab = 0;
  int _matchTab = 0;
  bool _generatingSchedule = false;

  @override
  void initState() {
    super.initState();
    TournamentService().loadDetail(widget.tournamentId);
  }

  void _snack(String message, [Color color = Colors.green]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _generateSchedule() async {
    setState(() => _generatingSchedule = true);
    try {
      await TournamentService().generateSchedule(widget.tournamentId);
      if (mounted) _snack('Schedule generated!');
    } catch (e) {
      if (mounted) _snack(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _generatingSchedule = false);
    }
  }

  Future<void> _resetMatch(TournamentMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Reset Score?',
          style: _t(size: 18, weight: FontWeight.w900),
        ),
        content: Text(
          'This will reset ${match.teamAName ?? "Team A"} vs '
          '${match.teamBName ?? "Team B"} and adjust the points table.',
          style: _t(size: 13, color: _m1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _m1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final scoreboardId = 'tourn_${widget.tournamentId}_${match.id}';
      ScoreboardService().removeMatch(scoreboardId);
      await TournamentService().resetMatchResult(
        tournamentId: widget.tournamentId,
        matchId: match.id,
      );
      if (mounted) _snack('Match reset to 0 - 0');
    } catch (e) {
      if (mounted) _snack('Reset failed: $e', Colors.red);
    }
  }

  Future<void> _openMatchDialog(TournamentMatch match) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .8),
      builder: (_) => _WebMatchDetailDialog(
        tournament: TournamentService().tournaments.firstWhere(
          (t) => t.id == widget.tournamentId,
        ),
        matchId: match.id,
      ),
    );
    if (mounted) {
      await TournamentService().loadDetail(widget.tournamentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc = TournamentService();
        final tournament = svc.tournaments
            .where((t) => t.id == widget.tournamentId)
            .cast<Tournament?>()
            .firstOrNull;
        if (tournament == null) {
          return const Dialog(
            backgroundColor: Color(0xFF101010),
            child: SizedBox(
              width: 420,
              height: 220,
              child: Center(child: CircularProgressIndicator(color: _red)),
            ),
          );
        }
        final accent = _sportAccent(tournament.sport);
        final teams = svc.teamsFor(tournament.id);
        final matches = svc.matchesFor(tournament.id);
        final venues = svc.venuesFor(tournament.id);
        final groups = svc.groupsFor(tournament.id);
        final admins = svc.adminsFor(tournament.id);
        final canManage =
            svc.isHost(tournament.id) || svc.isAdmin(tournament.id);
        final isHost = svc.isHost(tournament.id);
        final alreadyRegistered = _isUserRegisteredForTournament(
          UserService().userId ?? '',
          tournament.id,
          teams,
        );
        final tabs = [
          'Matches',
          'Table',
          'Stats',
          'Squads',
          'Venues',
          'Forecast',
        ];

        return Dialog(
          backgroundColor: const Color(0xFF101010),
          insetPadding: const EdgeInsets.all(28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: .08)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 760),
            child: Column(
              children: [
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: .28),
                        const Color(0xFF101010),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 42,
                        top: 18,
                        child: Opacity(
                          opacity: .16,
                          child: Icon(
                            _sportIcon(tournament.sport),
                            color: accent,
                            size: 150,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Badge(
                                  label: _formatLabel(tournament.format),
                                  color: _m1,
                                ),
                                const SizedBox(width: 8),
                                _Badge(
                                  label: _statusLabel(tournament.status),
                                  color: accent,
                                ),
                                const Spacer(),
                                if (canManage) ...[
                                  _RedBtn(
                                    label: 'Manage Tournament',
                                    icon: Icons.admin_panel_settings_outlined,
                                    onTap: () =>
                                        setState(() => _tab = tabs.length),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _m1,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              tournament.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(size: 28, weight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 18,
                              runSpacing: 8,
                              children: [
                                _InlineMeta(
                                  icon: _sportIcon(tournament.sport),
                                  text: tournament.sport,
                                  color: accent,
                                ),
                                _InlineMeta(
                                  icon: Icons.location_on_outlined,
                                  text: tournament.location,
                                ),
                                _InlineMeta(
                                  icon: Icons.calendar_today_outlined,
                                  text: tournament.endDate != null
                                      ? '${_fmtDate(tournament.startDate)} - ${_fmtDate(tournament.endDate!)}'
                                      : _fmtDate(tournament.startDate),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _border)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      for (int i = 0; i < tabs.length; i++)
                        _DialogTab(
                          label: tabs[i],
                          active: _tab == i,
                          onTap: () => setState(() => _tab = i),
                        ),
                      const Spacer(),
                      if (_tab == tabs.length)
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: _Badge(label: 'Host Portal', color: _red),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: alreadyRegistered
                              ? _OutlineBtn(
                                  label: 'Already Registered',
                                  icon: Icons.check_circle_rounded,
                                  onTap: null,
                                )
                              : _RedBtn(
                                  label: 'Register Team',
                                  onTap: () => EnrollTeamSheet.show(
                                    context,
                                    tournamentId: tournament.id,
                                    entryFee: tournament.entryFee,
                                    serviceFee: tournament.serviceFee,
                                    playersPerTeam: tournament.playersPerTeam,
                                    sport: tournament.sport,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        _TournamentMatchesPane(
                          tournament: tournament,
                          teams: teams,
                          matches: matches,
                          canManage: canManage,
                          matchTab: _matchTab,
                          generatingSchedule: _generatingSchedule,
                          onMatchTabChanged: (value) =>
                              setState(() => _matchTab = value),
                          onGenerateSchedule: _generateSchedule,
                          onResetMatch: _resetMatch,
                          onOpenMatch: _openMatchDialog,
                        ),
                        _TournamentTablePane(
                          tournament: tournament,
                          teams: teams,
                          matches: matches,
                          tableTab: _tableTab,
                          onTableTabChanged: (value) =>
                              setState(() => _tableTab = value),
                        ),
                        _TournamentStatsPane(
                          tournament: tournament,
                          teams: teams,
                          matches: matches,
                        ),
                        _TournamentSquadsPane(teams: teams),
                        _TournamentVenuesPane(
                          tournament: tournament,
                          venues: venues,
                        ),
                        _TournamentForecastPane(
                          tournament: tournament,
                          matches: matches,
                          venues: venues,
                        ),
                        if (canManage)
                          _TournamentManagePane(
                            tournament: tournament,
                            teams: teams,
                            matches: matches,
                            groups: groups,
                            venues: venues,
                            admins: admins,
                            isHost: isHost,
                            onCloseDialog: () => Navigator.pop(context),
                          )
                        else
                          const _EmptyPane(
                            label:
                                'Management access is only available to hosts and admins.',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _red, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(size: 20, weight: FontWeight.w900)),
                Text(subtitle, style: _t(size: 12, color: _m1)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: _m1),
          ),
        ],
      ),
    );
  }
}

class _WebTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const _WebTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: _t(size: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _t(size: 13, color: _m2),
            prefixIcon: Icon(icon, color: _m1, size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: .04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: _red, size: 18),
                  const SizedBox(width: 10),
                  Text(value, style: _t(size: 13, color: _m1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: .14)
                : Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: .48)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? color : _m1, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: _t(
                  size: 13,
                  weight: FontWeight.w700,
                  color: active ? _tx : _m1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateSummaryCard extends StatelessWidget {
  final String sport;
  final TournamentFormat format;
  final int maxTeams;
  final int playersPerTeam;

  const _CreateSummaryCard({
    required this.sport,
    required this.format,
    required this.maxTeams,
    required this.playersPerTeam,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _sportAccent(sport);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: .18),
            Colors.white.withValues(alpha: .03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_sportIcon(sport), color: accent, size: 38),
          const SizedBox(height: 14),
          Text(
            'Tournament Setup',
            style: _t(size: 17, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '$sport - ${_formatLabel(format)}',
            style: _t(size: 12, color: _m1),
          ),
          const SizedBox(height: 18),
          _SummaryMetric(label: 'Teams', value: '$maxTeams'),
          _SummaryMetric(label: 'Players / Team', value: '$playersPerTeam'),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: _t(size: 12, color: _m1)),
          const Spacer(),
          Text(value, style: _t(size: 13, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: _t(size: 13, weight: FontWeight.w700)),
          ),
          _SmallIconButton(
            icon: Icons.remove_rounded,
            onTap: value <= min ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: _t(size: 15, weight: FontWeight.w900),
            ),
          ),
          _SmallIconButton(
            icon: Icons.add_rounded,
            onTap: value >= max ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SmallIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: onTap == null ? .02 : .06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: onTap == null ? _m2 : _tx, size: 17),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(size: 13, weight: FontWeight.w800)),
                Text(subtitle, style: _t(size: 11, color: _m1)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: _red, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: Text(
        label,
        style: _t(size: 11, color: color, weight: FontWeight.w800),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InlineMeta({required this.icon, required this.text, this.color = _m1});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(
          text,
          style: _t(size: 13, color: color, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DialogTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DialogTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _red : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: _t(
              size: 13,
              weight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? _tx : _m1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentMatchesPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final bool canManage;
  final int matchTab;
  final bool generatingSchedule;
  final ValueChanged<int> onMatchTabChanged;
  final Future<void> Function() onGenerateSchedule;
  final ValueChanged<TournamentMatch> onResetMatch;
  final ValueChanged<TournamentMatch> onOpenMatch;

  const _TournamentMatchesPane({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.canManage,
    required this.matchTab,
    required this.generatingSchedule,
    required this.onMatchTabChanged,
    required this.onGenerateSchedule,
    required this.onResetMatch,
    required this.onOpenMatch,
  });

  @override
  Widget build(BuildContext context) {
    if (!tournament.bracketGenerated) {
      return _WebNoScheduleState(
        tournament: tournament,
        teamCount: teams.length,
        canManage: canManage,
        generating: generatingSchedule,
        onGenerate: onGenerateSchedule,
      );
    }

    final upcoming = matches.where((match) => !match.isPlayed).toList();
    final recent = matches.where((match) => match.isPlayed).toList().reversed;
    final championMatch = [...matches]
      ..sort((a, b) {
        final roundCompare = b.round.compareTo(a.round);
        if (roundCompare != 0) return roundCompare;
        return b.matchIndex.compareTo(a.matchIndex);
      });
    final finalMatch = championMatch
        .where((match) => match.isPlayed && (match.winnerId ?? '').isNotEmpty)
        .firstOrNull;
    final championTeam = finalMatch == null
        ? null
        : teams.where((team) => team.id == finalMatch.winnerId).firstOrNull;
    final visible = switch (matchTab) {
      0 => upcoming,
      1 => recent.toList(),
      _ => matches,
    };

    if (matchTab == 0 &&
        upcoming.isEmpty &&
        tournament.status == TournamentStatus.completed &&
        championTeam != null &&
        finalMatch != null) {
      return _WebChampionPane(
        tournament: tournament,
        championTeam: championTeam,
        finalMatch: finalMatch,
      );
    }

    return Column(
      children: [
        _SubTabBar(
          tabs: const ['Upcoming', 'Recent', 'All'],
          selected: matchTab,
          onSelect: onMatchTabChanged,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _WebMatchList(
            tournament: tournament,
            teams: teams,
            matches: visible,
            canManage: canManage,
            onResetMatch: onResetMatch,
            onOpenMatch: onOpenMatch,
          ),
        ),
      ],
    );
  }
}

class _WebChampionPane extends StatelessWidget {
  final Tournament tournament;
  final TournamentTeam championTeam;
  final TournamentMatch finalMatch;

  const _WebChampionPane({
    required this.tournament,
    required this.championTeam,
    required this.finalMatch,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _sportAccent(tournament.sport);
    final squad = TournamentService().squadFor(tournament.id, championTeam.id);
    final players = squad.isNotEmpty
        ? squad.map((player) => player.playerName).toList()
        : championTeam.players;
    final finalLabel = finalMatch.note?.isNotEmpty == true
        ? finalMatch.note!
        : 'Champion';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(label: finalLabel, color: accent),
                const SizedBox(height: 18),
                Text(
                  championTeam.teamName,
                  style: _t(size: 32, weight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '${finalMatch.winnerName ?? championTeam.teamName} lifted the trophy.',
                  style: _t(size: 14, color: _m1),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _InlineMeta(
                      icon: Icons.emoji_events_outlined,
                      text: 'Tournament Winner',
                      color: accent,
                    ),
                    if (finalMatch.scheduledAt != null)
                      _InlineMeta(
                        icon: Icons.schedule_rounded,
                        text: _fmtDate(finalMatch.scheduledAt!),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: .26),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 88,
                    color: Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Champions', style: _t(size: 18, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  tournament.name,
                  textAlign: TextAlign.center,
                  style: _t(size: 12, color: _m1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Players', style: _t(size: 16, weight: FontWeight.w900)),
                const SizedBox(height: 14),
                if (players.isEmpty)
                  Text(
                    'No player list available.',
                    style: _t(size: 13, color: _m1),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final player in players)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .035),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                          child: Text(
                            player,
                            style: _t(size: 13, weight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WebNoScheduleState extends StatelessWidget {
  final Tournament tournament;
  final int teamCount;
  final bool canManage;
  final bool generating;
  final Future<void> Function() onGenerate;

  const _WebNoScheduleState({
    required this.tournament,
    required this.teamCount,
    required this.canManage,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final recommendation = teamCount >= 2
        ? TournamentService.scheduleRecommendation(
            teamCount,
            tournament.sport,
            tournament.format,
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: _red,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule not generated',
                      style: _t(size: 22, weight: FontWeight.w900),
                    ),
                    Text(
                      teamCount < 2
                          ? 'Need at least 2 registered teams to generate matches.'
                          : 'Generate fixtures from registered teams to unlock match cards.',
                      style: _t(size: 13, color: _m1),
                    ),
                  ],
                ),
              ),
              if (canManage && teamCount >= 2)
                _RedBtn(
                  label: generating ? 'Generating...' : 'Generate Schedule',
                  icon: Icons.auto_fix_high_rounded,
                  onTap: generating ? null : onGenerate,
                ),
            ],
          ),
          if (recommendation != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule Preview',
                    style: _t(size: 12, color: _m1, weight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(recommendation, style: _t(size: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WebMatchList extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final bool canManage;
  final ValueChanged<TournamentMatch> onResetMatch;
  final ValueChanged<TournamentMatch> onOpenMatch;

  const _WebMatchList({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.canManage,
    required this.onResetMatch,
    required this.onOpenMatch,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const _EmptyPane(label: 'No matches here yet');
    }

    final grouped = <String, List<TournamentMatch>>{};
    for (final match in matches) {
      final key = match.note?.isNotEmpty == true
          ? match.note!
          : 'Round ${match.round}';
      grouped.putIfAbsent(key, () => []).add(match);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        for (final entry in grouped.entries) ...[
          _WebMatchGroupHeader(label: entry.key, matches: entry.value),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entry.value.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 430,
              mainAxisExtent: 214,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final match = entry.value[index];
              final displayA = match.teamAName ?? 'TBD';
              final displayB = match.teamBName ?? 'TBD';

              return _WebMatchCard(
                tournament: tournament,
                match: match,
                displayNameA: displayA,
                displayNameB: displayB,
                canManage: canManage,
                onReset: () => onResetMatch(match),
                onTap: () => onOpenMatch(match),
              );
            },
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _WebMatchGroupHeader extends StatelessWidget {
  final String label;
  final List<TournamentMatch> matches;

  const _WebMatchGroupHeader({required this.label, required this.matches});

  @override
  Widget build(BuildContext context) {
    final played = matches.where((match) => match.isPlayed).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _Badge(label: label, color: _red),
          const SizedBox(width: 10),
          Text(
            '$played/${matches.length} played',
            style: _t(size: 12, color: _m1, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WebMatchCard extends StatelessWidget {
  final Tournament tournament;
  final TournamentMatch match;
  final String displayNameA;
  final String displayNameB;
  final bool canManage;
  final VoidCallback onReset;
  final VoidCallback onTap;

  const _WebMatchCard({
    required this.tournament,
    required this.match,
    required this.displayNameA,
    required this.displayNameB,
    required this.canManage,
    required this.onReset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = match.isLive
        ? Colors.greenAccent
        : match.isPlayed
        ? _red
        : _m1;
    final resultLabel = _matchResultLabel(
      match,
      teamAName: displayNameA,
      teamBName: displayNameB,
    );
    final statusLabel = match.isLive
        ? 'LIVE'
        : match.isPlayed
        ? resultLabel
        : 'Upcoming';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(label: 'Round ${match.round}', color: _m1),
                  const Spacer(),
                  Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(
                      size: 11,
                      color: statusColor,
                      weight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _WebMatchTeamLine(
                name: displayNameA,
                score: match.scoreA,
                winner: match.result == TournamentMatchResult.teamAWin,
                played: match.isPlayed,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('vs', style: _t(size: 11, color: _m1)),
              ),
              _WebMatchTeamLine(
                name: displayNameB,
                score: match.scoreB,
                winner: match.result == TournamentMatchResult.teamBWin,
                played: match.isPlayed,
              ),
              const Spacer(),
              Text(
                _matchFooter(
                  tournament,
                  match,
                  teamAName: displayNameA,
                  teamBName: displayNameB,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _t(size: 12, color: _m1),
              ),
              if (canManage && match.isPlayed && !match.isBye) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded, size: 15),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WebMatchTeamLine extends StatelessWidget {
  final String name;
  final int? score;
  final bool winner;
  final bool played;

  const _WebMatchTeamLine({
    required this.name,
    required this.score,
    required this.winner,
    required this.played,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _t(
              size: 15,
              weight: winner ? FontWeight.w900 : FontWeight.w700,
              color: winner ? _tx : Colors.white70,
            ),
          ),
        ),
        if (played && score != null) ...[
          const SizedBox(width: 10),
          Text('$score', style: _t(size: 18, weight: FontWeight.w900)),
        ],
        if (winner) ...[
          const SizedBox(width: 6),
          const Icon(Icons.check_circle_rounded, color: _red, size: 16),
        ],
      ],
    );
  }
}

class _WebMatchDetailDialog extends StatefulWidget {
  final Tournament tournament;
  final String matchId;

  const _WebMatchDetailDialog({
    required this.tournament,
    required this.matchId,
  });

  @override
  State<_WebMatchDetailDialog> createState() => _WebMatchDetailDialogState();
}

class _WebMatchDetailDialogState extends State<_WebMatchDetailDialog> {
  int _tab = 0;
  bool _saving = false;
  final _streamCtrl = TextEditingController();

  TournamentMatch? get _match => TournamentService()
      .matchesFor(widget.tournament.id)
      .where((m) => m.id == widget.matchId)
      .firstOrNull;

  bool get _canManage =>
      TournamentService().isHost(widget.tournament.id) ||
      TournamentService().canDo(
        widget.tournament.id,
        AdminPermission.updateScores,
      );

  @override
  void initState() {
    super.initState();
    final match = _match;
    if (match?.teamAId != null) {
      TournamentService().loadSquad(widget.tournament.id, match!.teamAId!);
    }
    if (match?.teamBId != null) {
      TournamentService().loadSquad(widget.tournament.id, match!.teamBId!);
    }
    _streamCtrl.text = match?.liveStreamUrl ?? '';
  }

  @override
  void dispose() {
    _streamCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLiveState({required bool live}) async {
    final match = _match;
    if (match == null) return;
    setState(() => _saving = true);
    try {
      if (live) {
        await TournamentService().setMatchLive(
          widget.tournament.id,
          match.id,
          streamUrl: _streamCtrl.text.trim().isEmpty
              ? null
              : _streamCtrl.text.trim(),
        );
      } else {
        await TournamentService().endMatchLive(widget.tournament.id, match.id);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final match = _match;
        if (match == null) {
          return const Dialog(
            backgroundColor: _card,
            child: SizedBox(
              width: 420,
              height: 220,
              child: Center(child: CircularProgressIndicator(color: _red)),
            ),
          );
        }

        final squadsA = match.teamAId != null
            ? TournamentService().squadFor(widget.tournament.id, match.teamAId!)
            : <TournamentSquadPlayer>[];
        final squadsB = match.teamBId != null
            ? TournamentService().squadFor(widget.tournament.id, match.teamBId!)
            : <TournamentSquadPlayer>[];

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 760),
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.note ?? 'Match Detail',
                                style: _t(size: 22, weight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      match.teamAName ?? 'Team A',
                                      style: _t(
                                        size: 18,
                                        weight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${match.scoreA ?? 0} - ${match.scoreB ?? 0}',
                                    style: _t(
                                      size: 24,
                                      weight: FontWeight.w900,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      match.teamBName ?? 'Team B',
                                      textAlign: TextAlign.end,
                                      style: _t(
                                        size: 18,
                                        weight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _InlineMeta(
                                    icon: Icons.schedule_rounded,
                                    text: match.scheduledAt == null
                                        ? 'Yet to be scheduled'
                                        : _fmtDate(match.scheduledAt!),
                                  ),
                                  _InlineMeta(
                                    icon: Icons.stadium_outlined,
                                    text:
                                        _resolvedMatchVenueName(
                                          widget.tournament,
                                          match,
                                        ) ??
                                        widget.tournament.location,
                                  ),
                                  _InlineMeta(
                                    icon: Icons.flag_outlined,
                                    text: match.isLive
                                        ? 'Live'
                                        : match.isPlayed
                                        ? _matchResultLabel(match)
                                        : 'Upcoming',
                                    color: match.isLive
                                        ? Colors.greenAccent
                                        : _m1,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: _m1),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        for (final entry in [
                          (0, 'Info'),
                          (1, 'Scorecard'),
                          (2, 'Squads'),
                          (3, 'Watch Live'),
                        ]) ...[
                          _DialogTab(
                            label: entry.$2,
                            active: _tab == entry.$1,
                            onTap: () => setState(() => _tab = entry.$1),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          _WebMatchInfoTab(
                            tournament: widget.tournament,
                            match: match,
                          ),
                          _WebMatchScorecardTab(
                            tournament: widget.tournament,
                            match: match,
                            canManage: _canManage,
                          ),
                          _WebMatchSquadsTab(
                            match: match,
                            squadsA: squadsA,
                            squadsB: squadsB,
                          ),
                          _WebMatchLiveTab(
                            match: match,
                            canManage: _canManage,
                            streamCtrl: _streamCtrl,
                            saving: _saving,
                            onStartLive: () => _saveLiveState(live: true),
                            onEndLive: () => _saveLiveState(live: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WebMatchInfoTab extends StatelessWidget {
  final Tournament tournament;
  final TournamentMatch match;

  const _WebMatchInfoTab({required this.tournament, required this.match});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _InfoPanel(
          title: 'Match Information',
          children: [
            _InfoLine('Tournament', tournament.name),
            _InfoLine('Format', _formatLabel(tournament.format)),
            _InfoLine('Stage', match.note ?? 'Round ${match.round}'),
            _InfoLine(
              'Schedule',
              match.scheduledAt == null
                  ? 'Not set'
                  : _fmtDate(match.scheduledAt!),
            ),
            _InfoLine(
              'Venue',
              _resolvedMatchVenueName(tournament, match) ?? tournament.location,
            ),
            _InfoLine(
              'Status',
              match.isLive
                  ? 'Live'
                  : match.isPlayed
                  ? _matchResultLabel(match)
                  : 'Upcoming',
            ),
          ],
        ),
      ],
    );
  }
}

class _WebMatchScorecardTab extends StatefulWidget {
  final Tournament tournament;
  final TournamentMatch match;
  final bool canManage;

  const _WebMatchScorecardTab({
    required this.tournament,
    required this.match,
    required this.canManage,
  });

  @override
  State<_WebMatchScorecardTab> createState() => _WebMatchScorecardTabState();
}

class _WebMatchScorecardTabState extends State<_WebMatchScorecardTab> {
  bool _saving = false;

  bool get _canScore {
    if (widget.canManage) return true;
    final uid = UserService().userId ?? '';
    if (uid.isEmpty) return false;
    final match = widget.match;
    final teams = TournamentService().teamsFor(widget.tournament.id);
    return teams.any(
      (t) =>
          t.captainUserId == uid &&
          (t.id == match.teamAId || t.id == match.teamBId),
    );
  }

  Future<void> _showEditScoreDialog(BuildContext context) async {
    final m = widget.match;
    final ctrlA = TextEditingController(text: '${m.scoreA ?? 0}');
    final ctrlB = TextEditingController(text: '${m.scoreB ?? 0}');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Edit Score', style: _t(size: 17, weight: FontWeight.w900)),
        content: Row(
          children: [
            Expanded(child: _scoreInput(m.teamAName ?? 'Team A', ctrlA)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('-', style: TextStyle(color: _tx, fontSize: 28)),
            ),
            Expanded(child: _scoreInput(m.teamBName ?? 'Team B', ctrlB)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _m1)),
          ),
          TextButton(
            onPressed: () async {
              final sA = int.tryParse(ctrlA.text.trim()) ?? (m.scoreA ?? 0);
              final sB = int.tryParse(ctrlB.text.trim()) ?? (m.scoreB ?? 0);
              Navigator.pop(ctx);
              if (_saving) return;
              setState(() => _saving = true);
              try {
                await TournamentService().updateMatchResult(
                  tournamentId: widget.tournament.id,
                  matchId: widget.match.id,
                  scoreA: sA,
                  scoreB: sB,
                  winnerId: sA > sB
                      ? (m.teamAId ?? '')
                      : sB > sA
                      ? (m.teamBId ?? '')
                      : '',
                  winnerName: sA > sB
                      ? (m.teamAName ?? '')
                      : sB > sA
                      ? (m.teamBName ?? '')
                      : '',
                );
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: const Text('Save', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );

    ctrlA.dispose();
    ctrlB.dispose();
  }

  Widget _scoreInput(String label, TextEditingController ctrl) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: _t(size: 13, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: _t(size: 28, weight: FontWeight.w900),
          decoration: _webInputDecoration('0'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final appliedBestOf = _effectiveBestOfForMatch(widget.tournament, match);
    final appliedPointsToWin = _effectivePointsToWinForMatch(
      widget.tournament,
      match,
    );
    final scoringStage = _scoringStageLabelForMatch(widget.tournament, match);
    final board = ListView(
      children: [
        _InfoPanel(
          title: 'Score Summary',
          children: [
            _InfoLine(match.teamAName ?? 'Team A', '${match.scoreA ?? 0}'),
            _InfoLine(match.teamBName ?? 'Team B', '${match.scoreB ?? 0}'),
            _InfoLine('Result', _matchResultLabel(match)),
          ],
        ),
        const SizedBox(height: 14),
        _InfoPanel(
          title: scoringStage,
          children: [
            _InfoLine(
              'Scoring Type',
              _scoringTypeLabel(widget.tournament.scoringType),
            ),
            _InfoLine('Best Of', '$appliedBestOf'),
            _InfoLine('Points To Win', '$appliedPointsToWin'),
          ],
        ),
        if (match.scorecardData != null && match.scorecardData!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _InfoPanel(
            title: 'Live Data',
            children: [
              SelectableText(
                match.scorecardData.toString(),
                style: _t(size: 12, color: _m1),
              ),
            ],
          ),
        ],
      ],
    );

    if (_canScore && !match.isPlayed) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RedBtn(
                label: 'Open Scoring',
                icon: Icons.edit_note_rounded,
                onTap: () =>
                    _launchWebScoring(context, widget.tournament.id, match.id),
              ),
            ),
          ),
          Expanded(child: board),
        ],
      );
    }

    if (widget.canManage && match.isPlayed) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _OutlineBtn(
                label: _saving ? 'Saving...' : 'Edit Score',
                icon: Icons.edit_rounded,
                onTap: _saving ? null : () => _showEditScoreDialog(context),
              ),
            ),
          ),
          Expanded(child: board),
        ],
      );
    }

    return board;
  }
}

class _WebMatchSquadsTab extends StatelessWidget {
  final TournamentMatch match;
  final List<TournamentSquadPlayer> squadsA;
  final List<TournamentSquadPlayer> squadsB;

  const _WebMatchSquadsTab({
    required this.match,
    required this.squadsA,
    required this.squadsB,
  });

  @override
  Widget build(BuildContext context) {
    if (squadsA.isEmpty && squadsB.isEmpty) {
      return const _EmptyPane(label: 'No squad data available');
    }

    Widget squadColumn(String title, List<TournamentSquadPlayer> squad) {
      return _InfoPanel(
        title: title,
        children: squad.isEmpty
            ? [Text('No squad uploaded', style: _t(size: 13, color: _m1))]
            : squad
                  .map(
                    (player) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .06),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              player.jerseyNumber > 0
                                  ? '${player.jerseyNumber}'
                                  : player.playerName[0].toUpperCase(),
                              style: _t(
                                size: 11,
                                color: _m1,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              player.playerName,
                              style: _t(size: 13, weight: FontWeight.w700),
                            ),
                          ),
                          if (player.role.isNotEmpty)
                            Text(player.role, style: _t(size: 11, color: _m1)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: squadColumn(match.teamAName ?? 'Team A', squadsA)),
        const SizedBox(width: 14),
        Expanded(child: squadColumn(match.teamBName ?? 'Team B', squadsB)),
      ],
    );
  }
}

class _WebMatchLiveTab extends StatelessWidget {
  final TournamentMatch match;
  final bool canManage;
  final TextEditingController streamCtrl;
  final bool saving;
  final VoidCallback onStartLive;
  final VoidCallback onEndLive;

  const _WebMatchLiveTab({
    required this.match,
    required this.canManage,
    required this.streamCtrl,
    required this.saving,
    required this.onStartLive,
    required this.onEndLive,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _InfoPanel(
          title: 'Watch Live',
          children: [
            if (match.isLive)
              Text(
                'This match is currently live.',
                style: _t(size: 13, color: Colors.greenAccent),
              )
            else
              Text(
                'No active livestream right now.',
                style: _t(size: 13, color: _m1),
              ),
            const SizedBox(height: 12),
            if ((match.liveStreamUrl ?? '').isNotEmpty)
              SelectableText(
                match.liveStreamUrl!,
                style: _t(size: 13, color: _red),
              ),
            if (canManage) ...[
              const SizedBox(height: 18),
              TextField(
                controller: streamCtrl,
                style: _t(size: 13),
                decoration: _webInputDecoration('Livestream URL'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RedBtn(
                    label: saving ? 'Working...' : 'Start Live',
                    onTap: saving ? null : onStartLive,
                  ),
                  _OutlineBtn(
                    label: 'End Live',
                    icon: Icons.stop_circle_outlined,
                    onTap: saving ? null : onEndLive,
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _matchResultLabel(
  TournamentMatch match, {
  String? teamAName,
  String? teamBName,
}) {
  if (match.result == TournamentMatchResult.draw) return 'Draw';
  final storedWinner = match.winnerName?.trim();
  final genericWinners = {'Winner', 'Team A', 'Team B'};
  String? resolvedWinner;
  if (storedWinner != null &&
      storedWinner.isNotEmpty &&
      !genericWinners.contains(storedWinner)) {
    resolvedWinner = storedWinner;
  } else if (match.result == TournamentMatchResult.teamAWin) {
    resolvedWinner = teamAName ?? match.teamAName;
  } else if (match.result == TournamentMatchResult.teamBWin) {
    resolvedWinner = teamBName ?? match.teamBName;
  }
  return '${resolvedWinner ?? 'Winner'} won';
}

String _matchFooter(
  Tournament tournament,
  TournamentMatch match, {
  String? teamAName,
  String? teamBName,
}) {
  if (match.isBye) return '${match.teamAName ?? "Team"} advances by bye';
  if (match.isPlayed) {
    return _matchResultLabel(match, teamAName: teamAName, teamBName: teamBName);
  }
  final venueName = _resolvedMatchVenueName(tournament, match);
  if ((venueName ?? '').isNotEmpty) return venueName!;
  if (match.scheduledAt != null) return _fmtDate(match.scheduledAt!);
  return 'Yet to be played';
}

class _TournamentTablePane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final int tableTab;
  final ValueChanged<int> onTableTabChanged;

  const _TournamentTablePane({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.tableTab,
    required this.onTableTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SubTabBar(
          tabs: const ['Points Table', 'Bracket'],
          selected: tableTab,
          onSelect: onTableTabChanged,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: tableTab == 0
              ? _PointsTable(
                  tournament: tournament,
                  teams: teams,
                  matches: matches,
                )
              : _TournamentBracketPane(
                  tournament: tournament,
                  matches: matches,
                ),
        ),
      ],
    );
  }
}

class _TournamentStatsPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  const _TournamentStatsPane({
    required this.tournament,
    required this.teams,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    final played = matches.where((m) => m.isPlayed).length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Registered Teams',
                value: '${teams.length}/${tournament.maxTeams}',
                icon: Icons.groups_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Matches Played',
                value: '$played/${matches.length}',
                icon: Icons.sports_score_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Entry',
                value: tournament.entryFee == 0
                    ? 'Free'
                    : '\$${tournament.entryFee.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _InfoPanel(
          title: 'Tournament Details',
          children: [
            _InfoLine(
              'Organizer',
              tournament.createdByName.isEmpty
                  ? 'Unknown'
                  : tournament.createdByName,
            ),
            _InfoLine('Format', _formatLabel(tournament.format)),
            _InfoLine(
              'Players / Team',
              tournament.playersPerTeam == 0
                  ? 'Not specified'
                  : '${tournament.playersPerTeam}',
            ),
            _InfoLine('Privacy', tournament.isPrivate ? 'Private' : 'Public'),
          ],
        ),
      ],
    );
  }
}

class _TournamentSquadsPane extends StatelessWidget {
  final List<TournamentTeam> teams;
  const _TournamentSquadsPane({required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const _EmptyPane(label: 'No teams registered yet');
    }
    return ListView.separated(
      itemCount: teams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final team = teams[i];
        return _InfoPanel(
          title: team.teamName,
          children: [
            _InfoLine('Captain', team.captainName),
            _InfoLine('Players', '${team.players.length}'),
            if (team.players.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final player in team.players.take(12))
                    _Badge(label: player, color: _m1),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TournamentVenuesPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentVenue> venues;
  const _TournamentVenuesPane({required this.tournament, required this.venues});

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      return _InfoPanel(
        title: tournament.location,
        children: [
          Text(
            'No venue records have been added yet. Tournament location is ${tournament.location}.',
            style: _t(size: 13, color: _m1),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: venues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final venue = venues[i];
        return _InfoPanel(
          title: venue.name,
          children: [
            _InfoLine(
              'City',
              venue.city.isEmpty ? tournament.location : venue.city,
            ),
            _InfoLine(
              'Address',
              venue.address.isEmpty ? 'Not added' : venue.address,
            ),
            _InfoLine(
              'Capacity',
              venue.capacity == 0 ? 'Not specified' : '${venue.capacity}',
            ),
            _InfoLine('Floodlights', venue.hasFloodlights ? 'Yes' : 'No'),
          ],
        );
      },
    );
  }
}

class _TournamentForecastPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentMatch> matches;
  final List<TournamentVenue> venues;
  const _TournamentForecastPane({
    required this.tournament,
    required this.matches,
    required this.venues,
  });

  @override
  Widget build(BuildContext context) {
    final next = [...matches]
      ..sort(
        (a, b) => (a.scheduledAt ?? DateTime(2100)).compareTo(
          b.scheduledAt ?? DateTime(2100),
        ),
      );
    final nextMatch = next.where((m) => !m.isPlayed).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nextMatch != null)
          _InfoPanel(
            title: 'Next Match',
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nextMatch.teamAName ?? 'Team A',
                      style: _t(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'vs',
                    style: _t(size: 13, color: _m1, weight: FontWeight.w900),
                  ),
                  Expanded(
                    child: Text(
                      nextMatch.teamBName ?? 'Team B',
                      textAlign: TextAlign.end,
                      style: _t(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          const _EmptyPane(label: 'No upcoming match available'),
        const SizedBox(height: 14),
        _InfoPanel(
          title: 'Forecast',
          children: [
            Text(
              'Weather integration is not connected yet. Use venue and schedule details to plan the next match.',
              style: _t(size: 13, color: _m1),
            ),
          ],
        ),
      ],
    );
  }
}

class _WebTableStat {
  final String teamId;
  final String name;
  int played = 0;
  int won = 0;
  int lost = 0;
  int drawn = 0;
  int scoreFor = 0;
  int scoreAgainst = 0;
  final int wPts;
  final int dPts;
  final int lPts;

  _WebTableStat(
    this.teamId,
    this.name, {
    required this.wPts,
    required this.dPts,
    required this.lPts,
  });

  int get pts => (won * wPts) + (drawn * dPts) + (lost * lPts);
  double get diff => played == 0 ? 0 : (scoreFor - scoreAgainst).toDouble();
}

class _PointsTable extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  const _PointsTable({
    required this.tournament,
    required this.teams,
    required this.matches,
  });

  List<_WebTableStat> _buildStats() {
    final stats = {
      for (final team in teams)
        team.id: _WebTableStat(
          team.id,
          team.teamName,
          wPts: tournament.winPoints,
          dPts: tournament.drawPoints,
          lPts: tournament.lossPoints,
        ),
    };

    for (final match in matches) {
      if (!match.isPlayed || match.isBye) continue;
      _accumulate(
        stats,
        match.teamAId,
        match.scoreA,
        match.scoreB,
        match.result,
        true,
      );
      _accumulate(
        stats,
        match.teamBId,
        match.scoreB,
        match.scoreA,
        match.result,
        false,
      );
    }

    final rows = stats.values.toList()
      ..sort((a, b) {
        final ptsCompare = b.pts.compareTo(a.pts);
        if (ptsCompare != 0) return ptsCompare;
        final winsCompare = b.won.compareTo(a.won);
        if (winsCompare != 0) return winsCompare;
        return b.diff.compareTo(a.diff);
      });
    return rows;
  }

  void _accumulate(
    Map<String, _WebTableStat> stats,
    String? teamId,
    int? scoreFor,
    int? scoreAgainst,
    TournamentMatchResult result,
    bool isTeamA,
  ) {
    if (teamId == null || !stats.containsKey(teamId)) return;
    final row = stats[teamId]!;
    row.played++;
    row.scoreFor += scoreFor ?? 0;
    row.scoreAgainst += scoreAgainst ?? 0;
    switch (result) {
      case TournamentMatchResult.teamAWin:
        if (isTeamA) {
          row.won++;
        } else {
          row.lost++;
        }
      case TournamentMatchResult.teamBWin:
        if (isTeamA) {
          row.lost++;
        } else {
          row.won++;
        }
      case TournamentMatchResult.draw:
        row.drawn++;
      case TournamentMatchResult.pending:
      case TournamentMatchResult.bye:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const _EmptyPane(label: 'No teams in table yet');
    final sorted = _buildStats();
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Points Table',
                style: _t(size: 16, weight: FontWeight.w900),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _TableHeader(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              itemCount: sorted.length,
              itemBuilder: (context, i) =>
                  _TeamTableRow(index: i + 1, stat: sorted[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 34),
          Expanded(
            child: Text(
              'TEAM',
              style: _t(size: 11, color: _m1, weight: FontWeight.w800),
            ),
          ),
          for (final label in ['M', 'W', 'L', 'D', 'PTS'])
            SizedBox(
              width: 46,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: _t(
                  size: 11,
                  color: label == 'PTS' ? _red : _m1,
                  weight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamTableRow extends StatelessWidget {
  final int index;
  final _WebTableStat stat;
  const _TeamTableRow({required this.index, required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('$index', style: _t(size: 12, color: _m1)),
          ),
          Expanded(
            child: Text(
              stat.name,
              style: _t(size: 13, weight: FontWeight.w700),
            ),
          ),
          for (final value in [
            stat.played,
            stat.won,
            stat.lost,
            stat.drawn,
            stat.pts,
          ])
            SizedBox(
              width: 46,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: _t(
                  size: 12,
                  color: value == stat.pts ? _red : _m1,
                  weight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TournamentBracketPane extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentMatch> matches;
  final bool fullscreen;
  const _TournamentBracketPane({
    required this.tournament,
    required this.matches,
    this.fullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return _InfoPanel(
        title: 'Bracket',
        children: [
          Text(
            'No bracket has been generated yet. Hosts can generate schedule from Manage Tournament.',
            style: _t(size: 13, color: _m1),
          ),
        ],
      );
    }
    final byRound = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }
    final rounds = byRound.keys.toList()..sort();
    final bracket = _BracketRoundsView(
      tournament: tournament,
      rounds: rounds,
      byRound: byRound,
      fullscreen: fullscreen,
    );

    if (fullscreen) return bracket;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _OutlineBtn(
          label: 'Full Screen',
          icon: Icons.fullscreen_rounded,
          onTap: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: .86),
            builder: (_) => _BracketFullscreenDialog(
              tournament: tournament,
              matches: matches,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: bracket),
      ],
    );
  }
}

class _BracketRoundsView extends StatelessWidget {
  final Tournament tournament;
  final List<int> rounds;
  final Map<int, List<TournamentMatch>> byRound;
  final bool fullscreen;

  const _BracketRoundsView({
    required this.tournament,
    required this.rounds,
    required this.byRound,
    required this.fullscreen,
  });

  @override
  Widget build(BuildContext context) {
    if (fullscreen) {
      return _BracketFullscreenCanvas(
        tournament: tournament,
        rounds: rounds,
        byRound: byRound,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final spacing = fullscreen ? 24.0 : 18.0;
        final sidePadding = fullscreen ? 28.0 : 0.0;
        final availableWidth =
            viewportWidth - (sidePadding * 2) - (spacing * (rounds.length - 1));
        var roundWidth = fullscreen
            ? availableWidth / (rounds.isEmpty ? 1 : rounds.length)
            : 260.0;
        if (fullscreen && roundWidth < 360) roundWidth = 360;
        if (fullscreen && roundWidth > 560) roundWidth = 560;
        final requiredWidth =
            (roundWidth * rounds.length) +
            (spacing * (rounds.length - 1)) +
            (sidePadding * 2);
        final canvasWidth = requiredWidth > viewportWidth
            ? requiredWidth
            : viewportWidth;
        final firstRoundMatches = byRound[rounds.first]?.length ?? 1;
        final slotHeight = _kWebBracketCardH + _kWebBracketGap;
        final canvasHeight = math.max(560.0, firstRoundMatches * slotHeight);

        return InteractiveViewer(
          minScale: fullscreen ? .45 : .65,
          maxScale: fullscreen ? 2.6 : 2.2,
          boundaryMargin: EdgeInsets.all(fullscreen ? 360 : 220),
          constrained: false,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Padding(
              padding: EdgeInsets.all(sidePadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < rounds.length; i++) ...[
                    SizedBox(
                      width: roundWidth,
                      height: canvasHeight - (sidePadding * 2),
                      child: _BracketRoundColumn(
                        tournament: tournament,
                        round: rounds[i],
                        matches: byRound[rounds[i]]!,
                        fullscreen: fullscreen,
                        totalHeight: canvasHeight - (sidePadding * 2),
                      ),
                    ),
                    if (i != rounds.length - 1)
                      SizedBox(
                        width: _kWebBracketConnectorW,
                        height: canvasHeight - (sidePadding * 2),
                        child: CustomPaint(
                          painter: _WebBracketConnectorPainter(
                            matchCount: byRound[rounds[i]]!.length,
                            totalHeight: canvasHeight - (sidePadding * 2),
                            cardHeight: _kWebBracketCardH,
                          ),
                        ),
                      ),
                    if (i != rounds.length - 1) SizedBox(width: spacing),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BracketFullscreenCanvas extends StatefulWidget {
  final Tournament tournament;
  final List<int> rounds;
  final Map<int, List<TournamentMatch>> byRound;

  const _BracketFullscreenCanvas({
    required this.tournament,
    required this.rounds,
    required this.byRound,
  });

  @override
  State<_BracketFullscreenCanvas> createState() =>
      _BracketFullscreenCanvasState();
}

class _BracketFullscreenCanvasState extends State<_BracketFullscreenCanvas> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        const spacing = 24.0;
        const sidePadding = 28.0;
        final firstRoundMatches =
            widget.byRound[widget.rounds.first]?.length ?? 1;
        final slotHeight = _kWebBracketCardH + _kWebBracketGap;
        final canvasHeight = math.max(560.0, firstRoundMatches * slotHeight);
        final availableWidth =
            viewportWidth -
            (sidePadding * 2) -
            (spacing * (widget.rounds.length - 1));
        var roundWidth = availableWidth / widget.rounds.length.clamp(1, 99);
        if (roundWidth < 360) roundWidth = 360;
        if (roundWidth > 560) roundWidth = 560;

        return Scrollbar(
          controller: _vertical,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vertical,
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: Scrollbar(
              controller: _horizontal,
              thumbVisibility: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                child: SizedBox(
                  height: canvasHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.rounds.length; i++) ...[
                        SizedBox(
                          width: roundWidth,
                          height: canvasHeight,
                          child: _BracketRoundColumn(
                            tournament: widget.tournament,
                            round: widget.rounds[i],
                            matches: widget.byRound[widget.rounds[i]]!,
                            fullscreen: true,
                            totalHeight: canvasHeight,
                          ),
                        ),
                        if (i != widget.rounds.length - 1)
                          SizedBox(
                            width: _kWebBracketConnectorW,
                            height: canvasHeight,
                            child: CustomPaint(
                              painter: _WebBracketConnectorPainter(
                                matchCount:
                                    widget.byRound[widget.rounds[i]]!.length,
                                totalHeight: canvasHeight,
                                cardHeight: _kWebBracketCardH,
                              ),
                            ),
                          ),
                        if (i != widget.rounds.length - 1)
                          const SizedBox(width: spacing),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BracketRoundColumn extends StatelessWidget {
  final Tournament tournament;
  final int round;
  final List<TournamentMatch> matches;
  final bool fullscreen;
  final double totalHeight;

  const _BracketRoundColumn({
    required this.tournament,
    required this.round,
    required this.matches,
    required this.fullscreen,
    required this.totalHeight,
  });

  @override
  Widget build(BuildContext context) {
    final roundSlotHeight = totalHeight / matches.length.clamp(1, 999);
    return Container(
      padding: EdgeInsets.all(fullscreen ? 20 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(fullscreen ? 22 : 14),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round $round',
            style: _t(size: fullscreen ? 20 : 15, weight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Stack(
              children: [
                for (var i = 0; i < matches.length; i++)
                  Positioned(
                    top:
                        i * roundSlotHeight +
                        (roundSlotHeight - _kWebBracketCardH) / 2,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: _kWebBracketCardH,
                      child: _BracketMatchCard(
                        tournament: tournament,
                        match: matches[i],
                        fullscreen: fullscreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  final Tournament tournament;
  final TournamentMatch match;
  final bool fullscreen;

  const _BracketMatchCard({
    required this.tournament,
    required this.match,
    required this.fullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final teamAWinner = _isWinningSide(
      match,
      isTeamA: true,
      displayName: match.teamAName,
    );
    final teamBWinner = _isWinningSide(
      match,
      isTeamA: false,
      displayName: match.teamBName,
    );
    return Container(
      width: double.infinity,
      height: _kWebBracketCardH,
      padding: EdgeInsets.all(fullscreen ? 18 : 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(fullscreen ? 18 : 12),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BracketTeamLine(
            name: match.teamAName ?? 'TBD',
            winner: teamAWinner,
            fullscreen: fullscreen,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: fullscreen ? 8 : 4),
            child: Text(
              'vs',
              style: _t(size: fullscreen ? 13 : 11, color: _m1),
            ),
          ),
          _BracketTeamLine(
            name: match.teamBName ?? 'TBD',
            winner: teamBWinner,
            fullscreen: fullscreen,
          ),
          if (match.scheduledAt != null ||
              (_resolvedMatchVenueName(tournament, match) ?? '')
                  .isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (match.scheduledAt != null)
                  _miniMeta(
                    Icons.schedule_rounded,
                    '${match.scheduledAt!.day} ${_monthShort(match.scheduledAt!.month)} ${match.scheduledAt!.year}',
                  ),
                if ((_resolvedMatchVenueName(tournament, match) ?? '')
                    .isNotEmpty)
                  _miniMeta(
                    Icons.stadium_rounded,
                    _resolvedMatchVenueName(tournament, match)!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

bool _isWinningSide(
  TournamentMatch match, {
  required bool isTeamA,
  String? displayName,
}) {
  if (match.result == TournamentMatchResult.teamAWin) return isTeamA;
  if (match.result == TournamentMatchResult.teamBWin) return !isTeamA;

  final winnerId = match.winnerId?.trim();
  if (winnerId != null && winnerId.isNotEmpty) {
    if (isTeamA && winnerId == match.teamAId) return true;
    if (!isTeamA && winnerId == match.teamBId) return true;
  }

  final winnerName = match.winnerName?.trim().toLowerCase();
  final sideName = (displayName ?? '').trim().toLowerCase();
  if (winnerName != null &&
      winnerName.isNotEmpty &&
      sideName.isNotEmpty &&
      winnerName == sideName) {
    return true;
  }

  return false;
}

class _WebBracketConnectorPainter extends CustomPainter {
  final int matchCount;
  final double totalHeight;
  final double cardHeight;

  const _WebBracketConnectorPainter({
    required this.matchCount,
    required this.totalHeight,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _red.withValues(alpha: .24)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final slotHeight = totalHeight / matchCount.clamp(1, 999);
    for (var i = 0; i < matchCount; i += 2) {
      final topY =
          i * slotHeight + (slotHeight - cardHeight) / 2 + (cardHeight / 2);
      final bottomY = (i + 1) < matchCount
          ? (i + 1) * slotHeight +
                (slotHeight - cardHeight) / 2 +
                (cardHeight / 2)
          : topY;
      final midY = (topY + bottomY) / 2;
      final midX = size.width / 2;

      canvas.drawLine(Offset(0, topY), Offset(midX, topY), paint);
      if ((i + 1) < matchCount) {
        canvas.drawLine(Offset(0, bottomY), Offset(midX, bottomY), paint);
      }
      canvas.drawLine(Offset(midX, topY), Offset(midX, bottomY), paint);
      canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WebBracketConnectorPainter oldDelegate) {
    return oldDelegate.matchCount != matchCount ||
        oldDelegate.totalHeight != totalHeight ||
        oldDelegate.cardHeight != cardHeight;
  }
}

class _BracketTeamLine extends StatelessWidget {
  final String name;
  final bool winner;
  final bool fullscreen;

  const _BracketTeamLine({
    required this.name,
    required this.winner,
    required this.fullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (winner) ...[
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD54F),
            size: 16,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _t(
              size: fullscreen ? 18 : 13,
              color: winner ? const Color(0xFFFFD54F) : _tx,
              weight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BracketFullscreenDialog extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentMatch> matches;

  const _BracketFullscreenDialog({
    required this.tournament,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: _bg,
      child: Column(
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: _card,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _sportIcon(tournament.sport),
                  color: _sportAccent(tournament.sport),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(size: 18, weight: FontWeight.w900),
                      ),
                      Text(
                        'Full bracket view',
                        style: _t(size: 12, color: _m1),
                      ),
                    ],
                  ),
                ),
                _OutlineBtn(
                  label: 'Close',
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _TournamentBracketPane(
              tournament: tournament,
              matches: matches,
              fullscreen: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentManagePane extends StatefulWidget {
  final Tournament tournament;
  final List<TournamentTeam> teams;
  final List<TournamentMatch> matches;
  final List<TournamentGroup> groups;
  final List<TournamentVenue> venues;
  final List<TournamentAdmin> admins;
  final bool isHost;
  final VoidCallback onCloseDialog;

  const _TournamentManagePane({
    required this.tournament,
    required this.teams,
    required this.matches,
    required this.groups,
    required this.venues,
    required this.admins,
    required this.isHost,
    required this.onCloseDialog,
  });

  @override
  State<_TournamentManagePane> createState() => _TournamentManagePaneState();
}

class _TournamentManagePaneState extends State<_TournamentManagePane> {
  bool _busy = false;

  Future<void> _confirm({
    required String title,
    required String message,
    required String action,
    required Future<void> Function() run,
    bool closesDialog = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(title, style: _t(size: 17, weight: FontWeight.w900)),
        content: Text(message, style: _t(size: 13, color: _m1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: _t(size: 13, color: _m1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action,
              style: _t(size: 13, color: _red, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await run();
      if (closesDialog && mounted) widget.onCloseDialog();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTournament() => _confirm(
    title: 'Start Tournament?',
    message: 'This marks the tournament as ongoing.',
    action: 'Start',
    run: () => TournamentService().updateTournamentStatus(
      widget.tournament.id,
      TournamentStatus.ongoing,
    ),
  );

  Future<void> _generateSchedule() => _confirm(
    title: 'Generate Schedule?',
    message: 'This will generate tournament matches based on registered teams.',
    action: 'Generate',
    run: () => TournamentService().generateSchedule(widget.tournament.id),
  );

  Future<void> _resetTeams() => _confirm(
    title: 'Reset Teams & Matches?',
    message:
        'Deletes all registered teams, matches, and points. This cannot be undone.',
    action: 'Reset',
    run: () => TournamentService().clearTeamsAndMatches(widget.tournament.id),
  );

  Future<void> _deleteTournament() => _confirm(
    title: 'Delete Tournament?',
    message:
        'Permanently deletes this tournament and all its data. This cannot be undone.',
    action: 'Delete',
    closesDialog: true,
    run: () => TournamentService().deleteTournament(widget.tournament.id),
  );

  Future<void> _openWebManager({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WebManagerDialog(
        title: title,
        icon: icon,
        color: color,
        child: child,
      ),
    );
    if (mounted) {
      await TournamentService().loadDetail(widget.tournament.id);
    }
  }

  Future<void> _showTeamsManager() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WebTeamsManagerDialog(tournament: widget.tournament),
    );
    if (mounted) {
      await TournamentService().loadDetail(widget.tournament.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(widget.tournament.status).toUpperCase();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoPanel(
            title: 'Tournament Status',
            children: [
              Row(
                children: [
                  Text('Status:', style: _t(size: 13, color: _m1)),
                  const SizedBox(width: 8),
                  _Badge(
                    label: status,
                    color: _sportAccent(widget.tournament.sport),
                  ),
                  const Spacer(),
                  if (widget.tournament.status == TournamentStatus.open)
                    _OutlineBtn(
                      label: 'Starts today',
                      icon: Icons.event_available_outlined,
                      onTap: _busy ? null : _startTournament,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Tournament has ${widget.teams.length} teams registered and ${widget.matches.length} matches scheduled.',
                style: _t(size: 13, color: _m1),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _RedBtn(
                    label: _busy ? 'Working...' : 'Start Tournament',
                    onTap: _busy ? null : _startTournament,
                  ),
                  _OutlineBtn(
                    label: 'Generate Schedule',
                    icon: Icons.auto_awesome_rounded,
                    onTap: _busy ? null : _generateSchedule,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoPanel(
            title: 'Join Code',
            children: [
              Row(
                children: [
                  Icon(Icons.key_rounded, color: _m1, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    widget.tournament.joinCode ?? 'Public tournament',
                    style: _t(size: 18, weight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Manage',
            style: _t(size: 12, color: _m1, weight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 132,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: [
              _ManageActionCard(
                title: 'Edit Tournament',
                subtitle: 'Update basic tournament details',
                icon: Icons.edit_outlined,
                color: Colors.blue,
                onTap: widget.isHost
                    ? () => _openWebManager(
                        title: 'Edit Tournament',
                        icon: Icons.edit_outlined,
                        color: Colors.blue,
                        child: _WebEditTournamentPanel(
                          tournament: widget.tournament,
                        ),
                      )
                    : null,
              ),
              _ManageActionCard(
                title: 'Manage Teams',
                subtitle: '${widget.teams.length} registered teams',
                icon: Icons.groups_outlined,
                color: _red,
                badge: '${widget.teams.length}',
                onTap: _showTeamsManager,
              ),
              _ManageActionCard(
                title: 'Groups',
                subtitle: '${widget.groups.length} groups',
                icon: Icons.account_tree_outlined,
                color: Colors.deepPurple,
                onTap: () => _openWebManager(
                  title: 'Groups',
                  icon: Icons.account_tree_outlined,
                  color: Colors.deepPurple,
                  child: _WebGroupsPanel(tournament: widget.tournament),
                ),
              ),
              _ManageActionCard(
                title: 'Schedule Matches',
                subtitle: '${widget.matches.length} matches',
                icon: Icons.calendar_month_outlined,
                color: Colors.indigo,
                onTap: () => _openWebManager(
                  title: 'Schedule Matches',
                  icon: Icons.calendar_month_outlined,
                  color: Colors.indigo,
                  child: _WebSchedulePanel(tournament: widget.tournament),
                ),
              ),
              _ManageActionCard(
                title: 'Squads',
                subtitle: 'Review team rosters',
                icon: Icons.badge_outlined,
                color: Colors.purple,
                onTap: () => _openWebManager(
                  title: 'Squads',
                  icon: Icons.badge_outlined,
                  color: Colors.purple,
                  child: _WebSquadsPanel(tournament: widget.tournament),
                ),
              ),
              _ManageActionCard(
                title: 'Venues',
                subtitle: '${widget.venues.length} venues',
                icon: Icons.stadium_outlined,
                color: Colors.teal,
                onTap: () => _openWebManager(
                  title: 'Venues',
                  icon: Icons.stadium_outlined,
                  color: Colors.teal,
                  child: _WebVenuesManagerPanel(tournament: widget.tournament),
                ),
              ),
              _ManageActionCard(
                title: 'Admins',
                subtitle: '${widget.admins.length} admins',
                icon: Icons.admin_panel_settings_outlined,
                color: Colors.deepOrange,
                onTap: widget.isHost
                    ? () => _openWebManager(
                        title: 'Admins',
                        icon: Icons.admin_panel_settings_outlined,
                        color: Colors.deepOrange,
                        child: _WebAdminsPanel(tournament: widget.tournament),
                      )
                    : null,
              ),
            ],
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 18),
            Text(
              'Danger Zone',
              style: _t(size: 12, color: _m1, weight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _DangerAction(
              title: 'Reset Teams & Matches',
              subtitle:
                  'Deletes all registered teams, matches and points. Cannot be undone.',
              icon: Icons.cleaning_services_outlined,
              onTap: _busy ? null : _resetTeams,
            ),
            const SizedBox(height: 10),
            _DangerAction(
              title: 'Delete Tournament',
              subtitle:
                  'Permanently deletes this tournament and all its data. Cannot be undone.',
              icon: Icons.delete_forever_outlined,
              onTap: _busy ? null : _deleteTournament,
            ),
          ],
        ],
      ),
    );
  }
}

class _WebManagerDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _WebManagerDialog({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(26),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 780),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: _t(size: 21, weight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _m1),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: .07)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _webInputDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: _t(size: 13, color: _m1),
    prefixIcon: icon == null ? null : Icon(icon, color: _m1, size: 18),
    filled: true,
    fillColor: Colors.white.withValues(alpha: .04),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _red, width: 1.4),
    ),
  );
}

class _WebEditTournamentPanel extends StatefulWidget {
  final Tournament tournament;
  const _WebEditTournamentPanel({required this.tournament});

  @override
  State<_WebEditTournamentPanel> createState() =>
      _WebEditTournamentPanelState();
}

class _WebEditTournamentPanelState extends State<_WebEditTournamentPanel> {
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _maxTeams;
  late final TextEditingController _players;
  late final TextEditingController _entryFee;
  late final TextEditingController _serviceFee;
  late final TextEditingController _prize;
  late final TextEditingController _rules;
  late DateTime _start;
  DateTime? _end;
  late TournamentFormat _format;
  late ScoringType _scoringType;
  late bool _sameScoreAllRounds;
  late int _bestOf;
  late int _pointsToWin;
  late int _winPoints;
  late int _drawPoints;
  late int _lossPoints;
  late final TextEditingController _customScoringLabel;
  late Map<String, dynamic> _roundScoringConfig;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tournament;
    _name = TextEditingController(text: t.name);
    _location = TextEditingController(text: t.location);
    _maxTeams = TextEditingController(text: '${t.maxTeams}');
    _players = TextEditingController(text: '${t.playersPerTeam}');
    _entryFee = TextEditingController(text: '${t.entryFee}');
    _serviceFee = TextEditingController(text: '${t.serviceFee}');
    _prize = TextEditingController(text: t.prizePool ?? '');
    _rules = TextEditingController(text: t.rules ?? '');
    _customScoringLabel = TextEditingController(
      text: t.customScoringLabel ?? '',
    );
    _start = t.startDate;
    _end = t.endDate;
    _format = t.format;
    _scoringType = t.scoringType;
    _sameScoreAllRounds = t.sameScoreAllRounds;
    _bestOf = _uiSetsToWinFromStoredBestOf(t.bestOf);
    _pointsToWin = t.pointsToWin;
    _winPoints = t.winPoints;
    _drawPoints = t.drawPoints;
    _lossPoints = t.lossPoints;
    _roundScoringConfig = Map<String, dynamic>.from(
      t.roundScoringConfig ?? const {},
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _maxTeams.dispose();
    _players.dispose();
    _entryFee.dispose();
    _serviceFee.dispose();
    _prize.dispose();
    _rules.dispose();
    _customScoringLabel.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool end) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? (_end ?? _start) : _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => end ? _end = picked : _start = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TournamentService().updateTournament(
        tournamentId: widget.tournament.id,
        name: _name.text.trim(),
        sport: widget.tournament.sport,
        format: _format,
        startDate: _start,
        location: _location.text.trim(),
        maxTeams:
            int.tryParse(_maxTeams.text.trim()) ?? widget.tournament.maxTeams,
        entryFee:
            double.tryParse(_entryFee.text.trim()) ??
            widget.tournament.entryFee,
        serviceFee:
            double.tryParse(_serviceFee.text.trim()) ??
            widget.tournament.serviceFee,
        playersPerTeam:
            int.tryParse(_players.text.trim()) ??
            widget.tournament.playersPerTeam,
        endDate: _end,
        prizePool: _prize.text.trim().isEmpty ? null : _prize.text.trim(),
        rules: _rules.text.trim().isEmpty ? null : _rules.text.trim(),
        scoringType: _scoringType,
        bestOf: _storedBestOfFromUiSetsToWin(_bestOf),
        pointsToWin: _pointsToWin,
        winPoints: _winPoints,
        drawPoints: _drawPoints,
        lossPoints: _lossPoints,
        customScoringLabel: _customScoringLabel.text.trim().isEmpty
            ? null
            : _customScoringLabel.text.trim(),
        sameScoreAllRounds: _sameScoreAllRounds,
        roundScoringConfig: _sameScoreAllRounds ? null : _roundScoringConfig,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String date(DateTime d) => '${d.day} ${_monthShort(d.month)} ${d.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 500,
              child: _labeled(
                'Tournament Name',
                _name,
                Icons.emoji_events_outlined,
              ),
            ),
            SizedBox(
              width: 220,
              child: _labeled(
                'Location',
                _location,
                Icons.location_on_outlined,
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<TournamentFormat>(
                initialValue: _format,
                dropdownColor: _card,
                decoration: _webInputDecoration('Format'),
                style: _t(size: 13),
                items: TournamentFormat.values
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(_formatLabel(f)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _format = v ?? _format),
              ),
            ),
            SizedBox(
              width: 160,
              child: _labeled(
                'Max Teams',
                _maxTeams,
                Icons.groups_outlined,
                number: true,
              ),
            ),
            SizedBox(
              width: 180,
              child: _labeled(
                'Players / Team',
                _players,
                Icons.person_outline,
                number: true,
              ),
            ),
            SizedBox(
              width: 160,
              child: _labeled(
                'Entry Fee',
                _entryFee,
                Icons.attach_money_rounded,
                number: true,
              ),
            ),
            SizedBox(
              width: 160,
              child: _labeled(
                'Service Fee',
                _serviceFee,
                Icons.payments_outlined,
                number: true,
              ),
            ),
            _DateButton(
              label: 'Start Date',
              value: date(_start),
              onTap: () => _pickDate(false),
            ),
            _DateButton(
              label: 'End Date',
              value: _end == null ? 'Not set' : date(_end!),
              onTap: () => _pickDate(true),
            ),
            SizedBox(
              width: 300,
              child: _labeled(
                'Prize Pool',
                _prize,
                Icons.workspace_premium_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _rules,
          maxLines: 4,
          style: _t(size: 13),
          decoration: _webInputDecoration('Rules and notes'),
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          title: 'Scoring',
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<ScoringType>(
                    initialValue: _scoringType,
                    dropdownColor: _card,
                    decoration: _webInputDecoration('Scoring Type'),
                    style: _t(size: 13),
                    items: ScoringType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_scoringTypeLabel(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _scoringType = value ?? _scoringType),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: _stepperField(
                    label: 'Sets To Win',
                    value: _bestOf,
                    onChanged: (value) =>
                        setState(() => _bestOf = value < 1 ? 1 : value),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _stepperField(
                    label: 'Points To Win',
                    value: _pointsToWin,
                    onChanged: (value) => setState(() => _pointsToWin = value),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _stepperField(
                    label: 'Win Points',
                    value: _winPoints,
                    onChanged: (value) => setState(() => _winPoints = value),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _stepperField(
                    label: 'Draw Points',
                    value: _drawPoints,
                    onChanged: (value) => setState(() => _drawPoints = value),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _stepperField(
                    label: 'Loss Points',
                    value: _lossPoints,
                    onChanged: (value) => setState(() => _lossPoints = value),
                  ),
                ),
                if (_scoringType == ScoringType.custom)
                  SizedBox(
                    width: 260,
                    child: _labeled(
                      'Custom Score Label',
                      _customScoringLabel,
                      Icons.label_outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _ToggleRow(
              title: 'Same Scoring For All Rounds',
              subtitle:
                  'Turn this off to set different scoring for quarterfinals, semifinals, and finals.',
              value: _sameScoreAllRounds,
              onChanged: (value) => setState(() => _sameScoreAllRounds = value),
            ),
            if (!_sameScoreAllRounds) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _roundScoreCard('quarterFinal', 'Quarterfinals'),
                  _roundScoreCard('semiFinal', 'Semifinals'),
                  _roundScoreCard('final', 'Final'),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: _RedBtn(
            label: _saving ? 'Saving...' : 'Save Changes',
            onTap: _saving ? null : _save,
          ),
        ),
      ],
    );
  }

  Widget _labeled(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool number = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: ctrl,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          style: _t(size: 13),
          decoration: _webInputDecoration(label, icon: icon),
        ),
      ],
    );
  }

  Widget _stepperField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onChanged((value > 0 ? value - 1 : 0)),
                icon: const Icon(Icons.remove_rounded, color: _m1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: _t(size: 14, weight: FontWeight.w800),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_rounded, color: _m1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundScoreCard(String key, String title) {
    final config = Map<String, dynamic>.from(
      (_roundScoringConfig[key] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final bestOf = _uiSetsToWinFromStoredBestOf(
      (config['bestOf'] as num?)?.toInt() ??
          _storedBestOfFromUiSetsToWin(_bestOf),
    );
    final pointsToWin =
        (config['pointsToWin'] as num?)?.toInt() ?? _pointsToWin;

    void setValue(String field, int value) {
      final updated = Map<String, dynamic>.from(config);
      updated[field] = field == 'bestOf'
          ? _storedBestOfFromUiSetsToWin(value)
          : value;
      setState(() => _roundScoringConfig[key] = updated);
    }

    return SizedBox(
      width: 280,
      child: _MiniPanel(
        title: title,
        subtitle: 'Override default scoring for this stage',
        child: Column(
          children: [
            _stepperField(
              label: 'Sets To Win',
              value: bestOf,
              onChanged: (value) => setValue('bestOf', value),
            ),
            const SizedBox(height: 12),
            _stepperField(
              label: 'Points To Win',
              value: pointsToWin,
              onChanged: (value) => setValue('pointsToWin', value),
            ),
          ],
        ),
      ),
    );
  }
}

String _scoringTypeLabel(ScoringType type) {
  switch (type) {
    case ScoringType.standard:
      return 'Standard';
    case ScoringType.bestOfSets:
      return 'Best Of Sets';
    case ScoringType.points:
      return 'Points Table';
    case ScoringType.custom:
      return 'Custom';
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        _OutlineBtn(
          label: value,
          icon: Icons.calendar_month_outlined,
          onTap: onTap,
        ),
      ],
    ),
  );
}

class _WebGroupsPanel extends StatefulWidget {
  final Tournament tournament;
  const _WebGroupsPanel({required this.tournament});
  @override
  State<_WebGroupsPanel> createState() => _WebGroupsPanelState();
}

class _WebGroupsPanelState extends State<_WebGroupsPanel> {
  late int _count;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _count = widget.tournament.groupCount > 0
        ? widget.tournament.groupCount
        : 0;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc = TournamentService();
        final groups = svc.groupsFor(widget.tournament.id);
        final teams = svc.teamsFor(widget.tournament.id);
        final assigned = groups.expand((g) => g.teamIds).toSet();
        final unassigned = teams
            .where((t) => !assigned.contains(t.id))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: _count,
                    dropdownColor: _card,
                    decoration: _webInputDecoration('Groups'),
                    style: _t(size: 13),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('No groups'),
                      ),
                      ...List.generate(7, (i) => i + 2).map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text('$v groups'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _count = v ?? 2),
                  ),
                ),
                const SizedBox(width: 10),
                _RedBtn(
                  label: _busy
                      ? 'Working...'
                      : _count == 0
                      ? 'Remove Groups'
                      : 'Create / Reconfigure',
                  onTap: _busy
                      ? null
                      : () => _run(
                          () => _count == 0
                              ? svc.deleteAllGroups(widget.tournament.id)
                              : svc.createGroups(widget.tournament.id, _count),
                        ),
                ),
                const Spacer(),
                _OutlineBtn(
                  label: 'Generate Group Matches',
                  icon: Icons.auto_awesome_rounded,
                  onTap: _busy
                      ? null
                      : () => _run(() async {
                          for (final g in groups) {
                            if (g.teamIds.length >= 2) {
                              await svc.generateGroupMatches(
                                widget.tournament.id,
                                g.id,
                              );
                            }
                          }
                        }),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (groups.isEmpty)
              _emptyText('No groups yet. Create groups above.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: groups.map((g) {
                  return SizedBox(
                    width: 320,
                    child: _MiniPanel(
                      title: g.name,
                      subtitle: '${g.teamIds.length} teams',
                      child: Column(
                        children: [
                          ...g.teamIds.map(
                            (id) => _row(
                              g.teamNames[id] ?? 'Team',
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: _m1,
                                  size: 17,
                                ),
                                onPressed: () => _run(
                                  () => svc.removeTeamFromGroup(
                                    tournamentId: widget.tournament.id,
                                    groupId: g.id,
                                    teamId: id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (unassigned.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: null,
                              dropdownColor: _card,
                              decoration: _webInputDecoration('Add team'),
                              style: _t(size: 13),
                              items: unassigned
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t.id,
                                      child: Text(t.teamName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) {
                                final team = unassigned.firstWhere(
                                  (t) => t.id == id,
                                );
                                _run(
                                  () => svc.assignTeamToGroup(
                                    tournamentId: widget.tournament.id,
                                    groupId: g.id,
                                    teamId: team.id,
                                    teamName: team.teamName,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }
}

class _WebSchedulePanel extends StatefulWidget {
  final Tournament tournament;
  final bool fullscreen;
  const _WebSchedulePanel({required this.tournament, this.fullscreen = false});

  @override
  State<_WebSchedulePanel> createState() => _WebSchedulePanelState();
}

class _WebSchedulePanelState extends State<_WebSchedulePanel> {
  int _tab = 0;
  TournamentTeam? _slotA;
  TournamentTeam? _slotB;
  final _roundCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _roundCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _assignTeam(TournamentTeam team) {
    setState(() {
      if (_slotA?.id == team.id) {
        _slotA = null;
      } else if (_slotB?.id == team.id) {
        _slotB = null;
      } else if (_slotA == null) {
        _slotA = team;
      } else {
        _slotB = team;
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await TournamentService().loadDetail(widget.tournament.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createManualMatch() async {
    final a = _slotA;
    final b = _slotB;
    if (a == null || b == null || a.id == b.id) return;
    await _run(() async {
      await TournamentService().createCustomMatch(
        tournamentId: widget.tournament.id,
        teamAId: a.id,
        teamAName: a.teamName,
        teamBId: b.id,
        teamBName: b.teamName,
        round: int.tryParse(_roundCtrl.text.trim()) ?? 1,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
    });
    if (!mounted) return;
    setState(() {
      _slotA = null;
      _slotB = null;
      _noteCtrl.clear();
    });
  }

  Future<void> _deleteMatch(TournamentMatch match) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text(
          'Delete Match',
          style: _t(size: 17, weight: FontWeight.w900),
        ),
        content: Text(
          'Delete ${match.teamAName ?? 'TBD'} vs ${match.teamBName ?? 'TBD'}?',
          style: _t(size: 13, color: _m1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: _t(size: 13, color: _m1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: _t(size: 13, color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => TournamentService().deleteMatch(widget.tournament.id, match.id),
    );
  }

  Future<void> _editMatch(TournamentMatch match) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .76),
      builder: (_) =>
          _WebMatchScheduleDialog(tournament: widget.tournament, match: match),
    );
    if (saved == true) {
      await TournamentService().loadDetail(widget.tournament.id);
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'No date set';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month}/${dt.year}  $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc = TournamentService();
        final teams = svc.teamsFor(widget.tournament.id);
        final matches = svc.matchesFor(widget.tournament.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!widget.fullscreen)
                  _OutlineBtn(
                    label: 'Full Screen',
                    icon: Icons.fullscreen_rounded,
                    onTap: () => showDialog<void>(
                      context: context,
                      barrierColor: Colors.black.withValues(alpha: .86),
                      builder: (_) => _ScheduleFullscreenDialog(
                        tournament: widget.tournament,
                      ),
                    ),
                  ),
                _RedBtn(
                  label: _busy ? 'Working...' : 'Generate Auto Schedule',
                  icon: Icons.auto_awesome_rounded,
                  onTap: _busy
                      ? null
                      : () => _run(
                          () => TournamentService().generateSchedule(
                            widget.tournament.id,
                          ),
                        ),
                ),
                _OutlineBtn(
                  label: 'View Bracket',
                  icon: Icons.account_tree_rounded,
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _WebScheduleTabs(
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            const SizedBox(height: 18),
            if (_tab == 0)
              _WebScheduleList(
                matches: matches,
                onEdit: _editMatch,
                onDelete: _deleteMatch,
                formatDate: _fmt,
              )
            else if (_tab == 1)
              _WebManualMatchBuilder(
                teams: teams,
                slotA: _slotA,
                slotB: _slotB,
                roundCtrl: _roundCtrl,
                noteCtrl: _noteCtrl,
                busy: _busy,
                onAssign: _assignTeam,
                onDropA: (team) => setState(() => _slotA = team),
                onDropB: (team) => setState(() => _slotB = team),
                onClear: () => setState(() {
                  _slotA = null;
                  _slotB = null;
                }),
                onCreate: _createManualMatch,
              )
            else
              SizedBox(
                height: widget.fullscreen ? 620 : 480,
                child: _TournamentBracketPane(
                  tournament: widget.tournament,
                  matches: matches,
                  fullscreen: widget.fullscreen,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WebScheduleTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _WebScheduleTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (Icons.event_note_rounded, 'Scheduled Matches'),
      (Icons.drag_indicator_rounded, 'Manual Builder'),
      (Icons.account_tree_rounded, 'Bracket'),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: _webBox(),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected == i ? _red : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[i].$1,
                        size: 15,
                        color: selected == i ? Colors.white : _m1,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        tabs[i].$2,
                        style: _t(
                          size: 13,
                          color: selected == i ? Colors.white : _m1,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebScheduleList extends StatelessWidget {
  final List<TournamentMatch> matches;
  final Future<void> Function(TournamentMatch) onEdit;
  final Future<void> Function(TournamentMatch) onDelete;
  final String Function(DateTime?) formatDate;

  const _WebScheduleList({
    required this.matches,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return _emptyText(
        'No matches yet. Generate an automatic schedule or build matches manually.',
      );
    }
    final byRound = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }
    final rounds = byRound.keys.toList()..sort();
    return Column(
      children: [
        for (final round in rounds) ...[
          Row(
            children: [
              _Badge(label: 'Round $round', color: _red),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: .08)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final match in byRound[round]!)
            _WebScheduleMatchRow(
              match: match,
              onEdit: () => onEdit(match),
              onDelete: () => onDelete(match),
              dateText: formatDate(match.scheduledAt),
            ),
        ],
      ],
    );
  }
}

class _WebScheduleMatchRow extends StatelessWidget {
  final TournamentMatch match;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String dateText;

  const _WebScheduleMatchRow({
    required this.match,
    required this.onEdit,
    required this.onDelete,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _webBox(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_score_rounded,
              color: _red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.teamAName ?? 'TBD'} vs ${match.teamBName ?? 'TBD'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(size: 14, weight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _miniMeta(Icons.schedule_rounded, dateText),
                    if ((_sanitizeVenueLabel(match.venueName) ?? '').isNotEmpty)
                      _miniMeta(
                        Icons.stadium_rounded,
                        _sanitizeVenueLabel(match.venueName)!,
                      ),
                    if ((match.note ?? '').isNotEmpty)
                      _miniMeta(Icons.label_rounded, match.note!),
                  ],
                ),
              ],
            ),
          ),
          _OutlineBtn(label: 'Edit', icon: Icons.edit_rounded, onTap: onEdit),
          const SizedBox(width: 8),
          _OutlineBtn(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

Widget _miniMeta(IconData icon, String text) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, color: _m2, size: 13),
    const SizedBox(width: 5),
    Text(text, style: _t(size: 12, color: _m1)),
  ],
);

class _WebManualMatchBuilder extends StatelessWidget {
  final List<TournamentTeam> teams;
  final TournamentTeam? slotA;
  final TournamentTeam? slotB;
  final TextEditingController roundCtrl;
  final TextEditingController noteCtrl;
  final bool busy;
  final ValueChanged<TournamentTeam> onAssign;
  final ValueChanged<TournamentTeam> onDropA;
  final ValueChanged<TournamentTeam> onDropB;
  final VoidCallback onClear;
  final VoidCallback onCreate;

  const _WebManualMatchBuilder({
    required this.teams,
    required this.slotA,
    required this.slotB,
    required this.roundCtrl,
    required this.noteCtrl,
    required this.busy,
    required this.onAssign,
    required this.onDropA,
    required this.onDropB,
    required this.onClear,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final ready = slotA != null && slotB != null && slotA!.id != slotB!.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Teams Pool', style: _t(size: 15, weight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (teams.isEmpty)
          _emptyText('No teams registered yet.')
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final team in teams)
                LongPressDraggable<TournamentTeam>(
                  data: team,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _WebScheduleTeamChip(team: team, selected: true),
                  ),
                  childWhenDragging: Opacity(
                    opacity: .36,
                    child: _WebScheduleTeamChip(team: team, selected: false),
                  ),
                  child: GestureDetector(
                    onTap: () => onAssign(team),
                    child: _WebScheduleTeamChip(
                      team: team,
                      selected: slotA?.id == team.id || slotB?.id == team.id,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 22),
        Text(
          'Drag teams into bracket slots',
          style: _t(size: 15, weight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _WebDropSlot(
                label: 'Team A',
                team: slotA,
                onDrop: onDropA,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'VS',
                style: _t(size: 14, color: _m1, weight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: _WebDropSlot(
                label: 'Team B',
                team: slotB,
                onDrop: onDropB,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final fields = [
              SizedBox(
                width: compact ? double.infinity : 120,
                child: TextField(
                  controller: roundCtrl,
                  keyboardType: TextInputType.number,
                  style: _t(size: 13),
                  decoration: _webInputDecoration('Round'),
                ),
              ),
              SizedBox(
                width: compact ? double.infinity : 340,
                child: TextField(
                  controller: noteCtrl,
                  style: _t(size: 13),
                  decoration: _webInputDecoration('Label (optional)'),
                ),
              ),
              _RedBtn(
                label: busy ? 'Saving...' : 'Create Match',
                icon: Icons.add_rounded,
                onTap: ready && !busy ? onCreate : null,
              ),
              if (slotA != null || slotB != null)
                _OutlineBtn(
                  label: 'Clear Slots',
                  icon: Icons.close_rounded,
                  onTap: onClear,
                ),
            ];
            return Wrap(spacing: 10, runSpacing: 10, children: fields);
          },
        ),
      ],
    );
  }
}

class _WebScheduleTeamChip extends StatelessWidget {
  final TournamentTeam team;
  final bool selected;
  const _WebScheduleTeamChip({required this.team, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? _red.withValues(alpha: .14)
            : Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? _red : Colors.white.withValues(alpha: .09),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _red.withValues(alpha: .18),
            child: Text(
              team.teamName.isEmpty ? 'T' : team.teamName[0].toUpperCase(),
              style: _t(size: 11, color: _red, weight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 9),
          Text(team.teamName, style: _t(size: 13, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WebDropSlot extends StatelessWidget {
  final String label;
  final TournamentTeam? team;
  final ValueChanged<TournamentTeam> onDrop;

  const _WebDropSlot({
    required this.label,
    required this.team,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<TournamentTeam>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 112,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active
                ? _red.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? _red : Colors.white.withValues(alpha: .1),
              width: active ? 2 : 1,
            ),
          ),
          child: team == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: active ? _red : _m1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      active ? 'Release to assign' : 'Drop $label here',
                      style: _t(size: 13, color: active ? _red : _m1),
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _red.withValues(alpha: .18),
                      child: Text(
                        team!.teamName.isEmpty
                            ? 'T'
                            : team!.teamName[0].toUpperCase(),
                        style: _t(
                          size: 14,
                          color: _red,
                          weight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: _t(size: 11, color: _m1)),
                          Text(
                            team!.teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(size: 15, weight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _WebMatchScheduleDialog extends StatefulWidget {
  final Tournament tournament;
  final TournamentMatch match;
  const _WebMatchScheduleDialog({
    required this.tournament,
    required this.match,
  });

  @override
  State<_WebMatchScheduleDialog> createState() =>
      _WebMatchScheduleDialogState();
}

class _WebMatchScheduleDialogState extends State<_WebMatchScheduleDialog> {
  DateTime? _date;
  TimeOfDay? _time;
  TournamentVenue? _venue;
  late final TextEditingController _roundCtrl;
  late final TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final match = widget.match;
    _date = match.scheduledAt;
    if (match.scheduledAt != null) {
      _time = TimeOfDay.fromDateTime(match.scheduledAt!);
    }
    _roundCtrl = TextEditingController(text: '${match.round}');
    _noteCtrl = TextEditingController(text: match.note ?? '');
    final venues = TournamentService().venuesFor(widget.tournament.id);
    for (final venue in venues) {
      if (venue.id == match.venueId) _venue = venue;
    }
  }

  @override
  void dispose() {
    _roundCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime? get _combined {
    if (_date == null) return null;
    final t = _time ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(_date!.year, _date!.month, _date!.day, t.hour, t.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _red),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _red),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TournamentService().updateMatchSchedule(
        tournamentId: widget.tournament.id,
        matchId: widget.match.id,
        scheduledAt: _combined,
        venueId: _venue?.id,
        venueName: _venue?.name,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        round: int.tryParse(_roundCtrl.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venues = TournamentService().venuesFor(widget.tournament.id);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Match Schedule',
                      style: _t(size: 20, weight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded, color: _m1),
                  ),
                ],
              ),
              Text(
                '${widget.match.teamAName ?? 'TBD'} vs ${widget.match.teamBName ?? 'TBD'}',
                style: _t(size: 13, color: _m1),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SchedulePickTile(
                      icon: Icons.calendar_today_rounded,
                      label: _date == null
                          ? 'Pick date'
                          : '${_date!.day}/${_date!.month}/${_date!.year}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SchedulePickTile(
                      icon: Icons.schedule_rounded,
                      label: _time?.format(context) ?? 'Pick time',
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TournamentVenue?>(
                initialValue: _venue,
                dropdownColor: _card,
                isExpanded: true,
                decoration: _webInputDecoration('Venue'),
                items: [
                  DropdownMenuItem<TournamentVenue?>(
                    value: null,
                    child: Text('No venue', style: _t(size: 13, color: _m1)),
                  ),
                  ...venues.map(
                    (venue) => DropdownMenuItem<TournamentVenue?>(
                      value: venue,
                      child: Text(venue.name, style: _t(size: 13)),
                    ),
                  ),
                ],
                onChanged: (venue) => setState(() => _venue = venue),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _roundCtrl,
                      keyboardType: TextInputType.number,
                      style: _t(size: 13),
                      decoration: _webInputDecoration('Round'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _noteCtrl,
                      style: _t(size: 13),
                      decoration: _webInputDecoration('Label'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: _RedBtn(
                  label: _saving ? 'Saving...' : 'Save Schedule',
                  icon: Icons.check_rounded,
                  onTap: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedulePickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SchedulePickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: _webBox(),
        child: Row(
          children: [
            Icon(icon, color: _red, size: 16),
            const SizedBox(width: 9),
            Expanded(
              child: Text(label, style: _t(size: 13, color: _tx)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleFullscreenDialog extends StatelessWidget {
  final Tournament tournament;
  const _ScheduleFullscreenDialog({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: _bg,
      child: Column(
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: _card,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: _red, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament.name,
                        style: _t(size: 18, weight: FontWeight.w900),
                      ),
                      Text(
                        'Full schedule management',
                        style: _t(size: 12, color: _m1),
                      ),
                    ],
                  ),
                ),
                _OutlineBtn(
                  label: 'Close',
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _WebSchedulePanel(
                tournament: tournament,
                fullscreen: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSquadsPanel extends StatelessWidget {
  final Tournament tournament;
  const _WebSquadsPanel({required this.tournament});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TournamentService(),
    builder: (context, _) {
      final teams = TournamentService().teamsFor(tournament.id);
      if (teams.isEmpty) return _emptyText('No teams registered yet.');
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: teams
            .map(
              (t) => SizedBox(
                width: 320,
                child: _MiniPanel(
                  title: t.teamName,
                  subtitle: 'Captain: ${t.captainName}',
                  child: Column(
                    children: t.players.isEmpty
                        ? [_emptyText('No squad players listed.')]
                        : t.players.map((p) => _row(p)).toList(),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _WebVenuesManagerPanel extends StatefulWidget {
  final Tournament tournament;
  const _WebVenuesManagerPanel({required this.tournament});
  @override
  State<_WebVenuesManagerPanel> createState() => _WebVenuesManagerPanelState();
}

class _WebVenuesManagerPanelState extends State<_WebVenuesManagerPanel> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TournamentService(),
    builder: (context, _) {
      final venues = TournamentService().venuesFor(widget.tournament.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 230,
                child: TextField(
                  controller: _name,
                  style: _t(size: 13),
                  decoration: _webInputDecoration('Venue name'),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _address,
                  style: _t(size: 13),
                  decoration: _webInputDecoration('Address'),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _city,
                  style: _t(size: 13),
                  decoration: _webInputDecoration('City'),
                ),
              ),
              _RedBtn(
                label: '+ Add Venue',
                onTap: () async {
                  if (_name.text.trim().isEmpty) return;
                  await TournamentService().addVenue(
                    tournamentId: widget.tournament.id,
                    name: _name.text.trim(),
                    address: _address.text.trim(),
                    city: _city.text.trim(),
                  );
                  _name.clear();
                  _address.clear();
                  _city.clear();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (venues.isEmpty)
            _emptyText('No venues added yet.')
          else
            ...venues.map(
              (v) => _row(
                '${v.name} • ${v.city}',
                sub: v.address,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: _red),
                  onPressed: () => TournamentService().removeVenue(
                    widget.tournament.id,
                    v.id,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _WebAdminsPanel extends StatefulWidget {
  final Tournament tournament;
  const _WebAdminsPanel({required this.tournament});

  @override
  State<_WebAdminsPanel> createState() => _WebAdminsPanelState();
}

class _WebAdminsPanelState extends State<_WebAdminsPanel> {
  final _searchCtrl = TextEditingController();
  PlayerEntry? _selectedPlayer;
  List<PlayerSearchResult> _playerResults = [];
  bool _searching = false;
  bool _saving = false;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  final Set<AdminPermission> _selectedPerms = {
    AdminPermission.scheduleMatches,
    AdminPermission.updateScores,
    AdminPermission.editSquads,
    AdminPermission.manageVenues,
    AdminPermission.editMatchInfo,
  };

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    setState(() {
      _selectedPlayer = null;
      _playerResults = [];
      _searching = query.length >= 2;
    });
    if (query.length < 2) return;

    _searchDebounce = Timer(const Duration(milliseconds: 220), () async {
      final gen = ++_searchGeneration;
      final results = await PlayerSearchService().search(
        query,
        includeManual: false,
      );
      if (!mounted || gen != _searchGeneration) return;
      setState(() {
        _playerResults = results;
        _searching = false;
      });
    });
  }

  void _selectPlayer(PlayerEntry entry) {
    _searchDebounce?.cancel();
    _searchCtrl.text = entry.numericId != null
        ? '${entry.displayName} (${entry.numericId})'
        : entry.displayName;
    setState(() {
      _selectedPlayer = entry;
      _playerResults = [];
      _searching = false;
    });
  }

  String _permissionLabel(AdminPermission p) {
    switch (p) {
      case AdminPermission.scheduleMatches:
        return 'Schedule Matches';
      case AdminPermission.updateScores:
        return 'Enter Results / Scorecards';
      case AdminPermission.editSquads:
        return 'Manage Squads';
      case AdminPermission.manageVenues:
        return 'Manage Venues';
      case AdminPermission.editMatchInfo:
        return 'Edit Match Info';
    }
  }

  Future<void> _addAdmin() async {
    final player = _selectedPlayer;
    if (player == null) return;
    if (player.userId == null || player.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a registered player.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedPerms.isEmpty) return;

    setState(() => _saving = true);
    try {
      await TournamentService().addAdmin(
        tournamentId: widget.tournament.id,
        userId: player.userId!,
        userName: player.displayName,
        numericId: player.numericId?.toString() ?? '',
        permissions: _selectedPerms.toList(),
      );
      _searchCtrl.clear();
      setState(() {
        _selectedPlayer = null;
        _playerResults = [];
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TournamentService(),
    builder: (context, _) {
      final admins = TournamentService().adminsFor(widget.tournament.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniPanel(
            title: 'Add Host / Admin',
            subtitle:
                'Search a registered player and choose what they can manage.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: _t(size: 14),
                  decoration: _webInputDecoration(
                    'Search by name, phone, email or player ID',
                    icon: Icons.manage_search_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                _AdminPlayerResultsBox(
                  searching: _searching,
                  results: _playerResults,
                  selected: _selectedPlayer,
                  onSelect: _selectPlayer,
                ),
                if (_selectedPlayer != null) ...[
                  const SizedBox(height: 12),
                  _row(
                    _selectedPlayer!.displayName,
                    sub:
                        'Player ID ${_selectedPlayer!.numericId ?? '-'} • ${_selectedPlayer!.email ?? _selectedPlayer!.phone ?? 'Registered player'}',
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Permissions',
                  style: _t(size: 12, color: _m1, weight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AdminPermission.values.map((permission) {
                    final active = _selectedPerms.contains(permission);
                    return FilterChip(
                      selected: active,
                      label: Text(_permissionLabel(permission)),
                      labelStyle: _t(
                        size: 12,
                        color: active ? Colors.white : _m1,
                        weight: FontWeight.w800,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: .04),
                      selectedColor: _red.withValues(alpha: .22),
                      checkmarkColor: _red,
                      side: BorderSide(
                        color: active
                            ? _red.withValues(alpha: .65)
                            : Colors.white.withValues(alpha: .1),
                      ),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedPerms.add(permission);
                        } else {
                          _selectedPerms.remove(permission);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: _RedBtn(
                    label: _saving ? 'Adding...' : 'Make Host / Admin',
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: (_saving || _selectedPlayer == null)
                        ? null
                        : _addAdmin,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Current Admins',
            style: _t(size: 12, color: _m1, weight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (admins.isEmpty)
            _emptyText('No admins assigned yet.')
          else
            ...admins.map(
              (a) => _row(
                a.userName,
                sub:
                    'ID ${a.numericId.isEmpty ? '-' : a.numericId} • ${a.permissions.map(_permissionLabel).join(', ')}',
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: _red),
                  onPressed: () => TournamentService().removeAdmin(
                    widget.tournament.id,
                    a.userId,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AdminPlayerResultsBox extends StatelessWidget {
  final bool searching;
  final List<PlayerSearchResult> results;
  final PlayerEntry? selected;
  final void Function(PlayerEntry entry) onSelect;

  const _AdminPlayerResultsBox({
    required this.searching,
    required this.results,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final shouldShow = searching || results.isNotEmpty || selected != null;
    if (!shouldShow) return const SizedBox.shrink();

    return Container(
      height: 360,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1D),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: searching && results.isEmpty
          ? Center(
              child: Text('Searching...', style: _t(size: 13, color: _m1)),
            )
          : results.isEmpty
          ? Center(
              child: Text(
                selected == null ? 'No players found' : 'Player selected',
                style: _t(size: 13, color: _m1),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: results.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: .08),
              ),
              itemBuilder: (context, i) {
                final entry = results[i].entry;
                final active = selected?.entryId == entry.entryId;
                return InkWell(
                  onTap: () => onSelect(entry),
                  child: Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    color: active
                        ? _red.withValues(alpha: .12)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _red.withValues(alpha: .18),
                          backgroundImage: entry.imageUrl == null
                              ? null
                              : NetworkImage(entry.imageUrl!),
                          child: entry.imageUrl == null
                              ? Text(
                                  entry.displayName.isNotEmpty
                                      ? entry.displayName[0].toUpperCase()
                                      : '?',
                                  style: _t(
                                    size: 15,
                                    color: _red,
                                    weight: FontWeight.w900,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  entry.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _t(size: 14, weight: FontWeight.w900),
                                ),
                              ),
                              if (entry.numericId != null) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _red.withValues(alpha: .16),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    '${entry.numericId}',
                                    style: _t(
                                      size: 11,
                                      color: _red,
                                      weight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MiniPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _MiniPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _webBox(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _t(size: 15, weight: FontWeight.w900)),
        Text(subtitle, style: _t(size: 12, color: _m1)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

BoxDecoration _webBox() => BoxDecoration(
  color: Colors.white.withValues(alpha: .035),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: Colors.white.withValues(alpha: .08)),
);

Widget _row(String text, {String? sub, Widget? trailing}) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: _webBox(),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: _t(size: 13, weight: FontWeight.w800)),
            if (sub != null) Text(sub, style: _t(size: 12, color: _m1)),
          ],
        ),
      ),
      ?trailing,
    ],
  ),
);

Widget _emptyText(String text) => Padding(
  padding: const EdgeInsets.all(18),
  child: Text(text, style: _t(size: 13, color: _m1)),
);

class _WebTeamsManagerDialog extends StatelessWidget {
  final Tournament tournament;

  const _WebTeamsManagerDialog({required this.tournament});

  Future<void> _addTeam(BuildContext context) async {
    Navigator.pop(context);
    await EnrollTeamSheet.show(
      context,
      tournamentId: tournament.id,
      entryFee: tournament.entryFee,
      serviceFee: tournament.serviceFee,
      playersPerTeam: tournament.playersPerTeam,
      sport: tournament.sport,
    );
    await TournamentService().loadDetail(tournament.id);
  }

  Future<void> _removeTeam(BuildContext context, TournamentTeam team) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          'Remove Team?',
          style: _t(size: 17, weight: FontWeight.w900),
        ),
        content: Text(
          'Remove "${team.teamName}" from this tournament?',
          style: _t(size: 13, color: _m1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: _t(size: 13, color: _m1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: _t(size: 13, color: _red, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TournamentService().removeTeam(tournament.id, team.id);
    await TournamentService().loadDetail(tournament.id);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: ListenableBuilder(
            listenable: TournamentService(),
            builder: (context, _) {
              final teams = TournamentService().teamsFor(tournament.id);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.groups_outlined,
                            color: _red,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Teams',
                                style: _t(size: 20, weight: FontWeight.w900),
                              ),
                              Text(
                                '${teams.length}/${tournament.maxTeams} teams registered',
                                style: _t(size: 13, color: _m1),
                              ),
                            ],
                          ),
                        ),
                        _RedBtn(
                          label: '+ Add Team',
                          onTap: () => _addTeam(context),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: _m1),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: .07),
                  ),
                  Expanded(
                    child: teams.isEmpty
                        ? Center(
                            child: Text(
                              'No teams registered yet.',
                              style: _t(size: 14, color: _m1),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(18),
                            itemCount: teams.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final team = teams[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .035),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _red.withValues(
                                        alpha: .18,
                                      ),
                                      child: Text(
                                        team.teamName.isNotEmpty
                                            ? team.teamName[0].toUpperCase()
                                            : 'T',
                                        style: _t(weight: FontWeight.w900),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            team.teamName,
                                            style: _t(
                                              size: 15,
                                              weight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            'Captain: ${team.captainName.isEmpty ? 'Not set' : team.captainName}  •  ${team.players.length} players',
                                            style: _t(size: 12, color: _m1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _OutlineBtn(
                                      label: 'Remove',
                                      icon: Icons.delete_outline_rounded,
                                      onTap: () => _removeTeam(context, team),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _SubTabBar({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == i ? _red : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: _t(
                      size: 12,
                      color: selected == i ? _tx : _m1,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManageActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _ManageActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .28)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _Badge(label: badge!, color: color),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(size: 14, weight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: _t(size: 12, color: _m1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _DangerAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red.withValues(alpha: .35)),
          ),
          child: Row(
            children: [
              Icon(icon, color: _red, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _t(size: 14, color: _red, weight: FontWeight.w900),
                    ),
                    Text(subtitle, style: _t(size: 12, color: _m1)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _red),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _red, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: _t(size: 19, weight: FontWeight.w900)),
              Text(label, style: _t(size: 11, color: _m1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _t(size: 14, weight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: _t(size: 12, color: _m1)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: _t(size: 12, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  final String label;
  const _EmptyPane({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: _t(size: 14, color: _m1, weight: FontWeight.w700),
      ),
    );
  }
}

// ── Sport filter chips ─────────────────────────────────────────────────────────

class _SportFilterChips extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _SportFilterChips({required this.selected, required this.onSelect});

  @override
  State<_SportFilterChips> createState() => _SportFilterChipsState();
}

class _SportFilterChipsState extends State<_SportFilterChips> {
  final _query = TextEditingController();
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  bool _open = false;

  static const _quickSports = [
    'Cricket',
    'Football',
    'Basketball',
    'Badminton',
    'Tennis',
  ];

  static const _allSports = [
    'Cricket',
    'Football',
    'Basketball',
    'Badminton',
    'Tennis',
    'Volleyball',
    'Hockey',
    'Kabaddi',
    'Boxing',
    'Table Tennis',
    'Throwball',
    'Handball',
    'Swimming',
    'Rugby',
    'Golf',
    'Athletics',
    'Cycling',
    'Archery',
    'Squash',
    'Esports',
  ];

  @override
  void dispose() {
    _overlayController.hide();
    _query.dispose();
    super.dispose();
  }

  List<String> get _filteredSports {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _allSports;
    return _allSports.where((s) => s.toLowerCase().contains(q)).toList();
  }

  void _select(String? sport) {
    widget.onSelect(sport);
    _closeDropdown();
  }

  void _toggleDropdown() {
    setState(() => _open = !_open);
    if (_open) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  void _closeDropdown() {
    _overlayController.hide();
    setState(() {
      _open = false;
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final dropdownActive = selected == null || !_quickSports.contains(selected);
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final panelWidth = screenWidth < 520 ? screenWidth - 32 : 360.0;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Material(
                type: MaterialType.transparency,
                child: _AllSportsFilterPanel(
                  width: panelWidth,
                  query: _query,
                  sports: _filteredSports,
                  selected: selected,
                  onSearchChanged: (_) => setState(() {}),
                  onSelect: _select,
                ),
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AllSportsFilterButton(
              label: dropdownActive && selected != null
                  ? selected
                  : 'All Sports',
              active: dropdownActive,
              open: _open,
              onTap: _toggleDropdown,
            ),
            for (final s in _quickSports)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _Chip(
                  label: s,
                  active: selected == s,
                  onTap: () => _select(s),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllSportsFilterButton extends StatefulWidget {
  final String label;
  final bool active;
  final bool open;
  final VoidCallback onTap;

  const _AllSportsFilterButton({
    required this.label,
    required this.active,
    required this.open,
    required this.onTap,
  });

  @override
  State<_AllSportsFilterButton> createState() => _AllSportsFilterButtonState();
}

class _AllSportsFilterButtonState extends State<_AllSportsFilterButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.active
                ? _red.withValues(alpha: .15)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: widget.open
                  ? _red.withValues(alpha: .8)
                  : widget.active
                  ? _red.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: widget.active ? _red : _m1,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: _t(
                  size: 12,
                  weight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  color: widget.active ? _red : _m1,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                widget.open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: widget.active ? _red : _m1,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSportsFilterPanel extends StatelessWidget {
  final double width;
  final TextEditingController query;
  final List<String> sports;
  final String? selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onSelect;

  const _AllSportsFilterPanel({
    required this.width,
    required this.query,
    required this.sports,
    required this.selected,
    required this.onSearchChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .42),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: query,
              autofocus: true,
              onChanged: onSearchChanged,
              style: _t(size: 13),
              decoration: InputDecoration(
                hintText: 'Search sport...',
                hintStyle: _t(size: 13, color: _m1),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _m1,
                  size: 18,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: .04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _red),
                ),
                isDense: true,
              ),
            ),
          ),
          Container(height: .8, color: _border),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  _AllSportsFilterTile(
                    icon: Icons.grid_view_rounded,
                    label: 'All Sports',
                    color: _red,
                    selected: selected == null,
                    onTap: () => onSelect(null),
                  ),
                  for (final sport in sports)
                    _AllSportsFilterTile(
                      icon: _sportIcon(sport),
                      label: sport,
                      color: _sportAccent(sport),
                      selected: selected == sport,
                      onTap: () => onSelect(sport),
                    ),
                  if (sports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No sports found',
                        style: _t(size: 13, color: _m1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllSportsFilterTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AllSportsFilterTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AllSportsFilterTile> createState() => _AllSportsFilterTileState();
}

class _AllSportsFilterTileState extends State<_AllSportsFilterTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? _red.withValues(alpha: .15)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.selected ? _red : _m1, size: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    size: 13,
                    weight: FontWeight.w700,
                    color: widget.selected ? _tx : (_hover ? _tx : _m1),
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check_rounded, color: _red, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.active
                ? _red.withValues(alpha: .15)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: widget.active
                  ? _red.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Text(
            widget.label,
            style: _t(
              size: 12,
              weight: widget.active ? FontWeight.w700 : FontWeight.w500,
              color: widget.active ? _red : _m1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right stats panel ──────────────────────────────────────────────────────────

class _RightStatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _border, width: .8)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tournament Spotlight',
              style: _t(size: 15, weight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _BracketPreview(),
            const SizedBox(height: 24),
            Text(
              'Tournament Highlights',
              style: _t(size: 15, weight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _HighlightStats(),
            const SizedBox(height: 24),
            Text(
              'Popular Sports',
              style: _t(size: 15, weight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _PopularSports(),
          ],
        ),
      ),
    );
  }
}

class _BracketPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final tours = TournamentService().tournaments;
        if (tours.isEmpty) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            alignment: Alignment.center,
            child: Text(
              'No featured tournament',
              style: _t(size: 13, color: _m1),
            ),
          );
        }
        final t = tours.first;
        final accent = _sportAccent(t.sport);
        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: .25), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(_sportIcon(t.sport), color: accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(
                              size: 13,
                              weight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          Text(t.format.name, style: _t(size: 11, color: _m1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () =>
                        _openWebTournamentDetail(context, tournamentId: t.id),
                    child: Container(
                      height: 36,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'View Full Bracket',
                        style: _t(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HighlightStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final all = TournamentService().tournaments;
        final active = all
            .where((t) => t.status == TournamentStatus.ongoing)
            .length;
        final total = all.length;
        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _StatRow(
                Icons.emoji_events_rounded,
                'Active Tournaments',
                '$active',
                _red,
              ),
              Container(height: .8, color: _border),
              _StatRow(
                Icons.people_outline_rounded,
                'Total Tournaments',
                '$total',
                _orange,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: _t(size: 13, color: _m1)),
          ),
          Text(
            value,
            style: _t(size: 16, weight: FontWeight.w800, color: _tx),
          ),
        ],
      ),
    );
  }
}

class _PopularSports extends StatelessWidget {
  static const _sports = [
    ('Football', Icons.sports_soccer_rounded),
    ('Cricket', Icons.sports_cricket_rounded),
    ('Basketball', Icons.sports_basketball_rounded),
    ('Badminton', Icons.sports_tennis_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: _sports.asMap().entries.map((e) {
          final (sport, icon) = e.value;
          return Column(
            children: [
              if (e.key > 0) Container(height: .8, color: _border),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: _red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sport,
                        style: _t(size: 13, weight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _m2, size: 18),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Sort pill ──────────────────────────────────────────────────────────────────

class _SortPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort by: Start Date', style: _t(size: 12, color: _m1)),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 16),
        ],
      ),
    );
  }
}

// ── Shared button components ───────────────────────────────────────────────────

class _RedBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _RedBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_RedBtn> createState() => _RedBtnState();
}

class _RedBtnState extends State<_RedBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _hover ? .4 : .2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: _t(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _OutlineBtn({required this.label, this.icon, required this.onTap});

  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .06)
                : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: _m1, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: _t(size: 13, weight: FontWeight.w600, color: _tx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
