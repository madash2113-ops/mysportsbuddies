import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../register/register_game_screen.dart';
import 'game_detail_screen.dart';

class NearbyGamesScreen extends StatefulWidget {
  final String sport;
  const NearbyGamesScreen({super.key, required this.sport});

  @override
  State<NearbyGamesScreen> createState() => _NearbyGamesScreenState();
}

class _NearbyGamesScreenState extends State<NearbyGamesScreen> {
  List<Game> _games = [];
  Position?  _userPos;
  bool       _locating = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _locating = true);
    _userPos = await LocationService().getCurrentPosition();
    _load();
    setState(() => _locating = false);
  }

  void _load() {
    final raw = GameService().bySport(widget.sport);
    if (_userPos == null) {
      setState(() => _games = raw);
      return;
    }
    final svc = LocationService();
    raw.sort((a, b) {
      final dA = (a.latitude != null && a.longitude != null)
          ? svc.distanceInKm(_userPos!.latitude, _userPos!.longitude,
              a.latitude!, a.longitude!)
          : double.infinity;
      final dB = (b.latitude != null && b.longitude != null)
          ? svc.distanceInKm(_userPos!.latitude, _userPos!.longitude,
              b.latitude!, b.longitude!)
          : double.infinity;
      return dA.compareTo(dB);
    });
    setState(() => _games = raw);
  }

  double? _distanceTo(Game game) {
    if (_userPos == null || game.latitude == null || game.longitude == null) {
      return null;
    }
    return LocationService().distanceInKm(
      _userPos!.latitude, _userPos!.longitude,
      game.latitude!, game.longitude!,
    );
  }

  String _emoji(String sport) {
    const m = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Boxing': '🥊', 'Baseball': '⚾',
      'Hockey': '🏑', 'Running': '🏃', 'Swimming': '🏊',
      'Cycling': '🚴', 'MMA': '🥋', 'Wrestling': '🤼',
      'Kabaddi': '🤸', 'Kho Kho': '🏃', 'CS:GO': '🎮', 'Valorant': '🎮',
    };
    return m[sport] ?? '🏅';
  }

  String _formatDate(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(dt.year, dt.month, dt.day);
    final diff  = date.difference(today).inDays;
    if (diff == 0)  return 'Today';
    if (diff == 1)  return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m  = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  Future<void> _goToRegister() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RegisterGameScreen(sport: widget.sport),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final myId = UserService().userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Text(_emoji(widget.sport), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Nearby ${widget.sport} Games',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_locating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _userPos != null ? Icons.my_location : Icons.location_disabled_outlined,
                color: _userPos != null ? AppColors.primary : Colors.white38,
              ),
              onPressed: _init,
              tooltip: 'Refresh location',
            ),
          TextButton.icon(
            onPressed: _goToRegister,
            icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
            label: const Text('Add',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _games.isEmpty
          ? _EmptyState(sport: widget.sport, onAdd: _goToRegister)
          : Consumer<GameService>(
              builder: (ctx, gameSvc, _) {
                final updatedGames = gameSvc.bySport(widget.sport);
                if (_userPos != null) {
                  final svc = LocationService();
                  updatedGames.sort((a, b) {
                    final dA = (a.latitude != null && a.longitude != null)
                        ? svc.distanceInKm(_userPos!.latitude, _userPos!.longitude,
                            a.latitude!, a.longitude!)
                        : double.infinity;
                    final dB = (b.latitude != null && b.longitude != null)
                        ? svc.distanceInKm(_userPos!.latitude, _userPos!.longitude,
                            b.latitude!, b.longitude!)
                        : double.infinity;
                    return dA.compareTo(dB);
                  });
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.card,
                  onRefresh: () async => _init(),
                  child: Column(
                    children: [
                      if (_userPos != null) _LocationBanner(),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: updatedGames.length,
                          itemBuilder: (_, i) {
                            final game = updatedGames[i];
                            return _GameCard(
                              game: game,
                              distance: _distanceTo(game),
                              formatDate: _formatDate,
                              formatTime: _formatTime,
                              isOwner:
                                  myId != null && game.registeredBy == myId,
                              onEdit: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RegisterGameScreen(
                                      sport: widget.sport,
                                      existingGame: game,
                                    ),
                                  ),
                                );
                                _load();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── Location Banner ───────────────────────────────────────────────────────────

class _LocationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            'Sorted by distance from your location',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String sport;
  final VoidCallback onAdd;
  const _EmptyState({required this.sport, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏟️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSpacing.md),
            Text('No $sport games yet',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            const Text('Be the first to register a game\nin your area!',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm)),
                ),
                onPressed: onAdd,
                child: const Text('Register a Game',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game Card ─────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final Game game;
  final double? distance;
  final bool isOwner;
  final VoidCallback onEdit;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;

  const _GameCard({
    required this.game,
    required this.distance,
    required this.isOwner,
    required this.onEdit,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel  = formatDate(game.dateTime);
    final timeLabel  = formatTime(game.dateTime);
    final isToday    = dateLabel == 'Today';
    final isTomorrow = dateLabel == 'Tomorrow';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameDetailScreen(game: game)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.06),
          width: isToday ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Details ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        game.location,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (distance != null) ...[
                      const SizedBox(width: 4),
                      _DistanceChip(km: distance!),
                    ],
                    const SizedBox(width: 4),
                    _DateChip(
                        label: dateLabel,
                        isToday: isToday,
                        isTomorrow: isTomorrow),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    const Icon(Icons.access_time_outlined,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 5),
                    Text(timeLabel,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                    if (game.maxPlayers != null) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.group_outlined,
                          color: Colors.white38, size: 14),
                      const SizedBox(width: 5),
                      Text('${game.maxPlayers} players',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13)),
                    ],
                  ],
                ),

                if (game.skillLevel != null ||
                    game.format != null ||
                    game.ballType != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (game.skillLevel != null)
                        _InfoChip(
                            label: game.skillLevel!, color: Colors.white24),
                      if (game.format != null)
                        _InfoChip(
                            label: game.format!,
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      if (game.ballType != null)
                        _InfoChip(
                            label: game.ballType!, color: Colors.white12),
                    ],
                  ),
                ],

                if (game.notes != null && game.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    game.notes!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // ── RSVP + Edit Row ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Text('RSVP:',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 8),
                _RsvpButton(
                  label: 'In',
                  icon: Icons.check_circle_outline,
                  status: ParticipationStatus.inGame,
                  current: game.status,
                  activeColor: Colors.green,
                  gameId: game.id,
                ),
                const SizedBox(width: 6),
                _RsvpButton(
                  label: '?',
                  icon: Icons.help_outline,
                  status: ParticipationStatus.tentative,
                  current: game.status,
                  activeColor: Colors.amber,
                  gameId: game.id,
                ),
                const SizedBox(width: 6),
                _RsvpButton(
                  label: 'Out',
                  icon: Icons.cancel_outlined,
                  status: ParticipationStatus.out,
                  current: game.status,
                  activeColor: AppColors.primary,
                  gameId: game.id,
                ),
                const Spacer(),
                if (isOwner)
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white60, size: 14),
                          SizedBox(width: 4),
                          Text('Edit',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),   // end GestureDetector child
    );   // end GestureDetector
  }
}

// ── RSVP Button ───────────────────────────────────────────────────────────────

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final ParticipationStatus status;
  final ParticipationStatus current;
  final Color activeColor;
  final String gameId;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.status,
    required this.current,
    required this.activeColor,
    required this.gameId,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == status;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          context.read<GameService>().updateGameStatus(gameId, status);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.7)
                : Colors.white12,
            width: isActive ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? activeColor : Colors.white38, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white38,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _DistanceChip extends StatelessWidget {
  final double km;
  const _DistanceChip({required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_outlined,
              color: Colors.blueAccent, size: 11),
          const SizedBox(width: 3),
          Text(
            LocationService().formatDistance(km),
            style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool isToday;
  final bool isTomorrow;
  const _DateChip(
      {required this.label, required this.isToday, required this.isTomorrow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.15)
            : isTomorrow
                ? Colors.amber.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.5)
              : isTomorrow
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.white12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isToday
              ? AppColors.primary
              : isTomorrow
                  ? Colors.amber
                  : Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }
}
