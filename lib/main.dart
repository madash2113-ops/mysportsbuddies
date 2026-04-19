import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'core/routes/app_routes.dart';
import 'controllers/profile_controller.dart';
import 'screens/tournaments/tournament_detail_screen.dart';
import 'design/theme.dart';
import 'services/admin_service.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/feed_service.dart';
import 'services/follow_service.dart';
import 'services/game_service.dart';
import 'services/message_service.dart';
import 'services/notification_service.dart';
import 'services/scoreboard_service.dart';
import 'services/theme_service.dart';
import 'services/tournament_service.dart';
import 'services/user_service.dart';
import 'services/game_listing_service.dart';
import 'services/stats_service.dart';
import 'services/venue_service.dart';

// ======================================================
// MAIN ENTRY POINT
// ======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ──────────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    AnalyticsService().logEvent(AnalyticsEvents.appOpen);

    // Disable reCAPTCHA browser popup during development (debug builds only)
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }

    await UserService().init();
    debugPrint('✅ UserService initialized');

    await Future.wait([
      GameService().loadFromFirestore(),
      ScoreboardService().loadFromFirestore(),
      FollowService().init(),
      StatsService().load(),
      TournamentService().loadTournaments(),
    ]);
    debugPrint('✅ All services loaded in parallel');

    // Start real-time listeners
    FeedService().listenToFeed();
    FeedService().listenToStories();
    MessageService().listenToConversations();
    GameService().listenToFirestore();
    ScoreboardService().listenToFirestore();
    NotificationService().listen();
    TournamentService().listenToTournaments();
    await TournamentService().loadTournaments(); // ensure data on first frame
    VenueService().listenToVenues();
    GameListingService().listenToOpenGames();
    AdminService().listen(); // real-time admin roster
    debugPrint('✅ Real-time listeners started');
  } catch (e) {
    debugPrint('❌ Firebase error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AnalyticsService>(create: (_) => AnalyticsService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => ScoreboardService()),
        ChangeNotifierProvider(create: (_) => GameService()),
        ChangeNotifierProvider(create: (_) => UserService()),
        ChangeNotifierProvider(create: (_) => FeedService()),
        ChangeNotifierProvider(create: (_) => FollowService()),
        ChangeNotifierProvider(create: (_) => MessageService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => TournamentService()),
        ChangeNotifierProvider(create: (_) => VenueService()),
        ChangeNotifierProvider(create: (_) => GameListingService()),
        ChangeNotifierProvider(create: (_) => StatsService()),
        ChangeNotifierProvider(create: (_) => AdminService()),
      ],
      child: const MySportsApp(),
    ),
  );
}

// ======================================================
// ROOT APPLICATION
// ======================================================

final _navigatorKey = GlobalKey<NavigatorState>();

class MySportsApp extends StatefulWidget {
  const MySportsApp({super.key});

  @override
  State<MySportsApp> createState() => _MySportsAppState();
}

class _MySportsAppState extends State<MySportsApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    // Cold start: app opened via link
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handleLink(initial);

    // Hot start: link received while app is running
    _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    // msb://tournament/{id}?code={joinCode}
    if (uri.scheme != 'msb' || uri.host != 'tournament') return;
    AnalyticsService().logEvent(AnalyticsEvents.appOpenedViaLink, parameters: {'uri': uri.toString(), 'source': 'deep_link'});
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final tournamentId = segments.first;
    final code = uri.queryParameters['code'];

    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    nav.push(MaterialPageRoute(
      builder: (_) => TournamentDetailScreen(
        tournamentId: tournamentId,
        joinCode: code,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (_, ts, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        navigatorObservers: [AnalyticsService().getObserver()],
        initialRoute: '/',
        routes: AppRoutes.routes,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ts.mode,
      ),
    );
  }
}
