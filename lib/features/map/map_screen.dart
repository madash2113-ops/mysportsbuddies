import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  final String sportName;

  const MapScreen({
    super.key,
    required this.sportName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$sportName Games Nearby"),
      ),
      body: const Center(
        child: Text(
          "Map Integration Coming Soon",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
