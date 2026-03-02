import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_service.dart';

/// Types of in-app notifications.
enum NotifType { follow, like, comment, matchResult, gameInvite, nearby }

/// A single notification item.
class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id:        doc.id,
      type:      NotifType.values.firstWhere(
                   (t) => t.name == (d['type'] as String? ?? 'like'),
                   orElse: () => NotifType.like),
      title:     d['title']   as String? ?? '',
      body:      d['body']    as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead:    d['isRead']  as bool?   ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'type':      type.name,
    'title':     title,
    'body':      body,
    'isRead':    isRead,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

/// Manages real-time in-app notifications stored under
///   `notifications/{userId}/items`
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  static const _col = 'notifications';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.isRead).length;

  /// Start real-time listener for the current user's notifications.
  void listen() {
    final myId = UserService().userId;
    if (myId == null) return;

    _db
        .collection(_col)
        .doc(myId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snap) {
        _items
          ..clear()
          ..addAll(snap.docs.map(AppNotification.fromFirestore));
        notifyListeners();
      },
      onError: (e) => debugPrint('NotificationService.listen error: $e'),
    );
  }

  /// Push a notification to a specific user's feed.
  static Future<void> send({
    required String toUserId,
    required NotifType type,
    required String title,
    required String body,
  }) async {
    try {
      final db  = FirebaseFirestore.instance;
      final id  = DateTime.now().millisecondsSinceEpoch.toString();
      await db
          .collection(_col)
          .doc(toUserId)
          .collection('items')
          .doc(id)
          .set({
        'type':      type.name,
        'title':     title,
        'body':      body,
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationService.send error: $e');
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    final myId = UserService().userId;
    if (myId == null) return;

    final unread = _items.where((n) => !n.isRead).toList();
    for (final n in unread) {
      n.isRead = true;
    }
    notifyListeners();

    final batch = _db.batch();
    for (final n in unread) {
      batch.update(
        _db.collection(_col).doc(myId).collection('items').doc(n.id),
        {'isRead': true},
      );
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService.markAllRead error: $e');
    }
  }
}
