import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Splash
import '../../screens/splash/splash_screen.dart';

// Onboarding
import '../../screens/onboarding/onboarding_screen.dart';

// Welcome (role picker)
import '../../screens/welcome/welcome_screen.dart';

// Auth
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/phone_login_screen.dart';
import '../../screens/auth/email_login_screen.dart';
import '../../screens/auth/register_user_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/auth/complete_profile_screen.dart';

// Home (player)
import '../../screens/home/home_screen.dart';

// Web landing
import '../../screens/web/web_landing_page.dart';

// Merchant
import '../../screens/merchant/merchant_home_screen.dart';

// Venues (player-facing)
import '../../screens/venues/venues_list_screen.dart';

// Profile
import '../../screens/profile/edit_profile_screen.dart';

// Tournaments
import '../../screens/tournaments/tournaments_list_screen.dart';
import '../../screens/tournaments/tournament_link_gate.dart';

class AppRoutes {
  static final Map<String, WidgetBuilder> routes = {
    // App Entry
    '/': (context) => kIsWeb ? const WebLandingPage() : const SplashScreen(),
    '/onboarding': (context) => const OnboardingScreen(),
    '/welcome': (context) => const WebLandingPage(),
    '/web-landing': (context) => const WebLandingPage(),
    '/role-picker': (context) => const WelcomeScreen(),

    // Authentication
    '/login': (context) => const LoginScreen(),
    '/phone-login': (context) => const PhoneLoginScreen(),
    '/email-login': (context) => const EmailLoginScreen(),
    '/register-user': (context) => const RegisterUserScreen(),
    '/otp': (context) => const OtpScreen(),
    '/complete-profile': (context) => const CompleteProfileScreen(),

    // Web landing is handled by '/' on the web

    // Player Home
    '/home': (context) => const HomeScreen(),

    // Merchant Home
    '/merchant-home': (context) => const MerchantHomeScreen(),

    // Venues (player)
    '/venues': (context) => const VenuesListScreen(),

    // Profile
    '/edit_profile': (context) => const EditProfileScreen(),

    // Tournaments
    '/tournaments': (context) => const TournamentsListScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri == null) return null;

    if (uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'tournament') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => TournamentLinkGate(
          tournamentId: uri.pathSegments[1],
          joinCode: uri.queryParameters['code'],
        ),
      );
    }

    final legacyId = uri.queryParameters['t'];
    if ((legacyId ?? '').isNotEmpty) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => TournamentLinkGate(
          tournamentId: legacyId!,
          joinCode: uri.queryParameters['code'],
        ),
      );
    }

    return null;
  }
}
