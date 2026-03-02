import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String?> participantImageUrls;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageSenderId;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantImageUrls,
    this.lastMessage = '',
    required this.lastMessageAt,
    this.lastMessageSenderId = '',
    this.unreadCount = 0,
  });

  String otherUserId(String myId) =>
      participants.firstWhere((p) => p != myId, orElse: () => '');

  String otherUserName(String myId) =>
      participantNames[otherUserId(myId)] ?? 'User';

  String? otherUserImageUrl(String myId) =>
      participantImageUrls[otherUserId(myId)];

  Map<String, dynamic> toMap() => {
        'participants': participants,
        'participantNames': participantNames,
        'participantImageUrls': participantImageUrls,
        'lastMessage': lastMessage,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'lastMessageSenderId': lastMessageSenderId,
        'unreadCount': unreadCount,
      };

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(m['participants'] ?? []),
      participantNames: Map<String, String>.from(m['participantNames'] ?? {}),
      participantImageUrls: (m['participantImageUrls'] as Map?)
              ?.map((k, v) => MapEntry(k as String, v as String?)) ??
          {},
      lastMessage: m['lastMessage'] as String? ?? '',
      lastMessageAt: m['lastMessageAt'] != null
          ? (m['lastMessageAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastMessageSenderId: m['lastMessageSenderId'] as String? ?? '',
      unreadCount: (m['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
