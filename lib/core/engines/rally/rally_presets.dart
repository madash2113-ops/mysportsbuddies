import 'rally_rule_config.dart';

// PURPOSE:
// Official preset rule configurations for rally-based sports.
// Allows engine to stay generic and rules to stay centralized.

// Volleyball:
// 25 points per set
// Best of 5 (first to 3 sets)
// Win by 2
final RallyRuleConfig volleyballRules = RallyRuleConfig(
  pointsToWinSet: 25,
  setsToWinMatch: 3,
  winByTwo: true,
);

// Badminton:
// 21 points per set
// Best of 3 (first to 2 sets)
// Win by 2
// Cap at 30
final RallyRuleConfig badmintonRules = RallyRuleConfig(
  pointsToWinSet: 21,
  setsToWinMatch: 2,
  winByTwo: true,
  maxPointCap: 30,
);

// Table Tennis:
// 11 points per set
// Best of 5
// Win by 2
final RallyRuleConfig tableTennisRules = RallyRuleConfig(
  pointsToWinSet: 11,
  setsToWinMatch: 3,
  winByTwo: true,
);

// Tennis (Simplified game scoring version):
// For now we treat like rally 6-game set style simplified
final RallyRuleConfig tennisRules = RallyRuleConfig(
  pointsToWinSet: 6,
  setsToWinMatch: 3,
  winByTwo: true,
);
