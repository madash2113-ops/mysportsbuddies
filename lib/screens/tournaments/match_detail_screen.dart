import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../scoreboard/match_setup_screen.dart';
// ══════════════════════════════════════════════════════════════════════════════
// MatchDetailScreen — Info | Scorecard | Squads | Watch Live
// ══════════════════════════════════════════════════════════════════════════════

class MatchDetailScreen extends StatefulWidget {
  final String tournamentId;
  final String matchId;
  const MatchDetailScreen({
    super.key,
    required this.tournamentId,
    required this.matchId,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  TournamentMatch? get _match => TournamentService()
      .matchesFor(widget.tournamentId)
      .where((m) => m.id == widget.matchId)
      .firstOrNull;

  Tournament? get _tournament => TournamentService()
      .tournaments
      .where((t) => t.id == widget.tournamentId)
      .firstOrNull;

  bool get _canManage => TournamentService().isHost(widget.tournamentId) ||
      TournamentService().canDo(widget.tournamentId, AdminPermission.updateScores);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final match = _match;
        final tourn = _tournament;
        if (match == null || tourn == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(match.note ?? 'Match',
                style: const TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Info'),
                Tab(text: 'Scorecard'),
                Tab(text: 'Squads'),
                Tab(text: 'Watch Live'),
              ],
            ),
          ),
          body: Column(children: [
            _MatchHeader(match: match),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _InfoTab(match: match, tournament: tourn),
                  _ScorecardTab(match: match, canManage: _canManage,
                      tournamentId: widget.tournamentId),
                  _SquadsTab(match: match, tournamentId: widget.tournamentId),
                  _WatchLiveTab(match: match, canManage: _canManage,
                      tournamentId: widget.tournamentId),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Match Header ─────────────────────────────────────────────────────────────

class _MatchHeader extends StatelessWidget {
  final TournamentMatch match;
  const _MatchHeader({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(children: [
        Expanded(child: _TeamBlock(
            name: match.teamAName ?? 'TBD',
            score: match.scoreA,
            isWinner: match.result == TournamentMatchResult.teamAWin)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (match.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Colors.red, size: 7),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.red,
                      fontSize: 10, fontWeight: FontWeight.w800)),
                ]),
              )
            else
              Text(
                match.isPlayed ? 'FT' : 'VS',
                style: TextStyle(
                  color: match.isPlayed ? Colors.white54 : Colors.white38,
                  fontSize: 14, fontWeight: FontWeight.w700,
                ),
              ),
          ]),
        ),
        Expanded(child: _TeamBlock(
            name: match.teamBName ?? 'TBD',
            score: match.scoreB,
            isWinner: match.result == TournamentMatchResult.teamBWin,
            alignRight: true)),
      ]),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String name;
  final int?   score;
  final bool   isWinner;
  final bool   alignRight;
  const _TeamBlock({
    required this.name,
    required this.score,
    required this.isWinner,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (score != null)
          Text('$score',
              style: TextStyle(
                color: isWinner ? Colors.white : Colors.white54,
                fontSize: 36, fontWeight: FontWeight.w900,
              )),
        Text(name,
            style: const TextStyle(color: Colors.white70,
                fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: alignRight ? TextAlign.end : TextAlign.start,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ── Info Tab ─────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  const _InfoTab({required this.match, required this.tournament});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoRow(Icons.sports_outlined,       'Format',     tournament.format.name),
        _InfoRow(Icons.emoji_events_outlined, 'Tournament', tournament.name),
        _InfoRow(Icons.sports,                'Sport',      tournament.sport),
        if (match.venueName != null)
          _InfoRow(Icons.stadium_outlined,    'Venue',      match.venueName!),
        if (match.scheduledAt != null)
          _InfoRow(Icons.schedule_outlined,   'Scheduled',
              _fmt(match.scheduledAt!)),
        _InfoRow(Icons.person_outline,        'Organizer',  tournament.createdByName),
        if (match.note != null)
          _InfoRow(Icons.label_outline,       'Stage',      match.note!),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: Colors.white38, size: 18),
      const SizedBox(width: 10),
      Text('$label:',
          style: const TextStyle(color: Colors.white38, fontSize: 13)),
      const SizedBox(width: 8),
      Expanded(child: Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ── Scorecard Tab ─────────────────────────────────────────────────────────────

class _ScorecardTab extends StatelessWidget {
  final TournamentMatch match;
  final bool            canManage;
  final String          tournamentId;
  const _ScorecardTab({
    required this.match,
    required this.canManage,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context) {
    final data = match.scorecardData;

    if (data == null || data.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          const Text('No scorecard data yet',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          if (canManage) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => _editScorecard(context),
              icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
              label: const Text('Add Scorecard',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
    }

    return Stack(children: [
      ListView(
        padding: const EdgeInsets.all(16),
        children: data.entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Text('${e.key}:',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(child: Text('${e.value}',
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600))),
          ]),
        )).toList(),
      ),
      if (canManage)
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.small(
            heroTag: 'edit_scorecard',
            backgroundColor: AppColors.primary,
            onPressed: () => _editScorecard(context),
            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
          ),
        ),
    ]);
  }

  void _editScorecard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ScorecardEditorSheet(
          match: match, tournamentId: tournamentId),
    );
  }
}

class _ScorecardEditorSheet extends StatefulWidget {
  final TournamentMatch match;
  final String          tournamentId;
  const _ScorecardEditorSheet({required this.match, required this.tournamentId});

  @override
  State<_ScorecardEditorSheet> createState() => _ScorecardEditorSheetState();
}

class _ScorecardEditorSheetState extends State<_ScorecardEditorSheet> {
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  // Default scorecard keys per sport (we just seed with existing or defaults)
  static const _defaultKeys = ['Score A', 'Score B', 'Notes'];

  @override
  void initState() {
    super.initState();
    final existing = widget.match.scorecardData ?? {};
    final keys = existing.isNotEmpty ? existing.keys.toList() : _defaultKeys;
    _ctrls = {for (final k in keys) k: TextEditingController(text: '${existing[k] ?? ""}')};
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Edit Scorecard', style: TextStyle(color: Colors.white,
            fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ..._ctrls.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: e.value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: e.key,
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true, fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Scorecard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = {for (final e in _ctrls.entries) e.key: e.value.text.trim()};
    try {
      await TournamentService().updateScorecard(widget.tournamentId, widget.match.id, data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }
}

// ── Squads Tab ───────────────────────────────────────────────────────────────

class _SquadsTab extends StatefulWidget {
  final TournamentMatch match;
  final String          tournamentId;
  const _SquadsTab({required this.match, required this.tournamentId});

  @override
  State<_SquadsTab> createState() => _SquadsTabState();
}

class _SquadsTabState extends State<_SquadsTab> {
  @override
  void initState() {
    super.initState();
    final m = widget.match;
    if (m.teamAId != null) {
      TournamentService().loadSquad(widget.tournamentId, m.teamAId!);
    }
    if (m.teamBId != null) {
      TournamentService().loadSquad(widget.tournamentId, m.teamBId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m    = widget.match;
    final svc  = TournamentService();
    final sqA  = m.teamAId != null ? svc.squadFor(widget.tournamentId, m.teamAId!) : <TournamentSquadPlayer>[];
    final sqB  = m.teamBId != null ? svc.squadFor(widget.tournamentId, m.teamBId!) : <TournamentSquadPlayer>[];

    if (sqA.isEmpty && sqB.isEmpty) {
      return const Center(
        child: Text('No squad data available',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (m.teamAName != null) ...[
          _SquadHeader(name: m.teamAName!),
          const SizedBox(height: 8),
          ...sqA.map((p) => _PlayerTile(player: p)),
          const SizedBox(height: 20),
        ],
        if (m.teamBName != null) ...[
          _SquadHeader(name: m.teamBName!),
          const SizedBox(height: 8),
          ...sqB.map((p) => _PlayerTile(player: p)),
        ],
      ],
    );
  }
}

class _SquadHeader extends StatelessWidget {
  final String name;
  const _SquadHeader({required this.name});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 16,
        decoration: BoxDecoration(color: AppColors.primary,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(name, style: const TextStyle(color: Colors.white,
        fontSize: 15, fontWeight: FontWeight.w700)),
  ]);
}

class _PlayerTile extends StatelessWidget {
  final TournamentSquadPlayer player;
  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
        child: Center(child: Text(
          player.jerseyNumber > 0 ? '${player.jerseyNumber}' : player.playerName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
        )),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(player.playerName,
          style: const TextStyle(color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w500))),
      if (player.role.isNotEmpty)
        Text(player.role,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      if (player.isCaptain)
        const Padding(
          padding: EdgeInsets.only(left: 6),
          child: _Badge('C', AppColors.primary),
        ),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

// ── Watch Live Tab ────────────────────────────────────────────────────────────

class _WatchLiveTab extends StatefulWidget {
  final TournamentMatch match;
  final bool            canManage;
  final String          tournamentId;
  const _WatchLiveTab({
    required this.match,
    required this.canManage,
    required this.tournamentId,
  });

  @override
  State<_WatchLiveTab> createState() => _WatchLiveTabState();
}

class _WatchLiveTabState extends State<_WatchLiveTab> {
  final _urlCtrl = TextEditingController();
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = widget.match.liveStreamUrl ?? '';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (m.isLive) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(80)),
            ),
            child: const Row(children: [
              Icon(Icons.circle, color: Colors.red, size: 10),
              SizedBox(width: 8),
              Text('LIVE NOW', style: TextStyle(color: Colors.red,
                  fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (m.liveStreamUrl != null && m.liveStreamUrl!.isNotEmpty) ...[
          const Text('Stream URL',
              style: TextStyle(color: Colors.white54,
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(m.liveStreamUrl!,
                style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
          const SizedBox(height: 24),
        ] else if (!widget.canManage) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 56),
                SizedBox(height: 12),
                Text('No live stream available',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
              ]),
            ),
          ),
        ],
        if (widget.canManage && !widget.match.isPlayed) ...[
          const Text('Live Scoreboard',
              style: TextStyle(color: Colors.white54,
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2A1A),
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final tourn = TournamentService().tournaments
                    .where((t) => t.id == widget.tournamentId)
                    .firstOrNull;
                final sport = tourn?.sport ?? 'Cricket';
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MatchSetupScreen(
                    sportName: sport,
                    isTournamentMatch: true,
                  ),
                ));
              },
              icon: const Icon(Icons.scoreboard_outlined, color: Colors.green, size: 18),
              label: const Text('Start Live Scoreboard',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (widget.canManage) ...[
          const Text('Set Stream URL',
              style: TextStyle(color: Colors.white54,
                  fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : () => _setLive(true),
                icon: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                label: const Text('Go Live',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            if (m.isLive) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _saving ? null : () => _setLive(false),
                  child: const Text('End Live',
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
        ],
      ],
    );
  }

  Future<void> _setLive(bool live) async {
    setState(() => _saving = true);
    try {
      if (live) {
        await TournamentService().setMatchLive(
          widget.tournamentId, widget.match.id,
          streamUrl: _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null,
        );
      } else {
        await TournamentService().endMatchLive(widget.tournamentId, widget.match.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(live ? 'Match is now LIVE!' : 'Live stream ended'),
          backgroundColor: live ? Colors.red : Colors.grey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
