import 'rally_rule_config.dart';

// PURPOSE:
// Core scoring engine for rally-based sports.
// Handles points, sets, match win detection.

class RallyEngine {
  final RallyRuleConfig config;

  int teamAScore = 0;
  int teamBScore = 0;

  int teamASetsWon = 0;
  int teamBSetsWon = 0;

  bool isMatchOver = false;

  RallyEngine({required this.config});

  // Adds a point to selected team
  void addPointToA() {
    if (isMatchOver) return;
    teamAScore++;
    _checkSetWin();
  }

  void addPointToB() {
    if (isMatchOver) return;
    teamBScore++;
    _checkSetWin();
  }

  // Checks whether current set is won
  void _checkSetWin() {
    final int target = config.pointsToWinSet;

    // Check cap rule (e.g., Badminton 30 cap)
    if (config.maxPointCap != null) {
      if (teamAScore == config.maxPointCap ||
          teamBScore == config.maxPointCap) {
        _declareSetWinner(teamAScore > teamBScore);
        return;
      }
    }

    if (teamAScore >= target || teamBScore >= target) {
      if (config.winByTwo) {
        if ((teamAScore - teamBScore).abs() >= 2) {
          _declareSetWinner(teamAScore > teamBScore);
        }
      } else {
        _declareSetWinner(teamAScore > teamBScore);
      }
    }
  }

  void _declareSetWinner(bool isTeamA) {
    if (isTeamA) {
      teamASetsWon++;
    } else {
      teamBSetsWon++;
    }

    teamAScore = 0;
    teamBScore = 0;

    _checkMatchWin();
  }

  void _checkMatchWin() {
    if (teamASetsWon == config.setsToWinMatch ||
        teamBSetsWon == config.setsToWinMatch) {
      isMatchOver = true;
    }
  }

  // Export match state (used later for UI / Firestore)
  Map<String, dynamic> exportState() {
    return {
      "teamAScore": teamAScore,
      "teamBScore": teamBScore,
      "teamASetsWon": teamASetsWon,
      "teamBSetsWon": teamBSetsWon,
      "isMatchOver": isMatchOver,
    };
  }
}
