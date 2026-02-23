import 'package:flutter/material.dart';
import '../../design/colors.dart';

class LiveMatchesScreen extends StatelessWidget {
  final String sportName;

  const LiveMatchesScreen({
    super.key,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Live $sportName Matches',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Text(
          'Live matches for $sportName',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
