/// Entitlement keys — each string maps to a feature the user is allowed to use.
///
/// Grant entitlements via Firestore `users/{uid}.entitlements` (List of String).
/// Use [UserService.hasEntitlement] to check access; never read this map directly
/// in UI code.
class Entitlements {
  const Entitlements._();

  // ── Player premium ────────────────────────────────────────────────────────
  static const String pdfReports      = 'pdf_reports';
  static const String advancedStats   = 'advanced_stats';
  static const String priorityAlerts  = 'priority_alerts';
  static const String premiumBadge    = 'premium_badge';
  static const String boostedListings = 'boosted_listings';
  static const String earlyAccess     = 'early_access';

  // ── Organizer premium (stackable on top of any role) ─────────────────────
  static const String largeTournaments     = 'large_tournaments';
  static const String unlimitedScoreboards = 'unlimited_scoreboards';
  static const String aiBanners           = 'ai_banners';
  static const String advancedReports     = 'advanced_reports';

  // ── Convenience bundles (granted together when upgrading a tier) ──────────

  /// Everything a premium player gets.
  static const Set<String> playerBundle = {
    pdfReports, advancedStats, priorityAlerts, premiumBadge,
    boostedListings, earlyAccess,
    largeTournaments, unlimitedScoreboards,
  };

  /// Everything a premium organizer gets (superset of player).
  static const Set<String> organizerBundle = {
    ...playerBundle,
    aiBanners, advancedReports,
  };
}
