import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
// 👆 Provider package for global state management
//import 'screens/splash/splash_screen.dart';
//import 'features/onboarding/onboarding_screen.dart';
//import 'screens/auth/login_screen.dart';


import 'core/routes/app_routes.dart';
import 'controllers/profile_controller.dart'; 
// 👆 ProfileController will store profile image globally

void main() {
  runApp(
    // ===========================
    // GLOBAL PROVIDER WRAPPER
    // ===========================
    ChangeNotifierProvider(
      create: (_) => ProfileController(),
      child: const MySportsApp(),
    ),
  );
}

class MySportsApp extends StatelessWidget {
  const MySportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ===========================
      // BASIC APP CONFIG
      // ===========================
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: AppRoutes.routes,

      // ===========================
      // THEME
      // ===========================
      theme: ThemeData.dark(),
    );
  }
}
