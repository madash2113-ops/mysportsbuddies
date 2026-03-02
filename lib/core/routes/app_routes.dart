import 'package:flutter/material.dart';

// Splash
import '../../screens/splash/splash_screen.dart';

// Onboarding
import '../../screens/onboarding/onboarding_screen.dart';

// Auth
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/phone_login_screen.dart';
import '../../screens/auth/email_login_screen.dart';
import '../../screens/auth/register_user_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/auth/complete_profile_screen.dart';

// Home
import '../../screens/home/home_screen.dart';

// Profile
import '../../screens/profile/edit_profile_screen.dart';

class AppRoutes {
  static final Map<String, WidgetBuilder> routes = {

    // 🚀 App Entry
    '/': (context) => const SplashScreen(),
    '/onboarding': (context) => const OnboardingScreen(),

    // 🔐 Authentication
    '/login': (context) => const LoginScreen(),
    '/phone-login': (context) => const PhoneLoginScreen(),
    '/email-login': (context) => const EmailLoginScreen(),
    '/register-user': (context) => const RegisterUserScreen(),
    '/otp': (context) => const OtpScreen(),
    '/complete-profile': (context) => const CompleteProfileScreen(),

    // 🏠 Main App
    '/home': (context) => const HomeScreen(),

    // 👤 Profile
    '/edit_profile': (context) => const EditProfileScreen(),
  };
}
