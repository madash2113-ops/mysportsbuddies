import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 👇 Firebase Core
//import 'package:firebase_core/firebase_core.dart';
//import 'firebase_options.dart';
//import 'package:firebase_auth/firebase_auth.dart';

import 'core/routes/app_routes.dart';
import 'controllers/profile_controller.dart';
// 👆 ProfileController will store profile image globally

// ======================================================
// MAIN ENTRY POINT
// ======================================================
void main() async {
  // ======================================================
  // REQUIRED FOR ASYNC INITIALIZATION (FIREBASE)
  // ======================================================
  WidgetsFlutterBinding.ensureInitialized();

  // ======================================================
  // FIREBASE INITIALIZATION
  // This connects your app to:
  // - Firestore
  // - Firebase Auth
  // - Future cloud services
  // ======================================================
  //await Firebase.initializeApp(
   // options: DefaultFirebaseOptions.currentPlatform,
  //);
  // 🔥 Anonymous sign-in so every device has a UID
//await FirebaseAuth.instance.signInAnonymously();


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

// ======================================================
// ROOT APPLICATION
// ======================================================
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
