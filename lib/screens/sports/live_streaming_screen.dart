import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';

/// Live Streaming hub — lets users browse upcoming/live streams
/// and start their own stream (stub UI, real streaming can be added
/// via Agora / LiveKit / Mux in a future sprint).
class LiveStreamingScreen extends StatefulWidget {
  const LiveStreamingScreen({super.key});

  @override
  State<LiveStreamingScreen> createState() => _LiveStreamingScreenState();
}

class _LiveStreamingScreenState extends State<LiveStreamingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  // Stub stream data
  static const _streams = [
    _StreamData(
      title: 'Cricket Practice — IPL Nets',
      host: 'Rahul K.',
      sport: 'Cricket',
      viewers: 142,
      isLive: true,
      emoji: '🏏',
      color: Color(0xFFD32F2F),
    ),
    _StreamData(
      title: '5-a-side Football Match',
      host: 'Sports Hub',
      sport: 'Football',
      viewers: 87,
      isLive: true,
      emoji: '⚽',
      color: Color(0xFF1976D2),
    ),
    _StreamData(
      title: 'Badminton Tournament Finals',
      host: 'City Badminton Club',
      sport: 'Badminton',
      viewers: 0,
      isLive: false,
      emoji: '🏸',
      color: Color(0xFF388E3C),
      scheduledAt: 'Tomorrow, 6:00 PM',
    ),
    _StreamData(
      title: 'Basketball — 3×3 Street Game',
      host: 'StreetBall India',
      sport: 'Basketball',
      viewers: 0,
      isLive: false,
      emoji: '🏀',
      color: Color(0xFFE65100),
      scheduledAt: 'Sat, 5:00 PM',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _goLive() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _GoLiveSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live     = _streams.where((s) => s.isLive).toList();
    final upcoming = _streams.where((s) => !s.isLive).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Live Streaming',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Opacity(
              opacity: 0.5 + _pulseCtrl.value * 0.5,
              child: child,
            ),
            child: TextButton.icon(
              onPressed: _goLive,
              icon: const Icon(Icons.circle, color: AppColors.primary, size: 10),
              label: const Text(
                'Go Live',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Go Live banner ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _goLive,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B0000), Color(0xFFD32F2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(Icons.videocam_outlined,
                        size: 130,
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) => Opacity(
                            opacity: 0.6 + _pulseCtrl.value * 0.4,
                            child: child,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.white, size: 8),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Start streaming your\nsports moments',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Live now ───────────────────────────────────────────────────────
          if (live.isNotEmpty) ...[
            _SectionHeader(
              label: 'Live Now',
              badge: '${live.length}',
              badgeColor: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...live.map((s) => _StreamCard(stream: s, pulseCtrl: _pulseCtrl)),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Upcoming ───────────────────────────────────────────────────────
          if (upcoming.isNotEmpty) ...[
            const _SectionHeader(label: 'Upcoming'),
            const SizedBox(height: AppSpacing.sm),
            ...upcoming.map((s) => _StreamCard(stream: s)),
          ],
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? badge;
  final Color? badgeColor;
  const _SectionHeader({required this.label, this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.white38).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: (badgeColor ?? Colors.white38).withValues(alpha: 0.5)),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                  color: badgeColor ?? Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Stream card ────────────────────────────────────────────────────────────

class _StreamCard extends StatelessWidget {
  final _StreamData stream;
  final AnimationController? pulseCtrl;
  const _StreamCard({required this.stream, this.pulseCtrl});

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _StreamPlayerScreen(stream: stream)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: stream.isLive
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 90,
              height: 72,
              decoration: BoxDecoration(
                color: stream.color.withValues(alpha: 0.2),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(13)),
              ),
              child: Center(
                child: Text(stream.emoji,
                    style: const TextStyle(fontSize: 34)),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stream.host,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            // Status
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: stream.isLive
                  ? _LiveBadge(pulseCtrl: pulseCtrl)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.schedule_outlined,
                            color: Colors.white38, size: 14),
                        const SizedBox(height: 2),
                        Text(
                          stream.scheduledAt ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                          textAlign: TextAlign.end,
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

class _LiveBadge extends StatelessWidget {
  final AnimationController? pulseCtrl;
  const _LiveBadge({this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
          color: AppColors.primary, shape: BoxShape.circle),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pulseCtrl != null
            ? AnimatedBuilder(
                animation: pulseCtrl!,
                builder: (_, child) =>
                    Opacity(opacity: 0.5 + pulseCtrl!.value * 0.5, child: child),
                child: dot,
              )
            : dot,
        const SizedBox(width: 4),
        const Text(
          'LIVE',
          style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1),
        ),
      ],
    );
  }
}

// ── Stream data model ──────────────────────────────────────────────────────

class _StreamData {
  final String title, host, sport, emoji;
  final int viewers;
  final bool isLive;
  final Color color;
  final String? scheduledAt;
  const _StreamData({
    required this.title,
    required this.host,
    required this.sport,
    required this.viewers,
    required this.isLive,
    required this.emoji,
    required this.color,
    this.scheduledAt,
  });
}

// ── Simple stream player screen ────────────────────────────────────────────

class _StreamPlayerScreen extends StatelessWidget {
  final _StreamData stream;
  const _StreamPlayerScreen({required this.stream});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Player area
            Container(
              height: 240,
              color: stream.color.withValues(alpha: 0.15),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(stream.emoji,
                            style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 12),
                        if (!stream.isLive)
                          const Text(
                            'Stream starting soon…',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  // Back button
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  // Live badge
                  if (stream.isLive)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '● LIVE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  // Viewers
                  if (stream.isLive && stream.viewers > 0)
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye_outlined,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${stream.viewers} watching',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hosted by ${stream.host}',
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      stream.sport,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Coming soon
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.construction_outlined,
                        color: Colors.white38, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Live streaming integration coming soon!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'We\'re integrating Agora / LiveKit for real-time video.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Go Live bottom sheet ───────────────────────────────────────────────────

class _GoLiveSheet extends StatefulWidget {
  const _GoLiveSheet();

  @override
  State<_GoLiveSheet> createState() => _GoLiveSheetState();
}

class _GoLiveSheetState extends State<_GoLiveSheet> {
  final _titleCtrl = TextEditingController();
  String _sport = 'Cricket';

  static const _sports = [
    'Cricket', 'Football', 'Throwball', 'Handball',
    'Basketball', 'Badminton', 'Tennis', 'Volleyball',
    'Kabaddi', 'Hockey', 'Boxing',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Start a Live Stream',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          // Title field
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Stream title (e.g. "Cricket practice")',
              hintStyle:
                  const TextStyle(color: Colors.white38, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Sport picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _sport,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A1A),
              underline: const SizedBox.shrink(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: _sports
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _sport = v ?? _sport),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Live streaming integration coming soon! 🎥'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              icon: const Icon(Icons.videocam_outlined, size: 20),
              label: const Text(
                'Go Live',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
