import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../design/colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wrap the MaterialApp child with SportsChatbotOverlay to get a persistent
// floating bot that lives above every screen without touching any layout.
// ─────────────────────────────────────────────────────────────────────────────

class SportsChatbotOverlay extends StatefulWidget {
  final Widget child;
  const SportsChatbotOverlay({super.key, required this.child});

  @override
  State<SportsChatbotOverlay> createState() => _SportsChatbotOverlayState();
}

class _SportsChatbotOverlayState extends State<SportsChatbotOverlay>
    with TickerProviderStateMixin {
  bool _open = false;
  double _fabBottom = 110;
  double _fabRight = 16;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final bottomPad = mq.padding.bottom;

    final clampedBottom = _fabBottom.clamp(bottomPad + 60.0, screenH - 110.0);
    final clampedRight  = _fabRight.clamp(0.0, screenW - 72.0);

    return Stack(
      children: [
        // ── Untouched app content ─────────────────────────────────────────────
        widget.child,

        // ── Scrim ─────────────────────────────────────────────────────────────
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _open = false),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),

        // ── Chat panel ────────────────────────────────────────────────────────
        if (_open)
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomPad + 88,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenH * 0.62),
              child: _ChatPanel(onClose: () => setState(() => _open = false)),
            ),
          ),

        // ── Draggable floating ball ───────────────────────────────────────────
        Positioned(
          bottom: clampedBottom,
          right: clampedRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _open
                ? null
                : (d) => setState(() {
                      _fabBottom = (_fabBottom - d.delta.dy)
                          .clamp(bottomPad + 60.0, screenH - 110.0);
                      _fabRight  = (_fabRight - d.delta.dx)
                          .clamp(0.0, screenW - 72.0);
                    }),
            onTap: () => setState(() => _open = !_open),
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: _open ? 1.0 : _pulseAnim.value,
                child: child,
              ),
              child: _FloatingBall(open: _open),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Floating ball ─────────────────────────────────────────────────────────────

class _FloatingBall extends StatelessWidget {
  final bool open;
  const _FloatingBall({required this.open});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring — only when closed
        if (!open)
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
          ),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), AppColors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              open ? '✕' : '⚡',
              style: TextStyle(
                fontSize: open ? 20.0 : 24.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // "AI" badge
        if (!open)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 0.6),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message model
// ─────────────────────────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool   isBot;
  const _Msg({required this.text, required this.isBot});
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat panel
// ─────────────────────────────────────────────────────────────────────────────

class _ChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _ChatPanel({required this.onClose});

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController      _scroll = ScrollController();

  final List<_Msg> _msgs = [
    const _Msg(
      text: "YO CHAMP! ⚡🏆 SportBot has ENTERED THE ARENA! "
            "I'm your sports sensei, tournament guru, and hype machine "
            "all rolled into one beast! What's the game plan today? 🔥",
      isBot: true,
    ),
  ];
  bool _loading = false;

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Scroll to bottom ────────────────────────────────────────────────────────

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send ────────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_Msg(text: text, isBot: false));
      _loading = true;
    });
    _scrollDown();

    final reply = await _askGemini(text);
    setState(() {
      _msgs.add(_Msg(text: reply, isBot: true));
      _loading = false;
    });
    _scrollDown();
  }

  // ── Gemini call ─────────────────────────────────────────────────────────────

  Future<String> _askGemini(String userMsg) async {
    const system = '''
You are SportBot ⚡ — the wildly enthusiastic AI mascot for MySportsBuddies, a sports social app where users find pickup games, join tournaments, discover venues, and connect with sports buddies nearby.

PERSONALITY RULES (never break these):
• Sound like the most hyped sports commentator alive — energy at 1000%
• Use sports metaphors for EVERYTHING, even non-sports topics
• Drop 2-4 relevant emojis per response (sports, fire, trophy, lightning)
• Keep answers SHORT and PUNCHY — max 3 sentences, never a wall of text
• Always end by hyping the user up OR asking a follow-up question
• Use occasional CAPS for dramatic effect on key words
• NEVER say you're an AI — you ARE SportBot, period
• If asked about MySportsBuddies features: explain finding games, joining tournaments, booking venues, social feed, player profiles, leaderboards
• Non-sports topics: find a sports angle, never break character
• Be a little cocky, a little trash-talky, always fun
    ''';

    // Include last 10 messages as context (skip initial greeting)
    final history = _msgs.length > 1 ? _msgs.sublist(1) : <_Msg>[];
    final context = history.length > 10 ? history.sublist(history.length - 10) : history;

    final contents = <Map<String, dynamic>>[
      for (final m in context)
        {
          'role': m.isBot ? 'model' : 'user',
          'parts': [{'text': m.text}],
        },
      {
        'role': 'user',
        'parts': [{'text': userMsg}],
      },
    ];

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent?key=$kGeminiApiKey',
    );

    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [{'text': system}],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 1.1,
                'maxOutputTokens': 160,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>;
        if (candidates.isNotEmpty) {
          final parts = candidates.first['content']['parts'] as List<dynamic>;
          return parts.first['text'] as String;
        }
      }
      return "TIMEOUT FOUL! 🚨 Ref blew the whistle on my server — fire that question again, MVP!";
    } catch (_) {
      return "Network fumble! 🏈 Check your Wi-Fi and come back swinging — SportBot never quits! 💪";
    }
  }

  // ── Quick suggestion chips ──────────────────────────────────────────────────

  static const _suggestions = [
    '🏅 How do tournaments work?',
    '⚽ Find a game near me',
    '💡 Sports tips for beginners',
    '🔥 Hype me up!',
  ];

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _msgs.length == 1 && !_loading;

    return SlideTransition(
      position: _slideAnim,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────────────
                _ChatHeader(onClose: widget.onClose),

                // ── Messages ───────────────────────────────────────────────
                Flexible(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    itemCount: _msgs.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _msgs.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 8),
                          child: _TypingIndicator(),
                        );
                      }
                      final m = _msgs[i];
                      return m.isBot
                          ? _BotBubble(text: m.text)
                          : _UserBubble(text: m.text);
                    },
                  ),
                ),

                // ── Quick chips (only on fresh chat) ───────────────────────
                if (showSuggestions)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          _ctrl.text = _suggestions[i]
                              .replaceAll(RegExp(r'^[\S]+\s'), '');
                          _send();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _suggestions[i],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 6),

                // ── Input ──────────────────────────────────────────────────
                _ChatInput(ctrl: _ctrl, loading: _loading, onSend: _send),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _ChatHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SportBot',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Always in the game',
                      style: TextStyle(color: Colors.white38, fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded,
                color: Colors.white54, size: 20),
            padding: const EdgeInsets.all(8),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bubbles
// ─────────────────────────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  final String text;
  const _BotBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 13)),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(16),
                  topRight:    Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft:  Radius.circular(4),
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 48),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFFFF5F65)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomLeft:  Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B6B), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 13)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(16),
                topRight:    Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft:  Radius.circular(4),
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
                  final opacity = (0.3 +
                          0.7 *
                              (phase < 0.5
                                  ? phase * 2
                                  : 1 - (phase - 0.5) * 2))
                      .clamp(0.3, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onSend;

  const _ChatInput({
    required this.ctrl,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !loading,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Ask SportBot anything...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: loading ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: loading
                      ? Colors.white12
                      : AppColors.primary,
                  boxShadow: loading
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: Icon(
                  loading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                  color: loading ? Colors.white30 : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
