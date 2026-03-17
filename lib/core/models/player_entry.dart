import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';

/// Universal player selection result used across the entire app.
///
/// A [PlayerEntry] is either:
///  - **registered** — linked to a Firestore user doc (isRegistered = true)
///  - **manual**     — name-only, no account required (isRegistered = false)
///
/// Every screen that selects players stores [List<PlayerEntry>], never raw strings.
class PlayerEntry {
  /// Stable local ID. For registered players this equals the Firestore userId.
  /// For manual entries it is a timestamp-based unique string.
  final String entryId;

  /// Whether this player has a Firestore account.
  final bool isRegistered;

  /// Display name — always present.
  final String displayName;

  // ── Registered-only fields (null for manual entries) ─────────────────────
  final String? userId;
  final int?    numericId;   // 6-digit player ID
  final String? email;
  final String? phone;
  final String? imageUrl;

  const PlayerEntry({
    required this.entryId,
    required this.isRegistered,
    required this.displayName,
    this.userId,
    this.numericId,
    this.email,
    this.phone,
    this.imageUrl,
  });

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Creates a manual entry from a typed name — no DB record required.
  factory PlayerEntry.manual(String name) => PlayerEntry(
        entryId:      'manual_${DateTime.now().millisecondsSinceEpoch}',
        isRegistered: false,
        displayName:  name.trim(),
      );

  /// Creates a registered entry from a Firestore [UserProfile].
  factory PlayerEntry.fromProfile(UserProfile p) => PlayerEntry(
        entryId:      p.id,
        isRegistered: true,
        displayName:  p.name,
        userId:       p.id,
        numericId:    p.numericId,
        email:        p.email.isNotEmpty    ? p.email    : null,
        phone:        p.phone.isNotEmpty    ? p.phone    : null,
        imageUrl:     p.imageUrl,
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'entryId':      entryId,
        'isRegistered': isRegistered,
        'displayName':  displayName,
        if (userId    != null) 'userId':    userId,
        if (numericId != null) 'numericId': numericId,
        if (email     != null) 'email':     email,
        if (phone     != null) 'phone':     phone,
        if (imageUrl  != null) 'imageUrl':  imageUrl,
      };

  factory PlayerEntry.fromMap(Map<String, dynamic> m) => PlayerEntry(
        entryId:      m['entryId']      as String? ?? '',
        isRegistered: m['isRegistered'] as bool?   ?? false,
        displayName:  m['displayName']  as String? ?? '',
        userId:    m['userId']    as String?,
        numericId: (m['numericId'] as num?)?.toInt(),
        email:     m['email']     as String?,
        phone:     m['phone']     as String?,
        imageUrl:  m['imageUrl']  as String?,
      );

  factory PlayerEntry.fromFirestore(DocumentSnapshot doc) =>
      PlayerEntry.fromMap(doc.data() as Map<String, dynamic>);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// One-line subtitle for distinguishing players with the same name.
  /// Shows numericId and last-4 of phone where available.
  String get subtitle {
    final parts = <String>[];
    if (numericId != null)              parts.add('#$numericId');
    if (phone != null && phone!.length >= 4) {
      parts.add('···${phone!.substring(phone!.length - 4)}');
    }
    if (email != null && email!.isNotEmpty) parts.add(email!);
    return parts.join('  ·  ');
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerEntry && other.entryId == entryId;

  @override
  int get hashCode => entryId.hashCode;
}
