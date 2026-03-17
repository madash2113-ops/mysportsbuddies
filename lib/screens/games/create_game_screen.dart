import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/venue_model.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/game_listing_service.dart';

const _kSports = [
  'Cricket', 'Football', 'Throwball', 'Handball',
  'Basketball', 'Badminton', 'Tennis', 'Volleyball',
  'Table Tennis', 'Kabaddi', 'Hockey', 'Boxing',
];

class CreateGameScreen extends StatefulWidget {
  /// Pre-filled when coming from a venue booking.
  final VenueModel? venue;
  final String? prefilledDate;
  final String? prefilledSlot;
  final String? prefilledSport;

  const CreateGameScreen({
    super.key,
    this.venue,
    this.prefilledDate,
    this.prefilledSlot,
    this.prefilledSport,
  });

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  String?    _sport;
  DateTime?  _date;
  TimeOfDay? _time;
  int        _maxPlayers = 10;
  bool       _splitCost  = false;
  bool       _noSplit    = false;
  final      _costCtrl   = TextEditingController();
  final      _noteCtrl   = TextEditingController();
  bool       _saving     = false;
  String?    _error;
  File?      _photo;

  @override
  void initState() {
    super.initState();
    _sport = widget.prefilledSport;
    if (widget.venue != null) {
      _costCtrl.text = widget.venue!.pricePerHour.toStringAsFixed(0);
      _splitCost     = true;
    }
    if (widget.prefilledDate != null) {
      // parse "15 Mar 2026" style date
      try {
        final parts  = widget.prefilledDate!.split(' ');
        final months = ['Jan','Feb','Mar','Apr','May','Jun',
                        'Jul','Aug','Sep','Oct','Nov','Dec'];
        final day   = int.parse(parts[0]);
        final month = months.indexOf(parts[1]) + 1;
        final year  = int.parse(parts[2]);
        _date = DateTime(year, month, day);
      } catch (_) { /* ignore parse error */ }
    }
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _formattedDate {
    if (_date == null) return 'Select Date';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${_date!.day} ${months[_date!.month - 1]} ${_date!.year}';
  }

  String get _formattedTime {
    if (_time == null) return 'Select Time';
    final h  = _time!.hour;
    final m  = _time!.minute.toString().padLeft(2, '0');
    final am = h < 12 ? 'AM' : 'PM';
    final hr = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hr:$m $am';
  }

  double get _costPerPlayer {
    final total = double.tryParse(_costCtrl.text.trim()) ?? 0;
    if (!_splitCost || _maxPlayers <= 0) return 0;
    return total / _maxPlayers;
  }

  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                onTap: () { Navigator.pop(context); setState(() => _photo = null); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 7, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _create() async {
    if (_sport == null) {
      setState(() => _error = 'Please select a sport.');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'Please select a date.');
      return;
    }
    if (_time == null) {
      setState(() => _error = 'Please select a time.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final scheduled = DateTime(
        _date!.year, _date!.month, _date!.day,
        _time!.hour, _time!.minute,
      );
      final totalCost = double.tryParse(_costCtrl.text.trim()) ?? 0;

      // Upload photo first (we need the listing id, so create a temp id)
      final svc = GameListingService();
      String? photoUrl;
      if (_photo != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        photoUrl = await svc.uploadGamePhoto(_photo!, tempId);
      }

      await svc.createListing(
        sport:        _sport!,
        scheduledAt:  scheduled,
        maxPlayers:   _maxPlayers,
        splitCost:    _splitCost,
        totalCost:    _splitCost ? totalCost : 0,
        venueId:      widget.venue?.id,
        venueName:    widget.venue?.name ?? '',
        address:      widget.venue?.address ?? '',
        note:         _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        photoUrl:     photoUrl,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // true = created
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game listed! Players can now find and join.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() { _saving = false; _error = 'Failed to create game. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('List an Open Game',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Venue info banner (if from booking) ───────────────────
            if (widget.venue != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.venue!.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(widget.venue!.address,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Sport ─────────────────────────────────────────────────
            _Label('Select Sport *'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kSports.map((s) {
                final sel = s == _sport;
                return GestureDetector(
                  onTap: () => setState(() => _sport = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.primary : Colors.white24),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Date & Time ───────────────────────────────────────────
            _Label('Date & Time *'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: _formattedDate,
                    selected: _date != null,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time_outlined,
                    label: _formattedTime,
                    selected: _time != null,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Max Players ───────────────────────────────────────────
            _Label('Max Players: $_maxPlayers'),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: Colors.white12,
                overlayColor: AppColors.primary.withValues(alpha: 0.15),
                trackHeight: 4,
              ),
              child: Slider(
                value: _maxPlayers.toDouble(),
                min: 2,
                max: 30,
                divisions: 28,
                onChanged: (v) => setState(() => _maxPlayers = v.round()),
              ),
            ),
            Row(
              children: const [
                Text('2', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Spacer(),
                Text('30', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Cost Split ────────────────────────────────────────────
            _Label('Venue Cost'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _OptionTile(
                    icon: Icons.people_outline,
                    title: 'Split Cost',
                    subtitle: 'Players share the venue fee',
                    selected: _splitCost,
                    color: Colors.green,
                    onTap: () => setState(() { _splitCost = true; _noSplit = false; }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OptionTile(
                    icon: Icons.money_off_outlined,
                    title: 'No Split',
                    subtitle: 'Free to join, you cover cost',
                    selected: _noSplit || (!_splitCost && !_noSplit ? false : !_splitCost),
                    color: Colors.orange,
                    onTap: () => setState(() { _splitCost = false; _noSplit = true; }),
                  ),
                ),
              ],
            ),

            // ── Total cost field (only if split) ──────────────────────
            if (_splitCost) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _costCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Total venue cost (₹)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.currency_rupee,
                      color: Colors.white38, size: 20),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_costPerPlayer > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Each player pays ₹${_costPerPlayer.toStringAsFixed(0)}  '
                        '(₹${_costCtrl.text} ÷ $_maxPlayers players)',
                        style: const TextStyle(
                            color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── Photo ─────────────────────────────────────────────────
            _Label('Game Photo (optional)'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showPhotoOptions,
              child: _photo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Image.file(_photo!,
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _photo = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 130,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white24,
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo_outlined,
                              color: Colors.white38, size: 32),
                          SizedBox(height: 8),
                          Text('Tap to add a photo',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Note ──────────────────────────────────────────────────
            _Label('Note (optional)'),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. "Bring your own bat", "Beginners welcome"',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            // ── Error ─────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade400, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            // ── Create button ─────────────────────────────────────────
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
                onPressed: _saving ? null : _create,
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('List Game',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700));
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickerTile({
    required this.icon, required this.label,
    required this.selected, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.white24,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : Colors.white38,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon, required this.title, required this.subtitle,
    required this.selected, required this.color, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: selected ? color : Colors.white54, size: 18),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: selected ? Colors.white54 : Colors.white38,
                    fontSize: 11),
                maxLines: 2),
          ],
        ),
      ),
    );
  }
}
