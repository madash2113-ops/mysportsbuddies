import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/models/chat_message.dart';
import '../core/models/conversation.dart';
import 'analytics_service.dart';
import 'notification_service.dart';
import 'user_service.dart';

/// Manages direct messages between users.
///
/// Firestore:
///   conversations/{conversationId}               — Conversation doc
///   conversations/{conversationId}/messages/{id} — ChatMessage docs
///
/// Conversation ID = sorted([uid1, uid2]).join('_')
class MessageService extends ChangeNotifier {
  MessageService._();
  static final MessageService _instance = MessageService._();
  factory MessageService() => _instance;

  static const _col = 'conversations';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final List<Conversation> _conversations = [];
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  // ── Listen to my conversation list ───────────────────────────────────────

  void listenToConversations() {
    final myId = UserService().userId;
    if (myId == null) return;

    _db
        .collection(_col)
        .where('participants', arrayContains: myId)
        .snapshots()
        .listen(
      (snap) {
        _conversations
          ..clear()
          ..addAll(snap.docs.map(Conversation.fromFirestore))
          ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        notifyListeners();
      },
      onError: (e) => debugPrint('MessageService.listen error: $e'),
    );
  }

  // ── Get or create a conversation with another user ────────────────────────

  Future<String> getOrCreateConversation({
    required String otherId,
    required String otherName,
    String? otherImageUrl,
  }) async {
    final myId = UserService().userId ?? 'anonymous';
    final myName = UserService().profile?.name ?? 'Sports Buddy';
    final myImageUrl = UserService().profile?.imageUrl;

    final participants = [myId, otherId]..sort();
    final conversationId = participants.join('_');

    final docRef = _db.collection(_col).doc(conversationId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'participants': participants,
        'participantNames': {myId: myName, otherId: otherName},
        'participantImageUrls': {myId: myImageUrl, otherId: otherImageUrl},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unreadCount': 0,
      });
    } else {
      // Ensure names/images are up-to-date
      await docRef.update({
        'participantNames.$myId': myName,
        'participantImageUrls.$myId': myImageUrl,
      });
    }

    return conversationId;
  }

  // ── Send a message ────────────────────────────────────────────────────────

  Future<void> sendMessage(String conversationId, String text) async {
    final myId = UserService().userId ?? 'anonymous';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final msgRef = _db
        .collection(_col)
        .doc(conversationId)
        .collection('messages')
        .doc(msgId);

    final batch = _db.batch();
    batch.set(msgRef, {
      'id': msgId,
      'senderId': myId,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    batch.update(_db.collection(_col).doc(conversationId), {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': myId,
    });

    try {
      await batch.commit();
      AnalyticsService().logEvent(AnalyticsEvents.messageSent);
    } catch (e) {
      debugPrint('MessageService.sendMessage error: $e');
      rethrow;
    }

    // Notify recipient
    try {
      final myId   = UserService().userId ?? 'anonymous';
      final myName = UserService().profile?.name.isNotEmpty == true
          ? UserService().profile!.name
          : 'Someone';
      // Determine the other participant from conversationId (sorted UIDs joined by _)
      final parts = conversationId.split('_');
      final toUserId = parts.firstWhere((p) => p != myId, orElse: () => '');
      if (toUserId.isNotEmpty) {
        await NotificationService.send(
          toUserId: toUserId,
          type: NotifType.message,
          title: 'New message from $myName',
          body: trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed,
          targetId: conversationId,
        );
      }
    } catch (_) {}
  }

  // ── Real-time message stream ──────────────────────────────────────────────

  Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _db
        .collection(_col)
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  // ── Mark conversation as read ─────────────────────────────────────────────

  Future<void> markRead(String conversationId) async {
    try {
      await _db
          .collection(_col)
          .doc(conversationId)
          .update({'unreadCount': 0});
    } catch (_) {}
  }

  // ── Typing indicator ─────────────────────────────────────────────────────

  Future<void> setTyping(String conversationId, bool isTyping) async {
    final myId = UserService().userId;
    if (myId == null) return;
    try {
      await _db.collection(_col).doc(conversationId).update({
        'typing.$myId': isTyping,
      });
    } catch (_) {}
  }

  /// Emits true when [otherId] is currently typing in this conversation.
  Stream<bool> typingStream(String conversationId, String otherId) {
    return _db
        .collection(_col)
        .doc(conversationId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) return false;
      final typing = data['typing'] as Map<String, dynamic>? ?? {};
      return typing[otherId] == true;
    });
  }

  // ── Total unread count (for badge on DM icon) ─────────────────────────────

  int get totalUnread =>
      _conversations.fold(0, (acc, c) => acc + c.unreadCount);
}
