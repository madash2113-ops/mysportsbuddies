import 'package:flutter/material.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// VenueManagementScreen
// ══════════════════════════════════════════════════════════════════════════════

class VenueManagementScreen extends StatelessWidget {
  final String tournamentId;
  const VenueManagementScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final venues = TournamentService().venuesFor(tournamentId);

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Manage Venues',
                style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            centerTitle: true,
          ),
          body: venues.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.stadium_outlined,
                        color: Colors.white24, size: 56),
                    const SizedBox(height: 12),
                    const Text('No venues added yet',
                        style: TextStyle(color: Colors.white38, fontSize: 14)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () => _showVenueForm(context, null),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text('Add Venue',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: venues.length,
                  itemBuilder: (_, i) => _VenueCard(
                    venue: venues[i],
                    onEdit: () => _showVenueForm(context, venues[i]),
                    onDelete: () => _delete(context, venues[i]),
                  ),
                ),
          floatingActionButton: venues.isNotEmpty
              ? FloatingActionButton(
                  backgroundColor: AppColors.primary,
                  onPressed: () => _showVenueForm(context, null),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _showVenueForm(BuildContext context, TournamentVenue? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _VenueFormSheet(
          tournamentId: tournamentId, existing: existing),
    );
  }

  Future<void> _delete(BuildContext context, TournamentVenue venue) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Venue',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text('Delete "${venue.name}"?',
            style: const TextStyle(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                elevation: 0, shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await TournamentService().removeVenue(tournamentId, venue.id);
  }
}

// ── Venue Card ────────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final TournamentVenue venue;
  final VoidCallback    onEdit;
  final VoidCallback    onDelete;
  const _VenueCard({required this.venue, required this.onEdit, required this.onDelete});

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
              color: Colors.blue.withAlpha(30), shape: BoxShape.circle),
            child: const Center(
              child: Icon(Icons.stadium_outlined, color: Colors.blue, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(venue.name, style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w700)),
            if (venue.city.isNotEmpty || venue.address.isNotEmpty)
              Text('${venue.address.isNotEmpty ? venue.address : ""}${venue.city.isNotEmpty ? ", ${venue.city}" : ""}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
          ])),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: onDelete,
          ),
        ]),
        if (venue.pitchType.isNotEmpty || venue.hasFloodlights || venue.capacity > 0) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (venue.pitchType.isNotEmpty) _Tag(venue.pitchType, Colors.purple),
            if (venue.hasFloodlights)       _Tag('Floodlights', Colors.amber),
            if (venue.capacity > 0)         _Tag('Cap: ${venue.capacity}', Colors.teal),
          ]),
        ],
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color  color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color,
        fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ── Venue Form Sheet ──────────────────────────────────────────────────────────

class _VenueFormSheet extends StatefulWidget {
  final String          tournamentId;
  final TournamentVenue? existing;
  const _VenueFormSheet({required this.tournamentId, this.existing});

  @override
  State<_VenueFormSheet> createState() => _VenueFormSheetState();
}

class _VenueFormSheetState extends State<_VenueFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _cap;
  late String _pitchType;
  late bool   _flood;
  bool _saving = false;

  static const _pitchTypes = ['', 'Grass', 'Turf', 'Indoor', 'Hard Court', 'Clay', 'Parquet'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name    = TextEditingController(text: e?.name ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _city    = TextEditingController(text: e?.city ?? '');
    _cap     = TextEditingController(text: e != null && e.capacity > 0 ? '${e.capacity}' : '');
    _pitchType = e?.pitchType ?? '';
    _flood     = e?.hasFloodlights ?? false;
  }

  @override
  void dispose() {
    _name.dispose(); _address.dispose(); _city.dispose(); _cap.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final svc = TournamentService();
      if (widget.existing != null) {
        await svc.updateVenue(
          tournamentId:   widget.tournamentId,
          venueId:        widget.existing!.id,
          name:           _name.text.trim(),
          address:        _address.text.trim(),
          city:           _city.text.trim(),
          capacity:       int.tryParse(_cap.text.trim()) ?? 0,
          pitchType:      _pitchType,
          hasFloodlights: _flood,
        );
      } else {
        await svc.addVenue(
          tournamentId:   widget.tournamentId,
          name:           _name.text.trim(),
          address:        _address.text.trim(),
          city:           _city.text.trim(),
          capacity:       int.tryParse(_cap.text.trim()) ?? 0,
          pitchType:      _pitchType,
          hasFloodlights: _flood,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
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
        Text(widget.existing != null ? 'Edit Venue' : 'Add Venue',
            style: const TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _TF(ctrl: _name,    hint: 'Venue name *'),
        const SizedBox(height: 10),
        _TF(ctrl: _address, hint: 'Address'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _TF(ctrl: _city, hint: 'City')),
          const SizedBox(width: 10),
          Expanded(child: _TF(ctrl: _cap,  hint: 'Capacity',
              keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        // Pitch type dropdown (plain DropdownButton)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButton<String>(
            value: _pitchType,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            hint: const Text('Pitch type',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            items: _pitchTypes.map((p) => DropdownMenuItem(
              value: p,
              child: Text(p.isEmpty ? 'Not specified' : p),
            )).toList(),
            onChanged: (v) => setState(() => _pitchType = v ?? ''),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Has Floodlights',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          value: _flood,
          onChanged: (v) => setState(() => _flood = v),
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.primary,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.existing != null ? 'Save Changes' : 'Add Venue',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String                hint;
  final TextInputType         keyboardType;
  const _TF({required this.ctrl, required this.hint,
      this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true, fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}
