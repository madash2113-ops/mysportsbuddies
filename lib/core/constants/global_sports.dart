import 'package:flutter/material.dart';
import '../models/sport_model.dart';

/// Top 50 world sports for MySportsBuddies.
class GlobalSports {
  static final List<Sport> all = [
    // ── Bat & Ball ────────────────────────────────────────────────────────
    Sport(id: 'cricket',    name: 'Cricket',    category: 'team',       scoringType: 'runs',   icon: Icons.sports_cricket),
    Sport(id: 'baseball',   name: 'Baseball',   category: 'team',       scoringType: 'runs',   icon: Icons.sports_baseball),
    Sport(id: 'softball',   name: 'Softball',   category: 'team',       scoringType: 'runs',   icon: Icons.sports_baseball),

    // ── Football Family ───────────────────────────────────────────────────
    Sport(id: 'football',          name: 'Football',          category: 'team', scoringType: 'goals',  icon: Icons.sports_soccer),
    Sport(id: 'futsal',            name: 'Futsal',            category: 'team', scoringType: 'goals',  icon: Icons.sports_soccer),
    Sport(id: 'american_football', name: 'American Football', category: 'team', scoringType: 'points', icon: Icons.sports_football),
    Sport(id: 'rugby_union',       name: 'Rugby Union',       category: 'team', scoringType: 'points', icon: Icons.sports_rugby),
    Sport(id: 'rugby_league',      name: 'Rugby League',      category: 'team', scoringType: 'points', icon: Icons.sports_rugby),
    Sport(id: 'afl',               name: 'AFL',               category: 'team', scoringType: 'points', icon: Icons.sports_rugby),
    Sport(id: 'handball',          name: 'Handball',          category: 'team', scoringType: 'goals',  icon: Icons.sports_handball),

    // ── Basketball Family ─────────────────────────────────────────────────
    Sport(id: 'basketball', name: 'Basketball', category: 'team',       scoringType: 'points', icon: Icons.sports_basketball),
    Sport(id: 'netball',    name: 'Netball',    category: 'team',       scoringType: 'goals',  icon: Icons.sports_basketball),

    // ── Net / Rally ───────────────────────────────────────────────────────
    Sport(id: 'badminton',        name: 'Badminton',        category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),
    Sport(id: 'tennis',           name: 'Tennis',           category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),
    Sport(id: 'table_tennis',     name: 'Table Tennis',     category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),
    Sport(id: 'volleyball',       name: 'Volleyball',       category: 'team',       scoringType: 'sets', icon: Icons.sports_volleyball),
    Sport(id: 'beach_volleyball', name: 'Beach Volleyball', category: 'team',       scoringType: 'sets', icon: Icons.sports_volleyball),
    Sport(id: 'squash',           name: 'Squash',           category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),
    Sport(id: 'padel',            name: 'Padel',            category: 'individual', scoringType: 'sets', icon: Icons.sports_tennis),

    // ── Hockey ────────────────────────────────────────────────────────────
    Sport(id: 'hockey',     name: 'Hockey',     category: 'team', scoringType: 'goals', icon: Icons.sports_hockey),
    Sport(id: 'ice_hockey', name: 'Ice Hockey', category: 'team', scoringType: 'goals', icon: Icons.sports_hockey),

    // ── Aquatic ───────────────────────────────────────────────────────────
    Sport(id: 'water_polo', name: 'Water Polo', category: 'team',       scoringType: 'goals', icon: Icons.pool),
    Sport(id: 'swimming',   name: 'Swimming',   category: 'individual', scoringType: 'time',  icon: Icons.pool),
    Sport(id: 'rowing',     name: 'Rowing',     category: 'individual', scoringType: 'time',  icon: Icons.rowing),

    // ── Combat ────────────────────────────────────────────────────────────
    Sport(id: 'boxing',    name: 'Boxing',    category: 'combat', scoringType: 'rounds', icon: Icons.sports_mma),
    Sport(id: 'mma',       name: 'MMA',       category: 'combat', scoringType: 'rounds', icon: Icons.sports_mma),
    Sport(id: 'wrestling', name: 'Wrestling', category: 'combat', scoringType: 'points', icon: Icons.sports_mma),
    Sport(id: 'fencing',   name: 'Fencing',   category: 'combat', scoringType: 'points', icon: Icons.sports_martial_arts),

    // ── Stick & Target ────────────────────────────────────────────────────
    Sport(id: 'golf',     name: 'Golf',     category: 'individual', scoringType: 'strokes', icon: Icons.golf_course),
    Sport(id: 'lacrosse', name: 'Lacrosse', category: 'team',       scoringType: 'goals',   icon: Icons.sports),
    Sport(id: 'polo',     name: 'Polo',     category: 'team',       scoringType: 'goals',   icon: Icons.sports),
    Sport(id: 'curling',  name: 'Curling',  category: 'team',       scoringType: 'points',  icon: Icons.sports),
    Sport(id: 'archery',  name: 'Archery',  category: 'individual', scoringType: 'points',  icon: Icons.sports),
    Sport(id: 'shooting', name: 'Shooting', category: 'individual', scoringType: 'points',  icon: Icons.gps_fixed),
    Sport(id: 'darts',    name: 'Darts',    category: 'individual', scoringType: 'points',  icon: Icons.crisis_alert),
    Sport(id: 'snooker',  name: 'Snooker',  category: 'individual', scoringType: 'points',  icon: Icons.sports),

    // ── Athletics & Speed ─────────────────────────────────────────────────
    Sport(id: 'athletics',   name: 'Athletics',  category: 'individual', scoringType: 'time',  icon: Icons.directions_run),
    Sport(id: 'cycling',     name: 'Cycling',    category: 'individual', scoringType: 'time',  icon: Icons.pedal_bike),
    Sport(id: 'triathlon',   name: 'Triathlon',  category: 'individual', scoringType: 'time',  icon: Icons.directions_run),
    Sport(id: 'formula_one', name: 'Formula 1',  category: 'individual', scoringType: 'points',icon: Icons.speed),

    // ── Gym & Physical ────────────────────────────────────────────────────
    Sport(id: 'gymnastics',    name: 'Gymnastics',    category: 'individual', scoringType: 'points', icon: Icons.self_improvement),
    Sport(id: 'weightlifting', name: 'Weightlifting', category: 'individual', scoringType: 'kg',     icon: Icons.fitness_center),

    // ── E-Sports ──────────────────────────────────────────────────────────
    Sport(id: 'esports_csgo',    name: 'CS:GO',             category: 'esport', scoringType: 'rounds', icon: Icons.sports_esports),
    Sport(id: 'esports_valorant',name: 'Valorant',           category: 'esport', scoringType: 'rounds', icon: Icons.sports_esports),
    Sport(id: 'esports_lol',     name: 'League of Legends',  category: 'esport', scoringType: 'rounds', icon: Icons.sports_esports),
    Sport(id: 'esports_dota2',   name: 'Dota 2',             category: 'esport', scoringType: 'rounds', icon: Icons.sports_esports),
    Sport(id: 'esports_fifa',    name: 'FIFA Esports',        category: 'esport', scoringType: 'goals',  icon: Icons.sports_soccer),

    // ── Regional / Traditional ────────────────────────────────────────────
    Sport(id: 'kabaddi', name: 'Kabaddi', category: 'team', scoringType: 'points', icon: Icons.people),
    Sport(id: 'kho_kho', name: 'Kho Kho', category: 'team', scoringType: 'points', icon: Icons.people),
  ];

  /// Find a sport by its id
  static Sport? findById(String id) =>
      all.where((s) => s.id == id).firstOrNull;

  /// Filter by category
  static List<Sport> byCategory(String category) =>
      all.where((s) => s.category == category).toList();
}
