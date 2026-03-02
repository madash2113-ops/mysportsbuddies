import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../scoreboard/live_scoreboard_screen.dart';
import '../scoreboard/match_report_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return _EmptyState(label: emptyLabel);
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: matches.length,
      itemBuilder: (_, i) => _MatchCard(match: matches[i]),
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

  Color get _statusColor {
    switch (match.status) {
      case MatchStatus.live:      return AppColors.primary;
      case MatchStatus.completed: return Colors.green;
      case MatchStatus.paused:    return Colors.amber;
    }
  }

  String get _statusLabel {
    switch (match.status) {
      case MatchStatus.live:      return '● LIVE';
      case MatchStatus.completed: return '✓ FT';
      case MatchStatus.paused:    return '⏸ Paused';
    }
  }

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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      match.sportDisplayName,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (match.format.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '• ${match.format}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _timeAgo(match.createdAt),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.teamA,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'vs',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          match.teamB,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (match.venue.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Colors.white38, size: 12),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  match.venue,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ScoreWidget(match: match),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Text(
                isDone ? 'Tap to view report →' : 'Tap to score →',
                style: TextStyle(
                  color: isLive ? AppColors.primary : Colors.white38,
                  fontSize: 11,
                ),
              ),
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
