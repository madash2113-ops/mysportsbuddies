import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/comment.dart';
import '../../core/models/feed_post.dart';
import '../../design/colors.dart';
import '../../services/feed_service.dart';
import '../../controllers/profile_controller.dart';
import '../../services/user_service.dart';

class CommentsScreen extends StatefulWidget {
  final FeedPost post;
  const CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await context.read<FeedService>().addComment(widget.post.id, text);
      // Scroll to bottom after short delay
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
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
        title: const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Post preview ────────────────────────────────────────────────
          _PostPreview(post: widget.post),
          const Divider(height: 1, color: Color(0xFF262626)),

          // ── Comments list ───────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream:
                  context.read<FeedService>().commentsStream(widget.post.id),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final comments = snap.data ?? [];

                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No comments yet',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  itemBuilder: (_, i) =>
                      _CommentTile(comment: comments[i], myId: myId, timeAgo: _timeAgo),
                );
              },
            ),
          ),

          // ── Input bar ───────────────────────────────────────────────────
          _CommentInput(
            ctrl: _ctrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Post preview strip ────────────────────────────────────────────────────────

class _PostPreview extends StatelessWidget {
  final FeedPost post;
  const _PostPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage: post.userImageUrl != null
                ? NetworkImage(post.userImageUrl!)
                : null,
            child: post.userImageUrl == null
                ? Text(
                    post.userName.isNotEmpty
                        ? post.userName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: post.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  if (post.text.isNotEmpty) ...[
                    const TextSpan(
                        text: '  ',
                        style: TextStyle(color: Colors.white)),
                    TextSpan(
                      text: post.text,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (post.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: post.imageUrl!.startsWith('assets/')
                  ? Image.asset(post.imageUrl!,
                      width: 44, height: 44, fit: BoxFit.cover)
                  : Image.network(post.imageUrl!,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: const Color(0xFF1A1A1A),
                          )),
            ),
        ],
      ),
    );
  }
}

// ── Single comment tile ───────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String myId;
  final String Function(DateTime) timeAgo;
  const _CommentTile(
      {required this.comment, required this.myId, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final isMe = comment.userId == myId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage: comment.userImageUrl != null
                ? NetworkImage(comment.userImageUrl!)
                : null,
            child: comment.userImageUrl == null
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: comment.userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      const TextSpan(
                          text: '  ',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(
                        text: comment.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeAgo(comment.createdAt),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'You',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comment input bar ─────────────────────────────────────────────────────────

class _CommentInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;
  const _CommentInput(
      {required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFF0A0A0A),
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
        child: Row(
          children: [
            ListenableBuilder(
              listenable: UserService(),
              builder: (context, _) {
                final pc       = context.watch<ProfileController>();
                final imageUrl = UserService().profile?.imageUrl;
                final name     = UserService().profile?.name ?? '';
                final ImageProvider? img = pc.profileImage != null
                    ? FileImage(pc.profileImage!)
                    : (imageUrl != null && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null);
                return CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF2A2A2A),
                  backgroundImage: img,
                  child: img == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : GestureDetector(
                    onTap: onSend,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.send_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
