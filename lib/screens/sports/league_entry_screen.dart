import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/models/tournament.dart';
import '../../data/sports_list.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../premium/premium_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../../core/config/app_config.dart';
import '../../widgets/tournament_format_picker.dart';
import '../../widgets/date_range_picker_sheet.dart';
import '../../widgets/address_autocomplete_field.dart';

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
  TournamentFormat _format = TournamentFormat.leagueKnockout;
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

  // ── Scoring System ─────────────────────────────────────────────────────────
  ScoringType _scoringType = ScoringType.standard;
  // Best of sets: 3 / 5 / 7 / -1 (custom)
  int  _bestOf      = 3;
  final _bestOfCustomCtrl = TextEditingController();
  // Standard score: points to win per game — 11 / 15 / 21 / 25 / -1 (custom)
  int  _pointsToWin = 21;
  final _pointsToWinCustomCtrl = TextEditingController();
  int  _winPoints   = 3;
  int  _drawPoints  = 1;
  final int  _lossPoints  = 0; // always 0 — no points for losing
  final _customScoringCtrl = TextEditingController();

  // ── Round-specific scoring ─────────────────────────────────────────────────
  bool _sameScoreAllRounds = true;
  // Each round stores: scoringType, bestOf, pointsToWin, customLabel
  final Map<String, _RoundScore> _roundScores = {
    'quarters': _RoundScore(),
    'semis':    _RoundScore(),
    'final':    _RoundScore(),
  };

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

  bool get _isPremium => UserService().hasFullAccess;

  int get _effectiveBestOf =>
      _bestOf == -1 ? (int.tryParse(_bestOfCustomCtrl.text.trim()) ?? 3) : _bestOf;

  int get _effectivePointsToWin =>
      _pointsToWin == -1 ? (int.tryParse(_pointsToWinCustomCtrl.text.trim()) ?? 21) : _pointsToWin;


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
      // Format — use enum value directly
      _format             = t.format;
      _existingBannerUrl  = t.bannerUrl;
      _scoringType        = (t.scoringType == ScoringType.custom)
          ? ScoringType.standard
          : t.scoringType;
      _bestOf             = t.bestOf;
      _winPoints          = t.winPoints;
      _drawPoints         = t.drawPoints;
      _customScoringCtrl.text = t.customScoringLabel ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _entryFeeCtrl.dispose();
    _prizeCtrl.dispose();
    _rulesCtrl.dispose();
    _customScoringCtrl.dispose();
    _bestOfCustomCtrl.dispose();
    _pointsToWinCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showCustomDateRangePicker(
      context: context,
      initialStart: _startDate,
      initialEnd: _endDate,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate   = picked.end;
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

  Future<void> _showBannerOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white70),
              title: const Text('Upload from Gallery',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () { Navigator.pop(ctx); _pickBanner(); },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome,
                  color: AppColors.primary),
              title: const Text('Generate with AI',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14)),
              subtitle: const Text('Describe your banner and we\'ll create it',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              onTap: () { Navigator.pop(ctx); _showAiBannerSheet(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAiBannerSheet() async {
    final suggestion = [
      if (_nameCtrl.text.trim().isNotEmpty) _nameCtrl.text.trim(),
      _sport,
      'sports tournament',
    ].join(' ');

    final result = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiBannerSheet(promptSuggestion: suggestion),
    );

    if (result != null && mounted) {
      setState(() => _bannerImage = result);
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

      if (_isEditMode) {
        final tid = widget.existingTournament!.id;
        await TournamentService().updateTournament(
          tournamentId:   tid,
          name:           name,
          sport:          _sport,
          format:         _format,
          startDate:      _startDate!,
          endDate:        _endDate,
          location:       location,
          maxTeams:       maxTeams,
          entryFee:       entryFee,
          serviceFee:     serviceFee,
          prizePool:      _prizeCtrl.text.trim().isEmpty ? null : _prizeCtrl.text.trim(),
          playersPerTeam: playersPerTeam,
          rules:          _rulesCtrl.text.trim().isEmpty ? null : _rulesCtrl.text.trim(),
          scoringType:    _scoringType,
          bestOf:         _effectiveBestOf,
          pointsToWin:    _effectivePointsToWin,
          winPoints:      _winPoints,
          drawPoints:     _drawPoints,
          lossPoints:     _lossPoints,
          customScoringLabel: _customScoringCtrl.text.trim().isEmpty
              ? null : _customScoringCtrl.text.trim(),
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
        format:         _format,
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
        scoringType:    _scoringType,
        bestOf:         _bestOf,
        pointsToWin:    _pointsToWin,
        winPoints:      _winPoints,
        drawPoints:     _drawPoints,
        lossPoints:     _lossPoints,
        customScoringLabel: _customScoringCtrl.text.trim().isEmpty
            ? null : _customScoringCtrl.text.trim(),
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
                Navigator.pop(context, true); // pop LeagueEntryScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentDetailScreen(tournamentId: id),
                  ),
                );
              },
              child: const Text('View Tournament',
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
            GestureDetector(
              onTap: _showSportPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      _sportEmoji(_sport),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _sport,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white38, size: 22),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Format ────────────────────────────────────────────────────
            TournamentFormatPicker(
              selected:  _format,
              onChanged: (f) => setState(() => _format = f),
            ),

            const SizedBox(height: 16),

            // ── Scoring System ──────────────────────────────────────────
            _label('Scoring System'),
            _buildScoringSection(),

            if (_hasNamedRounds) ...[
              const SizedBox(height: 12),
              _label('Round Scoring'),
              _buildRoundScoringSection(),
            ],

            const SizedBox(height: 16),

            // ── Tournament Dates ──────────────────────────────────────────
            _label('Tournament Dates'),
            _dateRangePicker(
              start: _startDate,
              end: _endDate,
              onTap: _pickDateRange,
            ),

            const SizedBox(height: 16),

            // ── Location ──────────────────────────────────────────────────
            AddressAutocompleteField(
              controller: _locationCtrl,
              label: 'Location / Venue',
              hint: 'e.g. DY Patil Stadium, Mumbai',
            ),

            const SizedBox(height: 16),

            // ── Banner Image ──────────────────────────────────────────────
            _label('Banner Image (optional)'),
            if (_bannerImage != null)
              // Newly picked / AI-generated file
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_bannerImage!,
                      width: double.infinity, height: 130, fit: BoxFit.cover),
                ),
                // Close (remove)
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _bannerImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // Change
                Positioned(
                  bottom: 8, right: 8,
                  child: GestureDetector(
                    onTap: _showBannerOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Change',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ])
            else if (_existingBannerUrl != null)
              // Existing uploaded banner (edit mode)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _existingBannerUrl!,
                    width: double.infinity, height: 130, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
                Positioned(
                  bottom: 8, right: 8,
                  child: GestureDetector(
                    onTap: _showBannerOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('Change',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ])
            else
              // No banner yet — show Upload + AI options
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickBanner,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              color: Colors.white38, size: 22),
                          SizedBox(height: 4),
                          Text('Upload Image',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _showAiBannerSheet,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome,
                              color: AppColors.primary, size: 22),
                          SizedBox(height: 4),
                          Text('Generate with AI',
                              style: TextStyle(
                                  color: AppColors.primary, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),

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
                    // PRO badge next to "No Limit" when non-premium
                    if (!_isPremium) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: const Text('PRO',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8)),
                      ),
                      const SizedBox(width: 6),
                    ],
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
                  const SizedBox(height: 10),

                  // Stepper with locked + button
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: _maxTeams <= 2
                                ? Colors.white24
                                : Colors.white54,
                            size: 26),
                        onPressed: _maxTeams <= 2
                            ? null
                            : () => setState(() => _maxTeams--),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      Text('$_maxTeams teams',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),

                      // + button: shows lock icon when non-premium & at limit
                      GestureDetector(
                        onTap: () {
                          if (!_isPremium && _maxTeams >= 4) {
                            _requirePremium(
                                'More than 4 teams requires a Premium account.');
                            return;
                          }
                          if (_maxTeams < (_isPremium ? 64 : 4)) {
                            setState(() => _maxTeams++);
                          }
                        },
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: (!_isPremium && _maxTeams >= 4)
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: (!_isPremium && _maxTeams >= 4)
                                ? Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.5))
                                : null,
                          ),
                          child: Icon(
                            (!_isPremium && _maxTeams >= 4)
                                ? Icons.lock_outline
                                : Icons.add_circle_outline,
                            color: (!_isPremium && _maxTeams >= 4)
                                ? AppColors.primary
                                : (_maxTeams >= (_isPremium ? 64 : 4)
                                    ? Colors.white24
                                    : AppColors.primary),
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Upgrade banner — shown when at the free limit
                  if (!_isPremium && _maxTeams >= 4) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _requirePremium(
                          'More than 4 teams requires a Premium account.'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.05),
                          ]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.workspace_premium,
                              color: AppColors.primary, size: 15),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Upgrade to Premium to host more teams or use No Limit',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              color: AppColors.primary, size: 14),
                        ]),
                      ),
                    ),
                  ],
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Unlimited teams can join',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
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

  // ── Sport picker ─────────────────────────────────────────────────────────

  String _sportEmoji(String name) {
    for (final s in allSports) {
      if (s.name == name) return s.emoji;
    }
    return '🏅';
  }

  void _showSportPicker() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => _SportPickerSheet(controller: scrollCtrl),
      ),
    ).then((selected) {
      if (selected != null) {
        setState(() {
          _sport = selected;
          if (!_noPlayerLimit) {
            _playersPerTeam = _sportDefaultPlayers(_sport);
          }
          // Reset draw points for sports where draws are impossible
          if (!_sportAllowsDraws(_sport)) {
            _drawPoints = 0;
          }
          // Smart scoring defaults per sport family
          _scoringType  = _defaultScoringType(_sport);
          _bestOf       = 3;
          _pointsToWin  = _defaultPointsToWin(_sport);
        });
      }
    });
  }

  // ── Scoring section builder ──────────────────────────────────────────────

  Widget _buildScoringSection() {
    final types = _relevantScoringTypes(_sport);
    const labels = {
      ScoringType.standard: 'Standard Score',
      ScoringType.bestOfSets: 'Best of Sets',
      ScoringType.points: 'Points System',
    };
    final subtitles = {
      ScoringType.standard: 'Single game score (goals, runs, etc.)',
      ScoringType.bestOfSets: 'Best of 3 / 5 / 7 sets',
      ScoringType.points: _sportAllowsDraws(_sport)
          ? 'Win / Draw / Loss points'
          : 'Win / Loss points',
    };
    const icons = {
      ScoringType.standard: Icons.scoreboard_outlined,
      ScoringType.bestOfSets: Icons.format_list_numbered,
      ScoringType.points: Icons.star_outline,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type selector chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((t) {
            final selected = _scoringType == t;
            return GestureDetector(
              onTap: () => setState(() => _scoringType = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withAlpha(30)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.white12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icons[t], size: 16,
                        color: selected ? AppColors.primary : Colors.white38),
                    const SizedBox(width: 8),
                    Text(labels[t]!,
                        style: TextStyle(
                            color: selected ? AppColors.primary : Colors.white70,
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(subtitles[_scoringType] ?? '',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),

        // Best of sets config
        if (_scoringType == ScoringType.bestOfSets) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Best of', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 12),
              for (final n in [3, 5, 7])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _bestOf = n),
                    child: _PresetChip(label: '$n', selected: _bestOf == n),
                  ),
                ),
              GestureDetector(
                onTap: () => setState(() {
                  _bestOf = -1;
                  _bestOfCustomCtrl.clear();
                }),
                child: _PresetChip(
                  label: 'Custom',
                  selected: _bestOf == -1,
                  isCustom: true,
                ),
              ),
            ],
          ),
          if (_bestOf == -1) ...[
            const SizedBox(height: 10),
            _CustomNumberField(
              controller: _bestOfCustomCtrl,
              hint: 'Enter number of sets (e.g. 9)',
            ),
          ],
        ],

        // Standard score — points to win (shown for all sports)
        if (_scoringType == ScoringType.standard) ...[
          const SizedBox(height: 12),
          const Text('Points to win', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in [11, 16, 21])
                GestureDetector(
                  onTap: () => setState(() => _pointsToWin = n),
                  child: _PresetChip(label: '$n', selected: _pointsToWin == n),
                ),
              GestureDetector(
                onTap: () => setState(() {
                  _pointsToWin = -1;
                  _pointsToWinCustomCtrl.clear();
                }),
                child: _PresetChip(
                  label: 'Custom',
                  selected: _pointsToWin == -1,
                  isCustom: true,
                ),
              ),
            ],
          ),
          if (_pointsToWin == -1) ...[
            const SizedBox(height: 10),
            _CustomNumberField(
              controller: _pointsToWinCustomCtrl,
              hint: 'Enter points to win (e.g. 30)',
            ),
          ],
        ],

        // Points system config
        if (_scoringType == ScoringType.points) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _pointField('Win', _winPoints, (v) => setState(() => _winPoints = v)),
              if (_sportAllowsDraws(_sport)) ...[
                const SizedBox(width: 12),
                _pointField('Draw', _drawPoints, (v) => setState(() => _drawPoints = v)),
              ],
            ],
          ),
        ],

      ],
    );
  }

  // ── Round-specific scoring section ───────────────────────────────────────

  /// Only shown for knockout / league-knockout formats (which have Quarters,
  /// Semis, and Final rounds). League / round-robin have no named rounds.
  bool get _hasNamedRounds =>
      _format == TournamentFormat.knockout ||
      _format == TournamentFormat.leagueKnockout;

  Widget _buildRoundScoringSection() {
    if (!_hasNamedRounds) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "Same scoring for all rounds" toggle ──────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Same scoring for all rounds',
                        style: TextStyle(color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Use the main scoring config for every round',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: _sameScoreAllRounds,
                onChanged: (v) => setState(() => _sameScoreAllRounds = v),
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),

        // ── Per-round cards (visible when toggle is OFF) ──────────────────
        if (!_sameScoreAllRounds) ...[
          const SizedBox(height: 12),
          for (final entry in _roundScores.entries) ...[
            _RoundScoringCard(
              roundKey:  entry.key,
              roundData: entry.value,
              sport:     _sport,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _pointField(String label, int value, ValueChanged<int> onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () { if (value > 0) onChanged(value - 1); },
                  child: const Icon(Icons.remove, color: Colors.white38, size: 18),
                ),
                Expanded(
                  child: Text('$value',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onTap: () => onChanged(value + 1),
                  child: const Icon(Icons.add, color: AppColors.primary, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Smart default scoring type based on sport family.
  ScoringType _defaultScoringType(String sport) {
    const setSports = {
      'Badminton', 'Tennis', 'Table Tennis', 'Volleyball',
      'Squash', 'Padel', 'Beach Volleyball',
    };
    const fieldSports = {
      'Football', 'Rugby', 'Hockey', 'Handball',
      'Throwball', 'Futsal', 'Kabaddi', 'Lacrosse',
    };
    if (setSports.contains(sport))   return ScoringType.bestOfSets;
    if (fieldSports.contains(sport)) return ScoringType.points;
    // Cricket, Baseball, Basketball, etc. — standard score by default
    return ScoringType.standard;
  }

  /// Only show scoring types that make sense for the selected sport.
  List<ScoringType> _relevantScoringTypes(String sport) {
    // Rally/racket sports: Best of Sets is primary; standard is secondary option
    const setSports = {
      'Badminton', 'Tennis', 'Table Tennis', 'Volleyball',
      'Squash', 'Padel', 'Beach Volleyball',
    };
    // Innings/run-based sports: only standard score makes sense (no sets, no standings points per match)
    const inningsSports = {
      'Cricket', 'Baseball', 'Softball',
    };
    // Team/field sports where a points-system (Win/Draw/Loss) is also valid for standings
    const fieldSports = {
      'Football', 'Rugby', 'Hockey', 'Handball',
      'Throwball', 'Futsal', 'Kabaddi', 'Lacrosse',
    };
    if (setSports.contains(sport))    return [ScoringType.bestOfSets, ScoringType.standard];
    if (inningsSports.contains(sport)) return [ScoringType.standard];
    if (fieldSports.contains(sport))  return [ScoringType.standard, ScoringType.points];
    // Basketball, Athletics, Swimming, etc. — score-based only
    return [ScoringType.standard];
  }

  /// Sports where draws are impossible (rally = someone always wins,
  /// combat = winner declared, chess included as decisive games dominate
  /// tournament play).
  /// Sport-specific default points to win a game.
  int _defaultPointsToWin(String sport) {
    switch (sport) {
      case 'Table Tennis': return 11;
      case 'Badminton':    return 21;
      case 'Volleyball':   return 25;
      case 'Squash':       return 11;
      default:             return 21;
    }
  }

  bool _sportAllowsDraws(String sport) {
    const noDrawSports = {
      'Badminton', 'Tennis', 'Table Tennis', 'Volleyball',
      'Squash', 'Padel', 'Beach Volleyball',     // rally
      'Boxing', 'MMA', 'Wrestling', 'Fencing',   // combat
    };
    return !noDrawSports.contains(sport);
  }

  int _sportDefaultPlayers(String sport) {
    switch (sport) {
      case 'Cricket':          return 11;
      case 'Football':         return 11;
      case 'Basketball':       return 5;
      case 'Volleyball':       return 6;
      case 'Badminton':        return 2;
      case 'Tennis':           return 2;
      case 'Table Tennis':     return 1;
      case 'Handball':         return 7;
      case 'Throwball':        return 7;
      case 'Kabaddi':          return 7;
      case 'Hockey':           return 11;
      case 'Boxing':           return 1;
      case 'Chess':            return 1;
      default:                 return 5;
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  static String _fmt(DateTime d) =>
      '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';

  static const _kMonths = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  Widget _dateRangePicker({
    required DateTime? start,
    required DateTime? end,
    required VoidCallback onTap,
  }) {
    final bool hasRange = start != null;
    // Treat null end (or end == start) as a single-day selection
    final DateTime? effectiveEnd = (end == null) ? start : end;
    final bool sameDay = hasRange &&
        start.year == effectiveEnd!.year &&
        start.month == effectiveEnd.month &&
        start.day == effectiveEnd.day;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasRange ? AppColors.primary.withValues(alpha: 0.4) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: hasRange ? AppColors.primary : Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: hasRange
                  ? sameDay
                      // Single day
                      ? Text(_fmt(start),
                          style: const TextStyle(color: Colors.white, fontSize: 13))
                      // Range
                      : Row(children: [
                          Text(_fmt(start),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward,
                                color: AppColors.primary, size: 14),
                          ),
                          Text(_fmt(effectiveEnd!),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ])
                  : const Text('Tap to select dates',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_calendar_outlined,
                color: hasRange ? AppColors.primary : Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

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

// ── Round score data holder ───────────────────────────────────────────────────

class _RoundScore {
  ScoringType scoringType         = ScoringType.bestOfSets;
  int         bestOf              = 3;    // -1 = custom
  int         pointsToWin        = 21;   // -1 = custom
  final bestOfCustomCtrl          = TextEditingController();
  final pointsToWinCustomCtrl     = TextEditingController();
}

// ── Per-round scoring card ────────────────────────────────────────────────────

class _RoundScoringCard extends StatefulWidget {
  const _RoundScoringCard({
    required this.roundKey,
    required this.roundData,
    required this.sport,
    required this.onChanged,
  });

  final String      roundKey;
  final _RoundScore roundData;
  final String      sport;
  final VoidCallback onChanged;

  @override
  State<_RoundScoringCard> createState() => _RoundScoringCardState();
}

class _RoundScoringCardState extends State<_RoundScoringCard> {
  bool _expanded = false;

  static const _roundLabels = {
    'quarters': 'Quarter-Finals',
    'semis':    'Semi-Finals',
    'final':    'Final',
  };

  static const _roundIcons = {
    'quarters': Icons.looks_4_outlined,
    'semis':    Icons.looks_two_outlined,
    'final':    Icons.emoji_events_outlined,
  };

  List<ScoringType> _types() {
    const rally = {'Badminton', 'Tennis', 'Table Tennis', 'Volleyball', 'Squash'};
    if (rally.contains(widget.sport)) {
      return [ScoringType.bestOfSets, ScoringType.standard];
    }
    const goal = {'Football', 'Soccer', 'Hockey', 'Handball', 'Basketball'};
    if (goal.contains(widget.sport)) {
      return [ScoringType.standard, ScoringType.points];
    }
    return ScoringType.values.where((t) => t != ScoringType.custom).toList();
  }

  @override
  Widget build(BuildContext context) {
    final d      = widget.roundData;
    final label  = _roundLabels[widget.roundKey] ?? widget.roundKey;
    final icon   = _roundIcons[widget.roundKey]  ?? Icons.sports;
    final types  = _types();

    const typeLabels = {
      ScoringType.standard:   'Standard',
      ScoringType.bestOfSets: 'Best of Sets',
      ScoringType.points:     'Points',
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(typeLabels[d.scoringType] ?? '',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),

          // ── Expanded config ──────────────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white12, height: 16),

                  // Scoring type chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: types.map((t) {
                      final selected = d.scoringType == t;
                      return GestureDetector(
                        onTap: () {
                          setState(() => d.scoringType = t);
                          widget.onChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.white24),
                          ),
                          child: Text(typeLabels[t] ?? '',
                              style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),

                  // Best of N (only for bestOfSets)
                  if (d.scoringType == ScoringType.bestOfSets) ...[
                    const SizedBox(height: 12),
                    const Text('Best of',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ...[3, 5, 7].map((n) {
                          final sel = d.bestOf == n;
                          return GestureDetector(
                            onTap: () {
                              setState(() => d.bestOf = n);
                              widget.onChanged();
                            },
                            child: _PresetChip(label: '$n', selected: sel),
                          );
                        }),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              d.bestOf = -1;
                              d.bestOfCustomCtrl.clear();
                            });
                            widget.onChanged();
                          },
                          child: _PresetChip(
                              label: 'Custom',
                              selected: d.bestOf == -1,
                              isCustom: true),
                        ),
                      ],
                    ),
                    if (d.bestOf == -1) ...[
                      const SizedBox(height: 8),
                      _CustomNumberField(
                        controller: d.bestOfCustomCtrl,
                        hint: 'Enter number of sets (e.g. 9)',
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Points to win a set',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ...[11, 15, 21, 25].map((n) {
                          final sel = d.pointsToWin == n;
                          return GestureDetector(
                            onTap: () {
                              setState(() => d.pointsToWin = n);
                              widget.onChanged();
                            },
                            child: _PresetChip(label: '$n', selected: sel),
                          );
                        }),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              d.pointsToWin = -1;
                              d.pointsToWinCustomCtrl.clear();
                            });
                            widget.onChanged();
                          },
                          child: _PresetChip(
                              label: 'Custom',
                              selected: d.pointsToWin == -1,
                              isCustom: true),
                        ),
                      ],
                    ),
                    if (d.pointsToWin == -1) ...[
                      const SizedBox(height: 8),
                      _CustomNumberField(
                        controller: d.pointsToWinCustomCtrl,
                        hint: 'Enter points to win a set (e.g. 30)',
                      ),
                    ],
                  ],

                  // Standard score — points / goals to win (with Custom option)
                  if (d.scoringType == ScoringType.standard) ...[
                    const SizedBox(height: 12),
                    const Text('Points / Goals to win',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ...[1, 2, 3, 5].map((n) {
                          final sel = d.pointsToWin == n;
                          return GestureDetector(
                            onTap: () {
                              setState(() => d.pointsToWin = n);
                              widget.onChanged();
                            },
                            child: _PresetChip(label: '$n', selected: sel),
                          );
                        }),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              d.pointsToWin = -1;
                              d.pointsToWinCustomCtrl.clear();
                            });
                            widget.onChanged();
                          },
                          child: _PresetChip(
                              label: 'Custom',
                              selected: d.pointsToWin == -1,
                              isCustom: true),
                        ),
                      ],
                    ),
                    if (d.pointsToWin == -1) ...[
                      const SizedBox(height: 8),
                      _CustomNumberField(
                        controller: d.pointsToWinCustomCtrl,
                        hint: 'Enter target score (e.g. 10)',
                      ),
                    ],
                  ],

                  // Points system — no extra field needed (Win/Draw/Loss values
                  // are set in the main scoring config).
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Preset chip (3 / 5 / 7 etc.) ─────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final bool   isCustom;

  const _PresetChip({required this.label, required this.selected, this.isCustom = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCustom ? 64 : 40,
      height: 36,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withAlpha(30)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.white12,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : Colors.white54,
            fontSize: isCustom ? 13 : 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Custom number text field ──────────────────────────────────────────────────

class _CustomNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _CustomNumberField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary.withAlpha(120)),
        ),
      ),
    );
  }
}

// ── Sport picker bottom sheet ─────────────────────────────────────────────────

class _SportPickerSheet extends StatefulWidget {
  final ScrollController controller;
  const _SportPickerSheet({required this.controller});

  @override
  State<_SportPickerSheet> createState() => _SportPickerSheetState();
}

class _SportPickerSheetState extends State<_SportPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = allSports
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        // Handle bar
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Sport',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search sport...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // List
        Expanded(
          child: ListView.builder(
            controller: widget.controller,
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final sport = filtered[i];
              return ListTile(
                leading: Text(sport.emoji,
                    style: const TextStyle(fontSize: 22)),
                title: Text(sport.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(context, sport.name),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── AI Banner Generation Sheet ────────────────────────────────────────────────

class _AiBannerSheet extends StatefulWidget {
  final String promptSuggestion;
  const _AiBannerSheet({required this.promptSuggestion});

  @override
  State<_AiBannerSheet> createState() => _AiBannerSheetState();
}

class _AiBannerSheetState extends State<_AiBannerSheet> {
  // Initialized at declaration so hot-reload never causes LateInitializationError
  final TextEditingController _overlayCtrl = TextEditingController();
  final TextEditingController _ctrl        = TextEditingController();
  bool       _loading   = false;
  String?    _error;
  Uint8List? _imageBytes;
  Color      _textColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.promptSuggestion;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _overlayCtrl.dispose();
    super.dispose();
  }

  // ── Extract overlay text from the prompt (e.g. "UBS" from "with text UBS") ─
  String _extractOverlayText(String prompt) {
    // "with text XYZ" or "text XYZ"
    final m = RegExp(r'\bwith\s+text\s+([A-Za-z0-9]+)', caseSensitive: false)
            .firstMatch(prompt) ??
        RegExp(r'\btext\s+([A-Za-z0-9]+)', caseSensitive: false)
            .firstMatch(prompt);
    if (m != null) return m.group(1)!;

    // Quoted string: "UBS"
    final q = RegExp(r'"([^"]+)"').firstMatch(prompt);
    if (q != null) return q.group(1)!;

    // ALL-CAPS acronym (UBS, FIFA, IPL …)
    final caps = RegExp(r'\b([A-Z]{2,})\b').firstMatch(prompt);
    if (caps != null) return caps.group(1)!;

    return '';
  }

  Color _extractTextColor(String prompt) {
    final l = prompt.toLowerCase();
    if (l.contains('in white')  || l.contains('white text'))  return Colors.white;
    if (l.contains('in yellow') || l.contains('yellow text')) return Colors.yellow;
    if (l.contains('in red')    || l.contains('red text'))    return AppColors.primary;
    if (l.contains('in gold')   || l.contains('gold text'))   return const Color(0xFFFFD700);
    if (l.contains('in black')  || l.contains('black text'))  return Colors.black;
    return Colors.white;
  }

  // ── Composite overlay text onto the image bytes at full resolution ──────────
  Future<Uint8List> _compositeText({
    required Uint8List imageBytes,
    required String text,
    required Color color,
  }) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final src   = frame.image;

    final w = src.width.toDouble();
    final h = src.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas   = ui.Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Background image
    canvas.drawImage(src, Offset.zero, ui.Paint());

    // Gradient overlay in bottom 40% so text is always readable
    final gradPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.6),
        Offset(0, h),
        [Colors.transparent, const Color(0xCC000000)],
      );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.55, w, h * 0.45), gradPaint);

    // Text
    final fontSize = h * 0.28;
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
      maxLines: 1,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.bold,
        shadows: [
          ui.Shadow(
            color: const Color(0xAA000000),
            offset: const Offset(2, 2),
            blurRadius: 6,
          ),
        ],
      ))
      ..addText(text);

    final para = pb.build();
    para.layout(ui.ParagraphConstraints(width: w));

    // Centre vertically within the lower band
    canvas.drawParagraph(para, Offset(0, h * 0.62 + (h * 0.38 - para.height) / 2));

    final picture = recorder.endRecording();
    final result  = await picture.toImage(src.width, src.height);
    final bd      = await result.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  Future<void> _generate() async {
    final userPrompt = _ctrl.text.trim();
    if (userPrompt.isEmpty) return;

    setState(() { _loading = true; _error = null; _imageBytes = null; });

    try {
      // ── Step 1: Use Gemini text to craft a detailed image prompt ──────────
      // (best-effort — falls back to raw prompt if API unavailable)
      final imagePrompt = await _enhancePrompt(userPrompt);

      // ── Step 2: Generate image with Pollinations flux-pro ─────────────────
      final bytes = await _generateImage(imagePrompt);

      if (!mounted) return;
      if (bytes != null) {
        // Auto-fill overlay text from the prompt (e.g. "UBS")
        final extracted = _extractOverlayText(_ctrl.text);
        if (extracted.isNotEmpty && _overlayCtrl.text.isEmpty) {
          _overlayCtrl.text = extracted;
        }
        _textColor = _extractTextColor(_ctrl.text);
        setState(() { _imageBytes = bytes; _loading = false; });
      } else {
        setState(() { _error = 'Generation failed. Try again.'; _loading = false; });
      }
    } on TimeoutException {
      if (mounted) setState(() { _error = 'Timed out — try again.'; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed: $e'; _loading = false; });
    }
  }

  /// Uses Gemini 2.0 Flash (text only, high quota) to rewrite the user's
  /// simple description into a detailed, optimised image-generation prompt.
  /// Returns the original prompt unchanged if the API call fails.
  Future<String> _enhancePrompt(String userPrompt) async {
    if (kGeminiApiKey.isEmpty) return userPrompt;
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.0-flash:generateContent?key=$kGeminiApiKey',
      );
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [{
                'text': 'You are an expert AI image prompt engineer. '
                    'Turn this simple sports banner request into a rich, '
                    'detailed image-generation prompt (max 80 words). '
                    'Include: lighting style, color palette, composition, '
                    'mood, and quality keywords. Output ONLY the prompt, '
                    'no explanations.\n\nRequest: "$userPrompt"',
              }]
            }
          ],
          'generationConfig': {'maxOutputTokens': 120},
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final text = (data['candidates'] as List?)
            ?.firstOrNull?['content']?['parts']
            ?.firstOrNull?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) return text.trim();
      }
    } catch (_) {
      // Fall through — use raw prompt
    }
    return userPrompt;
  }

  /// Generates the banner image via Pollinations.ai (free, no quota).
  /// Uses the flux-pro model with 1200×400 landscape format.
  Future<Uint8List?> _generateImage(String prompt) async {
    final encoded = Uri.encodeComponent(prompt);
    final uri = Uri.parse(
      'https://image.pollinations.ai/prompt/$encoded'
      '?width=1200&height=400&model=flux-pro&nologo=true',
    );
    final res = await http.get(uri)
        .timeout(const Duration(seconds: 90));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      return res.bodyBytes;
    }
    return null;
  }

  Future<void> _useBanner() async {
    if (_imageBytes == null) return;

    Uint8List finalBytes = _imageBytes!;
    final overlay = _overlayCtrl.text.trim();
    if (overlay.isNotEmpty) {
      finalBytes = await _compositeText(
        imageBytes: _imageBytes!,
        text: overlay,
        color: _textColor,
      );
    }

    final tmp = File(
      '${Directory.systemTemp.path}/banner_ai_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tmp.writeAsBytes(finalBytes);
    if (mounted) Navigator.of(context).pop(tmp);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Row(children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text('Generate Banner with AI',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Describe the banner and AI will create it for you.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Prompt field
          TextField(
            controller: _ctrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Cricket tournament, green field, dramatic sky',
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bolt, size: 16),
              label: Text(_loading ? 'Generating…' : 'Generate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          // Loading hint
          if (_loading) ...[
            const SizedBox(height: 12),
            const Center(
              child: Text('Crafting prompt with AI, then generating image…\nThis takes 15–30 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],

          // ── Preview + text overlay controls ────────────────────────────
          if (_imageBytes != null) ...[
            const SizedBox(height: 16),

            // Live preview with overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.memory(_imageBytes!,
                      width: double.infinity, height: 130, fit: BoxFit.cover),
                  if (_overlayCtrl.text.trim().isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.bottomCenter,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xCC000000)],
                            stops: [0.45, 1.0],
                          ),
                        ),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          _overlayCtrl.text.trim(),
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Text overlay input
            const Text('Text on banner',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 5),
            TextField(
              controller: _overlayCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. UBS  (leave empty for no text)',
                hintStyle:
                    const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),

            // Color picker
            Row(children: [
              const Text('Color: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              for (final c in [
                Colors.white,
                Colors.yellow,
                AppColors.primary,
                const Color(0xFFFFD700),
                Colors.black,
              ])
                GestureDetector(
                  onTap: () => setState(() => _textColor = c),
                  child: Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == c
                            ? AppColors.primary
                            : Colors.white24,
                        width: _textColor == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _generate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _useBanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Use this banner'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
