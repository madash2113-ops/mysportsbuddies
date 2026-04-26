import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/player_entry.dart';
import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../widgets/player_search_field.dart';

// ── Sport mode classification ─────────────────────────────────────────────────

enum _SportMode { individual, pair, team }

_SportMode _resolveSportMode(String sport, int playersPerTeam) {
  if (playersPerTeam == 1) return _SportMode.individual;
  if (playersPerTeam == 2) return _SportMode.pair;
  if (playersPerTeam >= 3) return _SportMode.team;

  const individualSports = {
    'boxing', 'wrestling', 'swimming', 'cycling', 'athletics',
    'archery', 'golf', 'squash', 'chess',
  };
  const teamSports = {
    'cricket', 'football', 'basketball', 'volleyball', 'hockey',
    'kabaddi', 'throwball', 'handball', 'rugby',
  };

  final key = sport.toLowerCase();
  if (individualSports.contains(key)) return _SportMode.individual;
  if (teamSports.contains(key)) return _SportMode.team;
  return _SportMode.individual;
}

int _defaultPlayerCount(String sport) {
  switch (sport.toLowerCase()) {
    case 'cricket':   return 11;
    case 'football':  return 11;
    case 'basketball':return 5;
    case 'volleyball':return 6;
    case 'hockey':    return 11;
    case 'kabaddi':   return 7;
    case 'throwball': return 7;
    case 'handball':  return 7;
    case 'rugby':     return 15;
    default:          return 5;
  }
}

// ── EnrollTeamSheet ───────────────────────────────────────────────────────────

class EnrollTeamSheet extends StatefulWidget {
  final String tournamentId;
  final double entryFee;
  final double serviceFee;
  final int playersPerTeam;
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
        barrierColor: Colors.black.withValues(alpha: .72),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
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
  late final int _slotCount;
  int _defaultSlotCount = 0;

  late final List<TextEditingController> _playerCtrls;
  late final List<PlayerEntry?> _playerEntries;

  bool _loading = false;
  String? _error;

  bool get _countLocked => widget.playersPerTeam > 0;

  bool _canRemove(int index) {
    if (_countLocked) return false;
    if (_mode != _SportMode.team) return false;
    return _playerCtrls.length > _defaultSlotCount && index >= _defaultSlotCount;
  }

  @override
  void initState() {
    super.initState();
    _mode = _resolveSportMode(widget.sport, widget.playersPerTeam);

    if (widget.playersPerTeam > 0) {
      _slotCount = widget.playersPerTeam;
    } else {
      switch (_mode) {
        case _SportMode.individual: _slotCount = 1;
        case _SportMode.pair:       _slotCount = 2;
        case _SportMode.team:       _slotCount = _defaultPlayerCount(widget.sport);
      }
    }
    _defaultSlotCount = _slotCount;
    _playerCtrls  = List.generate(_slotCount, (_) => TextEditingController());
    _playerEntries = List.filled(_slotCount, null, growable: true);
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _playerCtrls) { c.dispose(); }
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
      final entry  = _playerEntries[i];
      final typed  = _playerCtrls[i].text.trim();
      final name   = entry?.displayName ?? typed;
      if (name.isEmpty) continue;
      players.add(name);
      playerUserIds.add(entry?.userId ?? '');
    }

    String captainName = '', captainPhone = '', captainUserId = '';
    String viceCaptainName = '', viceCaptainUserId = '', teamName = '';

    switch (_mode) {
      case _SportMode.individual:
        captainName   = players.isNotEmpty ? players.first : '';
        captainUserId = playerUserIds.isNotEmpty ? playerUserIds.first : '';
        captainPhone  = _phoneCtrl.text.trim();
        teamName      = captainName;

      case _SportMode.pair:
        teamName = _teamNameCtrl.text.trim().isNotEmpty
            ? _teamNameCtrl.text.trim()
            : players.isNotEmpty ? players.first : '';
        captainName   = players.isNotEmpty ? players.first : '';
        captainUserId = playerUserIds.isNotEmpty ? playerUserIds.first : '';
        captainPhone  = _phoneCtrl.text.trim();
        if (players.length >= 2) {
          viceCaptainName   = players[1];
          viceCaptainUserId = playerUserIds[1];
        }

      case _SportMode.team:
        teamName     = _teamNameCtrl.text.trim();
        captainPhone = _phoneCtrl.text.trim();
        if (players.isNotEmpty) {
          captainName   = players.first;
          captainUserId = playerUserIds.first;
        }
        if (players.length >= 2) {
          viceCaptainName   = players[1];
          viceCaptainUserId = playerUserIds[1];
        }
    }

    setState(() { _loading = true; _error = null; });
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
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  String _slotLabel(int index) {
    switch (_mode) {
      case _SportMode.individual: return 'Player Name';
      case _SportMode.pair:       return index == 0 ? 'Player 1' : 'Player 2';
      case _SportMode.team:
        if (index == 0) return 'Captain';
        if (index == 1) return 'Vice Captain';
        return 'Player ${index + 1}';
    }
  }

  Color _slotAccent(int index) {
    if (_mode == _SportMode.team) {
      if (index == 0) return const Color(0xFFFFD700);
      if (index == 1) return const Color(0xFFB0C4DE);
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

  // ── Titles ────────────────────────────────────────────────────────────────

  String get _title {
    switch (_mode) {
      case _SportMode.individual: return 'Register to Compete';
      case _SportMode.pair:       return 'Register Your Pair';
      case _SportMode.team:       return 'Enroll Your Team';
    }
  }

  String get _subtitle {
    switch (_mode) {
      case _SportMode.individual: return 'Reserve your spot in this tournament';
      case _SportMode.pair:       return 'Add your pair details and squad members';
      case _SportMode.team:       return 'Add your team details and all squad members';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWeb = widget.webDialog || MediaQuery.sizeOf(context).width >= 900;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    if (isWeb) return _buildWebDialog(context);

    // ── Mobile bottom sheet ───────────────────────────────────────────────
    return ConstrainedBox(
      constraints: const BoxConstraints(),
      child: Container(
        margin: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: _buildForm(isWeb: false),
            )),
          ],
        ),
      ),
    );
  }

  // ── Web dialog ────────────────────────────────────────────────────────────

  Widget _buildWebDialog(BuildContext context) {
    final totalFee = widget.entryFee + widget.serviceFee;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left panel ──────────────────────────────────────────────────
            _WebLeftPanel(
              mode: _mode,
              sport: widget.sport,
              totalFee: totalFee,
              entryFee: widget.entryFee,
              serviceFee: widget.serviceFee,
              playerCount: _playerCtrls.length,
              countLocked: _countLocked,
              lockedCount: widget.playersPerTeam,
            ),

            // ── Right panel (form) ──────────────────────────────────────────
            Expanded(
              child: Container(
                color: const Color(0xFF111318),
                child: Column(
                  children: [
                    // Header bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 16, 20),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF1F2230), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _subtitle,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _WebCloseButton(onTap: () => Navigator.pop(context)),
                        ],
                      ),
                    ),

                    // Scrollable form
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
                        child: _buildForm(isWeb: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared form body ──────────────────────────────────────────────────────

  Widget _buildForm({required bool isWeb}) {
    final totalFee = widget.entryFee + widget.serviceFee;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Team / Pair name ─────────────────────────────────────────────
          if (_mode != _SportMode.individual) ...[
            _WebLabel(
              _mode == _SportMode.pair ? 'Pair Name' : 'Team Name',
              optional: _mode == _SportMode.pair,
            ),
            const SizedBox(height: 6),
            _WebField(
              controller: _teamNameCtrl,
              hint: _mode == _SportMode.pair
                  ? 'e.g. Dynamic Duo'
                  : 'e.g. Thunder Warriors',
              icon: Icons.shield_outlined,
              validator: _mode == _SportMode.team
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Enter team name' : null
                  : null,
              isWeb: isWeb,
            ),
            const SizedBox(height: 18),
          ],

          // ── Phone ────────────────────────────────────────────────────────
          _WebLabel(
            _mode == _SportMode.individual ? 'Your Phone' : 'Contact Phone',
          ),
          const SizedBox(height: 6),
          _WebField(
            controller: _phoneCtrl,
            hint: '10-digit number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter phone number';
              if (v.trim().length < 10) return 'Enter valid phone number';
              return null;
            },
            isWeb: isWeb,
          ),
          const SizedBox(height: 24),

          // ── Player slots header ──────────────────────────────────────────
          Row(
            children: [
              Text(
                _mode == _SportMode.individual
                    ? 'Your Profile'
                    : _mode == _SportMode.pair
                    ? 'Players'
                    : 'Squad',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (_countLocked)
                _Badge('${widget.playersPerTeam} players')
              else if (_mode == _SportMode.team)
                _Badge('${_playerCtrls.length} players', muted: true),
              const Spacer(),
              if (!_countLocked && _mode == _SportMode.team)
                _AddPlayerButton(onTap: _addPlayer),
            ],
          ),

          if (_mode == _SportMode.team) ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 12),
                SizedBox(width: 4),
                Text('Captain', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                SizedBox(width: 12),
                Icon(Icons.star_half_rounded, color: Color(0xFFB0C4DE), size: 12),
                SizedBox(width: 4),
                Text('Vice Captain', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ── Player slots ─────────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _playerCtrls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final accent = _slotAccent(i);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Icon(_slotIcon(i), color: accent, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          _slotLabel(i),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .3,
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
                          onSelected: (entry) =>
                              setState(() => _playerEntries[i] = entry),
                        ),
                      ),
                      if (_canRemove(i))
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 6),
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

          const SizedBox(height: 24),

          // ── Fee summary (mobile only — web shows in left panel) ──────────
          if (!isWeb && totalFee > 0) ...[
            _MobileFeeSummary(
              entryFee: widget.entryFee,
              serviceFee: widget.serviceFee,
              totalFee: totalFee,
            ),
            const SizedBox(height: 6),
            const Text(
              'Payment is simulated — no real charge.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // ── Error ────────────────────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: .3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Submit ───────────────────────────────────────────────────────
          _SubmitButton(
            loading: _loading,
            label: totalFee > 0
                ? 'Pay ₹${totalFee.toInt()} & Enroll'
                : _mode == _SportMode.individual
                ? 'Register Now'
                : 'Enroll Team',
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

// ── Web left panel ────────────────────────────────────────────────────────────

class _WebLeftPanel extends StatelessWidget {
  final _SportMode mode;
  final String sport;
  final double totalFee, entryFee, serviceFee;
  final int playerCount;
  final bool countLocked;
  final int lockedCount;

  const _WebLeftPanel({
    required this.mode,
    required this.sport,
    required this.totalFee,
    required this.entryFee,
    required this.serviceFee,
    required this.playerCount,
    required this.countLocked,
    required this.lockedCount,
  });

  IconData get _sportIcon {
    switch (sport.toLowerCase()) {
      case 'cricket':    return Icons.sports_cricket;
      case 'football':   return Icons.sports_soccer;
      case 'basketball': return Icons.sports_basketball;
      case 'volleyball': return Icons.sports_volleyball;
      case 'hockey':     return Icons.sports_hockey;
      case 'badminton':  return Icons.sports_tennis;
      case 'tennis':     return Icons.sports_tennis;
      case 'boxing':     return Icons.sports_mma;
      default:           return Icons.emoji_events_rounded;
    }
  }

  String get _modeLabel {
    switch (mode) {
      case _SportMode.individual: return 'Solo Entry';
      case _SportMode.pair:       return 'Doubles Entry';
      case _SportMode.team:       return 'Team Entry';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A0A), Color(0xFF0F0F1A)],
        ),
        border: Border(
          right: BorderSide(color: Color(0xFF1F2230), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFFFF6B35)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sport icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: .25),
                    ),
                  ),
                  child: Icon(_sportIcon, color: AppColors.primary, size: 26),
                ),
                const SizedBox(height: 20),

                // Mode badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: .3),
                    ),
                  ),
                  child: Text(
                    _modeLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Tournament\nRegistration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sport.isNotEmpty
                      ? sport[0].toUpperCase() + sport.substring(1)
                      : 'Sports',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Divider(color: Color(0xFF1F2230), height: 1),
          ),

          // Info rows
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.group_outlined,
                  label: 'Players',
                  value: countLocked
                      ? '$lockedCount required'
                      : '$playerCount registered',
                ),
                const SizedBox(height: 14),
                if (totalFee > 0) ...[
                  _InfoRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Entry Fee',
                    value: '₹${entryFee.toInt()}',
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.miscellaneous_services_outlined,
                    label: 'Service Fee',
                    value: '₹${serviceFee.toInt()}',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: .2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Payable',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '₹${totalFee.toInt()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Payment is simulated —\nno real charge.',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  _InfoRow(
                    icon: Icons.confirmation_num_outlined,
                    label: 'Entry Fee',
                    value: 'Free',
                  ),
                ],
              ],
            ),
          ),

          const Spacer(),

          // Bottom note
          Padding(
            padding: const EdgeInsets.all(28),
            child: Row(
              children: const [
                Icon(Icons.lock_outline, color: Color(0xFF374151), size: 13),
                SizedBox(width: 6),
                Text(
                  'Secured registration',
                  style: TextStyle(color: Color(0xFF374151), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF4B5563), size: 15),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _WebLabel extends StatelessWidget {
  final String text;
  final bool optional;
  const _WebLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: .2,
        ),
      ),
      if (optional) ...[
        const SizedBox(width: 6),
        const Text(
          'optional',
          style: TextStyle(color: Color(0xFF4B5563), fontSize: 11),
        ),
      ],
    ],
  );
}

class _WebField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool isWeb;

  const _WebField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF4B5563), size: 17),
      filled: true,
      fillColor: const Color(0xFF0D0F15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1F2230)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1F2230)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.withValues(alpha: .6)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final bool muted;
  const _Badge(this.text, {this.muted = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: muted
          ? const Color(0xFF1F2230)
          : AppColors.primary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: muted
            ? const Color(0xFF2D3148)
            : AppColors.primary.withValues(alpha: .3),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: muted ? const Color(0xFF6B7280) : AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _AddPlayerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlayerButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2230),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D3148)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 14, color: AppColors.primary),
          SizedBox(width: 4),
          Text(
            'Add Player',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SubmitButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onTap;
  const _SubmitButton({required this.loading, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: loading ? null : onTap,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
              ),
            ),
    ),
  );
}

class _WebCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WebCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.close, color: Color(0xFF6B7280), size: 16),
    ),
  );
}

class _MobileFeeSummary extends StatelessWidget {
  final double entryFee, serviceFee, totalFee;
  const _MobileFeeSummary({
    required this.entryFee,
    required this.serviceFee,
    required this.totalFee,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _row('Entry Fee', '₹${entryFee.toInt()}'),
        const SizedBox(height: 6),
        _row('Service Fee', '₹${serviceFee.toInt()}'),
        const Divider(color: Colors.white12, height: 16),
        _row('Total', '₹${totalFee.toInt()}', bold: true),
      ],
    ),
  );

  Widget _row(String label, String amount, {bool bold = false}) => Row(
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
