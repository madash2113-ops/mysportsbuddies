import '../core/models/game.dart';

/// Local in-memory store.
/// Replace the body of each method with Firebase calls once credentials are provided.
class GameService {
  GameService._();

  static final List<Game> _games = [
    Game(
      id: '1',
      sport: 'Cricket',
      location: 'Central Park Ground',
      dateTime: DateTime.now().add(const Duration(hours: 3)),
      status: ParticipationStatus.inGame,
      skillLevel: 'Intermediate',
      format: 'T20',
      maxPlayers: '22',
    ),
    Game(
      id: '2',
      sport: 'Football',
      location: 'City Stadium',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      status: ParticipationStatus.tentative,
      skillLevel: 'Open',
      format: '11-a-side',
      maxPlayers: '22',
    ),
    Game(
      id: '3',
      sport: 'Basketball',
      location: 'Downtown Arena',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      status: ParticipationStatus.inGame,
      skillLevel: 'Advanced',
      format: '5v5',
      maxPlayers: '10',
    ),
  ];

  /// All registered games, newest first.
  static List<Game> get all =>
      List.unmodifiable(_games)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Games for a specific sport, newest first.
  static List<Game> bySport(String sport) => _games
      .where((g) => g.sport.toLowerCase() == sport.toLowerCase())
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static List<Game> byStatus(ParticipationStatus status) =>
      _games.where((g) => g.status == status).toList();

  /// Add a newly registered game.
  /// TODO: replace with Firebase Firestore write once credentials are provided.
  static void addGame(Game game) {
    _games.add(game);
  }
}
