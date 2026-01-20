enum ParticipationStatus { inGame, out, tentative }

class Game {
  final String id;
  final String sport;
  final String location;
  final DateTime dateTime;
  final ParticipationStatus status;

  Game({
    required this.id,
    required this.sport,
    required this.location,
    required this.dateTime,
    required this.status,
  });
}
