import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String text;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'postId': postId,
        'userId': userId,
        'userName': userName,
        'userImageUrl': userImageUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: m['postId'] as String? ?? '',
      userId: m['userId'] as String? ?? '',
      userName: m['userName'] as String? ?? 'Anonymous',
      userImageUrl: m['userImageUrl'] as String?,
      text: m['text'] as String? ?? '',
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
