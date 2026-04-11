// Rule configuration for the RallyEngine.
// Defines scoring rules for rally-based sports.
class RallyRuleConfig {
  final int pointsToWinSet;
  final int setsToWinMatch;
  final bool winByTwo;
  final int? maxPointCap; // e.g. Badminton caps at 30

  const RallyRuleConfig({
    required this.pointsToWinSet,
    required this.setsToWinMatch,
    this.winByTwo = true,
    this.maxPointCap,
  });
}
