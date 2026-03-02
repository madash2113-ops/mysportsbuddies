import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import 'live_scoreboard_screen.dart';
import 'match_report_screen.dart';
import 'match_setup_screen.dart';
import 'scoreboard_screen.dart';

/// Shows live / completed matches. If [sportName] is null, shows all sports.
/// All viewers subscribe to ScoreboardService so the list stays live.
class LiveMatchesScreen extends StatelessWidget {
  final String? sportName;

  const LiveMatchesScreen({super.key, this.sportName});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreboardService>(
      builder: (context, svc, _) {
        final matches = sportName != null
            ? svc.bySport(sportName!)
            : (svc.all.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

        final title =
            sportName != null ? '$sportName Scoreboards' : 'All Scoreboards';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            title: Text(
              title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_chart_outlined, color: Colors.white),
                tooltip: 'Create Scoreboard',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => sportName != null
                        ? MatchSetupScreen(sportName: sportName!)
                        : const ScoreboardScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: matches.isEmpty
              ? _EmptyState(sportName: sportName)
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: matches.length,
                  itemBuilder: (context, i) =>
                      _MatchCard(match: matches[i]),
                ),
        );
      },
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? sportName;
  const _EmptyState({this.sportName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.scoreboard_outlined,
                color: Colors.white.withValues(alpha: 0.2), size: 64),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No scoreboards yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a scoreboard to start tracking\nyour $sportName match live.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => sportName != null
                      ? MatchSetupScreen(sportName: sportName!)
                      : const ScoreboardScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Create Scoreboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Match card ─────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final LiveMatch match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live;
    final isDone = match.status == MatchStatus.completed;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LiveScoreboardScreen(
          matchId: match.id,
          isScorer: false,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLive
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: Row(children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLive
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isLive ? '● LIVE' : isDone ? '✓ FT' : '⏸',
                    style: TextStyle(
                      color: isLive ? AppColors.primary : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(match.format,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const Spacer(),
                Text(_timeAgo(match.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ]),
            ),

            // ── Score ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Teams + score
                  Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(match.teamA,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            Text(match.teamB,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ]),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Score display
                    _sportScore(match),
                  ]),

                  // ── Cricket extra info ─────────────────────────────
                  if (match.sport == MatchSport.cricket &&
                      match.cricket != null) ...[
                    const SizedBox(height: 6),
                    _cricketExtra(match),
                  ],

                  // ── Venue ──────────────────────────────────────────
                  if (match.venue.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Text(match.venue,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ],

                  // ── Result ─────────────────────────────────────────
                  if (isDone) ...[
                    const SizedBox(height: 8),
                    _resultBadge(match),
                  ],
                ],
              ),
            ),

            // ── Tap hint / View Report ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDone
                        ? 'Tap to view scoreboard →'
                        : 'Tap to view live scoreboard →',
                    style: TextStyle(
                        color: isLive
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontSize: 11),
                  ),
                  if (isDone)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MatchReportScreen(matchId: match.id),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.article_outlined,
                                color: AppColors.primary, size: 13),
                            SizedBox(width: 4),
                            Text('Report',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sportScore(LiveMatch m) {
    switch (m.sport) {
      case MatchSport.cricket:
        final cr = m.cricket;
        if (cr == null) return _bigScore('–', '–');
        final inn = cr.currentInnings;
        // Show both innings if 2nd innings started
        if (cr.innings.length == 2) {
          final inn1 = cr.innings[0];
          final inn2 = cr.innings[1];
          return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(inn1.fullStr,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            Text(inn2.fullStr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ]);
        }
        return _bigScore('${inn.runs}/${inn.wickets}',
            '(${inn.oversStr})');

      case MatchSport.football:
        final f = m.football;
        return _bigScore('${f?.teamAGoals ?? 0}',
            '${f?.teamBGoals ?? 0}');

      case MatchSport.basketball:
        final b = m.basketball;
        return _bigScore('${b?.teamATotal ?? 0}',
            '${b?.teamBTotal ?? 0}');

      case MatchSport.badminton:
      case MatchSport.tableTennis:
      case MatchSport.volleyball:
      case MatchSport.tennis:
        final r = m.rally;
        if (r == null) return _bigScore('0', '0');
        return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${r.setsWonA} – ${r.setsWonB} sets',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(
              '${r.currentSet.scoreA} – ${r.currentSet.scoreB} pts',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
        ]);

      case MatchSport.hockey:
        final h = m.hockey;
        return _bigScore('${h?.teamAGoals ?? 0}',
            '${h?.teamBGoals ?? 0}');

      case MatchSport.boxing:
        final c = m.combat;
        return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Rnd ${c?.currentRound ?? 1}/${c?.totalRounds ?? 3}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]);

      case MatchSport.csgo:
      case MatchSport.valorant:
        final e = m.esports;
        return _bigScore('${e?.teamARounds ?? 0}',
            '${e?.teamBRounds ?? 0}');

      default:
        return _bigScore('–', '–');
    }
  }

  Widget _bigScore(String a, String b) => Row(children: [
        Text(a,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('–',
              style: TextStyle(color: AppColors.textMuted, fontSize: 20)),
        ),
        Text(b,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
      ]);

  Widget _cricketExtra(LiveMatch m) {
    final inn = m.cricket!.currentInnings;
    return Row(children: [
      _chip('CRR: ${inn.currentRunRate.toStringAsFixed(2)}'),
      if (inn.target != null) ...[
        const SizedBox(width: 6),
        _chip('Need: ${inn.neededRuns}'),
        const SizedBox(width: 6),
        _chip('RRR: ${inn.requiredRunRate.toStringAsFixed(2)}'),
      ],
    ]);
  }

  Widget _resultBadge(LiveMatch m) {
    String result = '';
    if (m.sport == MatchSport.cricket) {
      result = m.cricket?.matchResult ?? '';
    } else if (m.sport == MatchSport.boxing) {
      final c = m.combat;
      if (c != null && c.winner.isNotEmpty) {
        result = '${c.winner == 'A' ? m.teamA : m.teamB} by ${c.result}';
      }
    } else if (m.rally?.isMatchOver == true) {
      final r = m.rally!;
      result = '${r.matchWinner == 'A' ? m.teamA : m.teamB} wins';
    } else if (m.esports?.isMatchOver == true) {
      final e = m.esports!;
      result = '${e.matchWinner == 'A' ? m.teamA : m.teamB} wins';
    } else if (m.basketball?.isMatchOver == true) {
      result = m.basketball!.matchResult;
    }
    if (result.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text('✓ $result',
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
