import 'package:flutter/material.dart';

// Onboarding
import '../../features/onboarding/onboarding_screen.dart';

// Auth
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/phone_login_screen.dart';
import '../../screens/auth/email_login_screen.dart';
import '../../screens/auth/register_user_screen.dart';

// Home
import '../../screens/home/home_screen.dart';

class AppRoutes {
  static final Map<String, WidgetBuilder> routes = {
    // 🚀 App Entry
    '/': (context) => const OnboardingScreen(),

    // 🔐 Authentication
    '/login': (context) => const LoginScreen(),
    '/phone-login': (context) => const PhoneLoginScreen(),
    '/email-login': (context) => const EmailLoginScreen(),
    '/register-user': (context) => const RegisterUserScreen(),

    // 🏠 Main App
    '/home': (context) => const HomeScreen(),
  };
}
