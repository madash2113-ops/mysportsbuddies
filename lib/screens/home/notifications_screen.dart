import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/notification_service.dart';
import '../community/community_feed_screen.dart';
import '../scoreboard/scoreboard_menu_screen.dart';
import '../sports/all_sports_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Attach listener here too in case it wasn't started yet
    NotificationService().listen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationService().markAllRead(),
            child: const Text(
              'Mark all read',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: NotificationService(),
        builder: (context, _) {
          final items = NotificationService().items;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'You\'ll get notified about likes, comments and follows',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(
              color: Colors.white10,
              height: 1,
              indent: 72,
            ),
            itemBuilder: (_, i) => _NotifTile(notif: items[i]),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  const _NotifTile({required this.notif});

  IconData get _icon {
    switch (notif.type) {
      case NotifType.follow:      return Icons.person_add_outlined;
      case NotifType.like:        return Icons.favorite_outline;
      case NotifType.comment:     return Icons.chat_bubble_outline;
      case NotifType.matchResult: return Icons.emoji_events_outlined;
      case NotifType.gameInvite:  return Icons.sports_outlined;
      case NotifType.nearby:      return Icons.location_on_outlined;
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case NotifType.follow:      return Colors.purple;
      case NotifType.like:        return AppColors.primary;
      case NotifType.comment:     return Colors.blue;
      case NotifType.matchResult: return Colors.amber;
      case NotifType.gameInvite:  return Colors.green;
      case NotifType.nearby:      return Colors.teal;
    }
  }

  void _navigate(BuildContext context) {
    NotificationService().markRead(notif.id);
    switch (notif.type) {
      case NotifType.like:
      case NotifType.comment:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CommunityFeedScreen()));
      case NotifType.follow:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CommunityFeedScreen()));
      case NotifType.matchResult:
        Navigator.of(context).push(PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => const ScoreboardMenuScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ));
      case NotifType.gameInvite:
      case NotifType.nearby:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AllSportsScreen()));
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _navigate(context),
      child: Container(
        color: notif.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(notif.createdAt),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
