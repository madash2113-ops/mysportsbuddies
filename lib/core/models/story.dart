import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String? imageUrl;
  final String? text;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;

  const Story({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    this.imageUrl,
    this.text,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
  });

  bool get isActive => DateTime.now().isBefore(expiresAt);
  bool isViewedBy(String uid) => viewedBy.contains(uid);

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userImageUrl': userImageUrl,
        'imageUrl': imageUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewedBy': viewedBy,
      };

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: m['userId'] as String? ?? '',
      userName: m['userName'] as String? ?? 'User',
      userImageUrl: m['userImageUrl'] as String?,
      imageUrl: m['imageUrl'] as String?,
      text: m['text'] as String?,
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: m['expiresAt'] != null
          ? (m['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 24)),
      viewedBy: List<String>.from(m['viewedBy'] ?? []),
    );
  }
}
