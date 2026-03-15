import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../services/tournament_service.dart';
import '../../widgets/player_search_field.dart';

/// Bottom sheet for enrolling a team into a tournament.
/// Call via [EnrollTeamSheet.show(...)].
class EnrollTeamSheet extends StatefulWidget {
  final String tournamentId;
  final double entryFee;
  final double serviceFee;
  final int    playersPerTeam;  // 0 = no limit

  const EnrollTeamSheet({
    super.key,
    required this.tournamentId,
    required this.entryFee,
    required this.serviceFee,
    this.playersPerTeam = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String tournamentId,
    required double entryFee,
    required double serviceFee,
    int playersPerTeam = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EnrollTeamSheet(
        tournamentId:   tournamentId,
        entryFee:       entryFee,
        serviceFee:     serviceFee,
        playersPerTeam: playersPerTeam,
      ),
    );
  }

  @override
  State<EnrollTeamSheet> createState() => _EnrollTeamSheetState();
}

class _EnrollTeamSheetState extends State<EnrollTeamSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _teamNameCtrl   = TextEditingController();
  final _captainCtrl    = TextEditingController();
  final _phoneCtrl      = TextEditingController();

  late final List<TextEditingController> _playerCtrls;
  late final List<String?> _playerUserIds; // parallel — userId if registered
  bool _loading = false;
  String? _error;

  // True when the host set a specific player count (locked to that count)
  bool get _countLocked => widget.playersPerTeam > 0;

  @override
  void initState() {
    super.initState();
    final slots = widget.playersPerTeam > 0 ? widget.playersPerTeam : 1;
    _playerCtrls   = List.generate(slots, (_) => TextEditingController());
    _playerUserIds = List.filled(slots, null, growable: true);
  }

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _captainCtrl.dispose();
    _phoneCtrl.dispose();
    for (final c in _playerCtrls) { c.dispose(); }
    super.dispose();
  }

  void _addPlayer() {
    if (_playerCtrls.length >= 20) return;
    setState(() {
      _playerCtrls.add(TextEditingController());
      _playerUserIds.add(null);
    });
  }

  void _removePlayer(int index) {
    if (_playerCtrls.length <= 1) return;
    setState(() {
      _playerCtrls[index].dispose();
      _playerCtrls.removeAt(index);
      _playerUserIds.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final players = _playerCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Collect registered userIds aligned to non-empty player names
    final playerUserIds = <String>[];
    for (int i = 0; i < _playerCtrls.length; i++) {
      if (_playerCtrls[i].text.trim().isNotEmpty) {
        playerUserIds.add(_playerUserIds[i] ?? '');
      }
    }

    setState(() { _loading = true; _error = null; });

    // Simulate payment processing delay
    await Future.delayed(const Duration(milliseconds: 900));

    try {
      await TournamentService().enrollTeam(
        tournamentId:   widget.tournamentId,
        teamName:       _teamNameCtrl.text.trim(),
        captainName:    _captainCtrl.text.trim(),
        captainPhone:   _phoneCtrl.text.trim(),
        players:        players,
        playerUserIds:  playerUserIds,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Team enrolled successfully!'),
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

  @override
  Widget build(BuildContext context) {
    final totalFee = widget.entryFee + widget.serviceFee;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                const Text('Enroll Your Team',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Name
                    _label('Team Name'),
                    _field(_teamNameCtrl, 'e.g. Thunder Warriors',
                        Icons.shield_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter team name' : null),
                    const SizedBox(height: 14),

                    // Captain Name
                    _label('Captain Name'),
                    _field(_captainCtrl, 'Full name',
                        Icons.person_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter captain name' : null),
                    const SizedBox(height: 14),

                    // Phone
                    _label('Captain Phone'),
                    _field(_phoneCtrl, '10-digit number',
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
                        }),
                    const SizedBox(height: 16),

                    // Players header
                    Row(
                      children: [
                        const Text('Players',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        if (_countLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.playersPerTeam} required',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        const Spacer(),
                        if (!_countLocked)
                          TextButton.icon(
                            onPressed: _addPlayer,
                            icon: const Icon(Icons.add,
                                size: 16, color: AppColors.primary),
                            label: const Text('Add',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _playerCtrls.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: PlayerSearchField(
                              controller: _playerCtrls[i],
                              hint: 'Player ${i + 1} name or ID',
                              onProfileSelected: (p) =>
                                  setState(() => _playerUserIds[i] = p.id),
                            ),
                          ),
                          if (!_countLocked && _playerCtrls.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                    size: 20),
                                onPressed: () => _removePlayer(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Fee summary
                    if (totalFee > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _feeRow('Entry Fee',
                                '₹${widget.entryFee.toInt()}'),
                            const SizedBox(height: 6),
                            _feeRow('Service Fee',
                                '₹${widget.serviceFee.toInt()}'),
                            const Divider(color: Colors.white12, height: 16),
                            _feeRow('Total',
                                '₹${totalFee.toInt()}',
                                bold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Payment is simulated — no real charge.',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Error
                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                      const SizedBox(height: 10),
                    ],

                    // Submit
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
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text(
                                totalFee > 0
                                    ? 'Pay ₹${totalFee.toInt()} & Enroll'
                                    : 'Enroll Team',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
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
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 11),
        ),
      );

  Widget _feeRow(String label, String amount, {bool bold = false}) => Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: bold ? Colors.white : Colors.white54,
                  fontSize: bold ? 14 : 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.normal)),
          const Spacer(),
          Text(amount,
              style: TextStyle(
                  color: bold ? AppColors.primary : Colors.white70,
                  fontSize: bold ? 15 : 13,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.normal)),
        ],
      );
}
