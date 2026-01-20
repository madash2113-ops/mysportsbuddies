import 'package:flutter/material.dart';

class Sport {
  final String id;
  final String name;
  final String category; // team, individual, combat, racing, e-sport
  final String scoringType; // runs, goals, points, sets, time
  final bool hasScoreboard;
  final IconData icon;

  const Sport({
    required this.id,
    required this.name,
    required this.category,
    required this.scoringType,
    this.hasScoreboard = true,
    required this.icon,
  });
}
