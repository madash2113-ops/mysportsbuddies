import 'package:cloud_firestore/cloud_firestore.dart';

enum ParticipationStatus { inGame, out, tentative }

class Game {
  final String id;
  final String sport;
  final String location;
  final DateTime dateTime;
  final ParticipationStatus status;
  final String? maxPlayers;
  final String? skillLevel;
  final String? format;
  final String? ballType;
  final String? notes;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? registeredBy; // device user ID of whoever created this game

  Game({
    required this.id,
    required this.sport,
    required this.location,
    required this.dateTime,
    required this.status,
    this.maxPlayers,
    this.skillLevel,
    this.format,
    this.ballType,
    this.notes,
    DateTime? createdAt,
    this.latitude,
    this.longitude,
    this.registeredBy,
  }) : createdAt = createdAt ?? DateTime.now();

  Game copyWith({
    ParticipationStatus? status,
    String? location,
    DateTime? dateTime,
    String? maxPlayers,
    String? skillLevel,
    String? format,
    String? ballType,
    String? notes,
    double? latitude,
    double? longitude,
  }) =>
      Game(
        id: id,
        sport: sport,
        location: location ?? this.location,
        dateTime: dateTime ?? this.dateTime,
        status: status ?? this.status,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        skillLevel: skillLevel ?? this.skillLevel,
        format: format ?? this.format,
        ballType: ballType ?? this.ballType,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        registeredBy: registeredBy,
      );

  // ── Firestore serialisation ───────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'sport': sport,
        'location': location,
        'dateTime': Timestamp.fromDate(dateTime),
        'status': status.name,
        'maxPlayers': maxPlayers,
        'skillLevel': skillLevel,
        'format': format,
        'ballType': ballType,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'latitude': latitude,
        'longitude': longitude,
        'registeredBy': registeredBy,
      };

  factory Game.fromMap(Map<String, dynamic> map) => Game(
        id: map['id'] as String,
        sport: map['sport'] as String,
        location: map['location'] as String,
        dateTime: (map['dateTime'] as Timestamp).toDate(),
        status: ParticipationStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => ParticipationStatus.tentative,
        ),
        maxPlayers: map['maxPlayers'] as String?,
        skillLevel: map['skillLevel'] as String?,
        format: map['format'] as String?,
        ballType: map['ballType'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        registeredBy: map['registeredBy'] as String?,
      );

  factory Game.fromFirestore(DocumentSnapshot doc) =>
      Game.fromMap(doc.data() as Map<String, dynamic>);
}
