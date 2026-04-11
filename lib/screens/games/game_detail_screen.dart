import 'package:flutter/material.dart';

import '../../core/models/game_listing.dart';
import '../../design/colors.dart';
import '../../services/game_listing_service.dart';
import '../../services/user_service.dart';

class GameDetailScreen extends StatefulWidget {
  final GameListing listing;
  const GameDetailScreen({super.key, required this.listing});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  bool _loading = false;

  bool get _hasJoined =>
      GameListingService().hasJoined(widget.listing);

  bool get _isOrganizer =>
      widget.listing.organizerId == (UserService().userId ?? '');

  String get _sportEmoji {
    switch (widget.listing.sport.toLowerCase()) {
      case 'cricket':      return '🏏';
      case 'football':     return '⚽';
      case 'basketball':   return '🏀';
      case 'badminton':    return '🏸';
      case 'tennis':       return '🎾';
      case 'volleyball':   return '🏐';
      case 'table tennis': return '🏓';
      case 'kabaddi':      return '🤼';
      case 'hockey':       return '🏑';
      case 'boxing':       return '🥊';
      default:             return '🏅';
    }
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final h  = dt.hour;
    final m  = dt.minute.toString().padLeft(2, '0');
    final am = h < 12 ? 'AM' : 'PM';
    final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · $hr:$m $am';
  }

  Future<void> _joinOrLeave() async {
    setState(() => _loading = true);
    try {
      if (_hasJoined && !_isOrganizer) {
        await GameListingService().leaveListing(widget.listing);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You left the game.')));
        }
      } else if (!_hasJoined) {
        await GameListingService().joinListing(widget.listing);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.listing.splitCost
                  ? 'Joined! Pay ₹${widget.listing.costPerPlayer.toStringAsFixed(0)} to confirm your spot.'
                  : 'You joined the game!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelGame() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Cancel Game',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will cancel the game for all players. Continue?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (ok == true) {
      await GameListingService().cancelListing(widget.listing.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.listing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.background,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (_isOrganizer)
                IconButton(
                  icon: Icon(Icons.cancel_outlined,
                      color: Colors.red.shade400),
                  onPressed: _cancelGame,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Text(_sportEmoji, style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 8),
                    Text(g.sport,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status + spots ──────────────────────────────────
                  Row(
                    children: [
                      _StatusBadge(listing: g),
                      const Spacer(),
                      Text(
                        '${g.playerIds.length}/${g.maxPlayers} players',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Date & time ─────────────────────────────────────
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'When',
                    value: _formatDate(g.scheduledAt),
                  ),

                  // ── Venue ───────────────────────────────────────────
                  if (g.venueName.isNotEmpty)
                    _InfoRow(
                      icon: Icons.store_outlined,
                      label: 'Venue',
                      value: g.venueName,
                    ),

                  // ── Address ─────────────────────────────────────────
                  if (g.address.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: g.address,
                    ),

                  // ── Organizer ───────────────────────────────────────
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Organizer',
                    value: g.organizerName,
                  ),

                  // ── Note ────────────────────────────────────────────
                  if (g.note != null && g.note!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Note',
                      value: g.note!,
                    ),

                  const SizedBox(height: 20),

                  // ── Cost info ───────────────────────────────────────
                  _CostCard(listing: g),

                  const SizedBox(height: 24),

                  // ── Players progress bar ────────────────────────────
                  Row(
                    children: [
                      const Text('Spots',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${g.spotsLeft} left',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.playerIds.length / g.maxPlayers,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        g.isFull ? Colors.orange : AppColors.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Players list ────────────────────────────────────
                  const Text('Players',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ...g.playerNames.asMap().entries.map((e) =>
                          _PlayerChip(
                            name: e.value,
                            isOrganizer: g.playerIds[e.key] == g.organizerId,
                          )),
                      // Empty spots
                      ...List.generate(
                        g.spotsLeft.clamp(0, 6),
                        (_) => const _EmptySpotChip(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Sticky action button ──────────────────────────────────────────
      bottomNavigationBar: _isOrganizer
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasJoined
                          ? Colors.red.shade700
                          : (g.isFull ? Colors.grey : AppColors.primary),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (_loading || (g.isFull && !_hasJoined))
                        ? null
                        : _joinOrLeave,
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            g.isFull && !_hasJoined
                                ? 'Game Full'
                                : _hasJoined
                                    ? 'Leave Game'
                                    : g.splitCost
                                        ? 'Join · Pay ₹${g.costPerPlayer.toStringAsFixed(0)}'
                                        : 'Join Game',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final GameListing listing;
  const _CostCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    if (!listing.splitCost && listing.totalCost == 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.money_off_outlined, color: Colors.green, size: 20),
            SizedBox(width: 10),
            Text('Free to join — organizer covers cost',
                style: TextStyle(color: Colors.green, fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Cost Split',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('₹${listing.totalCost.toStringAsFixed(0)} total',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Your share',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const Spacer(),
              Text(
                '₹${listing.costPerPlayer.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '₹${listing.totalCost.toStringAsFixed(0)} ÷ ${listing.maxPlayers} players',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final GameListing listing;
  const _StatusBadge({required this.listing});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (listing.status) {
      case GameListingStatus.open:
        color = Colors.green;
        label = 'Open';
        break;
      case GameListingStatus.full:
        color = Colors.orange;
        label = 'Full';
        break;
      case GameListingStatus.cancelled:
        color = Colors.red.shade400;
        label = 'Cancelled';
        break;
      case GameListingStatus.completed:
        color = Colors.grey;
        label = 'Completed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final bool isOrganizer;
  const _PlayerChip({required this.name, required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOrganizer
            ? AppColors.primary.withValues(alpha: 0.2)
            : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOrganizer ? AppColors.primary : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primary.withValues(alpha: 0.3),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Text(name,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (isOrganizer) ...[
            const SizedBox(width: 4),
            const Icon(Icons.star_rounded, color: AppColors.primary, size: 12),
          ],
        ],
      ),
    );
  }
}

class _EmptySpotChip extends StatelessWidget {
  const _EmptySpotChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: const Text('Open spot',
          style: TextStyle(color: Colors.white24, fontSize: 12)),
    );
  }
}
