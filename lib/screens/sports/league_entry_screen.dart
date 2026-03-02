import 'package:flutter/material.dart';

import '../../design/colors.dart';
import 'register_league_screen.dart';

/// Entry form — collects tournament basics before the full registration flow.
class LeagueEntryScreen extends StatefulWidget {
  const LeagueEntryScreen({super.key});

  @override
  State<LeagueEntryScreen> createState() => _LeagueEntryScreenState();
}

class _LeagueEntryScreenState extends State<LeagueEntryScreen> {
  final _nameCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();

  String  _sport  = 'Cricket';
  String  _format = 'Knockout';
  DateTime? _date;
  String? _error;

  static const _sports  = ['Cricket', 'Football', 'Basketball', 'Badminton',
                            'Tennis', 'Volleyball', 'Chess', 'Other'];
  static const _formats = ['Knockout', 'Round Robin', 'League', 'Double Elimination'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _continue() {
    final name     = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a tournament name.');
      return;
    }
    if (location.isEmpty) {
      setState(() => _error = 'Please enter a location.');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'Please select a date.');
      return;
    }

    final dateStr =
        '${_date!.day.toString().padLeft(2, '0')}/'
        '${_date!.month.toString().padLeft(2, '0')}/'
        '${_date!.year}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterLeagueScreen(
          tournamentName: name,
          sport:          _sport,
          format:         _format,
          date:           dateStr,
          location:       location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Register League',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tournament Details',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Fill in the basics to get started',
                style: TextStyle(color: Colors.white54, fontSize: 13)),

            const SizedBox(height: 28),

            // ── Tournament Name ───────────────────────────────────────
            _label('Tournament Name'),
            _field(_nameCtrl, 'e.g. Summer Cricket Cup 2025',
                Icons.emoji_events_outlined),

            const SizedBox(height: 16),

            // ── Sport ─────────────────────────────────────────────────
            _label('Sport'),
            _dropdown(
              value: _sport,
              items: _sports,
              onChanged: (v) => setState(() => _sport = v!),
              icon: Icons.sports_cricket_outlined,
            ),

            const SizedBox(height: 16),

            // ── Format ────────────────────────────────────────────────
            _label('Format'),
            _dropdown(
              value: _format,
              items: _formats,
              onChanged: (v) => setState(() => _format = v!),
              icon: Icons.format_list_bulleted,
            ),

            const SizedBox(height: 16),

            // ── Date ──────────────────────────────────────────────────
            _label('Tournament Start Date'),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.white38, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _date == null
                          ? 'Select date'
                          : '${_date!.day.toString().padLeft(2, '0')}/'
                            '${_date!.month.toString().padLeft(2, '0')}/'
                            '${_date!.year}',
                      style: TextStyle(
                        color: _date == null ? Colors.white38 : Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Location ──────────────────────────────────────────────
            _label('Location / Venue'),
            _field(_locationCtrl, 'e.g. DY Patil Stadium, Mumbai',
                Icons.location_on_outlined),

            // ── Error ─────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      TextStyle(color: Colors.red.shade400, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            // ── Continue button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _continue,
                child: const Text('Continue to Team Registration',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  Widget _field(TextEditingController ctrl, String hint, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                items: items
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
}
