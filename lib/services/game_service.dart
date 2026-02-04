import '../core/models/game.dart';

class GameService {
  static final List<Game> games = [
    Game(
      id: '1',
      sport: 'Cricket',
      location: 'Central Park Ground',
      dateTime: DateTime.now().add(const Duration(hours: 3)),
      status: ParticipationStatus.inGame,
    ),
    Game(
      id: '2',
      sport: 'Football',
      location: 'City Stadium',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      status: ParticipationStatus.tentative,
    ),
    Game(
      id: '3',
      sport: 'Basketball',
      location: 'Downtown Arena',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      status: ParticipationStatus.out,
    ),
  ];

  static List<Game> byStatus(ParticipationStatus status) {
    return games.where((g) => g.status == status).toList();
  }
}
