import 'package:cloud_firestore/cloud_firestore.dart';

/// User role — determines which home shell is shown after login.
enum UserRole { player, merchant }

class UserProfile {
  final String id;
  final int? numericId;   // Unique 6-digit player ID, e.g. 483921
  final String name;
  final String email;
  final String phone;
  final String location;
  final String dob;
  final String bio;
  final String? imageUrl;
  final DateTime updatedAt;
  final bool isPremium;
  final UserRole role;

  // ── Player statistics ─────────────────────────────────────────────────────
  final int tournamentsPlayed;
  final int matchesPlayed;
  final int matchesWon;

  // ── Sport preferences ─────────────────────────────────────────────────────
  final List<String>? favoriteSports;

  const UserProfile({
    required this.id,
    this.numericId,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.dob = '',
    this.bio = '',
    this.imageUrl,
    required this.updatedAt,
    this.isPremium = false,
    this.role = UserRole.player,
    this.tournamentsPlayed = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.favoriteSports,
  });

  // ── Search index helpers ──────────────────────────────────────────────────

  /// Lowercase full name — used for case-insensitive prefix search.
  String get nameLower => name.toLowerCase();

  /// Words in reverse order (lowercase) — lets users search by last name.
  /// "Jeshwanth Kumar" → "kumar jeshwanth"
  String get nameReversed =>
      name.trim().split(RegExp(r'\s+')).reversed.join(' ').toLowerCase();

  /// Individual lowercase words — supports array-contains word lookup.
  List<String> get nameWords => name
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        if (numericId != null) 'numericId': numericId,
        'name': name,
        // ── Search index fields (written on every save) ──────────────────
        'nameLower':    nameLower,
        'nameReversed': nameReversed,
        'nameWords':    nameWords,
        // ────────────────────────────────────────────────────────────────
        'email': email,
        'phone': phone,
        'location': location,
        'dob': dob,
        'bio': bio,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isPremium': isPremium,
        'role': role.name,
        'tournamentsPlayed': tournamentsPlayed,
        'matchesPlayed':     matchesPlayed,
        'matchesWon':        matchesWon,
        'favoriteSports':    favoriteSports,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String? ?? '',
        numericId: (map['numericId'] as num?)?.toInt(),
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        location: map['location'] as String? ?? '',
        dob: map['dob'] as String? ?? '',
        bio: map['bio'] as String? ?? '',
        imageUrl: map['imageUrl'] as String?,
        updatedAt: map['updatedAt'] != null
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        isPremium:          map['isPremium']          as bool? ?? false,
        role: UserRole.values.firstWhere(
          (r) => r.name == (map['role'] as String? ?? 'player'),
          orElse: () => UserRole.player,
        ),
        tournamentsPlayed:  (map['tournamentsPlayed'] as num?)?.toInt() ?? 0,
        matchesPlayed:      (map['matchesPlayed']     as num?)?.toInt() ?? 0,
        matchesWon:         (map['matchesWon']        as num?)?.toInt() ?? 0,
        favoriteSports: (() {
          final raw = map['favoriteSports'];
          if (raw == null) return null;
          if (raw is List) return raw.whereType<String>().toList();
          return null;
        })(),
      );

  factory UserProfile.fromFirestore(DocumentSnapshot doc) =>
      UserProfile.fromMap(doc.data() as Map<String, dynamic>);

  UserProfile copyWith({
    int? numericId,
    String? name,
    String? email,
    String? phone,
    String? location,
    String? dob,
    String? bio,
    String? imageUrl,
    bool? isPremium,
    UserRole? role,
    int? tournamentsPlayed,
    int? matchesPlayed,
    int? matchesWon,
    List<String>? favoriteSports,
  }) =>
      UserProfile(
        id: id,
        numericId: numericId ?? this.numericId,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        dob: dob ?? this.dob,
        bio: bio ?? this.bio,
        imageUrl: imageUrl ?? this.imageUrl,
        updatedAt: DateTime.now(),
        isPremium: isPremium ?? this.isPremium,
        role: role ?? this.role,
        tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
        matchesPlayed:     matchesPlayed     ?? this.matchesPlayed,
        matchesWon:        matchesWon        ?? this.matchesWon,
        favoriteSports: favoriteSports ?? this.favoriteSports,
      );
}
