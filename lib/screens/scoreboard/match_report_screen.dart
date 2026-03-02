import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../../services/match_report_pdf.dart';
import '../../services/user_service.dart';
import '../premium/premium_screen.dart';

class MatchReportScreen extends StatelessWidget {
  final String matchId;
  const MatchReportScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreboardService>(
      builder: (context, svc, _) {
        final match = svc.byId(matchId);
        if (match == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Text('Match not found',
                  style: TextStyle(color: Colors.white)),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            title: const Text(
              'Match Report',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white70),
                tooltip: 'Download PDF',
                onPressed: () {
                  if (UserService().hasFullAccess) {
                    MatchReportPdf.printReport(match);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReportHeader(match: match),
                const SizedBox(height: AppSpacing.md),

                // Cricket: full report
                if (match.sport == MatchSport.cricket &&
                    match.cricket != null) ...[
                  // Man of the Match
                  if (match.cricket!.manOfMatch != null) ...[
                    _MoMCard(
                        name: match.cricket!.manOfMatch!,
                        sport: match.sportDisplayName),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  // Each innings
                  ...match.cricket!.innings.asMap().entries.map(
                        (e) => _InningsCard(
                            innings: e.value,
                            inningsNum: e.key + 1),
                      ),
                  // Result
                  if (match.cricket!.matchResult.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ResultBanner(result: match.cricket!.matchResult),
                  ],
                ] else ...[
                  // Generic: simple result card
                  _SimpleScoreCard(match: match),
                  const SizedBox(height: AppSpacing.md),
                  _ResultBanner(result: _genericResult(match)),
                ],

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  String _genericResult(LiveMatch match) {
    if (match.sport == MatchSport.football && match.football != null) {
      final f = match.football!;
      if (f.teamAGoals > f.teamBGoals) return '${match.teamA} won';
      if (f.teamBGoals > f.teamAGoals) return '${match.teamB} won';
      return 'Draw';
    }
    if (match.sport == MatchSport.basketball && match.basketball != null) {
      return match.basketball!.matchResult;
    }
    return 'Match completed';
  }
}

// ── Report Header ─────────────────────────────────────────────────────────────

class _ReportHeader extends StatelessWidget {
  final LiveMatch match;
  const _ReportHeader({required this.match});

  @override
  Widget build(BuildContext context) {
    final date = match.createdAt;
    final dateStr =
        '${date.day}/${date.month}/${date.year}  ·  ${_fmtTime(date)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A0000), Color(0xFF1A0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              match.format.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${match.teamA}  vs  ${match.teamB}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (match.venue.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.white60, size: 13),
                const SizedBox(width: 4),
                Text(match.venue,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12)),
              ],
            ),
          const SizedBox(height: 4),
          Text(dateStr,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
}

// ── Man of the Match Card ─────────────────────────────────────────────────────

class _MoMCard extends StatelessWidget {
  final String name;
  final String sport;
  const _MoMCard({required this.name, required this.sport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.star_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MAN OF THE MATCH',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Text(sport,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Innings Card ──────────────────────────────────────────────────────────────

class _InningsCard extends StatelessWidget {
  final CricketInnings innings;
  final int inningsNum;
  const _InningsCard({required this.innings, required this.inningsNum});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Innings header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Innings $inningsNum — ${innings.battingTeam}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Text(
                  innings.fullStr,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Batting table
                if (innings.batsmen.isNotEmpty) ...[
                  _sectionLabel('BATTING'),
                  const SizedBox(height: 6),
                  _BattingTable(batsmen: innings.batsmen),
                  const SizedBox(height: 12),
                ],
                // Bowling table
                if (innings.bowlers.isNotEmpty) ...[
                  _sectionLabel('BOWLING'),
                  const SizedBox(height: 6),
                  _BowlingTable(bowlers: innings.bowlers),
                  const SizedBox(height: 12),
                ],
                // Extras
                Row(children: [
                  _sectionLabel('EXTRAS'),
                  const SizedBox(width: 8),
                  Text(
                    '${innings.extras}  (W ${innings.wides}, NB ${innings.noBalls}, B ${innings.byes}, LB ${innings.legByes})',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                  ),
                ]),
                // Fall of wickets
                if (innings.fow.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _sectionLabel('FALL OF WICKETS'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: innings.fow.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${f.wicketNum}-${f.runs} (${f.batsmanName}, ${f.oversStr})',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0),
      );
}

// ── Batting Table ─────────────────────────────────────────────────────────────

class _BattingTable extends StatelessWidget {
  final List<CricketBatsman> batsmen;
  const _BattingTable({required this.batsmen});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(0.8),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(1.2),
      },
      children: [
        _headerRow(['Batsman', 'R', 'B', '4s', '6s', 'SR']),
        ...batsmen.map((b) => TableRow(
              children: [
                _cell(b.name,
                    bold: !b.isOut, italic: b.isStriker),
                _cell('${b.runs}', bold: true),
                _cell('${b.balls}'),
                _cell('${b.fours}'),
                _cell('${b.sixes}'),
                _cell(b.srStr),
              ],
            )),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1))),
        ),
        children: labels
            .map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ))
            .toList(),
      );

  Widget _cell(String text, {bool bold = false, bool italic = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: bold ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
}

// ── Bowling Table ─────────────────────────────────────────────────────────────

class _BowlingTable extends StatelessWidget {
  final List<CricketBowler> bowlers;
  const _BowlingTable({required this.bowlers});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(0.8),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(0.8),
        5: FlexColumnWidth(1.2),
      },
      children: [
        _headerRow(['Bowler', 'O', 'M', 'R', 'W', 'Eco']),
        ...bowlers.map((b) => TableRow(
              children: [
                _cell(b.name, bold: b.wickets > 0),
                _cell(b.oversStr),
                _cell('${b.maidens}'),
                _cell('${b.runs}'),
                _cell('${b.wickets}', bold: b.wickets > 0),
                _cell(b.ecoStr),
              ],
            )),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) => TableRow(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1))),
        ),
        children: labels
            .map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l,
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ))
            .toList(),
      );

  Widget _cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: bold ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
}

// ── Simple Score Card (non-cricket) ──────────────────────────────────────────

class _SimpleScoreCard extends StatelessWidget {
  final LiveMatch match;
  const _SimpleScoreCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final scoreA = _scoreFor(match, 'A');
    final scoreB = _scoreFor(match, 'B');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _teamScore(match.teamA, scoreA),
          const Text('—',
              style: TextStyle(color: Colors.white38, fontSize: 28)),
          _teamScore(match.teamB, scoreB),
        ],
      ),
    );
  }

  Widget _teamScore(String name, String score) => Column(
        children: [
          Text(name,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(score,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
        ],
      );

  String _scoreFor(LiveMatch m, String side) {
    if (m.sport == MatchSport.football) {
      return side == 'A'
          ? '${m.football?.teamAGoals ?? 0}'
          : '${m.football?.teamBGoals ?? 0}';
    }
    if (m.sport == MatchSport.basketball) {
      return side == 'A'
          ? '${m.basketball?.teamATotal ?? 0}'
          : '${m.basketball?.teamBTotal ?? 0}';
    }
    if (m.sport == MatchSport.hockey) {
      return side == 'A'
          ? '${m.hockey?.teamAGoals ?? 0}'
          : '${m.hockey?.teamBGoals ?? 0}';
    }
    return '—';
  }
}

// ── Result Banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final String result;
  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        result,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: AppColors.primary,
            fontSize: 15,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
