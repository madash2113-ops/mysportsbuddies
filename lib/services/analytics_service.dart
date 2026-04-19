import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsEvents {
  // App lifecycle
  static const String appOpen = 'app_open';

  // Auth & Onboarding
  static const String signUpStart    = 'sign_up_start';
  static const String signUpComplete = 'sign_up_complete';
  static const String login          = 'login';
  static const String logout         = 'logout';
  static const String profileComplete = 'profile_complete';
  static const String onboardingComplete = 'onboarding_complete';

  // Games
  static const String gameCreated = 'game_created';
  static const String gameJoined  = 'game_joined';
  static const String gameLeft    = 'game_left';

  // Matches / Live scoring
  static const String matchStarted   = 'match_started';    // params: sport, context (casual|tournament)
  static const String matchCompleted = 'match_completed';  // params: sport, context, duration_min
  static const String scorecardShared = 'scorecard_shared'; // params: sport

  // Tournaments
  static const String tournamentCreated = 'tournament_created'; // params: sport, format, is_private, max_teams, has_entry_fee
  static const String tournamentJoined  = 'tournament_joined';  // params: sport, has_entry_fee

  // Social & Community
  static const String followUser     = 'follow_user';
  static const String unfollowUser   = 'unfollow_user';
  static const String feedPostCreated = 'feed_post_created'; // params: type (manual|scoreCard), has_image
  static const String storyCreated   = 'story_created';     // params: has_image, has_text
  static const String storyViewed    = 'story_viewed';
  static const String messageSent    = 'message_sent';

  // Venues
  static const String venueViewed  = 'venue_viewed';
  static const String venueBooked  = 'venue_booked';
  static const String venueSearched = 'venue_searched';

  // Sharing & Virality
  static const String tournamentShared   = 'tournament_shared';     // params: is_private
  static const String appOpenedViaLink   = 'app_opened_via_link';   // params: tournament_id

  // Premium
  static const String premiumScreenViewed = 'premium_screen_viewed'; // params: source
  static const String premiumUpgraded     = 'premium_upgraded';
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver getObserver() => FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      debugPrint('📊 Analytics Logged: $name | Params: $parameters');
    } catch (e, stackTrace) {
      debugPrint('❌ Analytics Error: $e');
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Analytics logging failed');
    }
  }

  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      if (userId != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(userId);
      }
      debugPrint('📊 Analytics UserId set: $userId');
    } catch (e) {
      debugPrint('❌ Analytics setUserId Error: $e');
    }
  }

  Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      FirebaseCrashlytics.instance.setCustomKey(name, value);
      debugPrint('📊 Analytics Property: $name = $value');
    } catch (e) {
      debugPrint('❌ Analytics setUserProperty Error: $e');
    }
  }

  Future<void> logScreenView({required String screenName, String? screenClass}) async {
    try {
      await _analytics.logScreenView(screenName: screenName, screenClass: screenClass);
      debugPrint('📊 Analytics Screen: $screenName');
    } catch (e) {
      debugPrint('❌ Analytics logScreenView Error: $e');
    }
  }

  /// Call once after login to segment all subsequent events by user attributes.
  Future<void> setUserProperties({
    required String role,
    required bool isPremium,
    required String primarySport,
    required bool hasPlayedMatch,
  }) async {
    await setUserProperty('role', role);
    await setUserProperty('is_premium', isPremium.toString());
    await setUserProperty('primary_sport', primarySport.isEmpty ? 'none' : primarySport);
    await setUserProperty('has_played_match', hasPlayedMatch.toString());
  }

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);
}
