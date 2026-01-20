import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'design/theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: AppRoutes.routes,
    );
  }
}
