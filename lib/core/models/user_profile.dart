import 'package:cloud_firestore/cloud_firestore.dart';

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

  // ── Player statistics ─────────────────────────────────────────────────────
  final int tournamentsPlayed;
  final int matchesPlayed;
  final int matchesWon;

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
    this.tournamentsPlayed = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        if (numericId != null) 'numericId': numericId,
        'name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'dob': dob,
        'bio': bio,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isPremium': isPremium,
        'tournamentsPlayed': tournamentsPlayed,
        'matchesPlayed':     matchesPlayed,
        'matchesWon':        matchesWon,
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
        tournamentsPlayed:  (map['tournamentsPlayed'] as num?)?.toInt() ?? 0,
        matchesPlayed:      (map['matchesPlayed']     as num?)?.toInt() ?? 0,
        matchesWon:         (map['matchesWon']        as num?)?.toInt() ?? 0,
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
    int? tournamentsPlayed,
    int? matchesPlayed,
    int? matchesWon,
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
        tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
        matchesPlayed:     matchesPlayed     ?? this.matchesPlayed,
        matchesWon:        matchesWon        ?? this.matchesWon,
      );
}
