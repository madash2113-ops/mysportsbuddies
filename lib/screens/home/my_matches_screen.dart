import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../scoreboard/match_report_screen.dart';
import '../../widgets/match_vs_banner.dart';

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Matches',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Completed'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: Consumer<ScoreboardService>(
        builder: (context, svc, _) {
          final all       = svc.all;
          final live      = all.where((m) => m.status == MatchStatus.live).toList();
          final completed = all.where((m) => m.status == MatchStatus.completed).toList();

          return TabBarView(
            controller: _tab,
            children: [
              _MatchList(matches: live,      emptyLabel: 'live'),
              _MatchList(matches: completed, emptyLabel: 'completed'),
              _MatchList(matches: all,       emptyLabel: 'any'),
            ],
          );
        },
      ),
    );
  }
}

// ── Match List ────────────────────────────────────────────────────────────────

class _MatchList extends StatelessWidget {
  final List<LiveMatch> matches;
  final String emptyLabel;
  const _MatchList({required this.matches, required this.emptyLabel});

  Future<void> _refresh() => ScoreboardService().loadFromFirestore();

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_EmptyState(label: emptyLabel)],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: matches.length,
        itemBuilder: (_, i) => _MatchCard(match: matches[i]),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: AppSpacing.md),
          Text(
            label == 'any' ? 'No matches yet' : 'No $label matches',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Create a scoreboard to track your matches',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Match Card ────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final LiveMatch match;
  const _MatchCard({required this.match});


  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _open(BuildContext context) {
    if (match.status == MatchStatus.completed) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => MatchReportScreen(matchId: match.id)));
    } else {
      Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => LiveScoreboardScreen(
              matchId: match.id,
              isScorer: true,
            ),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live;
    final isDone = match.status == MatchStatus.completed;

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.07),
            width: isLive ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── VS Banner ─────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: MatchVsBanner(
                teamA:    match.teamA,
                teamB:    match.teamB,
                label:    match.format.isNotEmpty ? match.format : match.sportDisplayName,
                sport:    match.sportDisplayName,
                isLive:   isLive,
                isPlayed: isDone,
                isMyMatch: false,
              ),
            ),

            // ── Score + footer ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(children: [
                if (match.venue.isNotEmpty) ...[
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white38, size: 11),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(match.venue,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                ] else
                  const Spacer(),
                Text(_timeAgo(match.createdAt),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(children: [
                Expanded(child: _ScoreWidget(match: match)),
                const SizedBox(width: 10),
                Text(
                  isDone ? 'View report →' : 'Score →',
                  style: TextStyle(
                    color: isLive ? AppColors.primary : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Score Widget ──────────────────────────────────────────────────────────────

class _ScoreWidget extends StatelessWidget {
  final LiveMatch match;
  const _ScoreWidget({required this.match});

  @override
  Widget build(BuildContext context) {
    String scoreA = '–', scoreB = '–';

    try {
      switch (match.sport) {
        case MatchSport.cricket:
          final inn = match.cricket?.currentInnings;
          if (inn != null) {
            scoreA = '${inn.runs}/${inn.wickets}';
            scoreB = '(${inn.oversStr})';
          }
        case MatchSport.football:
        case MatchSport.futsal:
        case MatchSport.americanFootball:
        case MatchSport.handball:
          scoreA = '${match.football?.teamAGoals ?? 0}';
          scoreB = '${match.football?.teamBGoals ?? 0}';
        case MatchSport.basketball:
        case MatchSport.netball:
          scoreA = '${match.basketball?.teamATotal ?? 0}';
          scoreB = '${match.basketball?.teamBTotal ?? 0}';
        case MatchSport.hockey:
        case MatchSport.iceHockey:
          scoreA = '${match.hockey?.teamAGoals ?? 0}';
          scoreB = '${match.hockey?.teamBGoals ?? 0}';
        case MatchSport.csgo:
        case MatchSport.valorant:
        case MatchSport.leagueOfLegends:
        case MatchSport.dota2:
        case MatchSport.fifaEsports:
          scoreA = '${match.esports?.teamARounds ?? 0}';
          scoreB = '${match.esports?.teamBRounds ?? 0}';
        case MatchSport.badminton:
        case MatchSport.tennis:
        case MatchSport.tableTennis:
        case MatchSport.volleyball:
        case MatchSport.beachVolleyball:
        case MatchSport.squash:
        case MatchSport.padel:
          final r = match.rally;
          if (r != null) {
            scoreA = '${r.setsWonA}';
            scoreB = '${r.setsWonB}';
          }
        case MatchSport.boxing:
        case MatchSport.mma:
        case MatchSport.wrestling:
        case MatchSport.fencing:
          final c = match.combat;
          if (c != null) {
            scoreA = 'Rnd ${c.currentRound}';
            scoreB = '/ ${c.rounds.length}';
          }
        default:
          final g = match.genericScore;
          if (g != null) {
            scoreA = '${g.teamAScore}';
            scoreB = '${g.teamBScore}';
          }
      }
    } catch (_) {
      scoreA = '–';
      scoreB = '–';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          scoreA,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          scoreB,
          style: const TextStyle(
              color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
