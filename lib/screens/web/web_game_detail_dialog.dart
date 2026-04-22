import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/player_entry.dart';
import '../../core/search/player_search_service.dart';
import '../../core/models/game_listing.dart';
import '../../services/game_listing_service.dart';
import '../../services/user_service.dart';
import 'web_avatar.dart';

const _bg = Color(0xFF080808);
const _card = Color(0xFF111111);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _green = Color(0xFF30D158);
const _orange = Color(0xFFFF9F0A);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

Future<void> openWebGameDetail(
  BuildContext context, {
  required GameListing listing,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .68),
    builder: (_) => WebGameDetailDialog(listing: listing),
  );
}

IconData _sportIcon(String sport) {
  const icons = {
    'Cricket': Icons.sports_cricket_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Basketball': Icons.sports_basketball_rounded,
    'Badminton': Icons.sports_tennis_rounded,
    'Tennis': Icons.sports_tennis_rounded,
    'Volleyball': Icons.sports_volleyball_rounded,
    'Hockey': Icons.sports_hockey_rounded,
    'Kabaddi': Icons.sports_kabaddi_rounded,
    'Boxing': Icons.sports_mma_rounded,
    'Table Tennis': Icons.sports_tennis_rounded,
    'Swimming': Icons.pool_rounded,
    'Rugby': Icons.sports_rugby_rounded,
  };
  return icons[sport] ?? Icons.sports_rounded;
}

Color _sportAccent(String sport) {
  const colors = {
    'Cricket': Color(0xFF4CAF50),
    'Football': Color(0xFF42A5F5),
    'Basketball': Color(0xFFFF9800),
    'Badminton': Color(0xFF29B6F6),
    'Tennis': Color(0xFFCDDC39),
    'Volleyball': Color(0xFF7E57C2),
    'Hockey': Color(0xFFFF7043),
    'Kabaddi': Color(0xFFEC407A),
    'Boxing': Color(0xFFEF5350),
    'Table Tennis': Color(0xFF26C6DA),
  };
  return colors[sport] ?? _red;
}

String _fmtDate(DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
}

String _fmtTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  return '$h:$min ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

class WebGameDetailDialog extends StatefulWidget {
  final GameListing listing;
  const WebGameDetailDialog({super.key, required this.listing});

  @override
  State<WebGameDetailDialog> createState() => _WebGameDetailDialogState();
}

class _WebGameDetailDialogState extends State<WebGameDetailDialog> {
  bool _loading = false;

  GameListing get _listing {
    final current = GameListingService().openGames.where(
      (g) => g.id == widget.listing.id,
    );
    return current.isEmpty ? widget.listing : current.first;
  }

  bool get _hasJoined => GameListingService().hasJoined(_listing);
  bool get _isOrganizer => _listing.organizerId == (UserService().userId ?? '');

  Future<void> _joinOrLeave() async {
    setState(() => _loading = true);
    try {
      if (_hasJoined && !_isOrganizer) {
        await GameListingService().leaveListing(_listing);
      } else if (!_hasJoined) {
        await GameListingService().joinListing(_listing);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddPlayers() async {
    final added = await showDialog<List<PlayerEntry>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .68),
      builder: (_) => _AddPlayersDialog(listing: _listing),
    );
    if (added == null || added.isEmpty) return;
    setState(() => _loading = true);
    try {
      await GameListingService().addPlayers(
        _listing,
        added,
        actorName: UserService().profile?.name ?? 'Player',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text(
          'Cancel Game',
          style: _t(size: 18, weight: FontWeight.w800),
        ),
        content: Text(
          'This will remove the game from Nearby Games for everyone.',
          style: _t(color: _m1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep Game', style: _t(color: _m1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cancel Game', style: _t(color: _red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await GameListingService().cancelListing(_listing.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _listing;
    final accent = _sportAccent(g.sport);
    final progress = g.maxPlayers <= 0
        ? 0.0
        : g.playerIds.length / g.maxPlayers;
    final actionLabel = _isOrganizer
        ? 'Organizer'
        : _hasJoined
        ? 'Leave Game'
        : g.isFull
        ? 'Game Full'
        : 'Join Game';

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: .20), _card],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                border: Border(bottom: BorderSide(color: _border, width: .8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: .35)),
                    ),
                    child: Icon(_sportIcon(g.sport), color: accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Pill(
                              icon: Icons.circle,
                              label: g.status.name.toUpperCase(),
                              color: g.isFull ? _orange : _green,
                            ),
                            const SizedBox(width: 8),
                            _Pill(
                              icon: Icons.groups_rounded,
                              label: '${g.playerIds.length}/${g.maxPlayers}',
                              color: _m1,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          g.venueName.isNotEmpty
                              ? g.venueName
                              : '${g.sport} Game',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 24, weight: FontWeight.w900),
                        ),
                        Text(
                          g.sport,
                          style: _t(
                            size: 13,
                            color: accent,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isOrganizer)
                    IconButton(
                      tooltip: 'Cancel game',
                      onPressed: _loading ? null : _cancel,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: _red,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _m1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _InfoGrid(game: g),
                          const SizedBox(height: 14),
                          _CostCard(game: g),
                          if (g.note?.isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            _Panel(
                              title: 'Notes',
                              child: Text(g.note!, style: _t(color: _m1)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _Panel(
                        title: 'Players',
                        trailing: Text(
                          '${g.spotsLeft} spots left',
                          style: _t(size: 12, color: _m1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0, 1),
                                minHeight: 8,
                                backgroundColor: Colors.white.withValues(
                                  alpha: .08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (int i = 0; i < g.maxPlayers; i++)
                                  _PlayerSlot(
                                    name: i < g.playerNames.length
                                        ? g.playerNames[i]
                                        : null,
                                    organizer: i == 0,
                                    onTap: i >= g.playerNames.length
                                        ? _openAddPlayers
                                        : null,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border, width: .8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      g.address.isNotEmpty ? g.address : 'Address not provided',
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 12, color: _m1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _ActionButton(
                    label: _loading ? 'Please wait...' : actionLabel,
                    disabled: _isOrganizer || g.isFull || _loading,
                    danger: _hasJoined && !_isOrganizer,
                    onTap: _joinOrLeave,
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

class _InfoGrid extends StatelessWidget {
  final GameListing game;
  const _InfoGrid({required this.game});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Game Details',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _fmtDate(game.scheduledAt),
          ),
          _InfoTile(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: _fmtTime(game.scheduledAt),
          ),
          _InfoTile(
            icon: Icons.person_outline_rounded,
            label: 'Organizer',
            value: game.organizerName,
          ),
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: game.address.isNotEmpty ? game.address : game.venueName,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Row(
        children: [
          Icon(icon, color: _red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _t(size: 11, color: _m1)),
                Text(
                  value.isEmpty ? '-' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(size: 13, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final GameListing game;
  const _CostCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final label = game.splitCost
        ? 'Split cost: ${game.costPerPlayer.toStringAsFixed(0)} per player'
        : 'Free to join - organizer covers cost';
    return _Panel(
      title: 'Cost',
      child: Row(
        children: [
          Icon(
            game.splitCost ? Icons.payments_outlined : Icons.money_off_rounded,
            color: _green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: _t(color: _green, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Panel({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: _t(size: 14, weight: FontWeight.w800)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 5),
          Text(
            label,
            style: _t(size: 10, weight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final String? name;
  final bool organizer;
  final VoidCallback? onTap;
  const _PlayerSlot({this.name, required this.organizer, this.onTap});

  @override
  Widget build(BuildContext context) {
    final filled = name?.isNotEmpty == true;
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: filled
                ? _red.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: filled
                  ? _red.withValues(alpha: .42)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: filled ? _red.withValues(alpha: .55) : _m2,
                child: Text(
                  filled ? name![0].toUpperCase() : '+',
                  style: _t(size: 10, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                filled
                    ? organizer
                          ? '${name!} - Organizer'
                          : name!
                    : 'Open spot',
                style: _t(size: 12, color: filled ? _tx : _m1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPlayersDialog extends StatefulWidget {
  final GameListing listing;
  const _AddPlayersDialog({required this.listing});

  @override
  State<_AddPlayersDialog> createState() => _AddPlayersDialogState();
}

class _AddPlayersDialogState extends State<_AddPlayersDialog> {
  final _searchCtrl = TextEditingController();
  List<PlayerSearchResult> _results = [];
  final List<PlayerEntry> _selected = [];
  bool _loading = false;

  int get _spotsLeft =>
      widget.listing.maxPlayers - widget.listing.playerIds.length;

  @override
  void initState() {
    super.initState();
    final profile = UserService().profile;
    final uid = UserService().userId;
    if (profile != null &&
        uid != null &&
        !widget.listing.playerIds.contains(uid)) {
      _selected.add(PlayerEntry.fromProfile(profile));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final results = await PlayerSearchService().search(
      value,
      includeManual: false,
    );
    if (!mounted) return;
    setState(() {
      _results = results
          .where((r) => !_alreadyInGameOrSelected(r.entry))
          .take(8)
          .toList();
      _loading = false;
    });
  }

  bool _alreadyInGameOrSelected(PlayerEntry entry) {
    final id = entry.userId ?? entry.entryId;
    return widget.listing.playerIds.contains(id) ||
        _selected.any((p) => (p.userId ?? p.entryId) == id);
  }

  void _toggle(PlayerEntry entry) {
    final id = entry.userId ?? entry.entryId;
    setState(() {
      final index = _selected.indexWhere((p) => (p.userId ?? p.entryId) == id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else if (_selected.length < _spotsLeft) {
        _selected.add(entry);
      }
      _results.removeWhere((r) => (r.entry.userId ?? r.entry.entryId) == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: SizedBox(
        width: 560,
        height: 610,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Add Players',
                    style: _t(size: 18, weight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${_selected.length}/$_spotsLeft selected',
                    style: _t(size: 12, color: _m1),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _m1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _search,
                style: _t(size: 13),
                decoration: InputDecoration(
                  hintText: 'Search registered players by name...',
                  hintStyle: _t(size: 13, color: _m1),
                  prefixIcon: const Icon(Icons.search_rounded, color: _m1),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _red),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_selected.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final player in _selected)
                      _SelectedPlayerChip(
                        player: player,
                        onRemove: () => _toggle(player),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Container(height: .8, color: _border),
              Expanded(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(color: _red),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount:
                            _results.length +
                            (_searchCtrl.text.trim().length >= 2 &&
                                    _results.isEmpty &&
                                    !_loading
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index >= _results.length) {
                            return Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                'No registered players found',
                                style: _t(color: _m1),
                              ),
                            );
                          }
                          final result = _results[index];
                          return _PlayerResultTile(
                            entry: result.entry,
                            onTap: () => _toggle(result.entry),
                          );
                        },
                        separatorBuilder: (_, _) =>
                            Container(height: .8, color: _border),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Each selected player takes one open spot.',
                      style: _t(size: 12, color: _m1),
                    ),
                  ),
                  _ActionButton(
                    label: 'Add to Game',
                    disabled: _selected.isEmpty,
                    danger: false,
                    onTap: () => Navigator.pop(context, _selected),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPlayerChip extends StatelessWidget {
  final PlayerEntry player;
  final VoidCallback onRemove;
  const _SelectedPlayerChip({required this.player, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: _red.withValues(alpha: .14),
      side: BorderSide(color: _red.withValues(alpha: .35)),
      deleteIcon: const Icon(Icons.close_rounded, size: 14, color: _m1),
      onDeleted: onRemove,
      avatar: CircleAvatar(
        backgroundColor: _red.withValues(alpha: .55),
        child: Text(player.displayName[0].toUpperCase(), style: _t(size: 10)),
      ),
      label: Text(player.displayName, style: _t(size: 12)),
    );
  }
}

class _PlayerResultTile extends StatelessWidget {
  final PlayerEntry entry;
  final VoidCallback onTap;
  const _PlayerResultTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (entry.numericId != null) 'ID: ${entry.numericId}',
      if (entry.email?.isNotEmpty == true) entry.email!,
      if (entry.phone?.isNotEmpty == true) entry.phone!,
    ];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        leading: WebAvatar(
          imageUrl: entry.imageUrl,
          displayName: entry.displayName,
          size: 42,
          backgroundColor: _red.withValues(alpha: .2),
          textColor: _red,
          borderColor: Colors.white.withValues(alpha: .08),
        ),
        title: Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _t(size: 14, weight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitleParts.isEmpty
              ? 'Registered player'
              : subtitleParts.join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _t(size: 12, color: _m1),
        ),
        trailing: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _red.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _red.withValues(alpha: .28)),
          ),
          child: const Icon(Icons.add_rounded, color: _red, size: 18),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final bool disabled;
  final bool danger;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.disabled,
    required this.danger,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? const Color(0xFF7A1F28) : _red;
    return MouseRegion(
      cursor: widget.disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          constraints: const BoxConstraints(minWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: widget.disabled
                ? Colors.white.withValues(alpha: .08)
                : (_hover ? color.withValues(alpha: .86) : color),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: _t(
              size: 13,
              weight: FontWeight.w800,
              color: widget.disabled ? _m1 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
