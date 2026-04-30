import 'package:flutter/material.dart';

import '../../core/models/player_entry.dart';
import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../widgets/player_search_field.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SquadManagementScreen
// ══════════════════════════════════════════════════════════════════════════════

class SquadManagementScreen extends StatefulWidget {
  final String tournamentId;
  const SquadManagementScreen({super.key, required this.tournamentId});

  @override
  State<SquadManagementScreen> createState() => _SquadManagementScreenState();
}

class _SquadManagementScreenState extends State<SquadManagementScreen> {
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectTeam(String teamId) async {
    setState(() => _selectedTeamId = teamId);
    await TournamentService().loadSquad(widget.tournamentId, teamId);
  }

  void _showAddPlayerSheet() {
    if (_selectedTeamId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddPlayerSheet(
        tournamentId: widget.tournamentId,
        teamId: _selectedTeamId!,
      ),
    );
  }

  Future<void> _removePlayer(TournamentSquadPlayer p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Player',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Remove "${p.playerName}" from squad?',
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await TournamentService().removePlayerFromSquad(
      widget.tournamentId,
      _selectedTeamId!,
      p.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc = TournamentService();
        final teams = svc.teamsFor(widget.tournamentId);
        final squad = _selectedTeamId != null
            ? svc.squadFor(widget.tournamentId, _selectedTeamId!)
            : <TournamentSquadPlayer>[];
        final selectedTeam = _selectedTeamId == null
            ? null
            : teams.where((t) => t.id == _selectedTeamId).firstOrNull;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: Icon(
                _selectedTeamId == null
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                if (_selectedTeamId != null) {
                  setState(() => _selectedTeamId = null);
                  return;
                }
                Navigator.pop(context);
              },
            ),
            title: Text(
              selectedTeam?.teamName ?? 'Manage Squads',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: _selectedTeamId == null
              ? _SquadTeamList(teams: teams, onSelect: _selectTeam)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedTeam == null
                                  ? 'Squad members'
                                  : 'Squad members for ${selectedTeam.teamName}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddPlayerSheet,
                            icon: const Icon(
                              Icons.person_add_outlined,
                              size: 17,
                            ),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Expanded(
                      child: squad.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_add_outlined,
                                    color: Colors.white24,
                                    size: 56,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No squad members yet',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _showAddPlayerSheet,
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add Player',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                100,
                              ),
                              itemCount: squad.length,
                              itemBuilder: (_, i) {
                                final p = squad[i];
                                return _SquadPlayerCard(
                                  player: p,
                                  onRemove: () => _removePlayer(p),
                                  onToggleCaptain: () async {
                                    await svc.updateSquadPlayer(
                                      tournamentId: widget.tournamentId,
                                      teamId: _selectedTeamId!,
                                      docId: p.id,
                                      isCaptain: !p.isCaptain,
                                      isViceCaptain: p.isCaptain ? false : null,
                                    );
                                  },
                                  onToggleVC: () async {
                                    await svc.updateSquadPlayer(
                                      tournamentId: widget.tournamentId,
                                      teamId: _selectedTeamId!,
                                      docId: p.id,
                                      isViceCaptain: !p.isViceCaptain,
                                      isCaptain: p.isViceCaptain ? false : null,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
          floatingActionButton: _selectedTeamId != null && squad.isNotEmpty
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: _showAddPlayerSheet,
                  child: const Icon(
                    Icons.person_add_outlined,
                    color: Colors.white,
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _SquadTeamList extends StatelessWidget {
  final List<TournamentTeam> teams;
  final ValueChanged<String> onSelect;

  const _SquadTeamList({required this.teams, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, color: Colors.white24, size: 56),
            SizedBox(height: 12),
            Text(
              'No teams registered yet',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: teams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final team = teams[i];
        return InkWell(
          onTap: () => onSelect(team.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: .16),
                  child: Text(
                    team.teamName.isNotEmpty
                        ? team.teamName[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Captain: ${team.captainName.isEmpty ? 'Not set' : team.captainName}  •  ${team.players.length} players',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Player Card ───────────────────────────────────────────────────────────────

class _SquadPlayerCard extends StatelessWidget {
  final TournamentSquadPlayer player;
  final VoidCallback onRemove;
  final VoidCallback onToggleCaptain;
  final VoidCallback onToggleVC;

  const _SquadPlayerCard({
    required this.player,
    required this.onRemove,
    required this.onToggleCaptain,
    required this.onToggleVC,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: player.isCaptain
                  ? AppColors.primary.withAlpha(40)
                  : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                player.jerseyNumber > 0
                    ? '${player.jerseyNumber}'
                    : player.playerName[0].toUpperCase(),
                style: TextStyle(
                  color: player.isCaptain ? AppColors.primary : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.playerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (player.isCaptain) ...[
                      const SizedBox(width: 6),
                      _Badge('C', AppColors.primary),
                    ],
                    if (player.isViceCaptain) ...[
                      const SizedBox(width: 4),
                      _Badge('VC', Colors.orange),
                    ],
                  ],
                ),
                if (player.role.isNotEmpty || player.playerId.isNotEmpty)
                  Text(
                    '${player.role.isNotEmpty ? player.role : "Player"}${player.playerId.isNotEmpty ? "  ${player.playerId}" : ""}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
            color: const Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: (v) {
              switch (v) {
                case 'captain':
                  onToggleCaptain();
                  break;
                case 'vc':
                  onToggleVC();
                  break;
                case 'remove':
                  onRemove();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'captain',
                child: Text(
                  player.isCaptain ? 'Remove Captain' : 'Make Captain',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              PopupMenuItem(
                value: 'vc',
                child: Text(
                  player.isViceCaptain
                      ? 'Remove Vice Captain'
                      : 'Make Vice Captain',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Text(
                  'Remove from Squad',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

// ── Add Player Sheet ──────────────────────────────────────────────────────────

class _AddPlayerSheet extends StatefulWidget {
  final String tournamentId;
  final String teamId;
  const _AddPlayerSheet({required this.tournamentId, required this.teamId});

  @override
  State<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<_AddPlayerSheet> {
  final _nameCtrl = TextEditingController();
  final _jerseyCtrl = TextEditingController();
  bool _saving = false;
  PlayerEntry? _selectedProfile;

  static const _roles = [
    'Batsman',
    'Bowler',
    'All-Rounder',
    'Wicket Keeper',
    'Goalkeeper',
    'Striker',
    'Midfielder',
    'Defender',
    'Point Guard',
    'Centre',
    'Forward',
    'Setter',
    'Libero',
    'Spiker',
    'Player',
  ];
  String _selectedRole = 'Player';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _jerseyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPlayer() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await TournamentService().addPlayerToSquad(
        tournamentId: widget.tournamentId,
        teamId: widget.teamId,
        playerId: _selectedProfile?.numericId?.toString() ?? '',
        userId: _selectedProfile?.userId ?? '',
        playerName: _nameCtrl.text.trim(),
        role: _selectedRole,
        jerseyNumber: int.tryParse(_jerseyCtrl.text.trim()) ?? 0,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Player to Squad',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Live player search (name or 6-digit ID)
            PlayerSearchField(
              controller: _nameCtrl,
              hint: 'Search by name or player ID',
              onSelected: (entry) => setState(() => _selectedProfile = entry),
            ),
            const SizedBox(height: 10),

            // Role dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButton<String>(
                value: _selectedRole,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRole = v ?? 'Player'),
              ),
            ),
            const SizedBox(height: 10),

            _TxtField(
              ctrl: _jerseyCtrl,
              hint: 'Jersey number (optional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _addPlayer,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add to Squad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

class _TxtField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType keyboardType;
  const _TxtField({
    required this.ctrl,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}
