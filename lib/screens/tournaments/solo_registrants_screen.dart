import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/models/player_entry.dart';
import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../widgets/player_search_field.dart';

// ── SoloRegistrantsScreen ─────────────────────────────────────────────────────
// Host-only screen: lists solo registrants + triggers auto-team formation.

class SoloRegistrantsScreen extends StatefulWidget {
  final String tournamentId;
  const SoloRegistrantsScreen({super.key, required this.tournamentId});

  @override
  State<SoloRegistrantsScreen> createState() => _SoloRegistrantsScreenState();
}

class _SoloRegistrantsScreenState extends State<SoloRegistrantsScreen> {
  bool _loading = true;
  bool _forming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await TournamentService().loadSoloRegistrants(widget.tournamentId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autoFormTeams() async {
    final tournament = TournamentService().tournaments
        .where((t) => t.id == widget.tournamentId)
        .firstOrNull;
    final registrants = TournamentService().soloRegistrantsFor(
      widget.tournamentId,
    );
    if (registrants.isEmpty) return;

    final teamSize = (tournament?.soloRegistrantsPerTeam ?? 0) > 0
        ? tournament!.soloRegistrantsPerTeam
        : ((tournament?.playersPerTeam ?? 0) > 0
              ? tournament!.playersPerTeam
              : 5);
    final teamsCount = (registrants.length / teamSize).ceil();
    final leftover = registrants.length % teamSize;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Auto-Form Teams',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${registrants.length} solo player${registrants.length != 1 ? "s" : ""} will be randomly grouped into $teamsCount team${teamsCount != 1 ? "s" : ""} of $teamSize.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (leftover > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: .3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.amber,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The last team will have $leftover player${leftover != 1 ? "s" : ""} (incomplete).',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Solo registrant records will be removed after teams are formed.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Form Teams',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _forming = true);
    try {
      final formed = await TournamentService().autoFormTeams(
        widget.tournamentId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$formed team${formed != 1 ? "s" : ""} formed successfully!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _forming = false);
    }
  }

  Future<void> _showAddPlayerSheet() async {
    final alreadyIds = TournamentService()
        .soloRegistrantsFor(widget.tournamentId)
        .map((r) => r.userId)
        .toSet();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlayerSheet(
        tournamentId: widget.tournamentId,
        excludeUserIds: alreadyIds,
        onAdded: _load,
      ),
    );
  }

  void _confirmRemove(SoloRegistrant registrant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Remove Player',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove ${registrant.userName} from solo registration?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('tournaments')
                    .doc(widget.tournamentId)
                    .collection('solo_registrants')
                    .doc(registrant.userId)
                    .delete();
                await TournamentService().loadSoloRegistrants(
                  widget.tournamentId,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final registrants = TournamentService().soloRegistrantsFor(
          widget.tournamentId,
        );
        final tournament = TournamentService().tournaments
            .where((t) => t.id == widget.tournamentId)
            .firstOrNull;
        final teamSize = (tournament?.soloRegistrantsPerTeam ?? 0) > 0
            ? tournament!.soloRegistrantsPerTeam
            : ((tournament?.playersPerTeam ?? 0) > 0
                  ? tournament!.playersPerTeam
                  : 5);
        final teamsWillForm = registrants.isNotEmpty
            ? (registrants.length / teamSize).ceil()
            : 0;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Solo Registrants',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Add player',
                onPressed: _loading ? null : _showAddPlayerSheet,
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: _loading ? null : _load,
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // ── Stats bar ──────────────────────────────────────────
                    Container(
                      color: const Color(0xFF121212),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          _StatChip(
                            icon: Icons.person_outlined,
                            label: 'Solo Players',
                            value: '${registrants.length}',
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            icon: Icons.groups_outlined,
                            label: 'Teams to Form',
                            value: '$teamsWillForm',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            icon: Icons.people_outline,
                            label: 'Per Team',
                            value: '$teamSize',
                            color: Colors.teal,
                          ),
                        ],
                      ),
                    ),

                    // ── Player list ────────────────────────────────────────
                    Expanded(
                      child: registrants.isEmpty
                          ? _EmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: registrants.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _RegistrantTile(
                                registrant: registrants[i],
                                index: i + 1,
                                onRemove: () => _confirmRemove(registrants[i]),
                              ),
                            ),
                    ),

                    // ── Auto-form button ───────────────────────────────────
                    if (registrants.isNotEmpty)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _forming ? null : _autoFormTeams,
                              icon: _forming
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                _forming
                                    ? 'Forming teams…'
                                    : 'Auto-Form $teamsWillForm Team${teamsWillForm != 1 ? "s" : ""}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _RegistrantTile extends StatelessWidget {
  final SoloRegistrant registrant;
  final int index;
  final VoidCallback onRemove;
  const _RegistrantTile({
    required this.registrant,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF2A2A2A)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                registrant.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                registrant.phone,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white24,
            size: 18,
          ),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_search_outlined, color: Colors.white12, size: 64),
        SizedBox(height: 16),
        Text(
          'No solo registrants yet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Players will appear here once they register\nwithout a team.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ── Add player sheet ──────────────────────────────────────────────────────────

class _AddPlayerSheet extends StatefulWidget {
  final String tournamentId;
  final Set<String> excludeUserIds;
  final VoidCallback onAdded;

  const _AddPlayerSheet({
    required this.tournamentId,
    required this.excludeUserIds,
    required this.onAdded,
  });

  @override
  State<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<_AddPlayerSheet> {
  final _search = TextEditingController();
  late final Set<String> _blockedUserIds;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _blockedUserIds = {...widget.excludeUserIds};
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addPlayer(PlayerEntry entry) async {
    final uid = entry.userId;
    if (uid == null || !entry.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an existing registered player.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_blockedUserIds.contains(uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.displayName} is already in the solo list.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _adding = true);
    try {
      await TournamentService().addSoloRegistrantByAdmin(
        tournamentId: widget.tournamentId,
        userId: uid,
        userName: entry.displayName,
        phone: entry.phone ?? '',
      );
      if (!mounted) return;
      widget.onAdded();
      _search.clear();
      setState(() => _blockedUserIds.add(uid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.displayName} added to solo list'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(top: 60, bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
                SizedBox(width: 10),
                Text(
                  'Add Player to Solo List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PlayerSearchField(
              controller: _search,
              hint: 'Search existing players by name, ID, phone or email',
              showManualOption: false,
              onSelected: (entry) {
                _addPlayer(entry);
              },
            ),
          ),
          Expanded(
            child: Center(
              child: _adding
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6366F1),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Adding player...',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    )
                  : const Text(
                      'Search and select an existing player to add them.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
