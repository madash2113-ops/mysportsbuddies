import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/routes/app_routes.dart';
import 'controllers/profile_controller.dart';
import 'design/theme.dart';
import 'services/admin_service.dart';
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
class MySportsApp extends StatelessWidget {
  const MySportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (_, ts, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: AppRoutes.routes,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ts.mode,
      ),
    );
  }
}
