import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:async' show unawaited;

import 'firebase_options.dart';
import 'core/routes/app_routes.dart';
import 'controllers/profile_controller.dart';
import 'screens/tournaments/tournament_detail_screen.dart';
import 'screens/common/firebase_setup_screen.dart';
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
import 'services/location_service.dart';
import 'services/venue_service.dart';
import 'services/search_service.dart';

// ======================================================
// MAIN ENTRY POINT
// ======================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Image Cache Configuration ─────────────────────────────────────────────
  imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
  imageCache.maximumSize = 300;

  // ── Web startup optimization ──────────────────────────────────────────────
  // On web, render the app immediately and initialize Firebase in the
  // background so users see content without waiting for network initialization.
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _launchAppForWeb();
    return;
  }

  // ── Firebase ──────────────────────────────────────────────────────────────
  bool firebaseInitialized = false;
  String? firebaseError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;

    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
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

    _precacheUserImages();

    await Future.wait([
      GameService().loadFromFirestore(),
      ScoreboardService().loadFromFirestore(),
      FollowService().init(),
      StatsService().load(),
      TournamentService().loadTournaments(),
    ]);

    // Start real-time listeners
    FeedService().listenToFeed();
    FeedService().listenToStories();
    MessageService().listenToConversations();
    GameService().listenToFirestore();
    ScoreboardService().listenToFirestore();
    NotificationService().listen();
    TournamentService().listenToTournaments();
    await TournamentService().loadTournaments();
    VenueService().listenToVenues();
    GameListingService().listenToOpenGames();
    AdminService().listen();
  } catch (e) {
    firebaseError = e.toString();
  }

  if (firebaseInitialized) {
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
          ChangeNotifierProvider(create: (_) => LocationService()),
          ChangeNotifierProvider(create: (_) => SearchService()),
        ],
        child: const MySportsApp(),
      ),
    );
  } else {
    runApp(FirebaseSetupApp(error: firebaseError));
  }
}

/// Launch the app immediately on web without waiting for Firebase.
/// Firebase initializes in the background via [_initializeFirebaseForWeb].
void _launchAppForWeb() {
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
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => SearchService()),
      ],
      child: const MySportsApp(),
    ),
  );

  unawaited(_initializeFirebaseForWeb());
}

/// Initialize Firebase on the web in the background.
Future<void> _initializeFirebaseForWeb() async {
  try {
    AnalyticsService().logEvent(AnalyticsEvents.appOpen);

    // Disable reCAPTCHA browser popup during development (debug builds only)
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }

    await UserService().init();
    _precacheUserImages();

    await Future.wait([
      GameService().loadFromFirestore(),
      ScoreboardService().loadFromFirestore(),
      FollowService().init(),
      StatsService().load(),
      TournamentService().loadTournaments(),
    ]);

    // Start real-time listeners
    FeedService().listenToFeed();
    FeedService().listenToStories();
    MessageService().listenToConversations();
    GameService().listenToFirestore();
    ScoreboardService().listenToFirestore();
    NotificationService().listen();
    TournamentService().listenToTournaments();
    await TournamentService().loadTournaments();
    VenueService().listenToVenues();
    GameListingService().listenToOpenGames();
    AdminService().listen();
  } catch (e) {
    debugPrint('Firebase web initialization failed: $e');
  }
}

// ======================================================
// HELPER FUNCTIONS
// ======================================================

void _precacheUserImages() {
  final userProfile = UserService().profile;
  debugPrint('📸 User profile image: ${userProfile?.imageUrl}');
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

class FirebaseSetupApp extends StatelessWidget {
  final String? error;
  const FirebaseSetupApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: FirebaseSetupScreen(error: error),
    );
  }
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
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handleLink(initial);

    _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'msb' || uri.host != 'tournament') return;
    AnalyticsService().logEvent(
      AnalyticsEvents.appOpenedViaLink,
      parameters: {'uri': uri.toString(), 'source': 'deep_link'},
    );
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final tournamentId = segments.first;
    final code = uri.queryParameters['code'];

    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) =>
            TournamentDetailScreen(tournamentId: tournamentId, joinCode: code),
      ),
    );
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
