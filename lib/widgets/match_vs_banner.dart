import 'package:flutter/material.dart';

import '../design/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MatchVsBanner — shared across all match cards in the app
//
// Fixed theme-aligned banner with two captain circles facing each other,
// VS centre, status badge and schedule label.
// ══════════════════════════════════════════════════════════════════════════════

class MatchVsBanner extends StatelessWidget {
  final String    teamA;
  final String    teamB;
  final String?   photoUrlA;
  final String?   photoUrlB;

  /// Match label shown in the centre top row (e.g. "Quarter Final", "Round 1")
  final String    label;

  final bool      isLive;
  final bool      isPlayed;
  final bool      isMyMatch;

  /// Optional sport name shown as a right badge ("T20", "Badminton"…)
  final String?   sport;

  /// Shown below the VS pill when the match is upcoming
  final DateTime? scheduledAt;

  const MatchVsBanner({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.label,
    required this.isLive,
    required this.isPlayed,
    required this.isMyMatch,
    this.photoUrlA,
    this.photoUrlB,
    this.sport,
    this.scheduledAt,
  });

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _scheduleLabel() {
    if (scheduledAt == null) return '';
    final now  = DateTime.now();
    final date = scheduledAt!;
    final time = _fmtTime(date);
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0)  return 'Today • $time';
    if (diff == 1)  return 'Tomorrow • $time';
    if (diff == -1) return 'Yesterday • $time';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${wd[(date.weekday - 1) % 7]} ${date.day} ${mo[date.month - 1]} • $time';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const double bannerH = 140;
    const double circleD = 68;

    return SizedBox(
      height: bannerH,
      width:  double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [

          // ── Linear gradient background ──────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                  colors: [
                    Color(0xFF1F0508), // dark flame-red
                    Color(0xFF0D0D0D), // neutral dark
                    Color(0xFF060C05), // app surface dark
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Live red overlay tint ───────────────────────────────────────────
          if (isLive)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.22),
                      Colors.transparent,
                      AppColors.primary.withValues(alpha: 0.22),
                    ],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                ),
              ),
            ),

          // ── Content ─────────────────────────────────────────────────────────
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [

                  // ── Row 1: status badge | match label | sport badge ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (isLive)
                        _Pill(
                          label: 'LIVE',
                          icon:  Icons.circle,
                          iconColor:   Colors.red,
                          bg:          Colors.red.withValues(alpha: 0.22),
                          border:      Colors.red.withValues(alpha: 0.55),
                          text:        Colors.red,
                        )
                      else if (isPlayed)
                        _Pill(
                          label: 'FT',
                          bg:    Colors.white.withValues(alpha: 0.12),
                          border:Colors.white.withValues(alpha: 0.2),
                          text:  Colors.white70,
                        )
                      else if (isMyMatch)
                        _Pill(
                          label: 'YOUR MATCH',
                          bg:    AppColors.primary.withValues(alpha: 0.2),
                          border:AppColors.primary.withValues(alpha: 0.45),
                          text:  AppColors.primary,
                        )
                      else
                        const SizedBox(width: 4),

                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      if (sport != null && sport!.isNotEmpty)
                        _Pill(
                          label:  sport!,
                          bg:     Colors.white.withValues(alpha: 0.1),
                          border: Colors.white.withValues(alpha: 0.18),
                          text:   Colors.white70,
                        )
                      else
                        const SizedBox(width: 4),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── Row 2: captain circle | VS | captain circle ──────────
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // Team A
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CaptainCircle(
                                name:     teamA,
                                photoUrl: photoUrlA,
                                diameter: circleD,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                teamA,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // VS centre
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.35),
                                      AppColors.primary.withValues(alpha: 0.55),
                                      AppColors.primary.withValues(alpha: 0.35),
                                    ],
                                    begin: Alignment.topLeft,
                                    end:   Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.7),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),

                              // Schedule time for upcoming matches
                              if (!isLive && !isPlayed && scheduledAt != null) ...[
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded,
                                        color: Colors.amber, size: 9),
                                    const SizedBox(width: 3),
                                    Text(
                                      _scheduleLabel(),
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Team B
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CaptainCircle(
                                name:     teamB,
                                photoUrl: photoUrlB,
                                diameter: circleD,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                teamB,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Captain circle ─────────────────────────────────────────────────────────────

class _CaptainCircle extends StatelessWidget {
  final String  name;
  final String? photoUrl;
  final double  diameter;

  const _CaptainCircle({
    required this.name,
    required this.diameter,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final radius  = diameter / 2;

    final Widget inner = photoUrl != null && photoUrl!.isNotEmpty
        ? CircleAvatar(
            radius:               radius,
            backgroundImage:      NetworkImage(photoUrl!),
            backgroundColor:      Colors.white12,
            onBackgroundImageError: (_, _) {},
          )
        : CircleAvatar(
            radius:          radius,
            backgroundColor: const Color(0xFF1C1C1C),
            child: Text(
              initial,
              style: TextStyle(
                color:      Colors.white,
                fontSize:   diameter * 0.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color:       AppColors.primary.withValues(alpha: 0.2),
            blurRadius:  10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: inner,
    );
  }
}

// ── Small label pill ───────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String    label;
  final Color     bg;
  final Color     border;
  final Color     text;
  final IconData? icon;
  final Color?    iconColor;

  const _Pill({
    required this.label,
    required this.bg,
    required this.border,
    required this.text,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor, size: 6),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            color:       text,
            fontSize:    9,
            fontWeight:  FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ]),
    );
  }
}

// ── Shared painter for tournament_detail_screen's _MatchVsBanner ─────────────
// Paints the same linear gradient used by MatchVsBanner above.

class MatchCardBannerPainter extends CustomPainter {
  const MatchCardBannerPainter();

  static const _gradient = LinearGradient(
    begin:  Alignment.topLeft,
    end:    Alignment.bottomRight,
    colors: [
      Color(0xFF1F0508), // dark flame-red
      Color(0xFF0D0D0D), // neutral dark
      Color(0xFF060C05), // app surface dark
    ],
    stops: [0.0, 0.5, 1.0],
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = _gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
