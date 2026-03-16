import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/chat_message.dart';
import '../../design/colors.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherId;
  final String otherName;
  final String? otherImageUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherId,
    required this.otherName,
    this.otherImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  Timer? _typingTimer;

  String get _myId => UserService().userId ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    MessageService().markRead(widget.conversationId);
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final svc = MessageService();
    svc.setTyping(widget.conversationId, _ctrl.text.isNotEmpty);
    _typingTimer?.cancel();
    if (_ctrl.text.isNotEmpty) {
      // Auto-clear typing after 3s of inactivity
      _typingTimer = Timer(const Duration(seconds: 3), () {
        svc.setTyping(widget.conversationId, false);
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    MessageService().setTyping(widget.conversationId, false);
    _ctrl.removeListener(_onTextChanged);
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
      await context
          .read<MessageService>()
          .sendMessage(widget.conversationId, text);

      // Scroll to bottom
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Send failed: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeLabel(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2A2A2A),
              backgroundImage: widget.otherImageUrl != null
                  ? NetworkImage(widget.otherImageUrl!)
                  : null,
              child: widget.otherImageUrl == null
                  ? Text(
                      widget.otherName.isNotEmpty
                          ? widget.otherName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                const Text(
                  'Active on SportsBuddies',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined,
                color: Colors.white, size: 26),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video calls coming soon!'),
                backgroundColor: Color(0xFF1A1A1A),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline,
                color: Colors.white, size: 24),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: widget.otherId),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages list ───────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: context
                  .read<MessageService>()
                  .messagesStream(widget.conversationId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  );
                }

                final messages = snap.data ?? [];

                if (messages.isEmpty) {
                  return _EmptyChat(otherName: widget.otherName);
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg  = messages[i];
                    final isMe = msg.senderId == _myId;

                    // Show time if first message or gap > 15 min
                    final showTime = i == 0 ||
                        msg.createdAt
                                .difference(messages[i - 1].createdAt)
                                .inMinutes >
                            15;

                    return Column(
                      children: [
                        if (showTime)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              _timeLabel(msg.createdAt),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ),
                        _Bubble(
                          message: msg,
                          isMe: isMe,
                          showAvatar: !isMe &&
                              (i == messages.length - 1 ||
                                  messages[i + 1].senderId == _myId),
                          otherName: widget.otherName,
                          otherImageUrl: widget.otherImageUrl,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Typing indicator ────────────────────────────────────────────
          StreamBuilder<bool>(
            stream: context
                .read<MessageService>()
                .typingStream(widget.conversationId, widget.otherId),
            builder: (_, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF2A2A2A),
                      backgroundImage: widget.otherImageUrl != null
                          ? NetworkImage(widget.otherImageUrl!)
                          : null,
                      child: widget.otherImageUrl == null
                          ? Text(
                              widget.otherName.isNotEmpty
                                  ? widget.otherName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const _TypingDots(),
                  ],
                ),
              );
            },
          ),

          // ── Input bar ───────────────────────────────────────────────────
          _InputBar(ctrl: _ctrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

// ── Empty chat state ──────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String otherName;
  const _EmptyChat({required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF1A1A1A),
            child: Text(
              otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 28,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            otherName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'No messages yet. Say hi! 👋',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final String otherName;
  final String? otherImageUrl;

  const _Bubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.otherName,
    required this.otherImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe)
            showAvatar
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF2A2A2A),
                      backgroundImage: otherImageUrl != null
                          ? NetworkImage(otherImageUrl!)
                          : null,
                      child: otherImageUrl == null
                          ? Text(
                              otherName.isNotEmpty
                                  ? otherName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10),
                            )
                          : null,
                    ),
                  )
                : const SizedBox(width: 34),

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary
                    : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar(
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
            // Emoji / image (stub)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.add_circle_outline,
                  color: Colors.white54, size: 28),
            ),

            // Text input
            Expanded(
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: const TextStyle(
                      color: Colors.white38, fontSize: 15),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white38, size: 22),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sending
                      ? Colors.white12
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Typing dots animation ─────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    ));
    _anims = _ctrls.map((c) =>
        Tween<double>(begin: 0, end: -6).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        )).toList();

    // Stagger each dot by 150ms
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) { _ctrls[i].repeat(reverse: true); }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (context, child) => Container(
            margin: EdgeInsets.only(
              right: i < 2 ? 4 : 0,
              top: _anims[i].value.abs(),
            ),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
        )),
      ),
    );
  }
}
