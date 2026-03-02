import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    MessageService().listenToConversations();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = UserService().userId ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search conversations…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                ),
              )
            : Text(
                UserService().profile?.name.isNotEmpty == true
                    ? UserService().profile!.name
                    : 'Direct Messages',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close : Icons.search,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchCtrl.clear();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New message coming soon!'),
                backgroundColor: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
      // Use ListenableBuilder with singleton — no Provider needed
      body: ListenableBuilder(
        listenable: MessageService(),
        builder: (ctx, _) {
          var conversations = MessageService().conversations;

          // Filter by search query
          if (_query.isNotEmpty) {
            conversations = conversations
                .where((c) =>
                    c.otherUserName(myId).toLowerCase().contains(_query) ||
                    c.lastMessage.toLowerCase().contains(_query))
                .toList();
          }

          if (conversations.isEmpty) {
            return _query.isNotEmpty
                ? _NoResults(query: _query)
                : const _EmptyInbox();
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (_, i) {
              final conv = conversations[i];
              final otherId   = conv.otherUserId(myId);
              final otherName = conv.otherUserName(myId);
              final otherImg  = conv.otherUserImageUrl(myId);
              final isUnread  = conv.unreadCount > 0 &&
                  conv.lastMessageSenderId != myId;

              return _ConversationTile(
                name: otherName,
                imageUrl: otherImg,
                lastMessage: conv.lastMessage,
                time: _timeAgo(conv.lastMessageAt),
                isUnread: isUnread,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: conv.id,
                      otherId: otherId,
                      otherName: otherName,
                      otherImageUrl: otherImg,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.near_me_outlined,
                color: Colors.white38, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Messages',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Follow someone and start a conversation with other sports fans.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── No results state ───────────────────────────────────────────────────────────

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: const TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Conversation row ──────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String lastMessage;
  final String time;
  final bool isUnread;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.imageUrl,
    required this.lastMessage,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2A2A2A),
                  backgroundImage:
                      imageUrl != null ? NetworkImage(imageUrl!) : null,
                  child: imageUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        )
                      : null,
                ),
                if (isUnread)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isUnread ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage.isEmpty ? 'Say hi! 👋' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread ? Colors.white70 : Colors.white38,
                      fontSize: 13,
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Time
            Text(
              time,
              style: TextStyle(
                color: isUnread ? AppColors.primary : Colors.white38,
                fontSize: 12,
                fontWeight:
                    isUnread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
