import 'package:flutter/material.dart';
import '../../design/colors.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Scoreboards', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(child: Text('Scoreboards will be here', style: TextStyle(color: Colors.white70))),
    );
  }
}
