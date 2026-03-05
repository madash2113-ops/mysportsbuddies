import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';

/// Visual knockout bracket tree + round-robin points table.
class BracketWidget extends StatelessWidget {
  final String           tournamentId;
  final List<TournamentRound> rounds;
  final bool             isHost;

  const BracketWidget({
    super.key,
    required this.tournamentId,
    required this.rounds,
    required this.isHost,
  });

  static const double _cardW   = 164;
  static const double _cardH   = 72;
  static const double _hGap    = 48;  // horizontal gap between rounds
  static const double _slotMin = 16;  // minimum vertical padding per slot

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const Center(
        child: Text('No bracket generated yet.',
            style: TextStyle(color: Colors.white38)),
      );
    }

    // Max matches in first round determines total height
    final maxMatches = rounds.first.matches.length;
    final slotH      = _cardH + _slotMin * 2;
    final totalH     = maxMatches * slotH;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: totalH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rounds.map((round) {
            final matchCount = round.matches.length;
            final roundSlotH = totalH / matchCount;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _cardW,
                  height: totalH,
                  child: Column(
                    children: [
                      // Round label
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
                      // Match cards with vertical centering
                      Expanded(
                        child: Stack(
                          children: List.generate(matchCount, (i) {
                            final topPad = i * roundSlotH +
                                (roundSlotH - _cardH) / 2;
                            return Positioned(
                              top: topPad,
                              left: 0,
                              right: 0,
                              child: _MatchCard(
                                match:        round.matches[i],
                                isHost:       isHost,
                                tournamentId: tournamentId,
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                // Connector lines between rounds (not after last round)
                if (round != rounds.last)
                  CustomPaint(
                    size: Size(_hGap, totalH),
                    painter: _ConnectorPainter(
                      matchCount: matchCount,
                      slotH:      roundSlotH,
                      cardH:      _cardH,
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Match Card ─────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final bool            isHost;
  final String          tournamentId;

  const _MatchCard({
    required this.match,
    required this.isHost,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = match.round >= 10; // just visual treatment

    return GestureDetector(
      onTap: (isHost && !match.isPlayed && !match.isBye && !match.isTBD)
          ? () => _showResultDialog(context)
          : null,
      child: Container(
        width: BracketWidget._cardW,
        height: BracketWidget._cardH,
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
                teamName: match.teamAName ?? 'Team A',
                score:    scoreA,
                onMinus:  () => setS(() { if (scoreA > 0) scoreA--; }),
                onPlus:   () => setS(() => scoreA++),
              ),
              const SizedBox(height: 12),
              _ScoreRow(
                teamName: match.teamBName ?? 'Team B',
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
                  backgroundColor: AppColors.primary),
              onPressed: () async {
                final winnerId   = scoreA >= scoreB
                    ? match.teamAId   : match.teamBId;
                final winnerName = scoreA >= scoreB
                    ? match.teamAName : match.teamBName;
                Navigator.pop(ctx);
                await TournamentService().updateMatchResult(
                  tournamentId: tournamentId,
                  matchId:      match.id,
                  scoreA:       scoreA,
                  scoreB:       scoreB,
                  winnerId:     winnerId   ?? '',
                  winnerName:   winnerName ?? '',
                );
              },
              child: const Text('Save',
                  style: TextStyle(color: Colors.white)),
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
