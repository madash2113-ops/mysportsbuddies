import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/story.dart';
import '../../services/feed_service.dart';
import '../../services/message_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';

/// Full-screen Instagram-style story viewer.
///
/// [storyGroups] — one sub-list per user (each user's stories in order).
/// [initialGroupIndex] — which user's stories to start on.
class StoryViewerScreen extends StatefulWidget {
  final List<List<Story>> storyGroups;
  final int initialGroupIndex;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    this.initialGroupIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageCtrl;
  int _groupIndex = 0;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex;
    _pageCtrl = PageController(initialPage: _groupIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_groupIndex < widget.storyGroups.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _goPrev() {
    if (_groupIndex > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storyGroups.isEmpty) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: Text('No stories', style: TextStyle(color: Colors.white))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.storyGroups.length,
        onPageChanged: (i) => setState(() => _groupIndex = i),
        itemBuilder: (_, i) => _UserStoriesPage(
          stories: widget.storyGroups[i],
          onNext: _goNext,
          onPrev: _goPrev,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

// ── One user's stories (with progress bar) ────────────────────────────────────

class _UserStoriesPage extends StatefulWidget {
  final List<Story> stories;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const _UserStoriesPage({
    required this.stories,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  State<_UserStoriesPage> createState() => _UserStoriesPageState();
}

class _UserStoriesPageState extends State<_UserStoriesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  int _storyIndex = 0;
  bool _sending = false;

  final _replyCtrl = TextEditingController();
  final _replyFocus = FocusNode();

  static const _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      })
      ..forward();
    _markViewed();

    // Pause progress while keyboard is open, resume when closed
    _replyFocus.addListener(() {
      if (_replyFocus.hasFocus) {
        _progressCtrl.stop();
      } else {
        if (_progressCtrl.status != AnimationStatus.completed) {
          _progressCtrl.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final story = _current;
    final myId = UserService().userId;
    if (myId == null || myId == story.userId) return; // can't reply to own story

    setState(() => _sending = true);
    _replyFocus.unfocus();

    try {
      final convId = await MessageService().getOrCreateConversation(
        otherId: story.userId,
        otherName: story.userName,
        otherImageUrl: story.userImageUrl,
      );
      await MessageService().sendMessage(
        convId,
        '↩ Replied to your story: $text',
      );

      // Notify the story owner
      final myName = UserService().profile?.name ?? 'Someone';
      await NotificationService.send(
        toUserId: story.userId,
        type: NotifType.comment,
        title: 'Story Reply',
        body: '$myName replied to your story: $text',
      );

      _replyCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to ${story.userName}'),
            backgroundColor: Colors.white12,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reply'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Story get _current => widget.stories[_storyIndex];

  void _advance() {
    if (_storyIndex < widget.stories.length - 1) {
      setState(() => _storyIndex++);
      _progressCtrl.forward(from: 0);
      _markViewed();
    } else {
      widget.onNext();
    }
  }

  void _retreat() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _progressCtrl.forward(from: 0);
    } else {
      widget.onPrev();
    }
  }

  void _markViewed() {
    final myId = UserService().userId;
    if (myId != null) {
      context.read<FeedService>().markStoryViewed(_current.id, myId);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final story = _current;

    return GestureDetector(
      onTapDown: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 2) {
          _retreat();
        } else {
          _advance();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background / image ─────────────────────────────────────────
          _StoryBackground(story: story),

          // ── Top overlay ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress segments
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: List.generate(widget.stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _ProgressSegment(
                            index: i,
                            currentIndex: _storyIndex,
                            controller: _progressCtrl,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                // User info + close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF2A2A2A),
                        backgroundImage: story.userImageUrl != null
                            ? NetworkImage(story.userImageUrl!)
                            : null,
                        child: story.userImageUrl == null
                            ? Text(
                                story.userName.isNotEmpty
                                    ? story.userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 8)
                                ]),
                          ),
                          Text(
                            _timeAgo(story.createdAt),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close,
                              color: Colors.white, size: 26,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 8)
                              ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Text overlay (above reply bar) ────────────────────────────
          if (story.text != null && story.text!.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  story.text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),

          // ── Reply bar (hidden for own stories) ────────────────────────
          if (story.userId != UserService().userId)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ReplyBar(
                storyOwnerName: story.userName,
                controller: _replyCtrl,
                focusNode: _replyFocus,
                sending: _sending,
                onSend: _sendReply,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Reply bar ─────────────────────────────────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  final String storyOwnerName;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  const _ReplyBar({
    required this.storyOwnerName,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Reply to $storyOwnerName...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sending ? Colors.white24 : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Story background (image or gradient) ──────────────────────────────────────

class _StoryBackground extends StatelessWidget {
  final Story story;
  const _StoryBackground({required this.story});

  @override
  Widget build(BuildContext context) {
    final url = story.imageUrl;
    if (url != null) {
      if (url.startsWith('assets/')) {
        return Image.asset(url, fit: BoxFit.cover,
            errorBuilder: (context, err, st) => _Gradient(userName: story.userName));
      }
      if (!url.startsWith('http')) {
        // Local file path — shown while upload is in progress
        return Image.file(File(url), fit: BoxFit.cover,
            errorBuilder: (context, err, st) => _Gradient(userName: story.userName));
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, p) {
          if (p == null) return child;
          return _Gradient(userName: story.userName);
        },
        errorBuilder: (context, err, st) => _Gradient(userName: story.userName),
      );
    }
    return _Gradient(userName: story.userName);
  }
}

class _Gradient extends StatelessWidget {
  final String userName;
  const _Gradient({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0010), Color(0xFF0D0030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
          style: const TextStyle(
              color: Colors.white30,
              fontSize: 120,
              fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// ── Progress segment ──────────────────────────────────────────────────────────

class _ProgressSegment extends StatelessWidget {
  final int index;
  final int currentIndex;
  final AnimationController controller;

  const _ProgressSegment({
    required this.index,
    required this.currentIndex,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (index < currentIndex) {
      // Fully completed
      return Container(
          height: 2.5,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2)));
    }
    if (index == currentIndex) {
      // Animating
      return AnimatedBuilder(
        animation: controller,
        builder: (context, child) => ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: controller.value,
            backgroundColor: Colors.white38,
            color: Colors.white,
            minHeight: 2.5,
          ),
        ),
      );
    }
    // Not yet reached
    return Container(
        height: 2.5,
        decoration: BoxDecoration(
            color: Colors.white38,
            borderRadius: BorderRadius.circular(2)));
  }
}
