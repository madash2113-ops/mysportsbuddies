import 'package:flutter/material.dart';
import '../models/sport_model.dart';

class GlobalSports {
  static final List<Sport> all = [
    // TEAM SPORTS
    Sport(id: 'cricket', name: 'Cricket', category: 'team', scoringType: 'runs', icon: Icons.sports_cricket),
    Sport(id: 'football', name: 'Football', category: 'team', scoringType: 'goals', icon: Icons.sports_soccer),
    Sport(id: 'basketball', name: 'Basketball', category: 'team', scoringType: 'points', icon: Icons.sports_basketball),
    Sport(id: 'baseball', name: 'Baseball', category: 'team', scoringType: 'runs', icon: Icons.sports_baseball),
    Sport(id: 'hockey', name: 'Hockey', category: 'team', scoringType: 'goals', icon: Icons.sports_hockey),

    // RACKET SPORTS
    Sport(id: 'tennis', name: 'Tennis', category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),
    Sport(id: 'badminton', name: 'Badminton', category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),
    Sport(id: 'table_tennis', name: 'Table Tennis', category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),

    // COMBAT SPORTS
    Sport(id: 'boxing', name: 'Boxing', category: 'combat', scoringType: 'rounds', icon: Icons.sports_mma),
    Sport(id: 'mma', name: 'MMA', category: 'combat', scoringType: 'rounds', icon: Icons.sports_mma),
    Sport(id: 'wrestling', name: 'Wrestling', category: 'combat', scoringType: 'points', icon: Icons.sports_mma),

    // ATHLETICS
    Sport(id: 'running', name: 'Running', category: 'athletics', scoringType: 'time', icon: Icons.directions_run),
    Sport(id: 'swimming', name: 'Swimming', category: 'athletics', scoringType: 'time', icon: Icons.pool),
    Sport(id: 'cycling', name: 'Cycling', category: 'athletics', scoringType: 'time', icon: Icons.two_wheeler),

    // ESPORTS
    Sport(id: 'esports_csgo', name: 'CS:GO', category: 'esport', scoringType: 'rounds', icon: Icons.sports_esports),
    Sport(id: 'esports_valorant', name: 'Valorant', category: 'esport', scoringType: 'rounds', icon: Icons.sports_esports),

    // REGIONAL / TRADITIONAL
    Sport(id: 'kabaddi', name: 'Kabaddi', category: 'team', scoringType: 'points', icon: Icons.people),
    Sport(id: 'kho_kho', name: 'Kho Kho', category: 'team', scoringType: 'points', icon: Icons.people),

    // This list can grow to 150+ safely
  ];
}
