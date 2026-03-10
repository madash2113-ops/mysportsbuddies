import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AdminManagementScreen — HOST only
// ══════════════════════════════════════════════════════════════════════════════

class AdminManagementScreen extends StatelessWidget {
  final String tournamentId;
  const AdminManagementScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final admins = TournamentService().adminsFor(tournamentId);

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Manage Admins',
                style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          body: admins.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.admin_panel_settings_outlined,
                        color: Colors.white24, size: 56),
                    const SizedBox(height: 12),
                    const Text('No admins assigned yet',
                        style: TextStyle(color: Colors.white38, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text(
                      'Admins can enter results, manage squads & venues',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => _showAddAdmin(context),
                      icon: const Icon(Icons.person_add_outlined,
                          color: Colors.white, size: 18),
                      label: const Text('Add Admin',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: admins.length,
                  itemBuilder: (_, i) => _AdminCard(
                    admin:        admins[i],
                    tournamentId: tournamentId,
                    onRemove: () => _remove(context, admins[i]),
                  ),
                ),
          floatingActionButton: admins.isNotEmpty
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: () => _showAddAdmin(context),
                  child: const Icon(Icons.person_add_outlined, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _showAddAdmin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddAdminSheet(tournamentId: tournamentId),
    );
  }

  Future<void> _remove(BuildContext context, TournamentAdmin admin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Admin',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text('Remove "${admin.userName}" as admin?',
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                elevation: 0, shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TournamentService().removeAdmin(tournamentId, admin.userId);
  }
}

// ── Admin Card ────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final TournamentAdmin admin;
  final String          tournamentId;
  final VoidCallback    onRemove;
  const _AdminCard({
    required this.admin,
    required this.tournamentId,
    required this.onRemove,
  });

  String _permLabel(AdminPermission p) {
    switch (p) {
      case AdminPermission.scheduleMatches: return 'Schedule';
      case AdminPermission.updateScores:    return 'Scores';
      case AdminPermission.editSquads:      return 'Squads';
      case AdminPermission.manageVenues:    return 'Venues';
      case AdminPermission.editMatchInfo:   return 'Match Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30), shape: BoxShape.circle),
            child: Center(child: Text(
              admin.userName.isNotEmpty ? admin.userName[0].toUpperCase() : 'A',
              style: const TextStyle(color: Colors.orange,
                  fontSize: 18, fontWeight: FontWeight.w800),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(admin.userName, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
            Text('#${admin.numericId}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
          IconButton(
            icon: const Icon(Icons.person_remove_outlined,
                color: Colors.red, size: 20),
            onPressed: onRemove,
          ),
        ]),
        const SizedBox(height: 8),
        const Text('Permissions:',
            style: TextStyle(color: Colors.white38,
                fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4,
          children: admin.permissions.map((p) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.withAlpha(80)),
            ),
            child: Text(_permLabel(p),
                style: const TextStyle(color: Colors.orange,
                    fontSize: 10, fontWeight: FontWeight.w700)),
          )).toList(),
        ),
      ]),
    );
  }
}

// ── Add Admin Sheet ───────────────────────────────────────────────────────────

class _AddAdminSheet extends StatefulWidget {
  final String tournamentId;
  const _AddAdminSheet({required this.tournamentId});

  @override
  State<_AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends State<_AddAdminSheet> {
  final _idCtrl = TextEditingController();
  bool _searching = false;
  bool _saving    = false;
  String? _foundUserId;
  String? _foundName;
  String? _searchError;

  final Set<AdminPermission> _selectedPerms = {
    AdminPermission.updateScores,
    AdminPermission.editSquads,
  };

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _idCtrl.text.trim();
    final numId = int.tryParse(raw);
    if (numId == null) {
      setState(() => _searchError = 'Enter a valid numeric ID');
      return;
    }
    setState(() { _searching = true; _searchError = null; _foundUserId = null; _foundName = null; });
    try {
      final profile = await UserService().searchByNumericId(numId);
      if (!mounted) return;
      if (profile != null) {
        setState(() { _foundUserId = profile.id; _foundName = profile.name; });
      } else {
        setState(() => _searchError = 'No user found with ID $raw');
      }
    } catch (e) {
      if (mounted) setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addAdmin() async {
    if (_foundUserId == null || _selectedPerms.isEmpty) return;
    setState(() => _saving = true);
    try {
      await TournamentService().addAdmin(
        tournamentId: widget.tournamentId,
        userId:       _foundUserId!,
        userName:     _foundName ?? '',
        numericId:    _idCtrl.text.trim(),
        permissions:  _selectedPerms.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  String _permLabel(AdminPermission p) {
    switch (p) {
      case AdminPermission.scheduleMatches: return 'Schedule Matches';
      case AdminPermission.updateScores:    return 'Enter Results / Scores';
      case AdminPermission.editSquads:      return 'Edit Squads';
      case AdminPermission.manageVenues:    return 'Manage Venues';
      case AdminPermission.editMatchInfo:   return 'Edit Match Info';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Add Admin',
            style: TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // Search by player ID
        Row(children: [
          Expanded(child: TextField(
            controller: _idCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '6-digit Player ID',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true, fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          )),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A2A2A),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _searching ? null : _search,
            child: _searching
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Find', style: TextStyle(color: Colors.white70,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),

        if (_searchError != null) ...[
          const SizedBox(height: 6),
          Text(_searchError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        if (_foundName != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withAlpha(80)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text('Found: $_foundName',
                  style: const TextStyle(color: Colors.green,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],

        const SizedBox(height: 16),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('PERMISSIONS',
              style: TextStyle(color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
        const SizedBox(height: 8),

        ...AdminPermission.values.map((p) => CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(_permLabel(p),
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          value: _selectedPerms.contains(p),
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          onChanged: (v) => setState(() {
            if (v == true) { _selectedPerms.add(p); }
            else { _selectedPerms.remove(p); }
          }),
        )),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _foundUserId != null
                  ? AppColors.primary
                  : Colors.white24,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: (_saving || _foundUserId == null) ? null : _addAdmin,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add Admin',
                    style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
