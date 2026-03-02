import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import 'match_report_screen.dart';

/// Live Scoreboard screen.
/// [isScorer] = true → shows update controls (scorer device)
/// [isScorer] = false → read-only view (spectator device)
///
/// All consumers of [ScoreboardService] rebuild every second (via Timer)
/// so the scoreboard stays live for every viewer on the same device session.
/// Once Firebase is wired up, replace ScoreboardService internals only.
class LiveScoreboardScreen extends StatefulWidget {
  final String matchId;
  final bool isScorer;

  const LiveScoreboardScreen({
    super.key,
    required this.matchId,
    this.isScorer = false,
  });

  @override
  State<LiveScoreboardScreen> createState() => _LiveScoreboardScreenState();
}

class _LiveScoreboardScreenState extends State<LiveScoreboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreboardService>(
      builder: (context, svc, _) {
        final match = svc.byId(widget.matchId);
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
          appBar: _buildAppBar(match, svc),
          body: Column(
            children: [
              Expanded(child: _buildScoreboard(match, svc)),
              if (widget.isScorer && match.status == MatchStatus.live)
                _buildControls(match, svc),
            ],
          ),
        );
      },
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(LiveMatch match, ScoreboardService svc) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: const BackButton(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${match.teamA} vs ${match.teamB}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            '${match.sportDisplayName}  ·  ${match.format}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        _statusBadge(match.status),
        if (widget.isScorer && match.status == MatchStatus.live) ...[
          TextButton(
            onPressed: () => _endMatch(match, svc),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('END',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
        if (match.status == MatchStatus.completed)
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MatchReportScreen(matchId: match.id)),
            ),
            icon: const Icon(Icons.article_outlined, size: 16, color: Colors.white70),
            label: const Text('Report',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _statusBadge(MatchStatus status) {
    final color = status == MatchStatus.live
        ? AppColors.primary
        : status == MatchStatus.paused
            ? Colors.amber
            : Colors.grey;
    final label = status == MatchStatus.live
        ? '● LIVE'
        : status == MatchStatus.paused
            ? '⏸ PAUSED'
            : '✓ FT';
    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Main scoreboard dispatch ──────────────────────────────────────────────

  Widget _buildScoreboard(LiveMatch match, ScoreboardService svc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: switch (engineForSport(match.sport)) {
        SportEngine.cricket  => _CricketBoard(match: match, svc: svc),
        SportEngine.football => _FootballBoard(match: match),
        SportEngine.basketball => _BasketballBoard(match: match),
        SportEngine.rally    => _RallyBoard(match: match),
        SportEngine.hockey   => _HockeyBoard(match: match),
        SportEngine.combat   => _BoxingBoard(match: match),
        SportEngine.esports  => _EsportsBoard(match: match),
        SportEngine.generic  => _GenericBoard(match: match),
      },
    );
  }

  // ── Score update controls dispatch ───────────────────────────────────────

  Widget _buildControls(LiveMatch match, ScoreboardService svc) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08))),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
      child: switch (engineForSport(match.sport)) {
        SportEngine.cricket =>
          _CricketControls(match: match, svc: svc, ctx: context),
        SportEngine.football =>
          _FootballControls(match: match, svc: svc, ctx: context),
        SportEngine.basketball =>
          _BasketballControls(match: match, svc: svc),
        SportEngine.rally =>
          _RallyControls(match: match, svc: svc),
        SportEngine.hockey =>
          _HockeyControls(match: match, svc: svc, ctx: context),
        SportEngine.combat =>
          _BoxingControls(match: match, svc: svc, ctx: context),
        SportEngine.esports =>
          _EsportsControls(match: match, svc: svc),
        SportEngine.generic =>
          _GenericControls(match: match, svc: svc, ctx: context),
      },
    );
  }

  void _endMatch(LiveMatch match, ScoreboardService svc) {
    if (match.sport == MatchSport.cricket && match.cricket != null) {
      _showCricketEndDialog(match, svc);
    } else {
      _showSimpleEndDialog(match, svc);
    }
  }

  void _showSimpleEndDialog(LiveMatch match, ScoreboardService svc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('End Match?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This will mark the match as completed.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.endMatch(match.id, 'Match ended');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('End Match'),
          ),
        ],
      ),
    );
  }

  void _showCricketEndDialog(LiveMatch match, ScoreboardService svc) {
    final cr = match.cricket!;
    final seen = <String>{};
    final players = <String>[];
    for (final inn in cr.innings) {
      for (final b in inn.batsmen) {
        if (seen.add(b.name)) players.add(b.name);
      }
      for (final b in inn.bowlers) {
        if (seen.add(b.name)) players.add(b.name);
      }
    }
    String? selected = players.isNotEmpty ? players.first : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('End Match',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Man of the Match',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              if (players.isEmpty)
                const Text('No players recorded.',
                    style: TextStyle(color: AppColors.textMuted))
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selected,
                    dropdownColor: AppColors.card,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: players
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setS(() => selected = v),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted))),
            // "Match Drawn" option for Test cricket
            if (cr.format == 'Test')
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (selected != null) svc.setManOfMatch(match.id, selected!);
                    svc.endMatch(match.id, 'Match Drawn');
                  },
                  child: const Text('Draw',
                      style: TextStyle(color: Colors.amber))),
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  svc.endMatch(match.id,
                      cr.matchResult.isNotEmpty ? cr.matchResult : 'Match ended');
                },
                child: const Text('Skip MoM',
                    style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (selected != null) svc.setManOfMatch(match.id, selected!);
                svc.endMatch(match.id,
                    cr.matchResult.isNotEmpty ? cr.matchResult : 'Match ended');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('End Match'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CRICKET SCOREBOARD
// ════════════════════════════════════════════════════════════════════════════

class _CricketBoard extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  const _CricketBoard({required this.match, required this.svc});

  @override
  Widget build(BuildContext context) {
    final cr = match.cricket!;
    final inn = cr.currentInnings;

    return Column(
      children: [
        // ── Innings header ───────────────────────────────────────────────
        _card(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              inn.battingTeam,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'vs ${inn.bowlingTeam}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(
              '${inn.runs}/${inn.wickets}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('(${inn.oversStr} ov)',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
              if (cr.format != 'Test')
                Text('${cr.totalOvers} overs',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
            const Spacer(),
            if (inn.target != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Target: ${inn.target}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text('Need: ${inn.neededRuns}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _rate('CRR', inn.currentRunRate.toStringAsFixed(2)),
            if (inn.target != null) ...[
              const SizedBox(width: 20),
              _rate('RRR', inn.requiredRunRate.toStringAsFixed(2)),
              const SizedBox(width: 20),
              _rate('Balls left', '${inn.remainingBalls}'),
            ],
          ]),
          // Format-specific phase badge
          Builder(builder: (_) {
            final phase = _cricketPhase(cr.format, inn.completedOvers);
            if (phase.isEmpty || inn.isComplete) return const SizedBox.shrink();
            final col = _phaseColor(phase);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: col.withValues(alpha: 0.5)),
                  ),
                  child: Text(phase,
                      style: TextStyle(
                          color: col,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                ),
              ),
            );
          }),
          if (cr.currentInningsNum == 1 && cr.innings[0].isComplete)
            _infoChip('1st Innings complete — tap "Start 2nd Innings"'),
          if (cr.isMatchOver)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _infoChip('✓ ${cr.matchResult}', isResult: true),
            ),
        ])),

        // ── Innings tab (2nd innings) ─────────────────────────────────────
        if (cr.innings.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(children: cr.innings.map((inn) {
              final isCurrent = cr.innings.indexOf(inn) == cr.innings.length - 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${inn.inningsNum == 1 ? '1st' : '2nd'}: ${inn.fullStr}',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList()),
          ),

        // ── Batsmen ───────────────────────────────────────────────────────
        if (inn.batsmen.isNotEmpty)
          _card(
            label: 'BATTING',
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(0.8),
                4: FlexColumnWidth(0.8),
                5: FlexColumnWidth(1.5),
              },
              children: [
                _tableHeader(['Batsman', 'R', 'B', '4s', '6s', 'SR']),
                ...inn.batsmen.where((b) => !b.isOut).map((b) => _batsmanRow(b)),
              ],
            ),
          ),

        // ── Current bowler ────────────────────────────────────────────────
        if (inn.currentBowler != null)
          _card(
            label: 'BOWLING',
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(0.8),
                3: FlexColumnWidth(0.8),
                4: FlexColumnWidth(0.8),
                5: FlexColumnWidth(1.5),
              },
              children: [
                _tableHeader(['Bowler', 'O', 'M', 'R', 'W', 'Eco']),
                ...inn.bowlers.map((b) => _bowlerRow(b)),
              ],
            ),
          ),

        // ── Extras ────────────────────────────────────────────────────────
        if (inn.extras > 0)
          _card(
            child: Row(children: [
              const Text('Extras', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const Spacer(),
              Text('${inn.extras}', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 16),
              Text('W:${inn.wides} NB:${inn.noBalls} B:${inn.byes} LB:${inn.legByes}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ),

        // ── Fall of Wickets ───────────────────────────────────────────────
        if (inn.fow.isNotEmpty)
          _card(
            label: 'FALL OF WICKETS',
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: inn.fow
                  .map((f) => Text(
                        '${f.wicketNum}/${f.runs} (${f.batsmanName}, ${f.oversStr})',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  TableRow _tableHeader(List<String> cols) => TableRow(
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        children: cols
            .map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(c,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ))
            .toList(),
      );

  TableRow _batsmanRow(CricketBatsman b) => TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              if (b.isStriker)
                const Text('* ',
                    style: TextStyle(color: AppColors.primary, fontSize: 12)),
              Flexible(
                child: Text(b.name,
                    style: TextStyle(
                        color: b.isStriker ? Colors.white : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: b.isStriker
                            ? FontWeight.bold
                            : FontWeight.normal),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          _cell('${b.runs}', bold: true),
          _cell('${b.balls}'),
          _cell('${b.fours}'),
          _cell('${b.sixes}'),
          _cell(b.srStr),
        ],
      );

  TableRow _bowlerRow(CricketBowler b) => TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(b.name,
                style: TextStyle(
                    color: b.isCurrent ? Colors.white : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight:
                        b.isCurrent ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis),
          ),
          _cell(b.oversStr, bold: b.isCurrent),
          _cell('${b.maidens}'),
          _cell('${b.runs}'),
          _cell('${b.wickets}', bold: b.wickets > 0, red: b.wickets > 0),
          _cell(b.ecoStr),
        ],
      );

  Widget _cell(String v,
          {bool bold = false, bool red = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(v,
            style: TextStyle(
                color: red ? AppColors.primary : Colors.white,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  /// Returns the current match phase label based on format & completed overs.
  static String _cricketPhase(String format, int completedOvers) {
    switch (format) {
      case 'T20':
        if (completedOvers < 6) return 'POWERPLAY';
        if (completedOvers < 16) return 'MIDDLE OVERS';
        return 'DEATH OVERS';
      case 'T10':
        if (completedOvers < 2) return 'POWERPLAY';
        if (completedOvers < 8) return 'MIDDLE OVERS';
        return 'DEATH OVERS';
      case 'ODI':
        if (completedOvers < 10) return 'POWERPLAY';
        if (completedOvers < 41) return 'MIDDLE OVERS';
        return 'DEATH OVERS';
      default:
        return ''; // Test / Custom — no phase
    }
  }

  static Color _phaseColor(String phase) {
    switch (phase) {
      case 'POWERPLAY':
        return AppColors.primary; // red
      case 'DEATH OVERS':
        return Colors.orange;
      default:
        return Colors.white38; // MIDDLE OVERS
    }
  }

  Widget _rate(String label, String val) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          Text(val,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
// CRICKET CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _CricketControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  final BuildContext ctx;
  const _CricketControls(
      {required this.match, required this.svc, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final cr = match.cricket!;
    final inn = cr.currentInnings;

    // If innings over, show either "Start 2nd Innings" or nothing
    if (inn.isComplete && cr.currentInningsNum == 1) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _startSecondInnings(context),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Start 2nd Innings'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      );
    }
    if (inn.isComplete || cr.isMatchOver) {
      return const SizedBox.shrink();
    }

    // No batsmen yet → mandatory opener/bowler setup
    if (inn.batsmen.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _promptOpeners(context),
          icon: const Icon(Icons.people_alt_outlined),
          label: const Text('Setup Openers & Bowler'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      );
    }

    // Prompt for new bowler (after over)
    if (inn.needsNewBowler) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => _promptNewBowler(context),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Enter New Bowler'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Undo last ball (shown when undo history is available)
        if (svc.canUndo(match.id))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => svc.undo(match.id),
                icon: const Icon(Icons.undo, size: 15, color: Colors.white60),
                label: const Text('Undo last ball',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        // Run buttons
        Row(children: [
          _runBtn(context, 0),
          _runBtn(context, 1),
          _runBtn(context, 2),
          _runBtn(context, 3),
          _runBtn(context, 4),
          _runBtn(context, 6),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // Extras + events row 1
        Row(children: [
          _ctrlBtn(context, 'Wide', color: Colors.orange,
              onTap: () => _showExtrasSheet(context, 'Wide', 'wide')),
          _ctrlBtn(context, 'No Ball', color: Colors.orange,
              onTap: () => _showNoBallSheet(context)),
          _ctrlBtn(context, 'Bye',
              onTap: () => _showExtrasSheet(context, 'Bye', 'bye')),
          _ctrlBtn(context, 'Leg Bye',
              onTap: () => _showExtrasSheet(context, 'Leg Bye', 'legbye')),
          _ctrlBtn(context, 'Wicket',
              color: AppColors.primary,
              onTap: () => _promptWicket(context)),
        ]),
        const SizedBox(height: AppSpacing.sm - 4),
        // Extra row 2: Swap + Ret. Hurt + Declare (Test only)
        Row(children: [
          _ctrlBtn(context, 'Swap \u21c4',
              color: Colors.teal,
              onTap: () => svc.cricketSwapBatsmen(match.id)),
          _ctrlBtn(context, 'Ret. Hurt',
              color: Colors.amber,
              onTap: () => _promptInjuredReplace(context)),
          if (cr.format == 'Test')
            _ctrlBtn(context, 'Declare',
                color: Colors.purple,
                onTap: () => _promptDeclare(context)),
        ]),
      ],
    );
  }

  Widget _runBtn(BuildContext context, int runs) => Expanded(
        child: GestureDetector(
          onTap: () => svc.cricketAddRuns(match.id, runs),
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: runs == 4
                  ? Colors.blue.withValues(alpha: 0.3)
                  : runs == 6
                      ? Colors.green.withValues(alpha: 0.3)
                      : AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Text('$runs',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );

  Widget _ctrlBtn(BuildContext context, String label,
      {required VoidCallback onTap, Color? color}) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (color ?? Colors.white).withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      );

  /// Show bottom sheet to pick batsman runs off a No Ball delivery.
  void _showNoBallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'No Ball \u2014 Runs scored by batsman?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // Chip row: 0, 1, 2, 4, 6
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0, 1, 2, 4, 6].map((batRuns) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      // Total runs = batRuns + 1 NB penalty
                      svc.cricketAddRuns(
                        match.id,
                        batRuns + 1,
                        extraType: 'nob',
                        nobBatRuns: batRuns,
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: batRuns == 4
                            ? Colors.blue.withValues(alpha: 0.25)
                            : batRuns == 6
                                ? Colors.green.withValues(alpha: 0.25)
                                : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          '$batRuns',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'NB penalty (+1) added automatically',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _promptWicket(BuildContext context) {
    final inn = match.cricket!.currentInnings;

    // Determine roster availability
    final isBattingTeamA = inn.battingTeam == match.teamA;
    final battingRoster =
        isBattingTeamA ? match.teamAPlayers : match.teamBPlayers;
    final hasRoster = battingRoster.isNotEmpty;

    // Active (not-out) batsmen for "who got out" dropdown
    final activeBatsmen =
        inn.batsmen.where((b) => !b.isOut).map((b) => b.name).toList();

    // Players not yet at the crease (for "new batsman" dropdown)
    final usedNames = inn.batsmen.map((b) => b.name).toSet();
    final nextBatsmen = hasRoster
        ? battingRoster.where((p) => !usedNames.contains(p)).toList()
        : <String>[];

    // Fallback text controllers (used when no roster)
    final outCtrl = TextEditingController(text: inn.striker?.name ?? '');
    final newCtrl = TextEditingController();

    // Pre-select striker as the out player; pre-select next batsman if available
    String? outPlayer = inn.striker?.name;
    String? newBatsman = nextBatsmen.isNotEmpty ? nextBatsmen[0] : null;
    String dismissal = 'Caught';
    final dismissals = [
      'Caught', 'Bowled', 'LBW', 'Run Out', 'Stumped',
      'Hit Wicket', 'Caught & Bowled', 'Retired'
    ];

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Wicket', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Batsman Out ─────────────────────────────────────────────
              if (hasRoster && activeBatsmen.isNotEmpty)
                _dialogDropdown('Batsman Out', activeBatsmen, outPlayer,
                    (v) => setDialogState(() => outPlayer = v))
              else
                _dialogField('Batsman Out', outCtrl),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Dismissal',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dismissals.map((d) {
                  final sel = d == dismissal;
                  return GestureDetector(
                    onTap: () => setDialogState(() => dismissal = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d,
                          style: TextStyle(
                              color: sel ? Colors.white : AppColors.textMuted,
                              fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // ── New Batsman ──────────────────────────────────────────────
              if (hasRoster && nextBatsmen.isNotEmpty)
                _dialogDropdown('New Batsman', nextBatsmen, newBatsman,
                    (v) => setDialogState(() => newBatsman = v))
              else
                _dialogField('New Batsman Name', newCtrl),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dCtx);
                final out = hasRoster
                    ? (outPlayer ?? outCtrl.text.trim())
                    : outCtrl.text.trim();
                final newB = hasRoster
                    ? (newBatsman ?? newCtrl.text.trim())
                    : newCtrl.text.trim();
                svc.cricketWicket(match.id, dismissal, out, newB);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _promptNewBowler(BuildContext context) {
    final inn = match.cricket!.currentInnings;
    final isBowlingTeamA = inn.bowlingTeam == match.teamA;
    final bowlingRoster =
        isBowlingTeamA ? match.teamAPlayers : match.teamBPlayers;
    final hasRoster = bowlingRoster.isNotEmpty;

    final ctrl = TextEditingController();
    String? selectedBowler;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Over Complete \u2014 New Bowler',
              style: TextStyle(color: Colors.white)),
          content: hasRoster
              ? _dialogDropdown('Select Bowler', bowlingRoster, selectedBowler,
                  (v) => setS(() => selectedBowler = v))
              : _dialogField('Bowler Name', ctrl),
          actions: [
            ElevatedButton(
              onPressed: () {
                final name =
                    hasRoster ? (selectedBowler ?? '') : ctrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(context);
                svc.cricketNewBowler(match.id, name);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Set Bowler'),
            ),
          ],
        ),
      ),
    );
  }

  void _startSecondInnings(BuildContext context) {
    final cr = match.cricket!;
    final firstInnBatTeam = cr.innings[0].battingTeam;
    final isBatTeamA = firstInnBatTeam != match.teamA; // 2nd innings batting team
    final battingRoster = isBatTeamA ? match.teamAPlayers : match.teamBPlayers;
    final bowlingRoster = isBatTeamA ? match.teamBPlayers : match.teamAPlayers;
    final hasRoster = battingRoster.isNotEmpty;

    final b1 = TextEditingController();
    final b2 = TextEditingController();
    final bowl = TextEditingController();
    String? bat1, bat2, bowler;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Start 2nd Innings',
              style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (hasRoster) ...[
              _dialogDropdown('Opener 1 (Striker)', battingRoster, bat1,
                  (v) => setS(() {
                        bat1 = v;
                        if (bat2 == v) bat2 = null;
                      })),
              const SizedBox(height: 8),
              _dialogDropdown(
                  'Opener 2 (Non-striker)',
                  battingRoster.where((p) => p != bat1).toList(),
                  bat2,
                  (v) => setS(() => bat2 = v)),
              const SizedBox(height: 8),
              _dialogDropdown('Opening Bowler', bowlingRoster, bowler,
                  (v) => setS(() => bowler = v)),
            ] else ...[
              _dialogField('Opener 1 (Striker)', b1),
              const SizedBox(height: 8),
              _dialogField('Opener 2 (Non-striker)', b2),
              const SizedBox(height: 8),
              _dialogField('Opening Bowler', bowl),
            ],
          ]),
          actions: [
            ElevatedButton(
              onPressed: () {
                final s1 = hasRoster ? (bat1 ?? '') : b1.text.trim();
                final s2 = hasRoster ? (bat2 ?? '') : b2.text.trim();
                final bwl = hasRoster ? (bowler ?? '') : bowl.text.trim();
                if (s1.isEmpty || s2.isEmpty || bwl.isEmpty) return;
                Navigator.pop(context);
                svc.cricketStartSecondInnings(match.id, s1, s2, bwl);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog: enter injured batsman + replacement name.
  void _promptInjuredReplace(BuildContext context) {
    final inn = match.cricket!.currentInnings;
    final isBattingTeamA = inn.battingTeam == match.teamA;
    final battingRoster =
        isBattingTeamA ? match.teamAPlayers : match.teamBPlayers;
    final hasRoster = battingRoster.isNotEmpty;
    final usedNames = inn.batsmen.map((b) => b.name).toSet();
    final availablePlayers = hasRoster
        ? battingRoster.where((p) => !usedNames.contains(p)).toList()
        : <String>[];

    final injuredCtrl =
        TextEditingController(text: inn.striker?.name ?? '');
    final replacementCtrl = TextEditingController();
    String? selectedReplacement;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Retired Hurt \u2014 Replacement',
              style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField('Injured Batsman Name', injuredCtrl),
            const SizedBox(height: 10),
            if (hasRoster && availablePlayers.isNotEmpty)
              _dialogDropdown('Replacement Batsman', availablePlayers,
                  selectedReplacement, (v) => setS(() => selectedReplacement = v))
            else
              _dialogField('Replacement Batsman Name', replacementCtrl),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () {
                final inj = injuredCtrl.text.trim();
                final rep = hasRoster
                    ? (selectedReplacement ?? replacementCtrl.text.trim())
                    : replacementCtrl.text.trim();
                Navigator.pop(context);
                if (inj.isNotEmpty && rep.isNotEmpty) {
                  svc.cricketInjuredReplace(match.id, inj, rep);
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog: enter both openers + opening bowler (mandatory before scoring).
  void _promptOpeners(BuildContext context) {
    final inn = match.cricket!.currentInnings;
    final isBattingTeamA = inn.battingTeam == match.teamA;
    final battingRoster =
        isBattingTeamA ? match.teamAPlayers : match.teamBPlayers;
    final bowlingRoster =
        isBattingTeamA ? match.teamBPlayers : match.teamAPlayers;
    final hasRoster = battingRoster.isNotEmpty;

    final b1Ctrl = TextEditingController();
    final b2Ctrl = TextEditingController();
    final bowlCtrl = TextEditingController();
    String? bat1, bat2, bowler;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Setup Openers & Bowler',
              style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (hasRoster) ...[
              _dialogDropdown(
                  'Striker (Opener 1) *', battingRoster, bat1,
                  (v) => setS(() {
                        bat1 = v;
                        if (bat2 == v) bat2 = null;
                      })),
              const SizedBox(height: 10),
              _dialogDropdown(
                  'Non-Striker (Opener 2) *',
                  battingRoster.where((p) => p != bat1).toList(),
                  bat2,
                  (v) => setS(() => bat2 = v)),
              const SizedBox(height: 10),
              _dialogDropdown('Opening Bowler *', bowlingRoster, bowler,
                  (v) => setS(() => bowler = v)),
            ] else ...[
              _dialogField('Striker (Opener 1) *', b1Ctrl),
              const SizedBox(height: 10),
              _dialogField('Non-Striker (Opener 2) *', b2Ctrl),
              const SizedBox(height: 10),
              _dialogField('Opening Bowler *', bowlCtrl),
            ],
          ]),
          actions: [
            ElevatedButton(
              onPressed: () {
                final b1 = hasRoster ? (bat1 ?? '') : b1Ctrl.text.trim();
                final b2 = hasRoster ? (bat2 ?? '') : b2Ctrl.text.trim();
                final bwl =
                    hasRoster ? (bowler ?? '') : bowlCtrl.text.trim();
                if (b1.isEmpty || b2.isEmpty || bwl.isEmpty) return;
                Navigator.pop(context);
                svc.cricketSetupOpeners(match.id, b1, b2, bwl);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  /// Declare innings (Test cricket only).
  void _promptDeclare(BuildContext context) {
    final inn = match.cricket!.currentInnings;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Declare Innings?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '${inn.battingTeam} declare at ${inn.runs}/${inn.wickets} (${inn.oversStr} ov)',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.cricketDeclare(match.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Declare'),
          ),
        ],
      ),
    );
  }

  /// Compact dropdown for use inside dialogs.
  Widget _dialogDropdown(
    String label,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: value != null
                    ? AppColors.primary
                    : Colors.white24,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: const Text('Select player',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 14)),
                dropdownColor: AppColors.card,
                isExpanded: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.expand_more,
                    color: Colors.white54, size: 18),
                items: options.isEmpty
                    ? [
                        const DropdownMenuItem(
                            value: '',
                            child: Text('No players available',
                                style: TextStyle(
                                    color: Colors.white54)))
                      ]
                    : options
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                onChanged: options.isEmpty ? null : onChanged,
              ),
            ),
          ),
        ],
      );

  /// Bottom sheet: choose runs for Wide / Bye / Leg Bye.
  void _showExtrasSheet(BuildContext context, String label, String extraType) {
    // Wide: runs = selected + 1 (penalty). Bye/LegBye: runs = selected.
    final isWide = extraType == 'wide';
    const options = [0, 1, 2, 3, 4, 5, 6];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isWide
                    ? '$label \u2014 Runs off the wide?'
                    : '$label \u2014 How many runs?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: options.map((r) {
                  Color btnColor = AppColors.background;
                  if (r == 4) btnColor = Colors.blue.withValues(alpha: 0.25);
                  if (r == 6) btnColor = Colors.green.withValues(alpha: 0.25);
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      // For wide: total = r + 1 (penalty). For bye/legbye: total = r (if 0, still 1 extra ball).
                      final totalRuns = isWide ? r + 1 : (r == 0 ? 1 : r);
                      svc.cricketAddRuns(match.id, totalRuns,
                          extraType: extraType);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text('$r',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isWide
                    ? '+1 wide penalty added automatically'
                    : 'Runs go to extras, ball counts',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FOOTBALL SCOREBOARD
// ════════════════════════════════════════════════════════════════════════════

class _FootballBoard extends StatelessWidget {
  final LiveMatch match;
  const _FootballBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final f = match.football!;
    return Column(children: [
      _card(child: Column(children: [
        // Timer
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: f.isHalfTime
                  ? Colors.amber.withValues(alpha: 0.15)
                  : f.isFullTime
                      ? Colors.grey.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              f.isHalfTime
                  ? 'HALF TIME'
                  : f.isFullTime
                      ? 'FULL TIME'
                      : f.minuteStr,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        // Score
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(
              child: Text(match.teamA,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${f.teamAGoals}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('\u2013',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 40)),
              ),
              Text('${f.teamBGoals}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
              child: Text(match.teamB,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // HT score
        if (f.isHalfTime || f.isFullTime)
          Text('HT: ${f.htA} \u2013 ${f.htB}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        // Cards row
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _cardRow('\ud83d\udfe1', f.teamAYellow, '\ud83d\udd34', f.teamARed),
          _cardRow('\ud83d\udfe1', f.teamBYellow, '\ud83d\udd34', f.teamBRed),
        ]),
      ])),

      // Events
      if (f.events.isNotEmpty)
        _card(
          label: 'MATCH EVENTS',
          child: Column(
            children: f.events.reversed
                .take(12)
                .map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(
                          width: 36,
                          alignment: Alignment.center,
                          child: Text("${e.minute}'",
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ),
                        Text('${e.emoji}  ',
                            style: const TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text(e.player,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ),
                        Text(e.team == 'A' ? match.teamA : match.teamB,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    ))
                .toList(),
          ),
        ),
    ]);
  }

  Widget _cardRow(String y, int yc, String r, int rc) => Row(children: [
        if (yc > 0) Text('$y \xd7$yc  ', style: const TextStyle(fontSize: 12)),
        if (rc > 0) Text('$r \xd7$rc', style: const TextStyle(fontSize: 12)),
        if (yc == 0 && rc == 0)
          const Text('\u2013', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// FOOTBALL CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _FootballControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  final BuildContext ctx;
  const _FootballControls(
      {required this.match, required this.svc, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final f = match.football!;
    if (f.isFullTime) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Timer
      Row(children: [
        _ctrlBtn(
          f.isHalfTime ? '\u25b6 Resume (2nd Half)' : (f.timer.isRunning ? '\u23f8 Pause' : '\u25b6 Start'),
          color: f.isHalfTime ? Colors.green : AppColors.primary,
          onTap: () {
            if (f.isHalfTime) {
              svc.footballSecondHalf(match.id);
            } else {
              svc.footballToggleTimer(match.id);
            }
          },
        ),
        const SizedBox(width: 8),
        _ctrlBtn(
          f.isHalfTime ? 'HT' : 'Half Time',
          color: Colors.amber,
          onTap: () {
            if (!f.isHalfTime) svc.footballHalfTime(match.id);
          },
        ),
        const SizedBox(width: 8),
        _ctrlBtn('Full Time', color: Colors.grey,
            onTap: () => svc.footballFullTime(match.id)),
      ]),
      const SizedBox(height: AppSpacing.sm),
      // Goal buttons
      Row(children: [
        _ctrlBtn('\u26bd ${match.teamA}', color: AppColors.primary,
            onTap: () => _promptGoal(context, 'A')),
        const SizedBox(width: 8),
        _ctrlBtn('\u26bd ${match.teamB}', color: AppColors.primary,
            onTap: () => _promptGoal(context, 'B')),
      ]),
      const SizedBox(height: 6),
      // Card buttons
      Row(children: [
        _ctrlBtn('\ud83d\udfe1 ${match.teamA}',
            onTap: () => _promptCard(context, 'A', 'yellow')),
        const SizedBox(width: 4),
        _ctrlBtn('\ud83d\udd34 ${match.teamA}',
            onTap: () => _promptCard(context, 'A', 'red')),
        const SizedBox(width: 4),
        _ctrlBtn('\ud83d\udfe1 ${match.teamB}',
            onTap: () => _promptCard(context, 'B', 'yellow')),
        const SizedBox(width: 4),
        _ctrlBtn('\ud83d\udd34 ${match.teamB}',
            onTap: () => _promptCard(context, 'B', 'red')),
      ]),
    ]);
  }

  Widget _ctrlBtn(String label, {required VoidCallback onTap, Color? color}) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (color ?? Colors.white).withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );

  void _promptGoal(BuildContext context, String team) {
    final ctrl = TextEditingController();
    bool isOg = false;
    bool isPen = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, ss) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('\u26bd Goal \u2014 ${team == 'A' ? match.teamA : match.teamB}',
              style: const TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField('Scorer Name', ctrl),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Own Goal',
                  style: TextStyle(color: Colors.white)),
              value: isOg,
              onChanged: (v) => ss(() => isOg = v ?? false),
              activeColor: AppColors.primary,
            ),
            CheckboxListTile(
              title: const Text('Penalty',
                  style: TextStyle(color: Colors.white)),
              value: isPen,
              onChanged: (v) => ss(() => isPen = v ?? false),
              activeColor: AppColors.primary,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                svc.footballGoal(match.id, team,
                    ctrl.text.trim().isEmpty ? 'Unknown' : ctrl.text.trim(),
                    isOwnGoal: isOg, isPenalty: isPen);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _promptCard(BuildContext context, String team, String cardType) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
            '${cardType == 'yellow' ? '\ud83d\udfe1 Yellow' : '\ud83d\udd34 Red'} Card \u2014 ${team == 'A' ? match.teamA : match.teamB}',
            style: const TextStyle(color: Colors.white)),
        content: _dialogField('Player Name', ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.footballCard(match.id, team,
                  ctrl.text.trim().isEmpty ? 'Unknown' : ctrl.text.trim(),
                  cardType);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BASKETBALL SCOREBOARD
// ════════════════════════════════════════════════════════════════════════════

class _BasketballBoard extends StatelessWidget {
  final LiveMatch match;
  const _BasketballBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final b = match.basketball!;
    return Column(children: [
      _card(child: Column(children: [
        // Quarter + timer
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(b.quarterLabel,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: b.timer.isRunning
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(b.timerStr,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        // Main score
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(
              child: Text(match.teamA,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text('${b.teamATotal}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('\u2013',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 40)),
              ),
              Text('${b.teamBTotal}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
              child: Text(match.teamB,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // Fouls + timeouts
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('Fouls', '${b.teamAFouls}'),
          _stat('Timeouts', '${b.teamATimeouts}'),
          const SizedBox(width: 24),
          _stat('Fouls', '${b.teamBFouls}'),
          _stat('Timeouts', '${b.teamBTimeouts}'),
        ]),
      ])),
      // Quarter-by-quarter breakdown
      if (b.teamAQtr.length > 1)
        _card(
          label: 'QUARTER SCORES',
          child: Table(
            columnWidths: {
              0: const FlexColumnWidth(2),
              for (int i = 0; i < b.teamAQtr.length; i++) i + 1: const FlexColumnWidth(1),
              b.teamAQtr.length + 1: const FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 0.5))),
                children: [
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Team',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11))),
                  ...List.generate(b.teamAQtr.length, (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(i < 4 ? 'Q${i + 1}' : 'OT${i - 3}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      )),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Total',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
                ],
              ),
              TableRow(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(match.teamA,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                ...b.teamAQtr.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('$s',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    )),
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('${b.teamATotal}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold))),
              ]),
              TableRow(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(match.teamB,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                ...b.teamBQtr.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('$s',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    )),
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('${b.teamBTotal}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold))),
              ]),
            ],
          ),
        ),
      if (b.isMatchOver) _infoChip('\u2713 ${b.matchResult}', isResult: true),
    ]);
  }

  Widget _stat(String label, String val) => Column(children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text(val,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// BASKETBALL CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _BasketballControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  const _BasketballControls({required this.match, required this.svc});

  @override
  Widget build(BuildContext context) {
    final b = match.basketball!;
    if (b.isMatchOver) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Timer row
      Row(children: [
        _ctrlBtn(b.timer.isRunning ? '\u23f8 Pause' : '\u25b6 Start',
            color: AppColors.primary,
            onTap: () => svc.basketballToggleTimer(match.id)),
        const SizedBox(width: 8),
        _ctrlBtn('Next ${b.currentQuarter >= 4 ? 'OT' : 'Quarter'}',
            color: Colors.amber,
            onTap: () => svc.basketballNextQuarter(match.id)),
        const SizedBox(width: 8),
        _ctrlBtn('End Match', color: Colors.grey,
            onTap: () => svc.basketballEndMatch(match.id)),
      ]),
      const SizedBox(height: 6),
      // Points — Team A
      Row(children: [
        const SizedBox(width: 4),
        Text('${match.teamA}: ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        _ptBtn('+1 FT', () => svc.basketballPoints(match.id, 'A', 1)),
        const SizedBox(width: 4),
        _ptBtn('+2', () => svc.basketballPoints(match.id, 'A', 2),
            color: Colors.blue),
        const SizedBox(width: 4),
        _ptBtn('+3', () => svc.basketballPoints(match.id, 'A', 3),
            color: Colors.green),
        const SizedBox(width: 4),
        _ptBtn('Foul',
            () => svc.basketballFoul(match.id, 'A'), color: Colors.orange),
        const SizedBox(width: 4),
        _ptBtn('TO', () => svc.basketballTimeout(match.id, 'A'),
            color: Colors.purple),
      ]),
      const SizedBox(height: 4),
      // Points — Team B
      Row(children: [
        const SizedBox(width: 4),
        Text('${match.teamB}: ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        _ptBtn('+1 FT', () => svc.basketballPoints(match.id, 'B', 1)),
        const SizedBox(width: 4),
        _ptBtn('+2', () => svc.basketballPoints(match.id, 'B', 2),
            color: Colors.blue),
        const SizedBox(width: 4),
        _ptBtn('+3', () => svc.basketballPoints(match.id, 'B', 3),
            color: Colors.green),
        const SizedBox(width: 4),
        _ptBtn('Foul',
            () => svc.basketballFoul(match.id, 'B'), color: Colors.orange),
        const SizedBox(width: 4),
        _ptBtn('TO', () => svc.basketballTimeout(match.id, 'B'),
            color: Colors.purple),
      ]),
    ]);
  }

  Widget _ctrlBtn(String label,
      {required VoidCallback onTap, Color? color}) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (color ?? Colors.white).withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      );

  Widget _ptBtn(String label, VoidCallback onTap, {Color? color}) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// RALLY SCOREBOARD (Badminton, Table Tennis, Volleyball, Tennis,
//                   Squash, Padel, Beach Volleyball, Netball)
// ════════════════════════════════════════════════════════════════════════════

class _RallyBoard extends StatelessWidget {
  final LiveMatch match;
  const _RallyBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final r = match.rally!;
    final isTennis = match.sport == MatchSport.tennis;

    return _card(
        child: Column(children: [
      // Sets won
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Expanded(
            child: Text(match.teamA,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('${r.setsWonA}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('\u2013',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 40)),
            ),
            Text('${r.setsWonB}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
            child: Text(match.teamB,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2)),
      ]),
      const SizedBox(height: 4),
      const Text('SETS',
          style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
      const SizedBox(height: AppSpacing.md),
      // Current set score
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isTennis) ...[
            // Tennis: show games + points in current game
            Column(children: [
              Text('${r.currentSet.scoreA}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              Text(r.tennisPtsAStr,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('\u2014',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 24)),
            ),
            Column(children: [
              Text('${r.currentSet.scoreB}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              Text(r.tennisPtsBStr,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
          ] else ...[
            Text('${r.currentSet.scoreA}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('\u2013',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 32)),
            ),
            Text('${r.currentSet.scoreB}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          ],
        ]),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text('Set ${r.currentSetNum} · ${isTennis ? 'Games' : 'Points'}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      // Server indicator
      const SizedBox(height: AppSpacing.sm),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
            r.serverIsA ? '\ud83c\udf3f ${match.teamA} serving' : '\ud83c\udf3f ${match.teamB} serving',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ]),
      // Previous sets
      if (r.sets.length > 1) ...[
        const Divider(color: AppColors.border, height: 20),
        Wrap(
          spacing: 8,
          children: r.sets.where((s) => s.isComplete).map((s) {
            final idx = r.sets.indexOf(s);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Set ${idx + 1}: ${s.scoreA}\u2013${s.scoreB}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            );
          }).toList(),
        ),
      ],
      if (r.isMatchOver)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _infoChip(
            '\u2713 ${r.matchWinner == 'A' ? match.teamA : match.teamB} wins!',
            isResult: true,
          ),
        ),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RALLY CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _RallyControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  const _RallyControls({required this.match, required this.svc});

  @override
  Widget build(BuildContext context) {
    final r = match.rally!;
    if (r.isMatchOver) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _pointBtn(match.teamA, AppColors.primary,
            () => svc.rallyPoint(match.id, 'A')),
        const SizedBox(width: 12),
        _pointBtn(match.teamB, Colors.blue,
            () => svc.rallyPoint(match.id, 'B')),
      ]),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => svc.rallyToggleServer(match.id),
        icon: const Icon(Icons.swap_horiz, color: AppColors.textMuted, size: 16),
        label: const Text('Switch Server',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
    ]);
  }

  Widget _pointBtn(String team, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text('+ Point\n$team',
                  style: TextStyle(
                      color: color, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// HOCKEY SCOREBOARD
// ════════════════════════════════════════════════════════════════════════════

class _HockeyBoard extends StatelessWidget {
  final LiveMatch match;
  const _HockeyBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final h = match.hockey!;
    return Column(children: [
      _card(child: Column(children: [
        // Period + timer — uses periodLabel (Q1/P1 depending on totalPeriods)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(h.periodLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: h.timer.isRunning
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(h.timerStr,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        // Main score
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(
              child: Text(match.teamA,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${h.teamAGoals}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('\u2013',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 40)),
              ),
              Text('${h.teamBGoals}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
              child: Text(match.teamB,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        // PC count
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('Penalty Corners', '${h.teamAPenaltyCorners}'),
          _stat('Penalty Corners', '${h.teamBPenaltyCorners}'),
        ]),
        // Period-by-period breakdown
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(h.totalPeriods, (i) {
            final aG = i < h.teamAQtrGoals.length ? h.teamAQtrGoals[i] : 0;
            final bG = i < h.teamBQtrGoals.length ? h.teamBQtrGoals[i] : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(children: [
                Text(h.totalPeriods == 3 ? 'P${i + 1}' : 'Q${i + 1}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                Text('$aG\u2013$bG',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            );
          }),
        ),
      ])),
      if (h.events.isNotEmpty)
        _card(
          label: 'EVENTS',
          child: Column(
            children: h.events.reversed.take(8).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Text('${e.quarter == 0 ? '' : h.totalPeriods == 3 ? 'P' : 'Q'}${e.quarter} ${e.timeStr}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(width: 8),
                Text(_hockeyEventIcon(e.type),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(e.player,
                        style: const TextStyle(color: Colors.white, fontSize: 13))),
                Text(e.team == 'A' ? match.teamA : match.teamB,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            )).toList(),
          ),
        ),
    ]);
  }

  String _hockeyEventIcon(String type) {
    switch (type) {
      case 'goal': return '\ud83c\udff1';
      case 'penalty_corner': return '\u2690';
      case 'green_card': return '\ud83d\udfe2';
      case 'yellow_card': return '\ud83d\udfe1';
      case 'red_card': return '\ud83d\udd34';
      default: return '\u2022';
    }
  }

  Widget _stat(String label, String val) => Column(children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text(val,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// HOCKEY CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _HockeyControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  final BuildContext ctx;
  const _HockeyControls(
      {required this.match, required this.svc, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final h = match.hockey!;
    if (h.isMatchOver) return const SizedBox.shrink();
    final periodWord = h.totalPeriods == 3 ? 'Period' : 'Quarter';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _btn(h.timer.isRunning ? '\u23f8 Pause' : '\u25b6 Start',
            AppColors.primary, () => svc.hockeyToggleTimer(match.id)),
        const SizedBox(width: 8),
        _btn('Next $periodWord', Colors.amber,
            () => svc.hockeyNextPeriod(match.id)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        _btn('\ud83c\udff1 ${match.teamA}', Colors.white,
            () => _promptGoal(context, 'A')),
        const SizedBox(width: 8),
        _btn('\ud83c\udff1 ${match.teamB}', Colors.white,
            () => _promptGoal(context, 'B')),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        _btn('PC ${match.teamA}', Colors.purple,
            () => svc.hockeyPenaltyCorner(match.id, 'A')),
        const SizedBox(width: 4),
        _btn('PC ${match.teamB}', Colors.purple,
            () => svc.hockeyPenaltyCorner(match.id, 'B')),
        const SizedBox(width: 4),
        _btn('\ud83d\udfe1 A', Colors.amber,
            () => _promptCard(context, 'A', 'yellow')),
        const SizedBox(width: 4),
        _btn('\ud83d\udd34 A', AppColors.primary,
            () => _promptCard(context, 'A', 'red')),
        const SizedBox(width: 4),
        _btn('\ud83d\udfe1 B', Colors.amber,
            () => _promptCard(context, 'B', 'yellow')),
        const SizedBox(width: 4),
        _btn('\ud83d\udd34 B', AppColors.primary,
            () => _promptCard(context, 'B', 'red')),
      ]),
    ]);
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );

  void _promptGoal(BuildContext context, String team) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('\ud83c\udff1 Goal \u2014 ${team == 'A' ? match.teamA : match.teamB}',
            style: const TextStyle(color: Colors.white)),
        content: _dialogField('Scorer Name', ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.hockeyGoal(match.id, team,
                  ctrl.text.trim().isEmpty ? 'Unknown' : ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _promptCard(BuildContext context, String team, String cardType) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Card \u2014 ${team == 'A' ? match.teamA : match.teamB}',
            style: const TextStyle(color: Colors.white)),
        content: _dialogField('Player Name', ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.hockeyCard(match.id, team,
                  ctrl.text.trim().isEmpty ? 'Unknown' : ctrl.text.trim(),
                  cardType);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOXING / COMBAT SCOREBOARD
// ════════════════════════════════════════════════════════════════════════════

class _BoxingBoard extends StatelessWidget {
  final LiveMatch match;
  const _BoxingBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final c = match.combat!;
    return Column(children: [
      _card(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Round ${c.currentRound} of ${c.totalRounds}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: c.timer.isRunning
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(c.timerStr,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _fighter(match.teamA, c.totalKnockdownsA, 'A', c),
          const Text('VS',
              style: TextStyle(color: AppColors.textMuted, fontSize: 20, fontWeight: FontWeight.bold)),
          _fighter(match.teamB, c.totalKnockdownsB, 'B', c),
        ]),
        if (c.isMatchOver) ...[
          const Divider(color: AppColors.border, height: 20),
          Text(
            '${c.winner == 'A' ? match.teamA : match.teamB} wins by ${c.result}',
            style: const TextStyle(
                color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ])),
      // Judge scorecards
      if (c.rounds.any((r) => r.judge1A != null))
        _card(
          label: 'JUDGE SCORECARDS',
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 0.5))),
                children: ['Rnd', 'Judge 1', 'Judge 2', 'Judge 3']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(h,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ))
                    .toList(),
              ),
              ...c.rounds.where((r) => r.judge1A != null).map((r) => TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text('${r.roundNum}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12))),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text('${r.judge1A}\u2013${r.judge1B}',
                              style: const TextStyle(color: Colors.white, fontSize: 12))),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text('${r.judge2A}\u2013${r.judge2B}',
                              style: const TextStyle(color: Colors.white, fontSize: 12))),
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text('${r.judge3A}\u2013${r.judge3B}',
                              style: const TextStyle(color: Colors.white, fontSize: 12))),
                    ],
                  )),
              // Total row
              if (c.rounds.length > 1)
                TableRow(
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.border, width: 0.5))),
                  children: [
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Text('Total',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                            '${c.rounds.fold(0, (s, r) => s + (r.judge1A ?? 0))}\u2013${c.rounds.fold(0, (s, r) => s + (r.judge1B ?? 0))}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                            '${c.rounds.fold(0, (s, r) => s + (r.judge2A ?? 0))}\u2013${c.rounds.fold(0, (s, r) => s + (r.judge2B ?? 0))}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                            '${c.rounds.fold(0, (s, r) => s + (r.judge3A ?? 0))}\u2013${c.rounds.fold(0, (s, r) => s + (r.judge3B ?? 0))}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
            ],
          ),
        ),
    ]);
  }

  Widget _fighter(String name, int kds, String side, CombatScore c) =>
      Column(children: [
        Text(name,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2),
        const SizedBox(height: 4),
        if (kds > 0)
          Text('Knockdowns: $kds',
              style: const TextStyle(color: AppColors.primary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
            'Score: ${side == 'A' ? c.cardTotalA : c.cardTotalB}',
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ]);
}

// ════════════════════════════════════════════════════════════════════════════
// BOXING / COMBAT CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _BoxingControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  final BuildContext ctx;
  const _BoxingControls(
      {required this.match, required this.svc, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final c = match.combat!;
    if (c.isMatchOver) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _btn(c.timer.isRunning ? '\u23f8 Pause' : '\u25b6 Start',
            AppColors.primary, () => svc.boxingToggleTimer(match.id)),
        const SizedBox(width: 8),
        _btn('End Round', Colors.amber, () => _promptEndRound(context)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        _btn('KD ${match.teamA}', Colors.orange,
            () => svc.boxingKnockdown(match.id, 'A')),
        const SizedBox(width: 8),
        _btn('KD ${match.teamB}', Colors.orange,
            () => svc.boxingKnockdown(match.id, 'B')),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        _btn('KO / TKO \u2014 ${match.teamA}', AppColors.primary,
            () => svc.boxingStoppage(match.id, 'A', 'KO/TKO')),
        const SizedBox(width: 8),
        _btn('KO / TKO \u2014 ${match.teamB}', AppColors.primary,
            () => svc.boxingStoppage(match.id, 'B', 'KO/TKO')),
      ]),
    ]);
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      );

  void _promptEndRound(BuildContext context) {
    final j1a = TextEditingController(text: '10');
    final j1b = TextEditingController(text: '9');
    final j2a = TextEditingController(text: '10');
    final j2b = TextEditingController(text: '9');
    final j3a = TextEditingController(text: '10');
    final j3b = TextEditingController(text: '9');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('End Round \u2014 Judge Scores (10-pt must)',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: Center(child: Text(match.teamA,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
            const SizedBox(width: 8),
            Expanded(child: Center(child: Text(match.teamB,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
          ]),
          const SizedBox(height: 8),
          _judgeRow('Judge 1', j1a, j1b),
          const SizedBox(height: 6),
          _judgeRow('Judge 2', j2a, j2b),
          const SizedBox(height: 6),
          _judgeRow('Judge 3', j3a, j3b),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.boxingEndRound(match.id,
                  judgesA: [
                    int.tryParse(j1a.text) ?? 10,
                    int.tryParse(j2a.text) ?? 10,
                    int.tryParse(j3a.text) ?? 10,
                  ],
                  judgesB: [
                    int.tryParse(j1b.text) ?? 9,
                    int.tryParse(j2b.text) ?? 9,
                    int.tryParse(j3b.text) ?? 9,
                  ]);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _judgeRow(String label, TextEditingController a, TextEditingController b) =>
      Row(children: [
        SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
        const SizedBox(width: 8),
        Expanded(child: _scoreField(a)),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('\u2013', style: TextStyle(color: AppColors.textMuted))),
        Expanded(child: _scoreField(b)),
      ]);

  Widget _scoreField(TextEditingController ctrl) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// E-SPORTS SCOREBOARD
// ════════════════════════════════════════════════════════════════════════════

class _EsportsBoard extends StatelessWidget {
  final LiveMatch match;
  const _EsportsBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final e = match.esports!;
    return Column(children: [
      _card(child: Column(children: [
        Text(match.format,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(
              child: Text(match.teamA,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${e.teamARounds}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('\u2013',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 40)),
              ),
              Text('${e.teamBRounds}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
              child: Text(match.teamB,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
        ]),
        const SizedBox(height: 4),
        const Text('ROUNDS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text('First to ${e.roundsToWin} rounds wins \xb7 Round ${e.currentRound}/${e.maxRounds}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        if (e.isHalfTime)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _infoChip('HALF TIME \u2014 Sides switch'),
          ),
        if (e.isMatchOver)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _infoChip(
                '\u2713 ${e.matchWinner == 'A' ? match.teamA : match.teamB} wins!',
                isResult: true),
          ),
      ])),
      // Round history
      if (e.roundHistory.isNotEmpty)
        _card(
          label: 'ROUND HISTORY',
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: e.roundHistory.asMap().entries.map((entry) {
              final isA = entry.value == 'A';
              return Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isA
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${entry.key + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              );
            }).toList(),
          ),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// E-SPORTS CONTROLS
// ════════════════════════════════════════════════════════════════════════════

class _EsportsControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  const _EsportsControls({required this.match, required this.svc});

  @override
  Widget build(BuildContext context) {
    final e = match.esports!;
    if (e.isMatchOver) return const SizedBox.shrink();
    if (e.isHalfTime) {
      return Center(
        child: ElevatedButton(
          onPressed: () => svc.esportsHalfTimeSwitch(match.id),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('\u25b6 Start 2nd Half (Sides Switched)'),
        ),
      );
    }
    return Row(children: [
      _btn('Round Won \u2014 ${match.teamA}', AppColors.primary,
          () => svc.esportsRoundWon(match.id, 'A')),
      const SizedBox(width: 12),
      _btn('Round Won \u2014 ${match.teamB}', Colors.blue,
          () => svc.esportsRoundWon(match.id, 'B')),
    ]);
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// GENERIC SCOREBOARD — all remaining sports
// (golf, snooker, darts, kabaddi, khoKho, athletics, rowing, etc.)
// ════════════════════════════════════════════════════════════════════════════

class _GenericBoard extends StatelessWidget {
  final LiveMatch match;
  const _GenericBoard({required this.match});

  @override
  Widget build(BuildContext context) {
    final g = match.genericScore!;

    // Timer display string
    final elapsed = g.timer.elapsed;
    final timerStr =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    return Column(
      children: [
        // ── Main score card ─────────────────────────────────────────────
        _card(child: Column(children: [
          // Timer pill
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: g.timer.isRunning
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  g.timer.isRunning ? Icons.timer : Icons.timer_off,
                  color: g.timer.isRunning ? AppColors.primary : AppColors.textMuted,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  timerStr,
                  style: TextStyle(
                    color: g.timer.isRunning ? Colors.white : AppColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          // Big score
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Expanded(
              child: Text(match.teamA,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Text('${g.teamAScore}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('\u2013',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 40)),
                ),
                Text('${g.teamBScore}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: Text(match.teamB,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2),
            ),
          ]),
          if (g.currentPeriod.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Period ${g.currentPeriod}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
          // Winner banner
          if (g.isMatchOver) ...[
            const SizedBox(height: 8),
            _infoChip(
              g.winner == 'Draw'
                  ? 'Match Drawn'
                  : '\u2713 ${g.winner == 'A' ? match.teamA : match.teamB} wins!',
              isResult: true,
            ),
          ],
        ])),

        // ── Recent events card ──────────────────────────────────────────
        if (g.events.isNotEmpty)
          _card(
            label: 'RECENT EVENTS',
            child: Column(
              children: g.events.reversed.take(5).map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text(e.timeStr,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.team == 'A'
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.team == 'A' ? match.teamA : match.teamB,
                          style: TextStyle(
                            color: e.team == 'A' ? AppColors.primary : Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.note,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                      Text(
                        '+${e.pts}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ]),
                  )).toList(),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GENERIC CONTROLS
// ════════════════════════════════════════════════════════════════════════════

/// Identifies sports where only +1 / -1 scoring is sensible
/// (golf: stroke count, snooker: frames, darts: legs).
bool _isCountSport(MatchSport sport) {
  switch (sport) {
    case MatchSport.golf:
    case MatchSport.snooker:
    case MatchSport.darts:
    case MatchSport.curling:
      return true;
    default:
      return false;
  }
}

class _GenericControls extends StatelessWidget {
  final LiveMatch match;
  final ScoreboardService svc;
  final BuildContext ctx;
  const _GenericControls(
      {required this.match, required this.svc, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final g = match.genericScore!;
    if (g.isMatchOver) return const SizedBox.shrink();

    final isCount = _isCountSport(match.sport);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Note label
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Tap score to record: ${match.sportDisplayName}',
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),

        if (isCount) ...[
          // Count-based sports: +1 / -1 for each team
          Row(children: [
            _teamLabel(match.teamA),
            _smallBtn('+1', AppColors.primary,
                () => svc.genericAddPoints(match.id, 'A', 1)),
            const SizedBox(width: 4),
            _smallBtn('-1', Colors.grey,
                () => svc.genericAddPoints(match.id, 'A', -1,
                    note: '-1')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _teamLabel(match.teamB),
            _smallBtn('+1', Colors.blue,
                () => svc.genericAddPoints(match.id, 'B', 1)),
            const SizedBox(width: 4),
            _smallBtn('-1', Colors.grey,
                () => svc.genericAddPoints(match.id, 'B', -1,
                    note: '-1')),
          ]),
        ] else ...[
          // General: +1 / +2 / +3 / +5 / +7 for Team A
          Row(children: [
            _teamLabel(match.teamA),
            ...[1, 2, 3, 5, 7].map((pts) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _ptBtn('+$pts', AppColors.primary,
                      () => svc.genericAddPoints(match.id, 'A', pts,
                          note: '+$pts')),
                )),
          ]),
          const SizedBox(height: 4),
          // General: +1 / +2 / +3 / +5 / +7 for Team B
          Row(children: [
            _teamLabel(match.teamB),
            ...[1, 2, 3, 5, 7].map((pts) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _ptBtn('+$pts', Colors.blue,
                      () => svc.genericAddPoints(match.id, 'B', pts,
                          note: '+$pts')),
                )),
          ]),
        ],

        const SizedBox(height: AppSpacing.sm),

        // Timer + end match row
        Row(children: [
          _ctrlBtn(
            g.timer.isRunning ? '\u23f8 Pause Timer' : '\u25b6 Start Timer',
            color: AppColors.primary,
            onTap: () => svc.genericToggleTimer(match.id),
          ),
          const SizedBox(width: 8),
          _ctrlBtn(
            'End Match',
            color: Colors.grey,
            onTap: () => _confirmEnd(context),
          ),
        ]),
      ],
    );
  }

  Widget _teamLabel(String name) => SizedBox(
        width: 60,
        child: Text(
          name,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );

  Widget _ptBtn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );

  Widget _smallBtn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );

  Widget _ctrlBtn(String label,
      {required VoidCallback onTap, Color? color}) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (color ?? Colors.white).withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      );

  void _confirmEnd(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('End Match?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This will finalise the score and mark the match as complete.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.genericEndMatch(match.id);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('End Match'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ════════════════════════════════════════════════════════════════════════════

Widget _card({Widget? child, String? label}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(label,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (child != null) child,
        ],
      ),
    );

Widget _infoChip(String msg, {bool isResult = false}) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isResult
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isResult
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        msg,
        style: TextStyle(
          color: isResult ? AppColors.primary : Colors.amber,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );

Widget _dialogField(String label, TextEditingController ctrl) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12),
          ),
        ),
      ],
    );
