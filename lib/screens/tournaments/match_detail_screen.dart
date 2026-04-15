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
                  _ScorecardTab(match: match, tournament: tourn,
                      canManage: _canManage, tournamentId: widget.tournamentId),
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

class _ScorecardTab extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final String          tournamentId;
  const _ScorecardTab({
    required this.match,
    required this.tournament,
    required this.canManage,
    required this.tournamentId,
  });

  @override
  State<_ScorecardTab> createState() => _ScorecardTabState();
}

class _ScorecardTabState extends State<_ScorecardTab> {
  bool _saving = false;

  // ── Sport family detection ────────────────────────────────────────────────
  static const _rallySports = {
    'Table Tennis', 'Badminton', 'Volleyball', 'Squash',
    'Racquetball', 'Pickleball', 'Beach Volleyball',
  };
  static const _tennisSports = {'Tennis', 'Padel'};
  static const _goalSports = {
    'Football', 'Soccer', 'Futsal', 'Hockey', 'Field Hockey',
    'Ice Hockey', 'Handball', 'Water Polo', 'Lacrosse',
  };
  static const _basketballSports = {
    'Basketball', 'Netball', 'Rugby', 'American Football',
  };
  static const _cricketSports = {'Cricket'};

  String get _sport => widget.tournament.sport;

  bool get _isRally      => _rallySports.contains(_sport);
  bool get _isTennis     => _tennisSports.contains(_sport);
  bool get _isGoal       => _goalSports.contains(_sport);
  bool get _isBasketball => _basketballSports.contains(_sport);
  bool get _isCricket    => _cricketSports.contains(_sport);


  Future<void> _save(Map<String, dynamic> newData, int sA, int sB) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await TournamentService().updateLiveScore(
          widget.tournamentId, widget.match.id, sA, sB, newData);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRally)      return _RallyBoard(match: widget.match, tournament: widget.tournament, canManage: widget.canManage, onSave: _save, saving: _saving);
    if (_isTennis)     return _TennisBoard(match: widget.match, tournament: widget.tournament, canManage: widget.canManage, onSave: _save, saving: _saving);
    if (_isGoal)       return _GoalBoard(match: widget.match, tournament: widget.tournament, canManage: widget.canManage, onSave: _save, saving: _saving);
    if (_isBasketball) return _BasketballBoard(match: widget.match, tournament: widget.tournament, canManage: widget.canManage, onSave: _save, saving: _saving);
    if (_isCricket)    return _CricketBoard(match: widget.match, tournament: widget.tournament, canManage: widget.canManage, onSave: _save, saving: _saving);
    return _SimpleBoard(match: widget.match, tournament: widget.tournament, canManage: widget.canManage, onSave: _save, saving: _saving);
  }
}

// ── Shared types ─────────────────────────────────────────────────────────────

typedef _SaveFn = Future<void> Function(Map<String, dynamic> data, int sA, int sB);

// ── Rally Board (Table Tennis / Badminton / Volleyball etc.) ──────────────────

class _RallyBoard extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final _SaveFn         onSave;
  final bool            saving;
  const _RallyBoard({required this.match, required this.tournament, required this.canManage, required this.onSave, required this.saving});

  @override
  State<_RallyBoard> createState() => _RallyBoardState();
}

class _RallyBoardState extends State<_RallyBoard> {
  late int _ptA;
  late int _ptB;
  late int _setA;
  late int _setB;
  late List<String> _setsLog;

  int get _ptWin => widget.tournament.pointsToWin;
  int get _bestOf => widget.tournament.bestOf > 0 ? widget.tournament.bestOf : 3;
  int get _setsToWin => (_bestOf / 2).ceil();

  bool get _inDeuceZone => _ptA >= _ptWin - 1 && _ptB >= _ptWin - 1;
  bool get _isDeuce     => _inDeuceZone && _ptA == _ptB;
  bool get _gameOver {
    if (_inDeuceZone) return (_ptA - _ptB).abs() >= 2;
    return _ptA >= _ptWin || _ptB >= _ptWin;
  }
  bool get _matchOver => _setA >= _setsToWin || _setB >= _setsToWin;

  @override
  void initState() {
    super.initState();
    _load(widget.match.scorecardData ?? {});
  }

  @override
  void didUpdateWidget(_RallyBoard old) {
    super.didUpdateWidget(old);
    if (old.match.scorecardData != widget.match.scorecardData) {
      _load(widget.match.scorecardData ?? {});
    }
  }

  void _load(Map<String, dynamic> d) {
    _ptA     = (d['ptA'] as num?)?.toInt()  ?? 0;
    _ptB     = (d['ptB'] as num?)?.toInt()  ?? 0;
    _setA    = (d['setA'] as num?)?.toInt() ?? 0;
    _setB    = (d['setB'] as num?)?.toInt() ?? 0;
    _setsLog = List<String>.from(d['setsLog'] as List? ?? []);
  }

  void _addPoint(bool isA) {
    if (!widget.canManage || _matchOver) return;
    setState(() {
      if (isA) _ptA++; else _ptB++;
      if (_gameOver) _nextSet();
    });
    _persist();
  }

  void _nextSet() {
    final winner = _ptA > _ptB ? 'A' : 'B';
    _setsLog.add('$_ptA-$_ptB');
    if (winner == 'A') _setA++; else _setB++;
    _ptA = 0; _ptB = 0;
  }

  Future<void> _persist() => widget.onSave({
    'type': 'rally',
    'ptA': _ptA, 'ptB': _ptB,
    'setA': _setA, 'setB': _setB,
    'setsLog': _setsLog,
  }, _setA, _setB);

  String get _status {
    if (_matchOver) {
      return _setA >= _setsToWin
          ? '${widget.match.teamAName ?? "Team A"} Wins!'
          : '${widget.match.teamBName ?? "Team B"} Wins!';
    }
    if (_isDeuce)  return 'DEUCE';
    if (_inDeuceZone) {
      return _ptA > _ptB ? 'Advantage ${widget.match.teamAName ?? "A"}' : 'Advantage ${widget.match.teamBName ?? "B"}';
    }
    return 'Set ${_setA + _setB + 1}  •  Best of $_bestOf';
  }

  @override
  Widget build(BuildContext context) {
    final teamA = widget.match.teamAName ?? 'Team A';
    final teamB = widget.match.teamBName ?? 'Team B';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sport badge
        Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Text(widget.tournament.sport,
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        )),
        const SizedBox(height: 16),

        // Sets scoreboard
        if (_setsLog.isNotEmpty) ...[
          _SetsLog(setsLog: _setsLog, setA: _setA, setB: _setB, teamA: teamA, teamB: teamB),
          const SizedBox(height: 16),
        ],

        // Current game score
        _ScoreCard(
          teamA: teamA, teamB: teamB,
          scoreA: _ptA, scoreB: _ptB,
          labelA: 'Sets: $_setA', labelB: 'Sets: $_setB',
          status: _status,
          matchOver: _matchOver,
          canManage: widget.canManage && !_matchOver,
          onPlusA: () => _addPoint(true),
          onPlusB: () => _addPoint(false),
          saving: widget.saving,
        ),

        // Reset set button if match not over
        if (widget.canManage && !_matchOver && (_ptA > 0 || _ptB > 0)) ...[
          const SizedBox(height: 12),
          Center(child: TextButton.icon(
            onPressed: () {
              setState(() { _ptA = 0; _ptB = 0; });
              _persist();
            },
            icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.white38),
            label: const Text('Reset current game', style: TextStyle(color: Colors.white38, fontSize: 12)),
          )),
        ],
      ],
    );
  }
}

// ── Tennis Board ─────────────────────────────────────────────────────────────

class _TennisBoard extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final _SaveFn         onSave;
  final bool            saving;
  const _TennisBoard({required this.match, required this.tournament, required this.canManage, required this.onSave, required this.saving});

  @override
  State<_TennisBoard> createState() => _TennisBoardState();
}

class _TennisBoardState extends State<_TennisBoard> {
  // Tennis points: 0,1,2,3 = 0,15,30,40; 4=Adv
  static const _ptLabels = ['0', '15', '30', '40', 'Adv'];
  late int _ptA, _ptB, _gamesA, _gamesB, _setA, _setB;
  late List<String> _setsLog;

  int get _bestOf => widget.tournament.bestOf > 0 ? widget.tournament.bestOf : 3;
  int get _setsToWin => (_bestOf / 2).ceil();

  @override
  void initState() { super.initState(); _load(widget.match.scorecardData ?? {}); }

  void _load(Map<String, dynamic> d) {
    _ptA    = (d['ptA'] as num?)?.toInt()    ?? 0;
    _ptB    = (d['ptB'] as num?)?.toInt()    ?? 0;
    _gamesA = (d['gamesA'] as num?)?.toInt() ?? 0;
    _gamesB = (d['gamesB'] as num?)?.toInt() ?? 0;
    _setA   = (d['setA'] as num?)?.toInt()   ?? 0;
    _setB   = (d['setB'] as num?)?.toInt()   ?? 0;
    _setsLog = List<String>.from(d['setsLog'] as List? ?? []);
  }

  bool get _inDeuce => _ptA >= 3 && _ptB >= 3 && _ptA == _ptB;
  bool get _matchOver => _setA >= _setsToWin || _setB >= _setsToWin;

  void _addPoint(bool isA) {
    if (!widget.canManage || _matchOver) return;
    setState(() {
      if (isA) _ptA++; else _ptB++;
      // Deuce: reset to 3-3 if both at 4
      if (_ptA >= 3 && _ptB >= 3) {
        if (_ptA == _ptB && _ptA > 3) { _ptA = 3; _ptB = 3; }
      }
      // Game won
      final aWins = (_ptA >= 4 && _ptA - _ptB >= 2) || (_ptA == 4 && _ptB <= 2);
      final bWins = (_ptB >= 4 && _ptB - _ptA >= 2) || (_ptB == 4 && _ptA <= 2);
      if (aWins || bWins) {
        if (aWins) _gamesA++; else _gamesB++;
        _ptA = 0; _ptB = 0;
        // Set won (first to 6, lead by 2 or tiebreak at 7-6)
        if (_gamesA >= 6 || _gamesB >= 6) {
          final aSetWin = _gamesA >= 6 && (_gamesA - _gamesB >= 2 || _gamesA == 7);
          final bSetWin = _gamesB >= 6 && (_gamesB - _gamesA >= 2 || _gamesB == 7);
          if (aSetWin || bSetWin) {
            _setsLog.add('$_gamesA-$_gamesB');
            if (aSetWin) _setA++; else _setB++;
            _gamesA = 0; _gamesB = 0;
          }
        }
      }
    });
    widget.onSave({'type': 'tennis', 'ptA': _ptA, 'ptB': _ptB, 'gamesA': _gamesA, 'gamesB': _gamesB, 'setA': _setA, 'setB': _setB, 'setsLog': _setsLog}, _setA, _setB);
  }

  @override
  Widget build(BuildContext context) {
    final teamA = widget.match.teamAName ?? 'Team A';
    final teamB = widget.match.teamBName ?? 'Team B';
    final ptLabelA = _ptA < _ptLabels.length ? _ptLabels[_ptA] : 'Adv';
    final ptLabelB = _ptB < _ptLabels.length ? _ptLabels[_ptB] : 'Adv';

    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(80))),
        child: Text(widget.tournament.sport, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 16),
      if (_setsLog.isNotEmpty) ...[
        _SetsLog(setsLog: _setsLog, setA: _setA, setB: _setB, teamA: teamA, teamB: teamB),
        const SizedBox(height: 16),
      ],
      _ScoreCard(
        teamA: teamA, teamB: teamB,
        scoreA: _gamesA, scoreB: _gamesB,
        labelA: 'Sets: $_setA', labelB: 'Sets: $_setB',
        customA: ptLabelA, customB: ptLabelB,
        status: _matchOver
            ? (_setA >= _setsToWin ? '$teamA Wins!' : '$teamB Wins!')
            : _inDeuce ? 'DEUCE' : 'Set ${_setA + _setB + 1}  •  Best of $_bestOf',
        matchOver: _matchOver,
        canManage: widget.canManage && !_matchOver,
        onPlusA: () => _addPoint(true),
        onPlusB: () => _addPoint(false),
        saving: widget.saving,
      ),
    ]);
  }
}

// ── Goal Board (Football / Hockey / Handball etc.) ────────────────────────────

class _GoalBoard extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final _SaveFn         onSave;
  final bool            saving;
  const _GoalBoard({required this.match, required this.tournament, required this.canManage, required this.onSave, required this.saving});

  @override
  State<_GoalBoard> createState() => _GoalBoardState();
}

class _GoalBoardState extends State<_GoalBoard> {
  late int _sA, _sB;
  late List<String> _events;

  @override
  void initState() { super.initState(); _load(widget.match.scorecardData ?? {}); }

  void _load(Map<String, dynamic> d) {
    _sA = (d['sA'] as num?)?.toInt() ?? widget.match.scoreA ?? 0;
    _sB = (d['sB'] as num?)?.toInt() ?? widget.match.scoreB ?? 0;
    _events = List<String>.from(d['events'] as List? ?? []);
  }

  void _add(bool isA, [int delta = 1]) {
    if (!widget.canManage) return;
    setState(() {
      if (isA) _sA = (_sA + delta).clamp(0, 99);
      else     _sB = (_sB + delta).clamp(0, 99);
    });
    _persist();
  }

  Future<void> _persist() => widget.onSave({'type': 'goal', 'sA': _sA, 'sB': _sB, 'events': _events}, _sA, _sB);

  @override
  Widget build(BuildContext context) {
    final teamA = widget.match.teamAName ?? 'Team A';
    final teamB = widget.match.teamBName ?? 'Team B';

    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(80))),
        child: Text(widget.tournament.sport, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 16),
      _ScoreCard(
        teamA: teamA, teamB: teamB,
        scoreA: _sA, scoreB: _sB,
        status: widget.match.isPlayed ? 'Full Time' : 'In Progress',
        matchOver: widget.match.isPlayed,
        canManage: widget.canManage,
        onPlusA: () => _add(true),
        onPlusB: () => _add(false),
        onMinusA: _sA > 0 ? () => _add(true, -1) : null,
        onMinusB: _sB > 0 ? () => _add(false, -1) : null,
        saving: widget.saving,
      ),
    ]);
  }
}

// ── Basketball Board ──────────────────────────────────────────────────────────

class _BasketballBoard extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final _SaveFn         onSave;
  final bool            saving;
  const _BasketballBoard({required this.match, required this.tournament, required this.canManage, required this.onSave, required this.saving});

  @override
  State<_BasketballBoard> createState() => _BasketballBoardState();
}

class _BasketballBoardState extends State<_BasketballBoard> {
  late int _sA, _sB;

  @override
  void initState() { super.initState(); _load(widget.match.scorecardData ?? {}); }

  void _load(Map<String, dynamic> d) {
    _sA = (d['sA'] as num?)?.toInt() ?? widget.match.scoreA ?? 0;
    _sB = (d['sB'] as num?)?.toInt() ?? widget.match.scoreB ?? 0;
  }

  void _add(bool isA, int pts) {
    if (!widget.canManage) return;
    setState(() { if (isA) _sA += pts; else _sB += pts; });
    widget.onSave({'type': 'basketball', 'sA': _sA, 'sB': _sB}, _sA, _sB);
  }

  @override
  Widget build(BuildContext context) {
    final teamA = widget.match.teamAName ?? 'Team A';
    final teamB = widget.match.teamBName ?? 'Team B';

    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(80))),
        child: Text(widget.tournament.sport, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 16),
      _ScoreCard(
        teamA: teamA, teamB: teamB,
        scoreA: _sA, scoreB: _sB,
        status: widget.match.isPlayed ? 'Final' : 'Live',
        matchOver: widget.match.isPlayed,
        canManage: widget.canManage,
        onPlusA: () => _add(true, 1),
        onPlusB: () => _add(false, 1),
        saving: widget.saving,
      ),
      if (widget.canManage && !widget.match.isPlayed) ...[
        const SizedBox(height: 16),
        const Text('Quick add', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _QuickRow(teamName: teamA, onAdd: (p) => _add(true, p))),
          const SizedBox(width: 12),
          Expanded(child: _QuickRow(teamName: teamB, onAdd: (p) => _add(false, p))),
        ]),
      ],
    ]);
  }
}

class _QuickRow extends StatelessWidget {
  final String         teamName;
  final void Function(int) onAdd;
  const _QuickRow({required this.teamName, required this.onAdd});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(teamName, style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
    const SizedBox(height: 6),
    Row(children: [1, 2, 3].map((p) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => onAdd(p),
        child: Container(
          width: 36, height: 32,
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withAlpha(80))),
          child: Center(child: Text('+$p', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
        ),
      ),
    )).toList()),
  ]);
}

// ── Cricket Board ─────────────────────────────────────────────────────────────

class _CricketBoard extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final _SaveFn         onSave;
  final bool            saving;
  const _CricketBoard({required this.match, required this.tournament, required this.canManage, required this.onSave, required this.saving});

  @override
  State<_CricketBoard> createState() => _CricketBoardState();
}

class _CricketBoardState extends State<_CricketBoard> {
  late int _runsA, _wicketsA, _ballsA;
  late int _runsB, _wicketsB, _ballsB;
  late int _innings; // 1 or 2

  @override
  void initState() { super.initState(); _load(widget.match.scorecardData ?? {}); }

  void _load(Map<String, dynamic> d) {
    _runsA    = (d['runsA']    as num?)?.toInt() ?? 0;
    _wicketsA = (d['wicketsA'] as num?)?.toInt() ?? 0;
    _ballsA   = (d['ballsA']   as num?)?.toInt() ?? 0;
    _runsB    = (d['runsB']    as num?)?.toInt() ?? 0;
    _wicketsB = (d['wicketsB'] as num?)?.toInt() ?? 0;
    _ballsB   = (d['ballsB']   as num?)?.toInt() ?? 0;
    _innings  = (d['innings']  as num?)?.toInt() ?? 1;
  }

  String _overs(int balls) => '${balls ~/ 6}.${balls % 6}';

  Future<void> _persist() => widget.onSave({
    'type': 'cricket',
    'runsA': _runsA, 'wicketsA': _wicketsA, 'ballsA': _ballsA,
    'runsB': _runsB, 'wicketsB': _wicketsB, 'ballsB': _ballsB,
    'innings': _innings,
  }, _runsA, _runsB);

  void _addRuns(bool isA, int runs) {
    setState(() { if (isA) _runsA += runs; else _runsB += runs; if (isA) _ballsA++; else _ballsB++; });
    _persist();
  }
  void _addWicket(bool isA) {
    setState(() { if (isA) { if (_wicketsA < 10) { _wicketsA++; _ballsA++; } } else { if (_wicketsB < 10) { _wicketsB++; _ballsB++; } } });
    _persist();
  }
  void _addWide(bool isA) {
    setState(() { if (isA) _runsA++; else _runsB++; });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final teamA = widget.match.teamAName ?? 'Team A';
    final teamB = widget.match.teamBName ?? 'Team B';
    final batting = _innings == 1 ? teamA : teamB;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(80))),
        child: Text('Cricket', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 16),

      // Innings scorecards
      _CricketInningsCard(team: teamA, runs: _runsA, wickets: _wicketsA, overs: _overs(_ballsA), isLive: _innings == 1 && !widget.match.isPlayed),
      const SizedBox(height: 10),
      _CricketInningsCard(team: teamB, runs: _runsB, wickets: _wicketsB, overs: _overs(_ballsB), isLive: _innings == 2 && !widget.match.isPlayed),

      if (widget.canManage && !widget.match.isPlayed) ...[
        const SizedBox(height: 20),
        Text('Batting: $batting', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        // Run buttons
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in [0, 1, 2, 3, 4, 6])
            GestureDetector(
              onTap: () => _addRuns(_innings == 1, r),
              child: Container(
                width: 44, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: r == 4 || r == 6 ? Colors.orange.withAlpha(120) : Colors.white12)),
                child: Center(child: Text(r == 0 ? 'Dot' : '+$r', style: TextStyle(color: r == 4 || r == 6 ? Colors.orange : Colors.white70, fontSize: 12, fontWeight: FontWeight.w700))),
              ),
            ),
          GestureDetector(
            onTap: () => _addWicket(_innings == 1),
            child: Container(
              width: 48, height: 40,
              decoration: BoxDecoration(color: Colors.red.withAlpha(30), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withAlpha(120))),
              child: const Center(child: Text('OUT', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w800))),
            ),
          ),
          GestureDetector(
            onTap: () => _addWide(_innings == 1),
            child: Container(
              width: 48, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
              child: const Center(child: Text('Wide', style: TextStyle(color: Colors.white54, fontSize: 11))),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_innings == 1)
          TextButton(
            onPressed: () { setState(() => _innings = 2); _persist(); },
            child: const Text('End Innings → Start 2nd Innings', style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
      ],
    ]);
  }
}

class _CricketInningsCard extends StatelessWidget {
  final String team;
  final int    runs, wickets;
  final String overs;
  final bool   isLive;
  const _CricketInningsCard({required this.team, required this.runs, required this.wickets, required this.overs, required this.isLive});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isLive ? AppColors.primary.withAlpha(80) : Colors.white12),
    ),
    child: Row(children: [
      if (isLive) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
      if (isLive) const SizedBox(width: 8),
      Expanded(child: Text(team, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
      Text('$runs/$wickets', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(width: 12),
      Text('($overs ov)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]),
  );
}

// ── Simple Board (default for all other sports) ───────────────────────────────

class _SimpleBoard extends StatefulWidget {
  final TournamentMatch match;
  final Tournament      tournament;
  final bool            canManage;
  final _SaveFn         onSave;
  final bool            saving;
  const _SimpleBoard({required this.match, required this.tournament, required this.canManage, required this.onSave, required this.saving});

  @override
  State<_SimpleBoard> createState() => _SimpleBoardState();
}

class _SimpleBoardState extends State<_SimpleBoard> {
  late int _sA, _sB;

  @override
  void initState() { super.initState(); _load(widget.match.scorecardData ?? {}); }

  void _load(Map<String, dynamic> d) {
    _sA = (d['sA'] as num?)?.toInt() ?? widget.match.scoreA ?? 0;
    _sB = (d['sB'] as num?)?.toInt() ?? widget.match.scoreB ?? 0;
  }

  void _add(bool isA) {
    if (!widget.canManage) return;
    setState(() { if (isA) _sA++; else _sB++; });
    widget.onSave({'type': 'simple', 'sA': _sA, 'sB': _sB}, _sA, _sB);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(80))),
        child: Text(widget.tournament.sport, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 16),
      _ScoreCard(
        teamA: widget.match.teamAName ?? 'Team A',
        teamB: widget.match.teamBName ?? 'Team B',
        scoreA: _sA, scoreB: _sB,
        status: widget.match.isPlayed ? 'Final' : 'In Progress',
        matchOver: widget.match.isPlayed,
        canManage: widget.canManage,
        onPlusA: () => _add(true),
        onPlusB: () => _add(false),
        saving: widget.saving,
      ),
    ]);
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String  teamA, teamB;
  final int     scoreA, scoreB;
  final String? labelA, labelB, customA, customB;
  final String  status;
  final bool    matchOver, canManage, saving;
  final VoidCallback  onPlusA, onPlusB;
  final VoidCallback? onMinusA, onMinusB;

  const _ScoreCard({
    required this.teamA, required this.teamB,
    required this.scoreA, required this.scoreB,
    this.labelA, this.labelB, this.customA, this.customB,
    required this.status,
    required this.matchOver, required this.canManage, required this.saving,
    required this.onPlusA, required this.onPlusB,
    this.onMinusA, this.onMinusB,
  });

  @override
  Widget build(BuildContext context) {
    final aWinning = scoreA > scoreB;
    final bWinning = scoreB > scoreA;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: matchOver ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: matchOver ? Colors.green.withAlpha(80) : Colors.orange.withAlpha(80)),
          ),
          child: Text(status, style: TextStyle(
            color: matchOver ? Colors.green : Colors.orange,
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          )),
        ),
        const SizedBox(height: 20),

        // Main score row
        Row(children: [
          // Team A
          Expanded(child: Column(children: [
            if (labelA != null)
              Text(labelA!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Text('$scoreA', style: TextStyle(
              color: aWinning ? AppColors.primary : Colors.white,
              fontSize: 56, fontWeight: FontWeight.w900, height: 1,
            )),
            if (customA != null) ...[
              const SizedBox(height: 4),
              Text(customA!, style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 8),
            Text(teamA, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (canManage) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (onMinusA != null)
                  _PmBtn(label: '-1', onTap: onMinusA!, color: Colors.red),
                if (onMinusA != null) const SizedBox(width: 8),
                _PmBtn(label: '+1', onTap: onPlusA, color: AppColors.primary),
              ]),
            ],
          ])),

          // VS divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: [
              Container(width: 1, height: 60, color: Colors.white12),
              const SizedBox(height: 8),
              const Text('VS', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(width: 1, height: 60, color: Colors.white12),
            ]),
          ),

          // Team B
          Expanded(child: Column(children: [
            if (labelB != null)
              Text(labelB!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Text('$scoreB', style: TextStyle(
              color: bWinning ? AppColors.primary : Colors.white,
              fontSize: 56, fontWeight: FontWeight.w900, height: 1,
            )),
            if (customB != null) ...[
              const SizedBox(height: 4),
              Text(customB!, style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 8),
            Text(teamB, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (canManage) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (onMinusB != null)
                  _PmBtn(label: '-1', onTap: onMinusB!, color: Colors.red),
                if (onMinusB != null) const SizedBox(width: 8),
                _PmBtn(label: '+1', onTap: onPlusB, color: AppColors.primary),
              ]),
            ],
          ])),
        ]),

        if (saving) ...[
          const SizedBox(height: 12),
          const SizedBox(height: 2, child: LinearProgressIndicator(
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          )),
        ],
      ]),
    );
  }
}

class _PmBtn extends StatelessWidget {
  final String        label;
  final VoidCallback  onTap;
  final Color         color;
  const _PmBtn({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
    ),
  );
}

class _SetsLog extends StatelessWidget {
  final List<String> setsLog;
  final int setA, setB;
  final String teamA, teamB;
  const _SetsLog({required this.setsLog, required this.setA, required this.setB, required this.teamA, required this.teamB});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Sets', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(teamA, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ...setsLog.asMap().entries.map((e) {
          final parts = e.value.split('-');
          final a = int.tryParse(parts[0]) ?? 0;
          final b = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          return Container(
            width: 32, margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: a > b ? AppColors.primary.withAlpha(30) : Colors.white10,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: a > b ? AppColors.primary.withAlpha(80) : Colors.white12),
            ),
            child: Center(child: Text('${parts[0]}', style: TextStyle(color: a > b ? AppColors.primary : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700))),
          );
        }),
        const SizedBox(width: 8),
        Text('$setA', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Text(teamB, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ...setsLog.asMap().entries.map((e) {
          final parts = e.value.split('-');
          final a = int.tryParse(parts[0]) ?? 0;
          final b = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          return Container(
            width: 32, margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: b > a ? AppColors.primary.withAlpha(30) : Colors.white10,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: b > a ? AppColors.primary.withAlpha(80) : Colors.white12),
            ),
            child: Center(child: Text('${parts.length > 1 ? parts[1] : "0"}', style: TextStyle(color: b > a ? AppColors.primary : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700))),
          );
        }),
        const SizedBox(width: 8),
        Text('$setB', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    ]),
  );
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
