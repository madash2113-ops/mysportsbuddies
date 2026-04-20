import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../../services/match_report_pdf.dart';
import '../../core/models/entitlements.dart';
import '../../services/user_service.dart';
import '../premium/premium_screen.dart';

class MatchReportScreen extends StatelessWidget {
  final String matchId;
  const MatchReportScreen({super.key, required this.matchId});

  static void _showPdfPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Export PDF Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Export this match as a formatted PDF scorecard — batting, bowling, fall of wickets and result on one page.',
                style: TextStyle(
                    color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(
                          context: PremiumContext.player,
                          reason: 'Export this match as a PDF report.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Unlock PDF Export',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  if (UserService().hasEntitlement(Entitlements.pdfReports)) {
                    MatchReportPdf.printReport(match);
                  } else {
                    _showPdfPaywall(context);
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

                // Cricket: full scorecard
                if (match.sport == MatchSport.cricket &&
                    match.cricket != null) ...[
                  // Team squads
                  _SquadsCard(match: match),
                  const SizedBox(height: AppSpacing.md),

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
                          inningsNum: e.key + 1,
                          match: match,
                        ),
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

// ── Team Squads Card ──────────────────────────────────────────────────────────

class _SquadsCard extends StatelessWidget {
  final LiveMatch match;
  const _SquadsCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final hasAny = match.teamAPlayers.isNotEmpty || match.teamBPlayers.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Text(
              'SQUADS',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team A
                Expanded(
                  child: _SquadColumn(
                    teamName: match.teamA,
                    players: match.teamAPlayers,
                  ),
                ),
                Container(
                  width: 1,
                  height: _squadHeight(match.teamAPlayers, match.teamBPlayers),
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Team B
                Expanded(
                  child: _SquadColumn(
                    teamName: match.teamB,
                    players: match.teamBPlayers,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _squadHeight(List<String> a, List<String> b) {
    final count = a.length > b.length ? a.length : b.length;
    return (count * 22.0) + 24.0;
  }
}

class _SquadColumn extends StatelessWidget {
  final String teamName;
  final List<String> players;
  const _SquadColumn({required this.teamName, required this.players});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        ...players.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(
                    '${e.key + 1}. ',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
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
  final int            inningsNum;
  final LiveMatch      match;

  const _InningsCard({
    required this.innings,
    required this.inningsNum,
    required this.match,
  });

  /// Players from the batting team's squad who did not bat this innings.
  List<String> get _didNotBat {
    final squad = innings.battingTeam == match.teamA
        ? match.teamAPlayers
        : match.teamBPlayers;
    final batted = innings.batsmen.map((b) => b.name).toSet();
    return squad
        .where((p) => p.isNotEmpty && !batted.contains(p))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dnb = _didNotBat;

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
                ],

                // Did not bat
                if (dnb.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('DID NOT BAT'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dnb.join(', '),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],

                // Bowling table
                if (innings.bowlers.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
        0: FlexColumnWidth(3.2),
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
                _nameCell(b),
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

  /// Name cell with dismissal/status as subtext.
  Widget _nameCell(CricketBatsman b) {
    final howOut = b.isOut
        ? (b.dismissal.isNotEmpty ? b.dismissal : 'out')
        : 'not out*';
    final howOutColor = b.isOut ? Colors.white38 : Colors.green.shade300;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            b.name,
            style: TextStyle(
              color: b.isOut ? Colors.white70 : Colors.white,
              fontSize: 12,
              fontWeight: b.isOut ? FontWeight.normal : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            howOut,
            style: TextStyle(
              color: howOutColor,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

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
