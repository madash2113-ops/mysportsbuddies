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
  final bool isAdmin;
  final String? membershipId;   // set when premium is granted, e.g. "MSB-517913-4821"
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
    this.isAdmin = false,
    this.membershipId,
    this.role = UserRole.player,
    this.tournamentsPlayed = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.favoriteSports,
  });

  // ── Search index helpers ──────────────────────────────────────────────────

  /// Lowercase full name — used for case-insensitive prefix search.
  String get nameLower => name.toLowerCase();

  /// Words in reverse order (lowercase) — lets users search by last name prefix.
  /// "Jeshwanth Vemuri" → "vemuri jeshwanth"
  String get nameReversed =>
      name.trim().split(RegExp(r'\s+')).reversed.join(' ').toLowerCase();

  /// Individual lowercase words — supports exact word array-contains lookup.
  List<String> get nameWords => name
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// Lowercase email — case-insensitive email search.
  String get emailLower => email.toLowerCase();

  /// Numeric ID as a string — enables prefix search on player IDs.
  /// Null when the user has no numericId yet.
  String? get numericIdStr => numericId?.toString();

  /// All word-prefix substrings (min 2 chars) for partial / substring search.
  ///
  /// "Jeshwanth Vemuri" → ["je","jes","jesh",…,"jeshwanth",
  ///                        "ve","vem","vemu","vemur","vemuri"]
  ///
  /// Queried with Firestore arrayContains so "vem" → finds "Jeshwanth Vemuri".
  List<String> get searchTokens {
    final tokens = <String>{};
    for (final word in nameWords) {
      for (int i = 2; i <= word.length; i++) {
        tokens.add(word.substring(0, i));
      }
    }
    return tokens.toList();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (numericId != null) 'numericId': numericId,
        'name': name,
        // ── Search index fields (written on every save) ──────────────────
        'nameLower':    nameLower,
        'nameReversed': nameReversed,
        'nameWords':    nameWords,
        'searchTokens': searchTokens,
        'emailLower':   emailLower,
        if (numericIdStr != null) 'numericIdStr': numericIdStr,
        // ────────────────────────────────────────────────────────────────
        'email': email,
        'phone': phone,
        'location': location,
        'dob': dob,
        'bio': bio,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isPremium': isPremium,
        'isAdmin':   isAdmin,
        if (membershipId != null) 'membershipId': membershipId,
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
        isPremium:    map['isPremium']    as bool?   ?? false,
        isAdmin:      map['isAdmin']      as bool?   ?? false,
        membershipId: map['membershipId'] as String?,
        role: UserRole.values.firstWhere(
          (r) => r.name == (map['role'] as String? ?? 'player'),
          orElse: () => UserRole.player,
        ),
        tournamentsPlayed: (map['tournamentsPlayed'] as num?)?.toInt() ?? 0,
        matchesPlayed:     (map['matchesPlayed']     as num?)?.toInt() ?? 0,
        matchesWon:        (map['matchesWon']        as num?)?.toInt() ?? 0,
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
    bool? isAdmin,
    String? membershipId,
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
        isAdmin:   isAdmin   ?? this.isAdmin,
        membershipId: membershipId ?? this.membershipId,
        role: role ?? this.role,
        tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
        matchesPlayed:     matchesPlayed     ?? this.matchesPlayed,
        matchesWon:        matchesWon        ?? this.matchesWon,
        favoriteSports: favoriteSports ?? this.favoriteSports,
      );
}
