import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../../services/message_service.dart';
import '../../widgets/map_picker_sheet.dart';
import '../community/chat_screen.dart';
import '../community/community_feed_screen.dart';
import '../community/user_profile_screen.dart';
import '../../services/feed_service.dart';
import '../home/scheduled_matches_screen.dart';
import '../register/register_game_screen.dart';

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

  void _shareToFeed(BuildContext context) {
    final buf = StringBuffer();
    buf.writeln('${_sportEmoji(game.sport)} ${game.sport} game at ${game.location}');
    buf.writeln('📅 ${_formatDate(game.dateTime)}  ·  ${_formatTime(game.dateTime)}');
    if (game.maxPlayers != null) buf.writeln('👥 ${game.maxPlayers} players');
    if (game.skillLevel != null) buf.writeln('🎯 ${game.skillLevel}');
    if (game.format != null)     buf.writeln('⚡ ${game.format}');
    buf.write('\nJoin us! 🎉');

    FeedService().createPost(text: buf.toString(), sport: game.sport);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Posted to Feed!'),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View Feed',
          textColor: AppColors.primary,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CommunityFeedScreen(allowBack: true),
            ),
          ),
        ),
      ),
    );
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
              if (isOwner) ...[
                // Delete button
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 18),
                  ),
                ),
                // Edit button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterGameScreen(
                          sport: game.sport, existingGame: game),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined,
                                    color: Colors.white70, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  game.photoUrls.isEmpty
                                      ? 'No photos yet'
                                      : 'Tap to view ${game.photoUrls.length} photo${game.photoUrls.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
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

                  // Location (tap to open maps)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showMapPickerSheet(
                      context,
                      lat: game.latitude,
                      lng: game.longitude,
                      label: game.location,
                    ),
                    child: Row(
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
                                height: 1.3,
                                decoration: TextDecoration.none),
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded,
                            color: AppColors.primary, size: 16),
                      ],
                    ),
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

                  // ── PLAYERS LIST ─────────────────────────────────────────
                  _PlayersListButton(gameId: game.id, sport: game.sport),

                  const SizedBox(height: AppSpacing.xl),

                  // ── ORGANIZER ───────────────────────────────────────────
                  _OrganizerCard(
                    game: game,
                    isOwner: isOwner,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── GROUND PHOTOS ───────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'GROUND PHOTOS',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _uploadPhoto(context),
                          icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 18),
                          label: const Text('Upload Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side:
                                const BorderSide(color: Colors.white24),
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (game.photoUrls.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showImageGallery(context),
                            icon: const Icon(Icons.collections_outlined,
                                size: 18),
                            label: Text(
                                'View (${game.photoUrls.length})'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── CREATE POST ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareToFeed(context),
                      icon: const Icon(Icons.forum_outlined, size: 18),
                      label: const Text('Share to Feed'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── MY SCHEDULE ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduledMatchesScreen(sport: game.sport),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('My Schedule'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5)),
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

  // ── Delete confirmation ───────────────────────────────────────────────────

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Game',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to delete this game? This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              GameService().deleteGame(game.id);
              Navigator.pop(ctx);          // close dialog
              Navigator.pop(context);     // go back to list
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Photo upload ──────────────────────────────────────────────────────────

  Future<void> _uploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    if (!context.mounted) return;

    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
      content: Text('Uploading photo...'),
      duration: Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));

    try {
      await GameService().uploadGamePhoto(game.id, File(picked.path));
      snack.hideCurrentSnackBar();
      snack.showSnackBar(const SnackBar(
        content: Text('Photo uploaded!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      snack.hideCurrentSnackBar();
      snack.showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
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
                  Flexible(
                    child: Text(game.location,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: game.photoUrls.isEmpty
                  ? Center(
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
                            'Upload photos of this ground\nusing the button on the game page.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: game.photoUrls.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          game.photoUrls[i],
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      color: const Color(0xFF1C1C1C),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Players List Section ──────────────────────────────────────────────────────

// ── Players List Button (tappable card with live counts) ──────────────────────

class _PlayersListButton extends StatelessWidget {
  final String gameId;
  final String sport;
  const _PlayersListButton({required this.gameId, required this.sport});

  static String _st(QueryDocumentSnapshot d) =>
      ((d.data() as Map<String, dynamic>?)?['status'] as String?) ?? '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .collection('rsvps')
          .snapshots(),
      builder: (context, snap) {
        final docs  = snap.data?.docs ?? [];
        final going = docs.where((d) => _st(d) == 'inGame').length;
        final maybe = docs.where((d) => _st(d) == 'tentative').length;
        final out   = docs.where((d) => _st(d) == 'out').length;
        final total = going + maybe + out;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayersListScreen(
                  gameId: gameId, sport: sport),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Players List',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      total == 0
                          ? const Text('No responses yet',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12))
                          : Row(
                              children: [
                                _CountBadge(going, Colors.green, '✓ Going'),
                                const SizedBox(width: 8),
                                _CountBadge(maybe, Colors.amber, '? Maybe'),
                                const SizedBox(width: 8),
                                _CountBadge(out, Colors.redAccent, '✕ Out'),
                              ],
                            ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white38, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _CountBadge(this.count, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Players List Screen ───────────────────────────────────────────────────────

class PlayersListScreen extends StatelessWidget {
  final String gameId;
  final String sport;
  const PlayersListScreen(
      {super.key, required this.gameId, required this.sport});

  static String _st(QueryDocumentSnapshot d) =>
      ((d.data() as Map<String, dynamic>?)?['status'] as String?) ?? '';
  static String _nm(QueryDocumentSnapshot d) =>
      ((d.data() as Map<String, dynamic>?)?['name'] as String?) ?? 'Player';
  static String _uid(QueryDocumentSnapshot d) =>
      ((d.data() as Map<String, dynamic>?)?['userId'] as String?) ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '$sport · Players',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(gameId)
            .collection('rsvps')
            .orderBy('updatedAt', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs  = snap.data!.docs;
          final going = docs.where((d) => _st(d) == 'inGame').toList();
          final maybe = docs.where((d) => _st(d) == 'tentative').toList();
          final out   = docs.where((d) => _st(d) == 'out').toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 16),
                  const Text('No responses yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Be the first to mark your status',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary row
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryCol(going.length, Colors.green, 'Going'),
                    _SummaryCol(maybe.length, Colors.amber, 'Maybe'),
                    _SummaryCol(out.length, Colors.redAccent, 'Out'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (going.isNotEmpty) ...[
                _GroupHeader(
                    icon: Icons.check_circle_rounded,
                    label: 'Going',
                    count: going.length,
                    color: Colors.green),
                const SizedBox(height: 8),
                ...going.map((d) => _PlayerTile(
                    userId: _uid(d), name: _nm(d), color: Colors.green)),
                const SizedBox(height: 20),
              ],

              if (maybe.isNotEmpty) ...[
                _GroupHeader(
                    icon: Icons.help_rounded,
                    label: 'Maybe',
                    count: maybe.length,
                    color: Colors.amber),
                const SizedBox(height: 8),
                ...maybe.map((d) => _PlayerTile(
                    userId: _uid(d), name: _nm(d), color: Colors.amber)),
                const SizedBox(height: 20),
              ],

              if (out.isNotEmpty) ...[
                _GroupHeader(
                    icon: Icons.cancel_rounded,
                    label: 'Out',
                    count: out.length,
                    color: Colors.redAccent),
                const SizedBox(height: 8),
                ...out.map((d) => _PlayerTile(
                    userId: _uid(d), name: _nm(d), color: Colors.redAccent)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCol extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _SummaryCol(this.count, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _GroupHeader(
      {required this.icon,
      required this.label,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String userId;
  final String name;
  final Color color;
  const _PlayerTile(
      {required this.userId, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: userId.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: userId),
                ),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (userId.isNotEmpty)
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Organizer Card ────────────────────────────────────────────────────────────

class _OrganizerCard extends StatelessWidget {
  final Game game;
  final bool isOwner;
  const _OrganizerCard({required this.game, required this.isOwner});

  bool get _canSeeContact => isOwner || !game.hideContact;

  Future<void> _openChat(BuildContext context) async {
    final otherId = game.registeredBy;
    if (otherId == null || otherId.isEmpty) return;
    final myId = UserService().userId;
    if (myId == null || myId == otherId) return;

    final name = game.organizerName?.isNotEmpty == true
        ? game.organizerName!
        : 'Sports Buddy';

    final convId = await MessageService().getOrCreateConversation(
      otherId: otherId,
      otherName: name,
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            otherId: otherId,
            otherName: name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name  = game.organizerName?.isNotEmpty == true
        ? game.organizerName!
        : 'Sports Buddy';
    final phone = game.organizerPhone?.isNotEmpty == true
        ? game.organizerPhone
        : null;

    final myId       = UserService().userId;
    final canChat    = !isOwner &&
        game.registeredBy != null &&
        game.registeredBy!.isNotEmpty &&
        game.registeredBy != myId;
    final canCall    = _canSeeContact && phone != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Organizer',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // ── Chat button ──────────────────────────────────────────
              if (canChat) ...[
                _OrganizerActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  color: Colors.blue,
                  onTap: () => _openChat(context),
                ),
                const SizedBox(width: 8),
              ],

              // ── Call button ──────────────────────────────────────────
              if (canCall)
                _OrganizerActionBtn(
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  color: Colors.green,
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                ),

              if (game.hideContact && !isOwner && !canChat)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off_outlined,
                          color: Colors.white38, size: 13),
                      SizedBox(width: 4),
                      Text('Hidden',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
          if (canCall) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(phone,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 13)),
            ),
          ],
          if (isOwner && game.hideContact) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text('Contact is hidden from other players',
                  style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrganizerActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OrganizerActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
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
