import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../../services/user_service.dart';
import 'live_scoreboard_screen.dart';
import 'match_report_screen.dart';
import 'match_setup_screen.dart';
import 'scoreboard_screen.dart';
import '../../widgets/match_vs_banner.dart';

/// Shows live / completed matches. If [sportName] is null, shows all sports.
/// All viewers subscribe to ScoreboardService so the list stays live.
/// Set [showBackButton] to false when embedding as a bottom-nav tab.
class LiveMatchesScreen extends StatefulWidget {
  final String? sportName;
  final bool showBackButton;

  const LiveMatchesScreen({super.key, this.sportName, this.showBackButton = true});

  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen> {
  String? _selectedSport; // null = "All"

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreboardService>(
      builder: (context, svc, _) {
        final uid = UserService().userId ?? '';

        // Base list: either pre-filtered by sportName or all
        final all = widget.sportName != null
            ? svc.bySport(widget.sportName!)
            : (svc.all.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

        // Show only matches the current user created or was added as a player
        final myMatches = uid.isEmpty
            ? all
            : all.where((m) =>
                m.createdByUserId == uid ||
                m.teamAPlayerUserIds.contains(uid) ||
                m.teamBPlayerUserIds.contains(uid)).toList();

        // Collect distinct sports from user's matches (for filter chips)
        final sportNames = <String>{};
        for (final m in myMatches) {
          final name = m.sportDisplayName;
          if (name.isNotEmpty) sportNames.add(name);
        }
        final sortedSports = sportNames.toList()..sort();

        // Apply sport filter
        final matches = _selectedSport == null
            ? myMatches
            : myMatches.where((m) =>
                m.sportDisplayName == _selectedSport).toList();

        final title = widget.sportName != null
            ? '${widget.sportName} Scoreboards'
            : 'My Scoreboards';

        return Scaffold(
          backgroundColor: AppC.bg(context),
          floatingActionButton: widget.showBackButton
              ? null
              : FloatingActionButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ScoreboardScreen())),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: AppColors.textOnPrimary),
                ),
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: widget.showBackButton,
            leading: widget.showBackButton
                ? BackButton(color: AppC.text(context))
                : null,
            title: Text(
              title,
              style: TextStyle(
                  color: AppC.text(context), fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_chart_outlined, color: AppC.text(context)),
                tooltip: 'Create Scoreboard',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => widget.sportName != null
                        ? MatchSetupScreen(sportName: widget.sportName!)
                        : const ScoreboardScreen(),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Sport filter chips — only show when not pre-filtered and >1 sport
              if (widget.sportName == null && sortedSports.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    children: [
                      _SportChip(
                        label: 'All',
                        selected: _selectedSport == null,
                        onTap: () => setState(() => _selectedSport = null),
                      ),
                      ...sortedSports.map((sport) => _SportChip(
                        label: sport,
                        selected: _selectedSport == sport,
                        onTap: () => setState(() => _selectedSport = sport),
                      )),
                    ],
                  ),
                ),
              // Match list
              Expanded(
                child: matches.isEmpty
                    ? _EmptyState(sportName: _selectedSport ?? widget.sportName)
                    : RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppC.card(context),
                        onRefresh: () => ScoreboardService().loadFromFirestore(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: matches.length,
                          itemBuilder: (context, i) =>
                              _MatchCard(match: matches[i]),
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

class _SportChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SportChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textOnPrimary : AppC.text(context),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
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
                color: AppC.hint(context), size: 64),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No scoreboards yet',
              style: TextStyle(
                  color: AppC.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              sportName != null
                  ? 'Create a scoreboard to start tracking\nyour $sportName match live.'
                  : 'Create a scoreboard to start tracking\nyour next match live.',
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
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
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
                : AppColors.border,
            width: isLive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── VS Banner ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: MatchVsBanner(
                teamA:     match.teamA,
                teamB:     match.teamB,
                label:     match.format.isNotEmpty ? match.format : match.sportDisplayName,
                sport:     match.sportDisplayName,
                isLive:    isLive,
                isPlayed:  isDone,
                isMyMatch: false,
              ),
            ),

            // ── Score ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score display + time
                  Row(children: [
                    Expanded(child: _sportScore(match)),
                    Text(_timeAgo(match.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ]),

                  // ── Cricket extra info ─────────────────────────────
                  if (match.sport == MatchSport.cricket &&
                      match.cricket != null) ...[
                    const SizedBox(height: 6),
                    _cricketExtra(match),
                  ],

                  // ── Players ────────────────────────────────────────
                  if (match.teamAPlayers.isNotEmpty ||
                      match.teamBPlayers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PlayersRow(match: match),
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

            // ── Footer buttons ─────────────────────────────────────────
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
                  Row(
                    children: [
                      // Scorecard button (always visible)
                      GestureDetector(
                        onTap: () => _showScorecardSheet(context, match),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_chart_outlined,
                                  color: AppColors.textMuted, size: 13),
                              SizedBox(width: 4),
                              Text('Scorecard',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 6),
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
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4)),
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
                    ],
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
                    color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
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
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('–',
              style: TextStyle(color: AppColors.textMuted, fontSize: 20)),
        ),
        Text(b,
            style: const TextStyle(
                color: AppColors.textPrimary,
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
          color: AppColors.textPrimary.withValues(alpha: 0.06),
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

  void _showScorecardSheet(BuildContext context, LiveMatch match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScorecardSheet(match: match),
    );
  }
}

// ── Players row ────────────────────────────────────────────────────────────

class _PlayersRow extends StatelessWidget {
  final LiveMatch match;
  const _PlayersRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final aPlayers = match.teamAPlayers.where((p) => p.isNotEmpty).toList();
    final bPlayers = match.teamBPlayers.where((p) => p.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team A players
          Expanded(child: _teamColumn(match.teamA, aPlayers)),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.border,
          ),
          // Team B players
          Expanded(child: _teamColumn(match.teamB, bPlayers)),
        ],
      ),
    );
  }

  Widget _teamColumn(String teamName, List<String> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teamName,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (players.isEmpty)
          const Text('—',
              style: TextStyle(color: AppColors.textHint, fontSize: 11))
        else
          ...players.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  p,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
      ],
    );
  }
}

// ── Scorecard bottom sheet ──────────────────────────────────────────────────

class _ScorecardSheet extends StatefulWidget {
  final LiveMatch match;
  const _ScorecardSheet({required this.match});

  @override
  State<_ScorecardSheet> createState() => _ScorecardSheetState();
}

class _ScorecardSheetState extends State<_ScorecardSheet> {
  // 0 = Team A, 1 = Team B
  int _selectedTeam = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final teamAName = m.teamA;
    final teamBName = m.teamB;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined,
                      color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  const Text('Scorecard',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Team toggle
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _teamToggle(0, teamAName),
                  const SizedBox(width: 8),
                  _teamToggle(1, teamBName),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: _buildContent(m),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamToggle(int index, String label) {
    final selected = _selectedTeam == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTeam = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.textPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textMuted,
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(LiveMatch m) {
    if (m.sport == MatchSport.cricket && m.cricket != null) {
      return _cricketContent(m);
    }
    // Generic: show player list with available scores
    return _genericContent(m);
  }

  // ── Cricket ────────────────────────────────────────────────────────────────

  List<Widget> _cricketContent(LiveMatch m) {
    final cr = m.cricket!;
    final isTeamA = _selectedTeam == 0;
    final teamName = isTeamA ? m.teamA : m.teamB;

    // Find innings for this team
    final innings = cr.innings
        .where((inn) => inn.battingTeam == teamName)
        .toList();

    if (innings.isEmpty) {
      return [_noDataTile('No innings data for $teamName yet')];
    }

    final widgets = <Widget>[];
    for (final inn in innings) {
      // Innings header
      widgets.add(_sectionHeader(
          'Innings ${inn.inningsNum} — Batting (${inn.scoreStr})'));
      // Batting table
      widgets.add(_battingTable(inn));
      widgets.add(const SizedBox(height: 16));

      // Bowling for this innings = opponents bowled
      widgets.add(_sectionHeader('Bowling (by ${inn.bowlingTeam})'));
      widgets.add(_bowlingTable(inn));
      widgets.add(const SizedBox(height: 20));
    }
    return widgets;
  }

  Widget _battingTable(CricketInnings inn) {
    final batsmen = inn.batsmen;
    if (batsmen.isEmpty) {
      return _noDataTile('No batting data recorded');
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          _tableRow(
            cells: const ['Batsman', 'R', 'B', '4s', '6s', 'SR'],
            isHeader: true,
          ),
          const Divider(color: AppColors.border, height: 1),
          ...batsmen.map<Widget>((b) {
            final dismissal = (b.dismissal as String?) ?? '';
            final sr = b.balls == 0
                ? '-'
                : (b.runs / b.balls * 100).toStringAsFixed(1);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tableRow(cells: [
                  b.name,
                  '${b.runs}',
                  '${b.balls}',
                  '${b.fours}',
                  '${b.sixes}',
                  sr,
                ], highlight: b.isStriker == true),
                if (dismissal.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 12, bottom: 4, right: 12),
                    child: Text(
                      dismissal,
                      style: TextStyle(
                        color: (b.isOut == true)
                            ? Colors.red.shade300
                            : Colors.green.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const Divider(color: AppColors.border, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _bowlingTable(CricketInnings inn) {
    final bowlers = inn.bowlers;
    if (bowlers.isEmpty) {
      return _noDataTile('No bowling data recorded');
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _tableRow(
            cells: const ['Bowler', 'O', 'M', 'R', 'W', 'Eco'],
            isHeader: true,
          ),
          const Divider(color: AppColors.border, height: 1),
          ...bowlers.map<Widget>((b) => Column(
                children: [
                  _tableRow(cells: [
                    b.name,
                    '${b.completedOvers}.${b.balls}',
                    '${b.maidens}',
                    '${b.runs}',
                    '${b.wickets}',
                    b.ecoStr,
                  ], highlight: b.isCurrent == true),
                  const Divider(color: AppColors.border, height: 1),
                ],
              )),
        ],
      ),
    );
  }

  // ── Generic (non-cricket) ───────────────────────────────────────────────────

  List<Widget> _genericContent(LiveMatch m) {
    final players = _selectedTeam == 0 ? m.teamAPlayers : m.teamBPlayers;
    final teamName = _selectedTeam == 0 ? m.teamA : m.teamB;

    if (players.isEmpty) {
      return [_noDataTile('No players registered for $teamName')];
    }

    final score = _selectedTeam == 0
        ? _teamScoreLabel(m, isTeamA: true)
        : _teamScoreLabel(m, isTeamA: false);

    return [
      _sectionHeader('$teamName  ·  $score'),
      Container(
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: players
              .where((p) => p.isNotEmpty)
              .map((p) => Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            p.isNotEmpty ? p[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13)),
                      ),
                      const Divider(
                          color: AppColors.border, height: 1, indent: 48),
                    ],
                  ))
              .toList(),
        ),
      ),
    ];
  }

  String _teamScoreLabel(LiveMatch m, {required bool isTeamA}) {
    switch (m.sport) {
      case MatchSport.football:
        return isTeamA
            ? '${m.football?.teamAGoals ?? 0} goals'
            : '${m.football?.teamBGoals ?? 0} goals';
      case MatchSport.basketball:
        return isTeamA
            ? '${m.basketball?.teamATotal ?? 0} pts'
            : '${m.basketball?.teamBTotal ?? 0} pts';
      case MatchSport.hockey:
        return isTeamA
            ? '${m.hockey?.teamAGoals ?? 0} goals'
            : '${m.hockey?.teamBGoals ?? 0} goals';
      default:
        return '';
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4),
        ),
      );

  Widget _tableRow({
    required List<String> cells,
    bool isHeader = false,
    bool highlight = false,
  }) {
    // First cell (name) is wider
    return Container(
      color: highlight
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              cells[0],
              style: TextStyle(
                color: isHeader ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: isHeader ? 10 : 12,
                fontWeight:
                    isHeader ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...cells.skip(1).map(
                (c) => SizedBox(
                  width: 36,
                  child: Text(
                    c,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isHeader ? AppColors.textMuted : AppColors.textPrimary,
                      fontSize: isHeader ? 10 : 12,
                      fontWeight: isHeader
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _noDataTile(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(msg,
              style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
        ),
      );
}
