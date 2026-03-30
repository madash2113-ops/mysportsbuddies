import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/models/game.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../core/models/player_entry.dart';
import '../../services/game_service.dart';
import '../../services/user_service.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../widgets/player_search_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  RegisterGameScreen
// ─────────────────────────────────────────────────────────────────────────────

class RegisterGameScreen extends StatefulWidget {
  final String sport;
  final Game? existingGame; // non-null → edit mode

  const RegisterGameScreen({
    super.key,
    required this.sport,
    this.existingGame,
  });

  @override
  State<RegisterGameScreen> createState() => _RegisterGameScreenState();
}

class _RegisterGameScreenState extends State<RegisterGameScreen> {
  final _venueCtrl         = TextEditingController();
  final _playersCtrl       = TextEditingController();
  final _notesCtrl         = TextEditingController();
  final _extraCtrl1        = TextEditingController();
  final _extraCtrl2        = TextEditingController();
  final _customFormatCtrl  = TextEditingController();
  final _contactNameCtrl   = TextEditingController();
  final _contactPhoneCtrl  = TextEditingController();

  PlayerEntry? _contactEntry;
  String _countryCode = '+91';
  final List<File> _pendingPhotos = [];

  DateTime?  _date;
  TimeOfDay? _time;
  String? _skillLevel;
  String? _ballType;
  String? _format;
  String? _matchType;
  String? _bestOf;
  bool _hideContact = false;

  // Validation error flags
  bool _venueError = false;
  bool _dateError  = false;
  bool _timeError  = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill controllers when editing an existing game
    final g = widget.existingGame;
    if (g != null) {
      _venueCtrl.text        = g.location;
      _playersCtrl.text      = g.maxPlayers ?? '';
      _notesCtrl.text        = g.notes ?? '';
      _contactNameCtrl.text  = g.organizerName ?? '';
      _contactPhoneCtrl.text = g.organizerPhone ?? '';
      _hideContact           = g.hideContact;
      _skillLevel            = g.skillLevel;
      _ballType              = g.ballType;
      _format                = g.format;
      _date              = DateTime(g.dateTime.year, g.dateTime.month, g.dateTime.day);
      _time              = TimeOfDay(hour: g.dateTime.hour, minute: g.dateTime.minute);
    }
    // Clear venue error as soon as user types
    _venueCtrl.addListener(() {
      if (_venueError && _venueCtrl.text.trim().isNotEmpty) {
        setState(() => _venueError = false);
      }
    });
  }

  /// Splits a full phone string like "+919876543210" into (countryCode, digits).
  /// Falls back to ("+91", rawDigits) if no known prefix is found.
  (String, String) _parsePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    // Common country codes sorted longest-first so +91 doesn't swallow +1
    const codes = ['+971', '+966', '+965', '+61', '+44', '+91', '+1'];
    for (final code in codes) {
      if (digits.startsWith(code)) {
        return (code, digits.substring(code.length));
      }
    }
    // If raw starts with "91" (no +), treat as India
    if (digits.startsWith('91') && digits.length > 10) {
      return ('+91', digits.substring(2));
    }
    return ('+91', digits.replaceAll('+', ''));
  }

  @override
  void dispose() {
    _venueCtrl.dispose();
    _playersCtrl.dispose();
    _notesCtrl.dispose();
    _extraCtrl1.dispose();
    _extraCtrl2.dispose();
    _customFormatCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _emoji() {
    const m = {
      'Cricket': '🏏', 'Football': '⚽', 'Basketball': '🏀',
      'Badminton': '🏸', 'Tennis': '🎾', 'Volleyball': '🏐',
      'Table Tennis': '🏓', 'Boxing': '🥊', 'Baseball': '⚾',
      'Hockey': '🏑', 'Running': '🏃', 'Swimming': '🏊',
      'Cycling': '🚴', 'MMA': '🥋', 'Wrestling': '🤼',
      'Kabaddi': '🤸', 'Kho Kho': '🏃', 'CS:GO': '🎮', 'Valorant': '🎮',
    };
    return m[widget.sport] ?? '🏅';
  }

  String _defaultMaxPlayers() {
    switch (widget.sport) {
      case 'Cricket':    return '22  (11 per side)';
      case 'Football':   return '22  (11 per side)';
      case 'Basketball': return '10  (5 per side)';
      case 'Volleyball': return '12  (6 per side)';
      case 'Hockey':     return '22  (11 per side)';
      case 'Baseball':   return '18  (9 per side)';
      case 'Kabaddi':    return '14  (7 per side)';
      default:           return 'Enter number';
    }
  }

  List<String>? _ballOptions() {
    switch (widget.sport) {
      case 'Cricket':      return ['Tennis Ball', 'Leather Ball', 'Tape Ball', 'Cork Ball'];
      case 'Football':     return ['Synthetic', 'Leather', 'Futsal Ball'];
      case 'Basketball':   return ['Standard', 'Street Ball'];
      case 'Tennis':       return ['Hard Court', 'Clay Court', 'Grass Court'];
      case 'Badminton':    return ['Feather Shuttle', 'Plastic Shuttle'];
      case 'Table Tennis': return ['3-Star Plastic', '2-Star Plastic', '1-Star'];
      case 'Volleyball':   return ['Indoor Ball', 'Beach Ball'];
      case 'Baseball':     return ['Hardball', 'Softball'];
      case 'Hockey':       return ['Field Ball', 'Street Ball', 'Puck (Ice)'];
      default:             return null;
    }
  }

  String _ballLabel() {
    switch (widget.sport) {
      case 'Tennis':
      case 'Badminton':
      case 'Table Tennis': return 'Equipment Type';
      case 'Hockey':       return 'Ball / Puck Type';
      default:             return 'Ball Type';
    }
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScrollDateSheet(initial: _date ?? DateTime.now()),
    );
    if (result != null) setState(() { _date = result; _dateError = false; });
  }

  Future<void> _pickTime() async {
    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScrollTimeSheet(initial: _time ?? TimeOfDay.now()),
    );
    if (result != null) setState(() { _time = result; _timeError = false; });
  }

  Future<void> _pickPhotos() async {
    final existingCount = widget.existingGame?.photoUrls.length ?? 0;
    final remaining = 10 - existingCount - _pendingPhotos.length;
    if (remaining <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum 10 photos allowed'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final picked = await ImagePicker().pickMultiImage(imageQuality: 75);
    if (picked.isEmpty) return;
    final files = picked.take(remaining).map((x) => File(x.path)).toList();
    setState(() => _pendingPhotos.addAll(files));
  }

  Future<void> _uploadEditPhoto(BuildContext context) async {
    final existing = GameService()
        .bySport(widget.sport)
        .where((g) => g.id == widget.existingGame!.id)
        .firstOrNull;
    final currentCount = existing?.photoUrls.length ?? widget.existingGame!.photoUrls.length;
    if (currentCount >= 10) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum 10 photos allowed'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final picked = await ImagePicker()
        .pickMultiImage(imageQuality: 75);
    if (picked.isEmpty) return;
    if (!context.mounted) return;
    final remaining = 10 - currentCount;
    final files = picked.take(remaining).map((x) => File(x.path)).toList();
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(SnackBar(
      content: Text('Uploading ${files.length} photo${files.length > 1 ? 's' : ''}...'),
      duration: const Duration(seconds: 30),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      for (final file in files) {
        await GameService()
            .uploadGamePhoto(widget.existingGame!.id, file);
      }
      snack.hideCurrentSnackBar();
      if (!context.mounted) return;
      snack.showSnackBar(SnackBar(
        content: Text('${files.length} photo${files.length > 1 ? 's' : ''} added!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      snack.hideCurrentSnackBar();
      if (!context.mounted) return;
      snack.showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ballOpts = _ballOptions();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.existingGame != null
              ? 'Edit ${widget.sport} Game'
              : 'Register ${widget.sport}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sport badge
            _SportBadge(sport: widget.sport, emoji: _emoji()),
            const SizedBox(height: AppSpacing.xl),

            // ── Game Details ─────────────────────────────────────────────
            const _SectionHeader('GAME DETAILS'),
            const SizedBox(height: AppSpacing.md),

            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AddressAutocompleteField(
                controller: _venueCtrl,
                label: 'Venue / Ground *',
                hint: 'Search stadium, ground or address...',
                onSelected: (_) {
                  if (_venueError) setState(() => _venueError = false);
                },
              ),
            ),

            _TapField(
              label: 'Date *',
              value: _date != null ? '${_date!.day}  /  ${_date!.month}  /  ${_date!.year}' : null,
              hint: 'Select date',
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
              hasError: _dateError,
            ),

            _TapField(
              label: 'Time *',
              value: _time?.format(context),
              hint: 'Select time',
              icon: Icons.access_time_outlined,
              onTap: _pickTime,
              hasError: _timeError,
            ),

            _InputField(
              label: 'Max Players',
              controller: _playersCtrl,
              hint: _defaultMaxPlayers(),
              keyboardType: TextInputType.number,
            ),

            const _Label('Skill Level'),
            const SizedBox(height: AppSpacing.xs),
            _ChipSelector(
              options: const ['Beginner', 'Intermediate', 'Advanced'],
              selected: _skillLevel,
              onSelect: (v) => setState(() => _skillLevel = v),
            ),

            // Ball / Equipment type (sport-specific)
            if (ballOpts != null) ...[
              const SizedBox(height: AppSpacing.md),
              _Label(_ballLabel()),
              const SizedBox(height: AppSpacing.xs),
              _ChipSelector(
                options: ballOpts,
                selected: _ballType,
                onSelect: (v) => setState(() => _ballType = v),
              ),
            ],

            // ── Sport-specific fields ─────────────────────────────────────
            ..._buildSportFields(),

            const SizedBox(height: AppSpacing.xl),

            _InputField(
              label: 'Notes (Optional)',
              controller: _notesCtrl,
              hint: 'Any additional info...',
              maxLines: 3,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Organizer Contact ─────────────────────────────────────────
            const _SectionHeader('ORGANIZER CONTACT'),
            const SizedBox(height: AppSpacing.md),

            const Text('Your Name',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            PlayerSearchField(
              controller: _contactNameCtrl,
              hint: 'Search by name, email or ID',
              onSelected: (entry) {
                setState(() => _contactEntry = entry);
                // Auto-fill phone from the selected user's profile
                final phone = entry.phone;
                if (phone != null && phone.isNotEmpty) {
                  final parsed = _parsePhone(phone);
                  setState(() {
                    _countryCode = parsed.$1;
                    _contactPhoneCtrl.text = parsed.$2;
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),

            const Text('Phone Number',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country code picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showModalBottomSheet<String>(
                      context: context,
                      backgroundColor: const Color(0xFF1A1A1A),
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (_) => _CountryCodePicker(selected: _countryCode),
                    );
                    if (picked != null) setState(() => _countryCode = picked);
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_countryCode,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white38, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // Phone number
                Expanded(
                  child: TextFormField(
                    controller: _contactPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Phone number',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => setState(() => _hideContact = !_hideContact),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _hideContact
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hideContact
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _hideContact
                          ? AppColors.primary
                          : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hide contact from other players',
                            style: TextStyle(
                              color: _hideContact
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _hideContact
                                ? 'Only you can see your contact'
                                : 'Players can see your contact info',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _hideContact,
                      onChanged: (v) => setState(() => _hideContact = v),
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Ground Photos ────────────────────────────────────────────
            const _SectionHeader('GROUND PHOTOS (max 10)'),
            const SizedBox(height: AppSpacing.md),
            if (widget.existingGame != null)
              // Edit mode — show uploaded photos from Firestore
              Consumer<GameService>(
                builder: (ctx, gameSvc, _) {
                  final live = gameSvc
                      .bySport(widget.sport)
                      .where((g) => g.id == widget.existingGame!.id)
                      .firstOrNull;
                  final urls =
                      live?.photoUrls ?? widget.existingGame!.photoUrls;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (urls.isNotEmpty) ...[
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: urls.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                urls[i],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('${urls.length}/10 photos',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _uploadEditPhoto(context),
                          icon: const Icon(
                              Icons.add_photo_alternate_outlined, size: 18),
                          label: Text(
                              urls.isEmpty ? 'Add Photos' : 'Add More Photos'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              // Create mode — show pending local photos
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pendingPhotos.isNotEmpty) ...[
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingPhotos.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _pendingPhotos[i],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2, right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                    _pendingPhotos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${_pendingPhotos.length}/10 photos selected',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickPhotos,
                      icon: const Icon(
                          Icons.add_photo_alternate_outlined, size: 18),
                      label: Text(_pendingPhotos.isEmpty
                          ? 'Add Photos'
                          : 'Add More Photos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),

            // ── Submit ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                ),
                onPressed: () async {
                  final venueEmpty = _venueCtrl.text.trim().isEmpty;
                  final dateEmpty  = _date == null;
                  final timeEmpty  = _time == null;
                  if (venueEmpty || dateEmpty || timeEmpty) {
                    setState(() {
                      _venueError = venueEmpty;
                      _dateError  = dateEmpty;
                      _timeError  = timeEmpty;
                    });
                    return;
                  }

                  final combined = DateTime(
                    _date!.year, _date!.month, _date!.day,
                    _time!.hour, _time!.minute,
                  );

                  final resolvedFormat = _format == 'Custom'
                      ? (_customFormatCtrl.text.trim().isEmpty
                          ? null
                          : _customFormatCtrl.text.trim())
                      : _format;

                  final isEditing = widget.existingGame != null;

                  final game = Game(
                    id: isEditing
                        ? widget.existingGame!.id
                        : DateTime.now().millisecondsSinceEpoch.toString(),
                    sport: widget.sport,
                    location: _venueCtrl.text.trim(),
                    dateTime: combined,
                    status: isEditing
                        ? widget.existingGame!.status
                        : ParticipationStatus.inGame,
                    maxPlayers: _playersCtrl.text.trim().isEmpty
                        ? null
                        : _playersCtrl.text.trim(),
                    skillLevel: _skillLevel,
                    format: resolvedFormat,
                    ballType: _ballType,
                    notes: _notesCtrl.text.trim().isEmpty
                        ? null
                        : _notesCtrl.text.trim(),
                    createdAt: isEditing
                        ? widget.existingGame!.createdAt
                        : DateTime.now(),
                    registeredBy: isEditing
                        ? widget.existingGame!.registeredBy
                        : UserService().userId,
                    organizerName: (_contactEntry?.displayName ??
                            _contactNameCtrl.text.trim())
                        .isEmpty
                        ? null
                        : (_contactEntry?.displayName ??
                            _contactNameCtrl.text.trim()),
                    organizerPhone: _contactPhoneCtrl.text.trim().isEmpty
                        ? null
                        : '$_countryCode${_contactPhoneCtrl.text.trim()}',
                    hideContact: _hideContact,
                    photoUrls: isEditing
                        ? widget.existingGame!.photoUrls
                        : const [],
                  );

                  if (isEditing) {
                    GameService().updateGame(game);
                  } else {
                    GameService().addGame(game);
                  }

                  // Upload pending photos (create mode)
                  if (_pendingPhotos.isNotEmpty) {
                    for (final file in _pendingPhotos) {
                      await GameService().uploadGamePhoto(game.id, file);
                    }
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing
                          ? 'Game updated!'
                          : 'Game registered successfully!'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.of(context).pop();
                },
                child: Text(
                  widget.existingGame != null ? 'Update Game' : 'Create Game',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Sport-specific field builder ──────────────────────────────────────────

  List<Widget> _buildSportFields() {
    final widgets = <Widget>[];

    void section(String title) {
      widgets.add(const SizedBox(height: AppSpacing.xl));
      widgets.add(_SectionHeader(title));
      widgets.add(const SizedBox(height: AppSpacing.md));
    }

    void chips(
      String label,
      List<String> opts,
      String? sel,
      ValueChanged<String> cb, {
      bool addCustom = false,
    }) {
      final allOpts = addCustom ? [...opts, 'Custom'] : opts;
      widgets.add(_Label(label));
      widgets.add(const SizedBox(height: AppSpacing.xs));
      widgets.add(_ChipSelector(options: allOpts, selected: sel, onSelect: cb));
      if (addCustom && sel == 'Custom') {
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(_InputField(
          label: 'Enter Custom Format',
          controller: _customFormatCtrl,
          hint: 'Describe your format...',
        ));
      }
      widgets.add(const SizedBox(height: AppSpacing.md));
    }

    void input(String label, TextEditingController ctrl, {String? hint, TextInputType? kb}) {
      widgets.add(_InputField(label: label, controller: ctrl, hint: hint, keyboardType: kb));
    }

    switch (widget.sport) {

      case 'Cricket':
        section('CRICKET SETTINGS');
        chips('Format', const ['T20', 'ODI', 'Test', 'T10', 'Tape Ball'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        if (_format != 'Test') {
          input('Overs', _extraCtrl1,
              hint: _format == 'T20' ? '20' : _format == 'ODI' ? '50' : _format == 'T10' ? '10' : 'Enter overs',
              kb: TextInputType.number);
        }
        input('Players per Side', _extraCtrl2, hint: '11', kb: TextInputType.number);
        break;

      case 'Football':
        section('FOOTBALL SETTINGS');
        chips('Format', const ['5-a-side', '7-a-side', '11-a-side'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        input('Match Duration (minutes)', _extraCtrl1, hint: '90', kb: TextInputType.number);
        break;

      case 'Basketball':
        section('BASKETBALL SETTINGS');
        chips('Format', const ['3×3', '5v5'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        input('Quarter Duration (minutes)', _extraCtrl1, hint: '10', kb: TextInputType.number);
        break;

      case 'Badminton':
        section('BADMINTON SETTINGS');
        chips('Category', const ['Singles', 'Doubles', 'Mixed Doubles'],
            _matchType, (v) => setState(() => _matchType = v));
        chips('Best Of', const ['Best of 1', 'Best of 3', 'Best of 5'],
            _bestOf, (v) => setState(() => _bestOf = v));
        break;

      case 'Tennis':
        section('TENNIS SETTINGS');
        chips('Category', const ['Singles', 'Doubles', 'Mixed Doubles'],
            _matchType, (v) => setState(() => _matchType = v));
        chips('Sets', const ['Best of 3', 'Best of 5'],
            _bestOf, (v) => setState(() => _bestOf = v));
        break;

      case 'Table Tennis':
        section('TABLE TENNIS SETTINGS');
        chips('Category', const ['Singles', 'Doubles'],
            _matchType, (v) => setState(() => _matchType = v));
        chips('Best Of', const ['Best of 3', 'Best of 5', 'Best of 7'],
            _bestOf, (v) => setState(() => _bestOf = v));
        break;

      case 'Volleyball':
        section('VOLLEYBALL SETTINGS');
        chips('Type', const ['Indoor', 'Beach (2v2)', 'Beach (3v3)'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        chips('Sets', const ['Best of 3', 'Best of 5'],
            _bestOf, (v) => setState(() => _bestOf = v));
        break;

      case 'Hockey':
        section('HOCKEY SETTINGS');
        chips('Type', const ['Field', 'Ice', 'Street'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        input('Match Duration (minutes)', _extraCtrl1, hint: '60', kb: TextInputType.number);
        break;

      case 'Boxing':
      case 'MMA':
      case 'Wrestling':
        section('${widget.sport.toUpperCase()} SETTINGS');
        input('Number of Rounds', _extraCtrl1,
            hint: widget.sport == 'Boxing' ? '12' : '3',
            kb: TextInputType.number);
        input('Round Duration (minutes)', _extraCtrl2, hint: '3', kb: TextInputType.number);
        break;

      case 'Running':
      case 'Cycling':
        section('${widget.sport.toUpperCase()} SETTINGS');
        input('Distance', _extraCtrl1,
            hint: widget.sport == 'Running' ? 'e.g. 5km, 10km, 21km' : 'e.g. 20km, 50km, 100km');
        chips('Format', const ['Sprint', 'Long Distance', 'Relay', 'Time Trial'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        break;

      case 'Swimming':
        section('SWIMMING SETTINGS');
        input('Distance', _extraCtrl1, hint: 'e.g. 50m, 100m, 400m');
        chips('Stroke', const ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly', 'Medley'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        break;

      case 'Baseball':
        section('BASEBALL SETTINGS');
        input('Innings', _extraCtrl1, hint: '9', kb: TextInputType.number);
        input('Players per Side', _extraCtrl2, hint: '9', kb: TextInputType.number);
        break;

      case 'Kabaddi':
      case 'Kho Kho':
        section('${widget.sport.toUpperCase()} SETTINGS');
        input('Players per Side', _extraCtrl1,
            hint: widget.sport == 'Kabaddi' ? '7' : '9',
            kb: TextInputType.number);
        input('Match Duration (minutes)', _extraCtrl2, hint: '40', kb: TextInputType.number);
        break;

      case 'CS:GO':
      case 'Valorant':
        section('${widget.sport.toUpperCase()} SETTINGS');
        chips('Format', const ['5v5', '2v2', '1v1'],
            _format, (v) => setState(() => _format = v), addCustom: true);
        chips('Match Type', const ['Best of 1', 'Best of 3', 'Best of 5'],
            _bestOf, (v) => setState(() => _bestOf = v));
        break;

      default:
        section('MATCH SETTINGS');
        input('Match Duration (minutes)', _extraCtrl1, hint: 'Enter duration', kb: TextInputType.number);
        input('Players per Side', _extraCtrl2, hint: 'Enter number', kb: TextInputType.number);
        break;
    }

    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Scroll Date Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollDateSheet extends StatefulWidget {
  final DateTime initial;
  const _ScrollDateSheet({required this.initial});

  @override
  State<_ScrollDateSheet> createState() => _ScrollDateSheetState();
}

class _ScrollDateSheetState extends State<_ScrollDateSheet> {
  late int _day;
  late int _month;
  late int _year;

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _day   = widget.initial.day;
    _month = widget.initial.month;
    _year  = widget.initial.year;

    final now = DateTime.now();
    _years = List.generate(3, (i) => now.year + i);

    final yIdx = _years.indexOf(_year);
    _dayCtrl   = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl  = FixedExtentScrollController(initialItem: yIdx < 0 ? 0 : yIdx);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int _maxDay() => DateTime(_year, _month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _Handle(),
          const SizedBox(height: 16),
          const Text(
            'Select Date',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // ── Wheels ─────────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Red highlight bar
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.55),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // Day
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _dayCtrl,
                        itemExtent: 44,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.003,
                        onSelectedItemChanged: (i) {
                          setState(() => _day = (i + 1).clamp(1, _maxDay()));
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 31,
                          builder: (_, i) => _WheelItem(
                            text: '${i + 1}',
                            selected: _day == i + 1,
                          ),
                        ),
                      ),
                    ),

                    // Month
                    Expanded(
                      flex: 2,
                      child: ListWheelScrollView.useDelegate(
                        controller: _monthCtrl,
                        itemExtent: 44,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.003,
                        onSelectedItemChanged: (i) {
                          final maxD = DateTime(_year, i + 2, 0).day;
                          setState(() {
                            _month = i + 1;
                            if (_day > maxD) _day = maxD;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12,
                          builder: (_, i) => _WheelItem(
                            text: _months[i],
                            selected: _month == i + 1,
                          ),
                        ),
                      ),
                    ),

                    // Year
                    Expanded(
                      flex: 2,
                      child: ListWheelScrollView.useDelegate(
                        controller: _yearCtrl,
                        itemExtent: 44,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.003,
                        onSelectedItemChanged: (i) => setState(() => _year = _years[i]),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _years.length,
                          builder: (_, i) => _WheelItem(
                            text: '${_years[i]}',
                            selected: _year == _years[i],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Column labels
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Center(child: Text('Day',   style: TextStyle(color: Colors.white30, fontSize: 11)))),
                Expanded(flex: 2, child: Center(child: Text('Month', style: TextStyle(color: Colors.white30, fontSize: 11)))),
                Expanded(flex: 2, child: Center(child: Text('Year',  style: TextStyle(color: Colors.white30, fontSize: 11)))),
              ],
            ),
          ),

          // Confirm
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final safe = _day.clamp(1, _maxDay());
                  Navigator.of(context).pop(DateTime(_year, _month, safe));
                },
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Scroll Time Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollTimeSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _ScrollTimeSheet({required this.initial});

  @override
  State<_ScrollTimeSheet> createState() => _ScrollTimeSheetState();
}

class _ScrollTimeSheetState extends State<_ScrollTimeSheet> {
  late int  _hour;   // 1–12
  late int  _minute; // 0–59
  late bool _isAm;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _isAm  = h < 12;
    _hour  = h % 12 == 0 ? 12 : h % 12;
    _minute = widget.initial.minute;

    _hourCtrl   = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _Handle(),
          const SizedBox(height: 16),
          const Text(
            'Select Time',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // ── Wheels ─────────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Red highlight bar (covers hour + minute columns only)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.only(left: 16, right: 88),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.55),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    // Hour wheel
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _hourCtrl,
                        itemExtent: 44,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.003,
                        onSelectedItemChanged: (i) => setState(() => _hour = i + 1),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 12,
                          builder: (_, i) => _WheelItem(
                            text: '${i + 1}'.padLeft(2, '0'),
                            selected: _hour == i + 1,
                          ),
                        ),
                      ),
                    ),

                    // Colon separator
                    const SizedBox(
                      width: 18,
                      child: Center(
                        child: Text(':',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),

                    // Minute wheel
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _minuteCtrl,
                        itemExtent: 44,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.003,
                        onSelectedItemChanged: (i) => setState(() => _minute = i),
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 60,
                          builder: (_, i) => _WheelItem(
                            text: '$i'.padLeft(2, '0'),
                            selected: _minute == i,
                          ),
                        ),
                      ),
                    ),

                    // AM / PM toggle
                    SizedBox(
                      width: 88,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AmPmBtn(
                            label: 'AM',
                            selected: _isAm,
                            onTap: () => setState(() => _isAm = true),
                          ),
                          const SizedBox(height: 10),
                          _AmPmBtn(
                            label: 'PM',
                            selected: !_isAm,
                            onTap: () => setState(() => _isAm = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Column labels
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Expanded(child: Center(child: Text('Hour',   style: TextStyle(color: Colors.white30, fontSize: 11)))),
                SizedBox(width: 18),
                Expanded(child: Center(child: Text('Minute', style: TextStyle(color: Colors.white30, fontSize: 11)))),
                SizedBox(width: 88),
              ],
            ),
          ),

          // Confirm
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final h24 = _isAm
                      ? (_hour == 12 ? 0 : _hour)
                      : (_hour == 12 ? 12 : _hour + 12);
                  Navigator.of(context).pop(TimeOfDay(hour: h24, minute: _minute));
                },
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Wheel Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WheelItem extends StatelessWidget {
  final String text;
  final bool selected;
  const _WheelItem({required this.text, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white24,
          fontSize: selected ? 18 : 15,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _AmPmBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AmPmBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : Colors.white12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Form Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SportBadge extends StatelessWidget {
  final String sport;
  final String emoji;
  const _SportBadge({required this.sport, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: AppSpacing.sm),
          Text(sport,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Selected',
                style: TextStyle(color: AppColors.primary, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ));
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13));
  }
}

class _ChipSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _ChipSelector({required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final active = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? AppColors.primary : Colors.white24),
            ),
            child: Text(opt,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        );
      }).toList(),
    );
  }
}

class _TapField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final bool hasError;

  const _TapField({
    required this.label,
    this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                border: hasError
                    ? Border.all(color: AppColors.primary, width: 1.2)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(icon, color: hasError ? AppColors.primary : AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    value ?? hint,
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.white30,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            const Text(
              'This field is required',
              style: TextStyle(color: AppColors.primary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _InputField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                borderSide: const BorderSide(color: Colors.white24, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Country Code Picker ───────────────────────────────────────────────────────

class _CountryCodePicker extends StatefulWidget {
  final String selected;
  const _CountryCodePicker({required this.selected});

  @override
  State<_CountryCodePicker> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<_CountryCodePicker> {
  static const _countries = [
    ('+91',  '🇮🇳', 'India'),
    ('+1',   '🇺🇸', 'USA / Canada'),
    ('+44',  '🇬🇧', 'United Kingdom'),
    ('+61',  '🇦🇺', 'Australia'),
    ('+64',  '🇳🇿', 'New Zealand'),
    ('+27',  '🇿🇦', 'South Africa'),
    ('+92',  '🇵🇰', 'Pakistan'),
    ('+94',  '🇱🇰', 'Sri Lanka'),
    ('+880', '🇧🇩', 'Bangladesh'),
    ('+93',  '🇦🇫', 'Afghanistan'),
    ('+263', '🇿🇼', 'Zimbabwe'),
    ('+353', '🇮🇪', 'Ireland'),
    ('+60',  '🇲🇾', 'Malaysia'),
    ('+65',  '🇸🇬', 'Singapore'),
    ('+971', '🇦🇪', 'UAE'),
    ('+968', '🇴🇲', 'Oman'),
    ('+974', '🇶🇦', 'Qatar'),
    ('+973', '🇧🇭', 'Bahrain'),
    ('+966', '🇸🇦', 'Saudi Arabia'),
    ('+49',  '🇩🇪', 'Germany'),
    ('+33',  '🇫🇷', 'France'),
    ('+39',  '🇮🇹', 'Italy'),
    ('+34',  '🇪🇸', 'Spain'),
    ('+31',  '🇳🇱', 'Netherlands'),
    ('+81',  '🇯🇵', 'Japan'),
    ('+86',  '🇨🇳', 'China'),
    ('+82',  '🇰🇷', 'South Korea'),
    ('+55',  '🇧🇷', 'Brazil'),
    ('+52',  '🇲🇽', 'Mexico'),
  ];

  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _countries
        .where((c) =>
            c.$1.contains(_search) ||
            c.$3.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),
        const Text('Select Country Code',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search country...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
              filled: true,
              fillColor: const Color(0xFF222222),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final c = filtered[i];
              final isSel = c.$1 == widget.selected;
              return ListTile(
                leading: Text(c.$2,
                    style: const TextStyle(fontSize: 22)),
                title: Text(c.$3,
                    style: TextStyle(
                        color: isSel ? AppColors.primary : Colors.white,
                        fontSize: 14,
                        fontWeight: isSel
                            ? FontWeight.w700
                            : FontWeight.normal)),
                trailing: Text(c.$1,
                    style: TextStyle(
                        color: isSel ? AppColors.primary : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, c.$1),
              );
            },
          ),
        ),
      ],
    );
  }
}
