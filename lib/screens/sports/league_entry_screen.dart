import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../premium/premium_screen.dart';

/// Full tournament creation / edit form — submits directly to Firestore.
class LeagueEntryScreen extends StatefulWidget {
  /// Pass an existing tournament to pre-fill the form for editing.
  final Tournament? existingTournament;

  const LeagueEntryScreen({super.key, this.existingTournament});

  @override
  State<LeagueEntryScreen> createState() => _LeagueEntryScreenState();
}

class _LeagueEntryScreenState extends State<LeagueEntryScreen> {
  final _nameCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _entryFeeCtrl = TextEditingController();
  final _prizeCtrl    = TextEditingController();
  final _rulesCtrl    = TextEditingController();

  String    _sport   = 'Cricket';
  String    _format  = 'Knockout';
  DateTime? _startDate;
  DateTime? _endDate;
  String?   _error;
  bool      _loading = false;

  // ── Max Teams ──────────────────────────────────────────────────────────────
  bool _noTeamLimit = false;
  int  _maxTeams    = 4;

  // ── Players Per Team ────────────────────────────────────────────────────────
  bool _noPlayerLimit = false;
  int  _playersPerTeam = 11;

  // ── Registration Fee ────────────────────────────────────────────────────────
  bool _freeEntry = true;

  // ── Banner ─────────────────────────────────────────────────────────────────
  File?   _bannerImage;
  String? _existingBannerUrl;

  bool get _isEditMode => widget.existingTournament != null;

  static const _sports  = [
    'Cricket', 'Football', 'Throwball', 'Handball',
    'Basketball', 'Badminton', 'Tennis', 'Volleyball',
    'Kabaddi', 'Hockey', 'Boxing', 'Chess', 'Other',
  ];
  static const _formats = ['Knockout', 'Round Robin', 'League'];

  bool get _isPremium => UserService().profile?.isPremium == true;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTournament;
    if (t != null) {
      _nameCtrl.text     = t.name;
      _locationCtrl.text = t.location;
      _sport             = _sports.contains(t.sport) ? t.sport : 'Other';
      _startDate         = t.startDate;
      _endDate           = t.endDate;
      _maxTeams          = t.maxTeams == 0 ? 4 : t.maxTeams;
      _noTeamLimit       = t.maxTeams == 0;
      _playersPerTeam    = t.playersPerTeam == 0 ? _sportDefaultPlayers(t.sport) : t.playersPerTeam;
      _noPlayerLimit     = t.playersPerTeam == 0;
      _freeEntry         = t.entryFee == 0;
      if (t.entryFee > 0) _entryFeeCtrl.text = t.entryFee.toStringAsFixed(0);
      _prizeCtrl.text    = t.prizePool ?? '';
      _rulesCtrl.text    = t.rules ?? '';
      // Format
      const fmtMap = {
        TournamentFormat.knockout:       'Knockout',
        TournamentFormat.roundRobin:     'Round Robin',
        TournamentFormat.leagueKnockout: 'League',
      };
      _format             = fmtMap[t.format] ?? 'Knockout';
      _existingBannerUrl  = t.bannerUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _entryFeeCtrl.dispose();
    _prizeCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd
        ? (_endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 1)))
        : (_startDate ?? DateTime.now().add(const Duration(days: 7)));
    final first = isEnd
        ? (_startDate ?? DateTime.now()).add(const Duration(days: 1))
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isEnd) {
          _endDate = picked;
        } else {
          _startDate = picked;
          // Reset end date if it's now before start date
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        }
      });
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (xfile != null) {
      setState(() => _bannerImage = File(xfile.path));
    }
  }

  void _requirePremium(String reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Premium Required',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(reason,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            child: const Text('Upgrade',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name     = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a tournament name.'); return;
    }
    if (location.isEmpty) {
      setState(() => _error = 'Please enter a location.'); return;
    }
    if (_startDate == null) {
      setState(() => _error = 'Please select a start date.'); return;
    }
    if (!_freeEntry) {
      final feeText = _entryFeeCtrl.text.trim();
      if (feeText.isEmpty || double.tryParse(feeText) == null) {
        setState(() => _error = 'Please enter a valid entry fee amount.'); return;
      }
    }
    if (_noTeamLimit && !_isPremium) {
      _requirePremium('Unlimited teams requires a Premium account.');
      return;
    }
    if (!_noTeamLimit && _maxTeams > 4 && !_isPremium) {
      _requirePremium('More than 4 teams requires a Premium account.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final entryFee   = _freeEntry ? 0.0
          : (double.tryParse(_entryFeeCtrl.text.trim()) ?? 0.0);
      final serviceFee = entryFee > 0 ? (entryFee * 0.05).roundToDouble() : 0.0;
      final maxTeams   = _noTeamLimit ? 0 : _maxTeams;
      final playersPerTeam = _noPlayerLimit ? 0 : _playersPerTeam;

      final formatMap = {
        'Knockout':    TournamentFormat.knockout,
        'Round Robin': TournamentFormat.roundRobin,
        'League':      TournamentFormat.leagueKnockout,
      };

      if (_isEditMode) {
        final tid = widget.existingTournament!.id;
        await TournamentService().updateTournament(
          tournamentId:   tid,
          name:           name,
          sport:          _sport,
          format:         formatMap[_format] ?? TournamentFormat.knockout,
          startDate:      _startDate!,
          endDate:        _endDate,
          location:       location,
          maxTeams:       maxTeams,
          entryFee:       entryFee,
          serviceFee:     serviceFee,
          prizePool:      _prizeCtrl.text.trim().isEmpty ? null : _prizeCtrl.text.trim(),
          playersPerTeam: playersPerTeam,
          rules:          _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
        );
        // Upload new banner if host picked one
        if (_bannerImage != null) {
          try {
            await TournamentService().uploadBanner(tid, _bannerImage!);
          } catch (_) {
            // non-fatal
          }
        }
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pop(context, true);
        return;
      }

      final id = await TournamentService().createTournament(
        name:           name,
        sport:          _sport,
        format:         formatMap[_format] ?? TournamentFormat.knockout,
        startDate:      _startDate!,
        endDate:        _endDate,
        location:       location,
        maxTeams:       maxTeams,
        entryFee:       entryFee,
        serviceFee:     serviceFee,
        scheduleMode:   ScheduleMode.auto,
        prizePool:      _prizeCtrl.text.trim().isEmpty ? null : _prizeCtrl.text.trim(),
        playersPerTeam: playersPerTeam,
        rules:          _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
      );

      // Upload banner if selected
      if (_bannerImage != null) {
        try {
          await TournamentService().uploadBanner(id, _bannerImage!);
        } catch (_) {
          // Banner upload failure is non-fatal
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Tournament Created!',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(
            '"$name" is now live. Teams can start enrolling.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, elevation: 0),
              onPressed: () {
                Navigator.pop(context);       // close dialog
                Navigator.pop(context, true); // pop LeagueEntryScreen → home switches to Tournaments tab
              },
              child: const Text('View Tournaments',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } on PremiumRequiredException catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_isEditMode ? 'Edit Tournament' : 'Host Tournament',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
            const Text('Fill in the details to create your tournament',
                style: TextStyle(color: Colors.white54, fontSize: 13)),

            const SizedBox(height: 28),

            // ── Tournament Name ────────────────────────────────────────────
            _label('Tournament Name'),
            _field(_nameCtrl, 'e.g. Summer Cricket Cup 2025',
                Icons.emoji_events_outlined),

            const SizedBox(height: 16),

            // ── Sport ──────────────────────────────────────────────────────
            _label('Sport'),
            _dropdown(
              value: _sport,
              items: _sports,
              onChanged: (v) => setState(() {
                _sport = v!;
                if (!_noPlayerLimit) {
                  _playersPerTeam = _sportDefaultPlayers(_sport);
                }
              }),
              icon: Icons.sports_cricket_outlined,
            ),

            const SizedBox(height: 16),

            // ── Format ────────────────────────────────────────────────────
            _label('Format'),
            _dropdown(
              value: _format,
              items: _formats,
              onChanged: (v) => setState(() => _format = v!),
              icon: Icons.format_list_bulleted,
            ),

            const SizedBox(height: 16),

            // ── Start & End Date ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Start Date'),
                      _datePicker(
                        date: _startDate,
                        hint: 'Select start',
                        onTap: () => _pickDate(isEnd: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('End Date'),
                      _datePicker(
                        date: _endDate,
                        hint: 'Select end',
                        onTap: () => _pickDate(isEnd: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Location ──────────────────────────────────────────────────
            _label('Location / Venue'),
            _field(_locationCtrl, 'e.g. DY Patil Stadium, Mumbai',
                Icons.location_on_outlined),

            const SizedBox(height: 16),

            // ── Banner Image ──────────────────────────────────────────────
            _label('Banner Image (optional)'),
            GestureDetector(
              onTap: _pickBanner,
              child: _bannerImage != null
                  // newly picked file
                  ? Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_bannerImage!,
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _bannerImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ])
                  : _existingBannerUrl != null
                      // existing uploaded banner (edit mode)
                      ? Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _existingBannerUrl!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(),
                            ),
                          ),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, color: Colors.white,
                                      size: 12),
                                  SizedBox(width: 4),
                                  Text('Tap to change',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ])
                      // no banner yet
                      : Container(
                          width: double.infinity,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white12, width: 1.5),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white38, size: 28),
                              SizedBox(height: 4),
                              Text('Tap to upload banner',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
            ),

            const SizedBox(height: 20),

            // ── Max Teams ─────────────────────────────────────────────────
            _sectionCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_outlined,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Max Teams',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text('Free tier: up to 4 teams',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Text('No Limit',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 4),
                    Switch(
                      value: _noTeamLimit,
                      onChanged: (v) {
                        if (v && !_isPremium) {
                          _requirePremium(
                              'Unlimited teams requires a Premium account.');
                          return;
                        }
                        setState(() => _noTeamLimit = v);
                      },
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                if (!_noTeamLimit) ...[
                  const SizedBox(height: 8),
                  _stepper(
                    value: _maxTeams,
                    min: 2,
                    max: _isPremium ? 64 : 4,
                    onDecrement: () =>
                        setState(() { if (_maxTeams > 2) _maxTeams--; }),
                    onIncrement: () {
                      if (!_isPremium && _maxTeams >= 4) {
                        _requirePremium(
                            'More than 4 teams requires a Premium account.');
                        return;
                      }
                      setState(() => _maxTeams++);
                    },
                    label: '$_maxTeams teams',
                  ),
                  if (!_isPremium && _maxTeams == 4)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: AppColors.primary, size: 12),
                          SizedBox(width: 4),
                          Text('Upgrade to add more than 4 teams',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 11)),
                        ],
                      ),
                    ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Unlimited teams can join',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Players Per Team ──────────────────────────────────────────
            _sectionCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outlined,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Players Per Team',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text('Including bench / substitutes',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Text('No Limit',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 4),
                    Switch(
                      value: _noPlayerLimit,
                      onChanged: (v) =>
                          setState(() => _noPlayerLimit = v),
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                if (!_noPlayerLimit) ...[
                  const SizedBox(height: 8),
                  _stepper(
                    value: _playersPerTeam,
                    min: 1,
                    max: 30,
                    onDecrement: () => setState(
                        () { if (_playersPerTeam > 1) _playersPerTeam--; }),
                    onIncrement: () => setState(
                        () { if (_playersPerTeam < 30) _playersPerTeam++; }),
                    label: '$_playersPerTeam players',
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Teams can add any number of players',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Registration Fee ──────────────────────────────────────────
            _sectionCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_rupee_outlined,
                        color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Registration Fee',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Text('Free',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 4),
                    Switch(
                      value: _freeEntry,
                      onChanged: (v) => setState(() => _freeEntry = v),
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                if (_freeEntry)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Free enrollment — no entry fee',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)),
                  )
                else ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _entryFeeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Entry fee amount (₹)',
                      hintStyle: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.currency_rupee,
                          color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_entryFeeCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Builder(builder: (ctx) {
                      final fee =
                          double.tryParse(_entryFeeCtrl.text.trim()) ?? 0;
                      final svc = (fee * 0.05).roundToDouble();
                      return Text(
                        'App service fee (5%): ₹${svc.toInt()}  ·  '
                        'Total per team: ₹${(fee + svc).toInt()}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      );
                    }),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Prize Pool ────────────────────────────────────────────────
            _label('Prize Pool (optional)'),
            _field(_prizeCtrl,
                'e.g. ₹10,000 cash + trophy', Icons.emoji_events_outlined),

            const SizedBox(height: 16),

            // ── Rules ─────────────────────────────────────────────────────
            _label('Rules & Regulations (optional)'),
            TextField(
              controller: _rulesCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'Enter tournament rules, format details, tie-breaker rules...',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade400, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            // ── Submit button ─────────────────────────────────────────────
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
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditMode ? 'Save Changes' : 'Create Tournament',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _sportDefaultPlayers(String sport) {
    switch (sport) {
      case 'Cricket':    return 11;
      case 'Football':   return 11;
      case 'Basketball': return 5;
      case 'Volleyball': return 6;
      case 'Badminton':  return 2;
      case 'Tennis':     return 2;
      default:           return 5;
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  Widget _datePicker({
    required DateTime? date,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  date == null
                      ? hint
                      : '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/'
                        '${date.year}',
                  style: TextStyle(
                    color: date == null ? Colors.white38 : Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _sectionCard({required List<Widget> children}) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _stepper({
    required int value,
    required int min,
    required int max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required String label,
  }) =>
      Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: value <= min ? Colors.white24 : Colors.white54,
              size: 22,
            ),
            onPressed: value <= min ? null : onDecrement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: (value >= max && _isPremium) || (value >= max)
                  ? Colors.white24
                  : AppColors.primary,
              size: 22,
            ),
            onPressed: onIncrement,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
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
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5),
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
                style:
                    const TextStyle(color: Colors.white, fontSize: 15),
                items: items
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
}
