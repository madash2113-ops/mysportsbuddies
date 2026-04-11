import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.read = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'read': read,
      };

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: m['senderId'] as String? ?? '',
      text: m['text'] as String? ?? '',
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      read: m['read'] as bool? ?? false,
    );
  }
}
