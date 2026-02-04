class SportItem {
  final String name;
  final String emoji;

  const SportItem({
    required this.name,
    required this.emoji,
  });
}

const List<SportItem> allSports = [
  SportItem(name: 'Badminton', emoji: '🏸'),
  SportItem(name: 'Baseball', emoji: '⚾'),
  SportItem(name: 'Basketball', emoji: '🏀'),
  SportItem(name: 'Boxing', emoji: '🥊'),
  SportItem(name: 'Cricket', emoji: '🏏'),
  SportItem(name: 'Football', emoji: '⚽'),
  SportItem(name: 'Hockey', emoji: '🏑'),
  SportItem(name: 'Running', emoji: '🏃'),
  SportItem(name: 'Swimming', emoji: '🏊'),
  SportItem(name: 'Table Tennis', emoji: '🏓'),
  SportItem(name: 'Tennis', emoji: '🎾'),
  SportItem(name: 'Volleyball', emoji: '🏐'),
];
