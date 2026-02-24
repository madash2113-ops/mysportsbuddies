import 'package:flutter/material.dart';

class RegisterGameScreen extends StatelessWidget {
  final String sportName;

  const RegisterGameScreen({
    super.key,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Register $sportName Game"),
      ),
      body: const Center(
        child: Text(
          "Game Registration Coming Soon",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
