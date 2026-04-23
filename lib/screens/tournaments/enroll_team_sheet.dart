import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/player_entry.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../widgets/player_search_field.dart';

// ── Sport mode classification ─────────────────────────────────────────────────

enum _SportMode { individual, pair, team }

/// Returns the enrollment mode based on sport name + host-set player count.
_SportMode _resolveSportMode(String sport, int playersPerTeam) {
  // Host-set count takes priority
  if (playersPerTeam == 1) return _SportMode.individual;
  if (playersPerTeam == 2) return _SportMode.pair;
  if (playersPerTeam >= 3) return _SportMode.team;

  // No count set — infer from sport name
  const individualSports = {
    'boxing',
    'wrestling',
    'swimming',
    'cycling',
    'athletics',
    'archery',
    'golf',
    'squash',
    'chess',
  };
  const pairSports = <String>{}; // reserved for future doubles formats
  const teamSports = {
    'cricket',
    'football',
    'basketball',
    'volleyball',
    'hockey',
    'kabaddi',
    'throwball',
    'handball',
    'rugby',
  };

  final key = sport.toLowerCase();
  if (individualSports.contains(key)) return _SportMode.individual;
  if (pairSports.contains(key)) return _SportMode.pair;
  if (teamSports.contains(key)) return _SportMode.team;

  // Badminton / Tennis / Table Tennis — default to individual (singles)
  // unless host set a count above 1
  return _SportMode.individual;
}

// ── Default player counts per team sport ─────────────────────────────────────

int _defaultPlayerCount(String sport) {
  switch (sport.toLowerCase()) {
    case 'cricket':
      return 11;
    case 'football':
      return 11;
    case 'basketball':
      return 5;
    case 'volleyball':
      return 6;
    case 'hockey':
      return 11;
    case 'kabaddi':
      return 7;
    case 'throwball':
      return 7;
    case 'handball':
      return 7;
    case 'rugby':
      return 15;
    default:
      return 5;
  }
}

// ── EnrollTeamSheet ───────────────────────────────────────────────────────────

class EnrollTeamSheet extends StatefulWidget {
  final String tournamentId;
  final double entryFee;
  final double serviceFee;
  final int playersPerTeam; // 0 = no limit set by host
  final String sport;
  final bool webDialog;

  const EnrollTeamSheet({
    super.key,
    required this.tournamentId,
    required this.entryFee,
    required this.serviceFee,
    this.playersPerTeam = 0,
    this.sport = '',
    this.webDialog = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String tournamentId,
    required double entryFee,
    required double serviceFee,
    int playersPerTeam = 0,
    String sport = '',
  }) {
    final isWebLayout = kIsWeb || MediaQuery.sizeOf(context).width >= 900;
    if (isWebLayout) {
      return showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .78),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: EnrollTeamSheet(
            tournamentId: tournamentId,
            entryFee: entryFee,
            serviceFee: serviceFee,
            playersPerTeam: playersPerTeam,
            sport: sport,
            webDialog: true,
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnrollTeamSheet(
        tournamentId: tournamentId,
        entryFee: entryFee,
        serviceFee: serviceFee,
        playersPerTeam: playersPerTeam,
        sport: sport,
      ),
    );
  }

  @override
  State<EnrollTeamSheet> createState() => _EnrollTeamSheetState();
}

class _EnrollTeamSheetState extends State<EnrollTeamSheet> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  late final _SportMode _mode;
  late final int _slotCount; // initial slot count
  int _defaultSlotCount = 0; // set in initState

  late final List<TextEditingController> _playerCtrls;
  late final List<PlayerEntry?> _playerEntries;

  bool _loading = false;
  String? _error;

  // locked = host specified exact count
  bool get _countLocked => widget.playersPerTeam > 0;

  // only allow removal of slots added beyond the initial default
  bool _canRemove(int index) {
    if (_countLocked) return false;
    if (_mode != _SportMode.team) return false;
    return _playerCtrls.length > _defaultSlotCount &&
        index >= _defaultSlotCount;
  }

  @override
  void initState() {
    super.initState();
    _mode = _resolveSportMode(widget.sport, widget.playersPerTeam);

    // Determine initial slot count
    if (widget.playersPerTeam > 0) {
      _slotCount = widget.playersPerTeam;
    } else {
      switch (_mode) {
        case _SportMode.individual:
          _slotCount = 1;
        case _SportMode.pair:
          _slotCount = 2;
        case _SportMode.team:
          _slotCount = _defaultPlayerCount(widget.sport);
      }
    }
    _defaultSlotCount = _slotCount;

    _playerCtrls = List.generate(_slotCount, (_) => TextEditingController());
    _playerEntries = List.filled(_slotCount, null, growable: true);
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _playerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_playerCtrls.length >= 25) return;
    setState(() {
      _playerCtrls.add(TextEditingController());
      _playerEntries.add(null);
    });
  }

  void _removePlayer(int index) {
    // Never remove below the default slot count
    if (_playerCtrls.length <= _defaultSlotCount) return;
    setState(() {
      _playerCtrls[index].dispose();
      _playerCtrls.removeAt(index);
      _playerEntries.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final players = <String>[];
    final playerUserIds = <String>[];
    for (int i = 0; i < _playerCtrls.length; i++) {
      final entry = _playerEntries[i];
      final typed = _playerCtrls[i].text.trim();
      final name = entry?.displayName ?? typed;
      if (name.isEmpty) continue;
      players.add(name);
      playerUserIds.add(entry?.userId ?? '');
    }

    // Derive captain/VC from player slots
    String captainName = '';
    String captainPhone = '';
    String captainUserId = '';
    String viceCaptainName = '';
    String viceCaptainUserId = '';
    String teamName = '';

    switch (_mode) {
      case _SportMode.individual:
        // Player name IS the "team" name and captain
        captainName = players.isNotEmpty ? players.first : '';
        captainUserId = playerUserIds.isNotEmpty ? playerUserIds.first : '';
        captainPhone = _phoneCtrl.text.trim();
        teamName = captainName;

      case _SportMode.pair:
        teamName = _teamNameCtrl.text.trim().isNotEmpty
            ? _teamNameCtrl.text.trim()
            : players.isNotEmpty
            ? players.first
            : '';
        captainName = players.isNotEmpty ? players.first : '';
        captainUserId = playerUserIds.isNotEmpty ? playerUserIds.first : '';
        captainPhone = _phoneCtrl.text.trim();
        if (players.length >= 2) {
          viceCaptainName = players[1];
          viceCaptainUserId = playerUserIds[1];
        }

      case _SportMode.team:
        teamName = _teamNameCtrl.text.trim();
        captainPhone = _phoneCtrl.text.trim();
        // Slot 0 = captain, slot 1 = vice captain
        if (players.isNotEmpty) {
          captainName = players.first;
          captainUserId = playerUserIds.first;
        }
        if (players.length >= 2) {
          viceCaptainName = players[1];
          viceCaptainUserId = playerUserIds[1];
        }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 900));

    try {
      await TournamentService().enrollTeam(
        tournamentId: widget.tournamentId,
        teamName: teamName,
        captainName: captainName,
        captainPhone: captainPhone,
        captainUserId: captainUserId,
        viceCaptainName: viceCaptainName,
        viceCaptainUserId: viceCaptainUserId,
        players: players,
        playerUserIds: playerUserIds,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mode == _SportMode.individual
                ? 'Registered successfully!'
                : 'Team enrolled successfully!',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ── Slot label ───────────────────────────────────────────────────────────

  String _slotLabel(int index) {
    switch (_mode) {
      case _SportMode.individual:
        return 'Player Name';
      case _SportMode.pair:
        return index == 0 ? 'Player 1' : 'Player 2';
      case _SportMode.team:
        if (index == 0) return 'Captain';
        if (index == 1) return 'Vice Captain';
        return 'Player ${index + 1}';
    }
  }

  Color _slotAccent(int index) {
    if (_mode == _SportMode.team) {
      if (index == 0) return const Color(0xFFFFD700); // gold for captain
      if (index == 1) return const Color(0xFFB0C4DE); // silver for VC
    }
    return Colors.white38;
  }

  IconData _slotIcon(int index) {
    if (_mode == _SportMode.team) {
      if (index == 0) return Icons.star_rounded;
      if (index == 1) return Icons.star_half_rounded;
    }
    return Icons.person_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final totalFee = widget.entryFee + widget.serviceFee;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isWeb = widget.webDialog || MediaQuery.sizeOf(context).width >= 900;

    return ConstrainedBox(
      constraints: isWeb
          ? const BoxConstraints(maxWidth: 1040, maxHeight: 780)
          : const BoxConstraints(),
      child: Container(
        margin: EdgeInsets.only(bottom: isWeb ? 0 : bottom),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: isWeb
              ? BorderRadius.circular(22)
              : const BorderRadius.vertical(top: Radius.circular(20)),
          border: isWeb
              ? Border.all(color: Colors.white.withValues(alpha: .09))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            if (!isWeb)
              Container(
                margin: const EdgeInsets.only(top: 38, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                isWeb ? 22 : 8,
                20,
                isWeb ? 12 : 0,
              ),
              child: Row(
                children: [
                  if (isWeb) ...[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mode == _SportMode.individual
                              ? 'Register to Compete'
                              : _mode == _SportMode.pair
                              ? 'Register Your Pair'
                              : 'Enroll Your Team',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isWeb ? 24 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isWeb)
                          Text(
                            _mode == _SportMode.individual
                                ? 'Reserve your spot in this tournament'
                                : 'Add your team details and squad members',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (isWeb) const Divider(height: 1, color: Colors.white10),
            // Scrollable form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isWeb ? 20 : 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Team / Pair name (not shown for individual) ──
                      if (_mode != _SportMode.individual) ...[
                        _label(
                          _mode == _SportMode.pair
                              ? 'Pair Name (optional)'
                              : 'Team Name',
                        ),
                        _field(
                          _teamNameCtrl,
                          _mode == _SportMode.pair
                              ? 'e.g. Dynamic Duo'
                              : 'e.g. Thunder Warriors',
                          Icons.shield_outlined,
                          validator: _mode == _SportMode.team
                              ? (v) => (v == null || v.trim().isEmpty)
                                    ? 'Enter team name'
                                    : null
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Phone ──
                      _label(
                        _mode == _SportMode.individual
                            ? 'Your Phone'
                            : 'Contact Phone',
                      ),
                      _field(
                        _phoneCtrl,
                        '10-digit number',
                        Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          if (v.trim().length < 10) {
                            return 'Enter valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Player slots header ──
                      Row(
                        children: [
                          Text(
                            _mode == _SportMode.individual
                                ? 'Your Profile'
                                : _mode == _SportMode.pair
                                ? 'Players'
                                : 'Squad',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_countLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${widget.playersPerTeam} players',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (!_countLocked && _mode == _SportMode.team)
                            TextButton.icon(
                              onPressed: _addPlayer,
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Add',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),

                      // ── Captain / VC legend for team mode ──
                      if (_mode == _SportMode.team) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: const Color(0xFFFFD700),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Captain  ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            Icon(
                              Icons.star_half_rounded,
                              color: const Color(0xFFB0C4DE),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Vice Captain',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ── Player slots ──
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _playerCtrls.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final accent = _slotAccent(i);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Slot label with icon
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(_slotIcon(i), color: accent, size: 13),
                                    const SizedBox(width: 5),
                                    Text(
                                      _slotLabel(i),
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: PlayerSearchField(
                                      controller: _playerCtrls[i],
                                      hint: 'Search by name, ID or email',
                                      onSelected: (entry) => setState(
                                        () => _playerEntries[i] = entry,
                                      ),
                                    ),
                                  ),
                                  // Remove button — only for extra slots added beyond default
                                  if (_canRemove(i))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _removePlayer(i),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Fee summary ──
                      if (totalFee > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _feeRow(
                                'Entry Fee',
                                '₹${widget.entryFee.toInt()}',
                              ),
                              const SizedBox(height: 6),
                              _feeRow(
                                'Service Fee',
                                '₹${widget.serviceFee.toInt()}',
                              ),
                              const Divider(color: Colors.white12, height: 16),
                              _feeRow(
                                'Total',
                                '₹${totalFee.toInt()}',
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Payment is simulated — no real charge.',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Error ──
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // ── Submit ──
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  totalFee > 0
                                      ? 'Pay ₹${totalFee.toInt()} & Enroll'
                                      : _mode == _SportMode.individual
                                      ? 'Register'
                                      : 'Enroll',
                                  style: const TextStyle(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    ),
  );

  Widget _feeRow(String label, String amount, {bool bold = false}) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          color: bold ? Colors.white : Colors.white54,
          fontSize: bold ? 14 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      const Spacer(),
      Text(
        amount,
        style: TextStyle(
          color: bold ? AppColors.primary : Colors.white70,
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
        ),
      ),
    ],
  );
}
