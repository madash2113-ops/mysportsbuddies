enum ParticipationStatus { inGame, out, tentative }

class Game {
  final String id;
  final String sport;
  final String location;
  final DateTime dateTime;
  final ParticipationStatus status;

  // Optional details from RegisterGameScreen
  final String? maxPlayers;
  final String? skillLevel;
  final String? format;
  final String? ballType;
  final String? notes;
  final DateTime createdAt;

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
  }) : createdAt = createdAt ?? DateTime.now();
}
