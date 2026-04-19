import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';

// ── Bracket layout constants (file-level so _MatchCard can access them) ──────
const double _kCardW   = 164;
const double _kCardH   = 72;
const double _kHGap    = 48;
const double _kSlotMin = 16;

/// Visual knockout bracket tree + round-robin points table.
///
/// Uses a raw [Listener]-based pan/zoom so that neither [NestedScrollView]
/// nor [TabBarView] can steal pointer events through the gesture arena.
class BracketWidget extends StatefulWidget {
  final String              tournamentId;
  final List<TournamentRound> rounds;
  final bool                isHost;

  const BracketWidget({
    super.key,
    required this.tournamentId,
    required this.rounds,
    required this.isHost,
  });

  @override
  State<BracketWidget> createState() => _BracketWidgetState();
}

class _BracketWidgetState extends State<BracketWidget> {
  static const double _minScale = 0.2;
  static const double _maxScale = 3.0;

  // ── Transform state ────────────────────────────────────────────────────────
  double _scale  = 1.0;
  Offset _offset = Offset.zero;

  // ── Per-pointer tracking (enables pinch-to-zoom) ───────────────────────────
  final Map<int, Offset> _ptrs = {};

  // Snapshot at the start of each gesture (reset whenever pointer count changes)
  double _scaleSnap   = 1.0;
  Offset _offsetSnap  = Offset.zero;
  Offset _focalSnap   = Offset.zero;
  double _spanSnap    = 0;

  // ── Helpers ────────────────────────────────────────────────────────────────
  Offset _centroid() {
    if (_ptrs.isEmpty) return Offset.zero;
    Offset s = Offset.zero;
    for (final p in _ptrs.values) {
      s += p;
    }
    return s / _ptrs.length.toDouble();
  }

  double _currentSpan() {
    if (_ptrs.length < 2) return 0;
    final ps = _ptrs.values.toList();
    return (ps[0] - ps[1]).distance;
  }

  /// Save a snapshot of the current state so subsequent moves are relative to it.
  void _snapshot() {
    _scaleSnap  = _scale;
    _offsetSnap = _offset;
    _focalSnap  = _centroid();
    _spanSnap   = _currentSpan();
  }

  // ── Pointer handlers (bypass gesture arena) ────────────────────────────────
  void _onPointerDown(PointerDownEvent e) {
    _ptrs[e.pointer] = e.localPosition;
    _snapshot();
  }

  void _onPointerMove(PointerMoveEvent e) {
    _ptrs[e.pointer] = e.localPosition;
    final focal = _centroid();
    final span  = _currentSpan();

    setState(() {
      if (_ptrs.length >= 2 && _spanSnap > 0) {
        // ── Pinch-to-zoom + pan ──────────────────────────────────────────
        final rawScale = _scaleSnap * span / _spanSnap;
        _scale  = rawScale.clamp(_minScale, _maxScale);
        _offset = _offsetSnap + (focal - _focalSnap);
      } else {
        // ── Single-finger pan ────────────────────────────────────────────
        _offset = _offsetSnap + (focal - _focalSnap);
      }
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    _ptrs.remove(e.pointer);
    _snapshot(); // re-anchor remaining fingers
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _ptrs.remove(e.pointer);
    _snapshot();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.rounds.isEmpty) {
      return const Center(
        child: Text('No bracket generated yet.',
            style: TextStyle(color: Colors.white38)),
      );
    }

    final maxMatches = widget.rounds.first.matches.length;
    final slotH      = _kCardH + _kSlotMin * 2;
    final totalH     = maxMatches * slotH;

    final bracketContent = Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.rounds.map((round) {
            final matchCount = round.matches.length;
            final roundSlotH = totalH / matchCount;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _kCardW,
                  height: totalH,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          round.label,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: List.generate(matchCount, (i) {
                            final topPad =
                                i * roundSlotH + (roundSlotH - _kCardH) / 2;
                            return Positioned(
                              top:   topPad,
                              left:  0,
                              right: 0,
                              child: _MatchCard(
                                match:        round.matches[i],
                                isHost:       widget.isHost,
                                tournamentId: widget.tournamentId,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                if (round != widget.rounds.last)
                  CustomPaint(
                    size: Size(_kHGap, totalH),
                    painter: _ConnectorPainter(
                      matchCount: matchCount,
                      slotH:      roundSlotH,
                      cardH:      _kCardH,
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );

    // ClipRect keeps the bracket inside the tab body boundary.
    // Listener captures ALL pointer events before any gesture recognizer sees
    // them — so NestedScrollView and TabBarView cannot steal the drag.
    return ClipRect(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown:   _onPointerDown,
        onPointerMove:   _onPointerMove,
        onPointerUp:     _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: OverflowBox(
          alignment:  Alignment.topLeft,
          maxWidth:   double.infinity,
          maxHeight:  double.infinity,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()
              // ignore: deprecated_member_use - Using for zoom/pan transform
              ..translate(_offset.dx, _offset.dy)
              // ignore: deprecated_member_use
              ..scale(_scale, _scale, 1),
            child: bracketContent,
          ),
        ),
      ),
    );
  }
}

// ── Match Card ─────────────────────────────────────────────────────────────

/// Uses [Listener] instead of [GestureDetector] so it never enters the gesture
/// arena — this lets [InteractiveViewer] receive pan/scale events anywhere on
/// the bracket, including directly over match cards.
class _MatchCard extends StatefulWidget {
  final TournamentMatch match;
  final bool            isHost;
  final String          tournamentId;

  const _MatchCard({
    required this.match,
    required this.isHost,
    required this.tournamentId,
  });

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  Offset? _pointerDownPos;

  bool get _tappable =>
      widget.isHost &&
      !widget.match.isPlayed &&
      !widget.match.isBye &&
      !widget.match.isTBD;

  @override
  Widget build(BuildContext context) {
    final match   = widget.match;
    final isFinal = match.round >= 10;

    return Listener(
      // Record where the finger went down
      onPointerDown: (e) => _pointerDownPos = e.localPosition,
      // On pointer-up: if it barely moved it's a tap, not a pan
      onPointerUp: (e) {
        final down = _pointerDownPos;
        _pointerDownPos = null;
        if (!_tappable || down == null) return;
        if ((e.localPosition - down).distance < 10) {
          _showResultDialog(context);
        }
      },
      onPointerCancel: (_) => _pointerDownPos = null,
      child: Container(
        width: _kCardW,
        height: _kCardH,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFinal
                ? AppColors.primary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            _TeamRow(
              name:     match.teamAName,
              score:    match.scoreA,
              isWinner: match.winnerId == match.teamAId,
              isPlayed: match.isPlayed,
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            _TeamRow(
              name:     match.teamBName,
              score:    match.scoreB,
              isWinner: match.winnerId == match.teamBId,
              isPlayed: match.isPlayed,
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(BuildContext context) {
    int scoreA = 0;
    int scoreB = 0;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Enter Match Result',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScoreRow(
                teamName: widget.match.teamAName ?? 'Team A',
                score:    scoreA,
                onMinus:  () => setS(() { if (scoreA > 0) scoreA--; }),
                onPlus:   () => setS(() => scoreA++),
              ),
              const SizedBox(height: 12),
              _ScoreRow(
                teamName: widget.match.teamBName ?? 'Team B',
                score:    scoreB,
                onMinus:  () => setS(() { if (scoreB > 0) scoreB--; }),
                onPlus:   () => setS(() => scoreB++),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: scoreA == scoreB
                      ? Colors.white12 : AppColors.primary),
              onPressed: scoreA == scoreB ? null : () async {
                final winnerId   = scoreA > scoreB
                    ? widget.match.teamAId   : widget.match.teamBId;
                final winnerName = scoreA > scoreB
                    ? widget.match.teamAName : widget.match.teamBName;
                Navigator.pop(ctx);
                await TournamentService().updateMatchResult(
                  tournamentId: widget.tournamentId,
                  matchId:      widget.match.id,
                  scoreA:       scoreA,
                  scoreB:       scoreB,
                  winnerId:     winnerId   ?? '',
                  winnerName:   winnerName ?? '',
                );
              },
              child: Text(
                  scoreA == scoreB ? 'No draws — adjust score' : 'Save',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String? name;
  final int?    score;
  final bool    isWinner;
  final bool    isPlayed;

  const _TeamRow({
    this.name,
    this.score,
    required this.isWinner,
    required this.isPlayed,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'TBD';
    final color = isPlayed && isWinner ? AppColors.primary : Colors.white70;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight:
                        isWinner ? FontWeight.w700 : FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (score != null)
              Text(
                '$score',
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String   teamName;
  final int      score;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _ScoreRow({
    required this.teamName,
    required this.score,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(teamName,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.white38, size: 20),
            onPressed: onMinus),
        Text('$score',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        IconButton(
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primary, size: 20),
            onPressed: onPlus),
      ],
    );
  }
}

// ── Connector Lines ────────────────────────────────────────────────────────

class _ConnectorPainter extends CustomPainter {
  final int    matchCount;
  final double slotH;
  final double cardH;

  const _ConnectorPainter({
    required this.matchCount,
    required this.slotH,
    required this.cardH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw connector for each pair of matches → their parent
    for (int i = 0; i < matchCount; i += 2) {
      final topY    = i * slotH + (slotH - cardH) / 2 + cardH / 2;
      final bottomY = (i + 1) < matchCount
          ? (i + 1) * slotH + (slotH - cardH) / 2 + cardH / 2
          : topY;
      final midY    = (topY + bottomY) / 2;
      final midX    = size.width / 2;

      // Horizontal from left edge to midX (top match)
      canvas.drawLine(Offset(0, topY), Offset(midX, topY), paint);
      // Horizontal from left edge to midX (bottom match)
      if ((i + 1) < matchCount) {
        canvas.drawLine(
            Offset(0, bottomY), Offset(midX, bottomY), paint);
      }
      // Vertical spine connecting both
      canvas.drawLine(Offset(midX, topY), Offset(midX, bottomY), paint);
      // Horizontal to right edge at midY
      canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) =>
      old.matchCount != matchCount ||
      old.slotH != slotH ||
      old.cardH != cardH;
}

// ── Points Table (Round Robin) ─────────────────────────────────────────────

class PointsTableWidget extends StatelessWidget {
  final List<TournamentTeam> teams;

  const PointsTableWidget({super.key, required this.teams});

  @override
  Widget build(BuildContext context) {
    final sorted = [...teams]
      ..sort((a, b) => b.points.compareTo(a.points));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FixedColumnWidth(36),
            2: FixedColumnWidth(36),
            3: FixedColumnWidth(36),
            4: FixedColumnWidth(36),
            5: FixedColumnWidth(40),
          },
          children: [
            // Header
            TableRow(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              children: ['Team', 'P', 'W', 'D', 'L', 'Pts']
                  .map((h) => _cell(h,
                      isHeader: true,
                      color: Colors.white38))
                  .toList(),
            ),
            // Rows
            ...sorted.asMap().entries.map((e) {
              final t = e.value;
              return TableRow(
                decoration: BoxDecoration(
                  color: e.key.isEven
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.02),
                ),
                children: [
                  _cell(t.teamName, color: Colors.white),
                  _cell('${t.played}'),
                  _cell('${t.wins}'),
                  _cell('${t.draws}'),
                  _cell('${t.losses}'),
                  _cell('${t.points}',
                      color: AppColors.primary,
                      bold: true),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text,
      {bool isHeader = false,
      Color color = Colors.white54,
      bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        style: TextStyle(
            color: color,
            fontSize: isHeader ? 11 : 13,
            fontWeight:
                (isHeader || bold) ? FontWeight.w700 : FontWeight.normal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
