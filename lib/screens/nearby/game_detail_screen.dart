import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../register/register_game_screen.dart';
import '../community/create_post_sheet.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  // Sport → gradient colors for the placeholder banner
  static const Map<String, List<Color>> _sportGradients = {
    'Cricket':       [Color(0xFF1B5E20), Color(0xFF388E3C)],
    'Football':      [Color(0xFF0D47A1), Color(0xFF1976D2)],
    'Basketball':    [Color(0xFFBF360C), Color(0xFFE64A19)],
    'Badminton':     [Color(0xFF4A148C), Color(0xFF7B1FA2)],
    'Tennis':        [Color(0xFF006064), Color(0xFF00838F)],
    'Volleyball':    [Color(0xFF880E4F), Color(0xFFC2185B)],
    'Table Tennis':  [Color(0xFF01579B), Color(0xFF0288D1)],
    'Hockey':        [Color(0xFF1A237E), Color(0xFF3949AB)],
    'Baseball':      [Color(0xFF4E342E), Color(0xFF6D4C41)],
    'Boxing':        [Color(0xFFB71C1C), Color(0xFFE53935)],
  };

  List<Color> get _gradient {
    final colors = _sportGradients[game.sport];
    if (colors != null) return colors;
    return [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)];
  }

  String _sportEmoji(String sport) {
    const m = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Boxing': '🥊', 'Baseball': '⚾',
      'Hockey': '🏑', 'Running': '🏃', 'Swimming': '🏊',
      'Cycling': '🚴', 'MMA': '🥋', 'Wrestling': '🤼',
    };
    return m[sport] ?? '🏅';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = UserService().userId;
    final isOwner = myId != null && game.registeredBy == myId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Banner ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
            ),
            actions: [
              if (isOwner)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterGameScreen(
                          sport: game.sport, existingGame: game),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () => _showImageGallery(context),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Sport emoji centered
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sportEmoji(game.sport),
                            style: const TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_library_outlined,
                                    color: Colors.white70, size: 13),
                                SizedBox(width: 4),
                                Text('Tap to view photos',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom fade
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.background,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Detail Body ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sport badge + location
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          game.sport,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Your game',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          game.location,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.3),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Date & time card
                  _DetailCard(children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(game.dateTime),
                    ),
                    _DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: _formatTime(game.dateTime),
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.md),

                  // Game info card
                  if (game.maxPlayers != null ||
                      game.skillLevel != null ||
                      game.format != null ||
                      game.ballType != null)
                    _DetailCard(children: [
                      if (game.maxPlayers != null)
                        _DetailRow(
                          icon: Icons.group_outlined,
                          label: 'Players',
                          value: '${game.maxPlayers} per side',
                        ),
                      if (game.skillLevel != null)
                        _DetailRow(
                          icon: Icons.bar_chart_outlined,
                          label: 'Skill Level',
                          value: game.skillLevel!,
                        ),
                      if (game.format != null)
                        _DetailRow(
                          icon: Icons.sports_cricket_outlined,
                          label: 'Format',
                          value: game.format!,
                        ),
                      if (game.ballType != null)
                        _DetailRow(
                          icon: Icons.circle_outlined,
                          label: 'Ball Type',
                          value: game.ballType!,
                        ),
                    ]),

                  if (game.notes != null && game.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notes',
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(
                            game.notes!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // ── MY STATUS (RSVP) ────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.how_to_reg_outlined,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'MY STATUS',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Consumer<GameService>(
                    builder: (ctx, gameSvc, _) {
                      final live = gameSvc.bySport(game.sport)
                              .where((g) => g.id == game.id)
                              .firstOrNull ??
                          game;
                      return Row(
                        children: [
                          _RsvpBtn(
                            label: '✓  Going',
                            status: ParticipationStatus.inGame,
                            current: live.status,
                            activeColor: Colors.green,
                            gameId: game.id,
                          ),
                          const SizedBox(width: 10),
                          _RsvpBtn(
                            label: '?  Maybe',
                            status: ParticipationStatus.tentative,
                            current: live.status,
                            activeColor: Colors.amber,
                            gameId: game.id,
                          ),
                          const SizedBox(width: 10),
                          _RsvpBtn(
                            label: '✕  Out',
                            status: ParticipationStatus.out,
                            current: live.status,
                            activeColor: AppColors.primary,
                            gameId: game.id,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── ORGANIZER ───────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A0000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Organizer',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 2),
                              Text('Sports Buddy',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text('Contact',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── CREATE POST ─────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.photo_camera_outlined,
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'CREATE POST',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const CreatePostSheet(),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          size: 18),
                      label: const Text('Share this game with the community'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageGallery(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Ground Photos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(game.location,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Colors.white24, size: 56),
                    const SizedBox(height: 12),
                    const Text('No photos yet',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                      'Photos of this ground will\nappear here once added.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          height: 1.5),
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

// ── Detail Card ───────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: children
            .expand((w) => [
                  w,
                  if (w != children.last)
                    const Divider(
                        height: 1, color: Colors.white10, thickness: 0.5,
                        indent: 44),
                ])
            .toList(),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── RSVP Button ───────────────────────────────────────────────────────────────

class _RsvpBtn extends StatelessWidget {
  final String label;
  final ParticipationStatus status;
  final ParticipationStatus current;
  final Color activeColor;
  final String gameId;

  const _RsvpBtn({
    required this.label,
    required this.status,
    required this.current,
    required this.activeColor,
    required this.gameId,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isActive) {
            context.read<GameService>().updateGameStatus(gameId, status);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.7)
                  : Colors.white12,
              width: isActive ? 1.5 : 0.8,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white38,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
