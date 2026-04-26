import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/match_score.dart';
import '../../core/models/tournament.dart';
import '../../services/scoreboard_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../scoreboard/live_scoreboard_screen.dart';

// ── Design tokens (matches web_tournaments_page.dart) ─────────────────────────
const _bg = Color(0xFF080808);
const _card = Color(0xFF111111);
const _panel = Color(0xFF0E0E0E);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _green = Color(0xFF30D158);
const _orange = Color(0xFFFF9F0A);

TextStyle _ts({
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

// ── Scoring utils (mirrors web_tournaments_page.dart helpers) ──────────────────

int _defaultRallyPts(MatchSport sport) =>
    sport == MatchSport.tableTennis ? 11 : 21;

int _normBestOf(int v) {
  if (v <= 0) return 3;
  if (v.isEven) return v + 1;
  return v;
}

int _effectiveBestOf(Tournament t, TournamentMatch m) {
  if (t.sameScoreAllRounds) return _normBestOf(t.bestOf);
  final rounds = TournamentService()
      .matchesFor(t.id)
      .map((x) => x.round)
      .toSet()
      .toList()
    ..sort();
  final idx = rounds.indexOf(m.round);
  final fromEnd = rounds.length - idx;
  final roundKey = switch (fromEnd) {
    3 => 'quarterFinal',
    2 => 'semiFinal',
    1 => 'final',
    _ => null,
  };
  if (roundKey == null) return _normBestOf(t.bestOf);
  final override =
      (t.roundScoringConfig?[roundKey] as Map?)?.cast<String, dynamic>();
  final overrideBestOf = (override?['bestOf'] as num?)?.toInt();
  return _normBestOf(overrideBestOf ?? t.bestOf);
}

int _effectivePts(Tournament t, TournamentMatch m) {
  if (t.sameScoreAllRounds) return t.pointsToWin;
  final rounds = TournamentService()
      .matchesFor(t.id)
      .map((x) => x.round)
      .toSet()
      .toList()
    ..sort();
  final idx = rounds.indexOf(m.round);
  final fromEnd = rounds.length - idx;
  final roundKey = switch (fromEnd) {
    3 => 'quarterFinal',
    2 => 'semiFinal',
    1 => 'final',
    _ => null,
  };
  if (roundKey == null) return t.pointsToWin;
  final override =
      (t.roundScoringConfig?[roundKey] as Map?)?.cast<String, dynamic>();
  return (override?['pointsToWin'] as num?)?.toInt() ?? t.pointsToWin;
}

LiveMatch _buildLiveMatch({
  required String id,
  required TournamentMatch match,
  required Tournament tourn,
}) {
  final sport = sportFromName(tourn.sport);
  final teamA = match.teamAName ?? 'Team A';
  final teamB = match.teamBName ?? 'Team B';
  final venueId = match.venueId ?? '';
  String? venueName;
  if (venueId.isNotEmpty) {
    venueName = TournamentService()
        .venuesFor(tourn.id)
        .where((v) => v.id == venueId)
        .firstOrNull
        ?.name;
  }
  final venue = venueName ?? match.venueName ?? tourn.location;
  final bestOf = math.max(1, _effectiveBestOf(tourn, match));
  final pts = _effectivePts(tourn, match);
  final fmt = '${tourn.sport} · Best of $bestOf';
  final myUid = UserService().userId ?? '';
  final now = DateTime.now();

  switch (engineForSport(sport)) {
    case SportEngine.rally:
      final setsToWin = (bestOf / 2).ceil();
      final pointsToWin = pts > 0 ? pts : _defaultRallyPts(sport);
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: fmt,
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
      final teamAObj =
          allTeams.where((t) => t.id == match.teamAId).firstOrNull;
      final teamBObj =
          allTeams.where((t) => t.id == match.teamBId).firstOrNull;
      final perSide = tourn.playersPerTeam > 0 ? tourn.playersPerTeam : 11;
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: fmt,
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
        format: fmt,
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
        format: fmt,
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
        format: fmt,
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
        format: fmt,
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
        format: fmt,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        esports: EsportsScore(roundsToWin: bestOf > 0 ? bestOf : 13),
      );
    case SportEngine.generic:
      return LiveMatch(
        id: id,
        sport: sport,
        teamA: teamA,
        teamB: teamB,
        venue: venue,
        format: fmt,
        createdAt: now,
        createdByUserId: myUid,
        isTournamentMatch: true,
        tournamentId: tourn.id,
        tournamentMatchId: match.id,
        teamAId: match.teamAId,
        teamBId: match.teamBId,
        genericScore: GenericScore(pointsToWin: pts > 0 ? pts : 0),
      );
  }
}

Future<void> launchTournamentMatchScoring(
  BuildContext context,
  String tournamentId,
  String matchId,
) async {
  final tourn = TournamentService()
      .tournaments
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

  if (!needsRecreate) {
    if (existing.isTournamentMatch &&
        (existing.tournamentId == null || existing.teamAId == null)) {
      needsRecreate = true;
    }
  }

  if (needsRecreate) {
    if (existing != null) svc.removeMatch(scoreboardId);
    svc.addMatch(
      _buildLiveMatch(id: scoreboardId, match: match, tourn: tourn),
    );
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'active_tournament_scoring',
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

// ── Page ───────────────────────────────────────────────────────────────────────

class WebMultiGameView extends StatefulWidget {
  final String tournamentId;
  const WebMultiGameView({super.key, required this.tournamentId});

  @override
  State<WebMultiGameView> createState() => _WebMultiGameViewState();
}

class _WebMultiGameViewState extends State<WebMultiGameView> {
  bool _globalBusy = false;
  String _filter = 'all'; // 'all' | 'live' | 'upcoming' | 'played'

  @override
  void initState() {
    super.initState();
    TournamentService().loadDetail(widget.tournamentId);
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
          return Scaffold(
            backgroundColor: _bg,
            body: const Center(
              child: CircularProgressIndicator(color: _red),
            ),
          );
        }

        final allMatches =
            svc.matchesFor(widget.tournamentId).where((m) => !m.isBye).toList();

        final filtered = switch (_filter) {
          'live' => allMatches.where((m) => m.isLive).toList(),
          'upcoming' => allMatches.where((m) => !m.isLive && !m.isPlayed).toList(),
          'played' => allMatches.where((m) => m.isPlayed).toList(),
          _ => allMatches,
        };

        // Sort: live first, then upcoming, then played
        final sorted = [...filtered]..sort((a, b) {
          int priority(TournamentMatch m) =>
              m.isLive ? 0 : m.isPlayed ? 2 : 1;
          return priority(a).compareTo(priority(b));
        });

        final liveCount = allMatches.where((m) => m.isLive).length;
        final upcomingCount =
            allMatches.where((m) => !m.isLive && !m.isPlayed).length;
        final playedCount = allMatches.where((m) => m.isPlayed).length;

        final canManage =
            svc.isHost(widget.tournamentId) ||
            svc.isAdmin(widget.tournamentId);

        return Scaffold(
          backgroundColor: _bg,
          body: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              _TopBar(
                tournamentName: tournament.name,
                liveCount: liveCount,
                busy: _globalBusy,
                onBack: () => Navigator.pop(context),
              ),

              // ── Filter tabs ──────────────────────────────────────────────
              _FilterBar(
                selected: _filter,
                allCount: allMatches.length,
                liveCount: liveCount,
                upcomingCount: upcomingCount,
                playedCount: playedCount,
                onSelect: (v) => setState(() => _filter = v),
              ),

              // ── Stats strip ──────────────────────────────────────────────
              if (liveCount > 0)
                _LiveStrip(liveCount: liveCount),

              // ── Match grid ───────────────────────────────────────────────
              Expanded(
                child: sorted.isEmpty
                    ? _EmptyState(filter: _filter)
                    : _MatchGrid(
                        tournament: tournament,
                        matches: sorted,
                        canManage: canManage,
                        onBusy: (v) => setState(() => _globalBusy = v),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String tournamentName;
  final int liveCount;
  final bool busy;
  final VoidCallback onBack;

  const _TopBar({
    required this.tournamentName,
    required this.liveCount,
    required this.busy,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onBack,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _m1,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Back',
                    style: _ts(size: 13, color: _m1, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Container(width: 1, height: 22, color: _border),
          const SizedBox(width: 20),
          const Icon(Icons.sports_score_rounded, color: _red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tournamentName,
                  style: _ts(size: 14, weight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Live Match Center',
                  style: _ts(size: 11, color: _m1),
                ),
              ],
            ),
          ),
          if (liveCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _red.withValues(alpha: .4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$liveCount LIVE',
                    style: _ts(
                      size: 11,
                      weight: FontWeight.w800,
                      color: _red,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: _red, strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final int allCount;
  final int liveCount;
  final int upcomingCount;
  final int playedCount;
  final ValueChanged<String> onSelect;

  const _FilterBar({
    required this.selected,
    required this.allCount,
    required this.liveCount,
    required this.upcomingCount,
    required this.playedCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('all', 'All', allCount, _m1),
      ('live', 'Live', liveCount, _red),
      ('upcoming', 'Upcoming', upcomingCount, _orange),
      ('played', 'Played', playedCount, _green),
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final (key, label, count, color) in tabs) ...[
            _FilterTab(
              label: label,
              count: count,
              color: color,
              active: selected == key,
              onTap: () => onSelect(key),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.color,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _red : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: _ts(
                  size: 13,
                  weight: FontWeight.w600,
                  color: active ? _tx : _m1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: .2)
                      : Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: _ts(
                    size: 10,
                    weight: FontWeight.w700,
                    color: active ? color : _m2,
                    height: 1.4,
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

// ── Live strip ─────────────────────────────────────────────────────────────────

class _LiveStrip extends StatelessWidget {
  final int liveCount;
  const _LiveStrip({required this.liveCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: .06),
        border: Border(bottom: BorderSide(color: _red.withValues(alpha: .15))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$liveCount match${liveCount > 1 ? 'es' : ''} currently live — scores update in real time',
            style: _ts(size: 12, color: _red, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      'live' => 'No live matches right now',
      'upcoming' => 'No upcoming matches',
      'played' => 'No completed matches yet',
      _ => 'No matches scheduled',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_outlined, color: _m2, size: 52),
          const SizedBox(height: 14),
          Text(
            msg,
            style: _ts(size: 16, weight: FontWeight.w700, color: _m1),
          ),
        ],
      ),
    );
  }
}

// ── Match grid ─────────────────────────────────────────────────────────────────

class _MatchGrid extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentMatch> matches;
  final bool canManage;
  final ValueChanged<bool> onBusy;

  const _MatchGrid({
    required this.tournament,
    required this.matches,
    required this.canManage,
    required this.onBusy,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: 320,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: matches.length,
      itemBuilder: (context, i) => _GameCard(
        tournament: tournament,
        match: matches[i],
        canManage: canManage,
        onBusy: onBusy,
      ),
    );
  }
}

// ── Game card ──────────────────────────────────────────────────────────────────

class _GameCard extends StatefulWidget {
  final Tournament tournament;
  final TournamentMatch match;
  final bool canManage;
  final ValueChanged<bool> onBusy;

  const _GameCard({
    required this.tournament,
    required this.match,
    required this.canManage,
    required this.onBusy,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _saving = false;

  TournamentMatch get _m => widget.match;

  Future<void> _adjustScore(bool teamA, int delta) async {
    if (_saving) return;
    final currentA = _m.scoreA ?? 0;
    final currentB = _m.scoreB ?? 0;
    final newA = (currentA + (teamA ? delta : 0)).clamp(0, 999);
    final newB = (currentB + (!teamA ? delta : 0)).clamp(0, 999);
    if (newA == currentA && newB == currentB) return;

    setState(() => _saving = true);
    widget.onBusy(true);
    try {
      await _saveScore(newA, newB);
    } finally {
      if (mounted) setState(() => _saving = false);
      widget.onBusy(false);
    }
  }

  Future<void> _saveScore(int scoreA, int scoreB) async {
    String winnerId = '';
    String winnerName = '';
    if (scoreA > scoreB) {
      winnerId = _m.teamAId ?? '';
      winnerName = _m.teamAName ?? '';
    } else if (scoreB > scoreA) {
      winnerId = _m.teamBId ?? '';
      winnerName = _m.teamBName ?? '';
    }
    await TournamentService().updateMatchResult(
      tournamentId: widget.tournament.id,
      matchId: _m.id,
      scoreA: scoreA,
      scoreB: scoreB,
      winnerId: winnerId,
      winnerName: winnerName,
    );
  }

  Future<void> _openFullScoreboard() async {
    if (!context.mounted) return;
    await launchTournamentMatchScoring(
      context,
      widget.tournament.id,
      _m.id,
    );
  }

  Future<void> _setWinner() async {
    final winner = await showDialog<String?>(
      context: context,
      builder: (ctx) => _SetWinnerDialog(
        teamAName: _m.teamAName ?? 'Team A',
        teamBName: _m.teamBName ?? 'Team B',
      ),
    );
    if (winner == null || !mounted) return;

    setState(() => _saving = true);
    widget.onBusy(true);
    try {
      final sA = _m.scoreA ?? 0;
      final sB = _m.scoreB ?? 0;
      if (winner == 'A') {
        final finalA = sA > sB ? sA : sB + 1;
        await _saveScore(finalA, sB);
      } else {
        final finalB = sB > sA ? sB : sA + 1;
        await _saveScore(sA, finalB);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      widget.onBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = _m.isLive;
    final isPlayed = _m.isPlayed;
    final aWins =
        isPlayed && _m.result == TournamentMatchResult.teamAWin;
    final bWins =
        isPlayed && _m.result == TournamentMatchResult.teamBWin;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive
              ? _green.withValues(alpha: .4)
              : Colors.white.withValues(alpha: .07),
          width: isLive ? 1.5 : 1,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: _green.withValues(alpha: .07),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // ── Card header ──────────────────────────────────────────────────
          _CardHeader(match: _m),

          // ── Score section ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _TeamColumn(
                    name: _m.teamAName ?? 'Team A',
                    score: _m.scoreA ?? 0,
                    isWinner: aWins,
                    canEdit: widget.canManage && !isPlayed,
                    saving: _saving,
                    onAdd: () => _adjustScore(true, 1),
                    onRemove: () => _adjustScore(true, -1),
                  ),
                  _VsDivider(isLive: isLive),
                  _TeamColumn(
                    name: _m.teamBName ?? 'Team B',
                    score: _m.scoreB ?? 0,
                    isWinner: bWins,
                    canEdit: widget.canManage && !isPlayed,
                    saving: _saving,
                    onAdd: () => _adjustScore(false, 1),
                    onRemove: () => _adjustScore(false, -1),
                  ),
                ],
              ),
            ),
          ),

          // ── Action buttons ───────────────────────────────────────────────
          if (widget.canManage)
            _CardActions(
              isPlayed: isPlayed,
              saving: _saving,
              onOpenScoreboard: _openFullScoreboard,
              onSetWinner: !isPlayed ? _setWinner : null,
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Card header ────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final TournamentMatch match;
  const _CardHeader({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    final isPlayed = match.isPlayed;
    final statusColor =
        isLive ? _green : isPlayed ? _m1 : _orange;
    final statusLabel = isLive ? 'LIVE' : isPlayed ? 'FINAL' : 'UPCOMING';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: .1)),
            ),
            child: Text(
              match.note?.isNotEmpty == true
                  ? match.note!
                  : 'Round ${match.round}',
              style: _ts(size: 10, weight: FontWeight.w700, color: _m1, height: 1),
            ),
          ),
          const Spacer(),
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _green.withValues(alpha: .4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: _ts(
                      size: 9,
                      weight: FontWeight.w900,
                      color: _green,
                      height: 1,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              statusLabel,
              style: _ts(
                size: 11,
                weight: FontWeight.w700,
                color: statusColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Team column ────────────────────────────────────────────────────────────────

class _TeamColumn extends StatelessWidget {
  final String name;
  final int score;
  final bool isWinner;
  final bool canEdit;
  final bool saving;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _TeamColumn({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.canEdit,
    required this.saving,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isWinner) ...[
            const Icon(Icons.emoji_events_rounded, color: _orange, size: 14),
            const SizedBox(height: 4),
          ],
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _ts(
              size: 12,
              weight: FontWeight.w700,
              color: isWinner ? Colors.white : _m1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$score',
            style: _ts(
              size: 46,
              weight: FontWeight.w900,
              color: isWinner ? Colors.white : _tx,
              height: 1,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScoreBtn(
                  icon: Icons.remove_rounded,
                  color: _red,
                  disabled: saving || score <= 0,
                  onTap: onRemove,
                ),
                const SizedBox(width: 14),
                _ScoreBtn(
                  icon: Icons.add_rounded,
                  color: _green,
                  disabled: saving,
                  onTap: onAdd,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── VS divider ─────────────────────────────────────────────────────────────────

class _VsDivider extends StatelessWidget {
  final bool isLive;
  const _VsDivider({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 1,
          height: 50,
          color: Colors.white.withValues(alpha: .06),
        ),
        const SizedBox(height: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLive
                ? _green.withValues(alpha: .1)
                : Colors.white.withValues(alpha: .04),
            border: Border.all(
              color: isLive
                  ? _green.withValues(alpha: .3)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'VS',
            style: _ts(
              size: 9,
              weight: FontWeight.w900,
              color: isLive ? _green : _m2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 1,
          height: 50,
          color: Colors.white.withValues(alpha: .06),
        ),
      ],
    );
  }
}

// ── Score button ───────────────────────────────────────────────────────────────

class _ScoreBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool disabled;
  final VoidCallback onTap;

  const _ScoreBtn({
    required this.icon,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  @override
  State<_ScoreBtn> createState() => _ScoreBtnState();
}

class _ScoreBtnState extends State<_ScoreBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.disabled ? _m2 : widget.color;
    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.disabled
                ? Colors.white.withValues(alpha: .04)
                : _hover
                    ? c.withValues(alpha: .25)
                    : c.withValues(alpha: .12),
            border: Border.all(
              color: widget.disabled
                  ? Colors.white.withValues(alpha: .06)
                  : c.withValues(alpha: .45),
            ),
          ),
          child: Icon(widget.icon, size: 18, color: c),
        ),
      ),
    );
  }
}

// ── Card actions ───────────────────────────────────────────────────────────────

class _CardActions extends StatelessWidget {
  final bool isPlayed;
  final bool saving;
  final VoidCallback onOpenScoreboard;
  final VoidCallback? onSetWinner;

  const _CardActions({
    required this.isPlayed,
    required this.saving,
    required this.onOpenScoreboard,
    required this.onSetWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.scoreboard_outlined,
              label: 'Full Scoreboard',
              color: _m1,
              borderColor: _border,
              disabled: saving,
              onTap: onOpenScoreboard,
            ),
          ),
          if (onSetWinner != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.emoji_events_outlined,
                label: 'Set Winner',
                color: _orange,
                borderColor: _orange.withValues(alpha: .35),
                disabled: saving,
                onTap: onSetWinner!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.disabled,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: _hover && !widget.disabled
                ? widget.color.withValues(alpha: .1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: widget.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 13,
                color: widget.disabled ? _m2 : widget.color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: _ts(
                  size: 12,
                  weight: FontWeight.w600,
                  color: widget.disabled ? _m2 : widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Set winner dialog ──────────────────────────────────────────────────────────

class _SetWinnerDialog extends StatelessWidget {
  final String teamAName;
  final String teamBName;

  const _SetWinnerDialog({required this.teamAName, required this.teamBName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Set Match Winner',
        style: _ts(size: 16, weight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select the winning team to record the final result.',
            style: _ts(size: 13, color: _m1),
          ),
          const SizedBox(height: 16),
          _WinnerTile(
            name: teamAName,
            onTap: () => Navigator.pop(context, 'A'),
          ),
          const SizedBox(height: 8),
          _WinnerTile(
            name: teamBName,
            onTap: () => Navigator.pop(context, 'B'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: _ts(color: _m1)),
        ),
      ],
    );
  }
}

class _WinnerTile extends StatefulWidget {
  final String name;
  final VoidCallback onTap;
  const _WinnerTile({required this.name, required this.onTap});

  @override
  State<_WinnerTile> createState() => _WinnerTileState();
}

class _WinnerTileState extends State<_WinnerTile> {
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
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover
                ? _red.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover ? _red.withValues(alpha: .4) : _border,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 16, color: _orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.name,
                  style: _ts(
                    size: 14,
                    weight: FontWeight.w700,
                    color: _hover ? Colors.white : _m1,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _hover ? _tx : _m2,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
