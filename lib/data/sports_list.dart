class SportItem {
  final String name;
  final String emoji;

  const SportItem({
    required this.name,
    required this.emoji,
  });
}

/// Top 50 world sports — used in sport selection UI.
const List<SportItem> allSports = [
  // ── Bat & Ball ──────────────────────────────────────────────────────────
  SportItem(name: 'Cricket',          emoji: '🏏'),
  SportItem(name: 'Baseball',         emoji: '⚾'),
  SportItem(name: 'Softball',         emoji: '🥎'),

  // ── Football Family ─────────────────────────────────────────────────────
  SportItem(name: 'Football',         emoji: '⚽'),
  SportItem(name: 'Futsal',           emoji: '⚽'),
  SportItem(name: 'American Football',emoji: '🏈'),
  SportItem(name: 'Rugby Union',      emoji: '🏉'),
  SportItem(name: 'Rugby League',     emoji: '🏉'),
  SportItem(name: 'AFL',              emoji: '🏉'),
  SportItem(name: 'Handball',         emoji: '🤾'),

  // ── Basketball Family ───────────────────────────────────────────────────
  SportItem(name: 'Basketball',       emoji: '🏀'),
  SportItem(name: 'Netball',          emoji: '🏀'),

  // ── Net / Rally ─────────────────────────────────────────────────────────
  SportItem(name: 'Badminton',        emoji: '🏸'),
  SportItem(name: 'Tennis',           emoji: '🎾'),
  SportItem(name: 'Table Tennis',     emoji: '🏓'),
  SportItem(name: 'Volleyball',       emoji: '🏐'),
  SportItem(name: 'Beach Volleyball', emoji: '🏐'),
  SportItem(name: 'Squash',           emoji: '🎾'),
  SportItem(name: 'Padel',            emoji: '🎾'),

  // ── Hockey ──────────────────────────────────────────────────────────────
  SportItem(name: 'Hockey',           emoji: '🏑'),
  SportItem(name: 'Ice Hockey',       emoji: '🏒'),

  // ── Aquatic ─────────────────────────────────────────────────────────────
  SportItem(name: 'Water Polo',       emoji: '🤽'),
  SportItem(name: 'Swimming',         emoji: '🏊'),
  SportItem(name: 'Rowing',           emoji: '🚣'),

  // ── Combat ──────────────────────────────────────────────────────────────
  SportItem(name: 'Boxing',           emoji: '🥊'),
  SportItem(name: 'MMA',              emoji: '🥋'),
  SportItem(name: 'Wrestling',        emoji: '🤼'),
  SportItem(name: 'Fencing',          emoji: '🤺'),

  // ── Stick & Target ──────────────────────────────────────────────────────
  SportItem(name: 'Golf',             emoji: '⛳'),
  SportItem(name: 'Lacrosse',         emoji: '🥍'),
  SportItem(name: 'Polo',             emoji: '🏇'),
  SportItem(name: 'Curling',          emoji: '🥌'),
  SportItem(name: 'Archery',          emoji: '🏹'),
  SportItem(name: 'Shooting',         emoji: '🎯'),
  SportItem(name: 'Darts',            emoji: '🎯'),
  SportItem(name: 'Snooker',          emoji: '🎱'),

  // ── Athletics & Speed ───────────────────────────────────────────────────
  SportItem(name: 'Athletics',        emoji: '🏃'),
  SportItem(name: 'Cycling',          emoji: '🚴'),
  SportItem(name: 'Triathlon',        emoji: '🏊'),
  SportItem(name: 'Formula 1',        emoji: '🏎'),

  // ── Gym & Physical ──────────────────────────────────────────────────────
  SportItem(name: 'Gymnastics',       emoji: '🤸'),
  SportItem(name: 'Weightlifting',    emoji: '🏋'),

  // ── E-Sports ────────────────────────────────────────────────────────────
  SportItem(name: 'CS:GO',            emoji: '🎮'),
  SportItem(name: 'Valorant',         emoji: '🔺'),
  SportItem(name: 'League of Legends',emoji: '🎮'),
  SportItem(name: 'Dota 2',           emoji: '🎮'),
  SportItem(name: 'FIFA Esports',     emoji: '⚽'),

  // ── Regional / Traditional ──────────────────────────────────────────────
  SportItem(name: 'Kabaddi',          emoji: '🤼'),
  SportItem(name: 'Kho Kho',          emoji: '🏃'),
];
