import 'package:flutter/material.dart';
import '../../design/colors.dart';

/// Full registration flow for joining a tournament league.
/// 3 steps: Team Details → Players → Confirm & Submit
class RegisterLeagueScreen extends StatefulWidget {
  final String tournamentName;
  final String sport;
  final String format;
  final String date;
  final String location;

  const RegisterLeagueScreen({
    super.key,
    required this.tournamentName,
    required this.sport,
    required this.format,
    required this.date,
    required this.location,
  });

  @override
  State<RegisterLeagueScreen> createState() => _RegisterLeagueScreenState();
}

class _RegisterLeagueScreenState extends State<RegisterLeagueScreen> {
  int _step = 0; // 0=Team, 1=Players, 2=Confirm

  // Step 1 — Team details
  final _teamNameCtrl    = TextEditingController();
  final _captainCtrl     = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _emailCtrl       = TextEditingController();
  String? _skillLevel;
  bool _agreeToRules = false;

  // Step 2 — Squad
  final List<TextEditingController> _playerCtrls =
      List.generate(11, (_) => TextEditingController());

  bool _submitted = false;

  @override
  void dispose() {
    _teamNameCtrl.dispose();
    _captainCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    for (final c in _playerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int get _minPlayers {
    switch (widget.sport) {
      case 'Cricket':    return 11;
      case 'Football':   return 11;
      case 'Basketball': return 5;
      case 'Volleyball': return 6;
      case 'Badminton':  return 2;
      case 'Tennis':     return 2;
      default:           return 5;
    }
  }

  List<String> get _filledPlayers =>
      _playerCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

  bool get _step1Valid =>
      _teamNameCtrl.text.trim().isNotEmpty &&
      _captainCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().length >= 10;

  bool get _step2Valid => _filledPlayers.length >= _minPlayers;

  void _next() {
    if (_step == 0) {
      if (!_step1Valid) {
        setState(() {}); // trigger validation display
        return;
      }
    }
    if (_step == 1) {
      if (!_step2Valid) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Please add at least $_minPlayers players for ${widget.sport}'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submitRegistration();
    }
  }

  void _submitRegistration() {
    if (!_agreeToRules) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please agree to the tournament rules'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitted = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _showSuccessDialog();
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark  = Theme.of(context).brightness == Brightness.dark;
        final primary = isDark ? AppColors.primary : AppColorsLight.primary;
        return AlertDialog(
          backgroundColor:
              isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline,
                    color: primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text('Registration Submitted!',
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Your team "${_teamNameCtrl.text.trim()}" has been registered for ${widget.tournamentName}. You\'ll receive a confirmation once approved.',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0A0A0A) : AppColorsLight.background;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final textCol = isDark ? Colors.white : const Color(0xFF111827);
    final subCol  = isDark ? Colors.white54 : Colors.black54;
    final cardBg  = isDark ? const Color(0xFF111111) : Colors.white;
    final divCol  = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textCol, size: 20),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('Register for League',
            style: TextStyle(
                color: textCol,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Stepper indicator ────────────────────────────────────────
          _StepBar(step: _step, primary: primary, textCol: textCol, subCol: subCol),

          // ── Tournament info card ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _TournamentInfoCard(
              name: widget.tournamentName,
              sport: widget.sport,
              format: widget.format,
              date: widget.date,
              location: widget.location,
              primary: primary,
              textCol: textCol,
              subCol: subCol,
              cardBg: cardBg,
              divCol: divCol,
            ),
          ),

          // ── Step content ─────────────────────────────────────────────
          Expanded(
            child: _submitted
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: primary,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Submitting…',
                            style: TextStyle(color: subCol, fontSize: 14)),
                      ],
                    ),
                  )
                : IndexedStack(
                    index: _step,
                    children: [
                      _Step1Team(
                        teamNameCtrl: _teamNameCtrl,
                        captainCtrl: _captainCtrl,
                        phoneCtrl: _phoneCtrl,
                        emailCtrl: _emailCtrl,
                        skillLevel: _skillLevel,
                        onSkillChanged: (v) =>
                            setState(() => _skillLevel = v),
                        isDark: isDark,
                        primary: primary,
                        textCol: textCol,
                        subCol: subCol,
                        cardBg: cardBg,
                        divCol: divCol,
                        showErrors: !_step1Valid && _step > 0,
                      ),
                      _Step2Players(
                        ctrls: _playerCtrls,
                        minPlayers: _minPlayers,
                        sport: widget.sport,
                        isDark: isDark,
                        primary: primary,
                        textCol: textCol,
                        subCol: subCol,
                        cardBg: cardBg,
                        divCol: divCol,
                        onChanged: () => setState(() {}),
                      ),
                      _Step3Confirm(
                        teamName: _teamNameCtrl.text,
                        captain: _captainCtrl.text,
                        phone: _phoneCtrl.text,
                        email: _emailCtrl.text,
                        skillLevel: _skillLevel,
                        players: _filledPlayers,
                        tournamentName: widget.tournamentName,
                        agreeToRules: _agreeToRules,
                        onAgreeChanged: (v) =>
                            setState(() => _agreeToRules = v),
                        isDark: isDark,
                        primary: primary,
                        textCol: textCol,
                        subCol: subCol,
                        cardBg: cardBg,
                        divCol: divCol,
                      ),
                    ],
                  ),
          ),

          // ── Bottom CTA ───────────────────────────────────────────────
          if (!_submitted)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _step == 2 ? 'Submit Registration' : 'Continue',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Step indicator bar ────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  final int step;
  final Color primary, textCol, subCol;
  const _StepBar(
      {required this.step,
      required this.primary,
      required this.textCol,
      required this.subCol});

  @override
  Widget build(BuildContext context) {
    const labels = ['Team Details', 'Players', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(3, (i) {
          final done   = i < step;
          final active = i == step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done || active
                                  ? primary
                                  : primary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: done || active
                                    ? primary
                                    : primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 13)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          color: active
                                              ? Colors.white
                                              : primary.withValues(alpha: 0.6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(labels[i],
                              style: TextStyle(
                                  color: active ? textCol : subCol,
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          if (i < 2)
                            Expanded(
                              child: Container(
                                height: 1.5,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 6),
                                color: done
                                    ? primary
                                    : primary.withValues(alpha: 0.15),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Tournament info card ──────────────────────────────────────────────────────

class _TournamentInfoCard extends StatelessWidget {
  final String name, sport, format, date, location;
  final Color primary, textCol, subCol, cardBg, divCol;
  const _TournamentInfoCard({
    required this.name,
    required this.sport,
    required this.format,
    required this.date,
    required this.location,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.divCol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: textCol,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$sport \u00B7 $format \u00B7 $date',
                    style: TextStyle(color: subCol, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Team Details ──────────────────────────────────────────────────────

class _Step1Team extends StatelessWidget {
  final TextEditingController teamNameCtrl, captainCtrl, phoneCtrl, emailCtrl;
  final String? skillLevel;
  final ValueChanged<String?> onSkillChanged;
  final bool isDark, showErrors;
  final Color primary, textCol, subCol, cardBg, divCol;
  const _Step1Team({
    required this.teamNameCtrl,
    required this.captainCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.skillLevel,
    required this.onSkillChanged,
    required this.isDark,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.divCol,
    required this.showErrors,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Team Name *', textCol),
          _Field(ctrl: teamNameCtrl, hint: 'e.g. Thunder Warriors',
              isDark: isDark, textCol: textCol, cardBg: cardBg, divCol: divCol,
              error: showErrors && teamNameCtrl.text.trim().isEmpty
                  ? 'Required' : null),
          const SizedBox(height: 14),

          _FieldLabel('Captain / Manager Name *', textCol),
          _Field(ctrl: captainCtrl, hint: 'Full name',
              isDark: isDark, textCol: textCol, cardBg: cardBg, divCol: divCol,
              error: showErrors && captainCtrl.text.trim().isEmpty
                  ? 'Required' : null),
          const SizedBox(height: 14),

          _FieldLabel('Contact Phone *', textCol),
          _Field(ctrl: phoneCtrl, hint: '+91 9000000000',
              keyboardType: TextInputType.phone,
              isDark: isDark, textCol: textCol, cardBg: cardBg, divCol: divCol,
              error: showErrors && phoneCtrl.text.trim().length < 10
                  ? 'Enter valid phone' : null),
          const SizedBox(height: 14),

          _FieldLabel('Email (optional)', textCol),
          _Field(ctrl: emailCtrl, hint: 'team@example.com',
              keyboardType: TextInputType.emailAddress,
              isDark: isDark, textCol: textCol, cardBg: cardBg, divCol: divCol),
          const SizedBox(height: 14),

          _FieldLabel('Skill Level', textCol),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Beginner', 'Intermediate', 'Advanced']
                .map((s) => GestureDetector(
                      onTap: () => onSkillChanged(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: skillLevel == s
                              ? primary
                              : cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: skillLevel == s
                                ? primary
                                : divCol,
                          ),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                color: skillLevel == s
                                    ? Colors.white
                                    : subCol,
                                fontSize: 13,
                                fontWeight: skillLevel == s
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Players ───────────────────────────────────────────────────────────

class _Step2Players extends StatelessWidget {
  final List<TextEditingController> ctrls;
  final int minPlayers;
  final String sport;
  final bool isDark;
  final Color primary, textCol, subCol, cardBg, divCol;
  final VoidCallback onChanged;
  const _Step2Players({
    required this.ctrls,
    required this.minPlayers,
    required this.sport,
    required this.isDark,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.divCol,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Squad Members',
                    style: TextStyle(
                        color: textCol,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Min $minPlayers required',
                    style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Add player names for your $sport team',
              style: TextStyle(color: subCol, fontSize: 12)),
          const SizedBox(height: 14),
          ...List.generate(ctrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrls[i],
                      onChanged: (_) => onChanged(),
                      style: TextStyle(color: textCol, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: i == 0
                            ? 'Captain name'
                            : 'Player ${i + 1}',
                        hintStyle:
                            TextStyle(color: subCol, fontSize: 13),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: divCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: divCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Step 3: Confirm ───────────────────────────────────────────────────────────

class _Step3Confirm extends StatelessWidget {
  final String teamName, captain, phone, email, tournamentName;
  final String? skillLevel;
  final List<String> players;
  final bool agreeToRules, isDark;
  final ValueChanged<bool> onAgreeChanged;
  final Color primary, textCol, subCol, cardBg, divCol;
  const _Step3Confirm({
    required this.teamName,
    required this.captain,
    required this.phone,
    required this.email,
    required this.skillLevel,
    required this.players,
    required this.tournamentName,
    required this.agreeToRules,
    required this.onAgreeChanged,
    required this.isDark,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.divCol,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Confirm',
              style: TextStyle(
                  color: textCol,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),

          // Team info card
          _SummaryCard(
            title: 'Team Information',
            isDark: isDark,
            primary: primary,
            textCol: textCol,
            subCol: subCol,
            cardBg: cardBg,
            divCol: divCol,
            rows: [
              _Row('Team Name', teamName),
              _Row('Captain', captain),
              _Row('Phone', phone),
              if (email.isNotEmpty) _Row('Email', email),
              if (skillLevel != null) _Row('Skill Level', skillLevel!),
            ],
          ),

          const SizedBox(height: 14),

          // Players card
          _SummaryCard(
            title: 'Squad (${players.length} players)',
            isDark: isDark,
            primary: primary,
            textCol: textCol,
            subCol: subCol,
            cardBg: cardBg,
            divCol: divCol,
            rows: players
                .asMap()
                .entries
                .map((e) => _Row('${e.key + 1}', e.value))
                .toList(),
          ),

          const SizedBox(height: 20),

          // Agreement
          GestureDetector(
            onTap: () => onAgreeChanged(!agreeToRules),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: agreeToRules ? primary : Colors.transparent,
                    border: Border.all(
                      color: agreeToRules ? primary : subCol,
                      width: 1.5,
                    ),
                  ),
                  child: agreeToRules
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          color: subCol,
                          fontSize: 12,
                          height: 1.5),
                      children: [
                        const TextSpan(
                            text:
                                'I confirm all player details are accurate and agree to the '),
                        TextSpan(
                          text: 'Tournament Rules & Code of Conduct',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String label, value;
  const _Row(this.label, this.value);
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final bool isDark;
  final Color primary, textCol, subCol, cardBg, divCol;
  final List<_Row> rows;
  const _SummaryCard({
    required this.title,
    required this.isDark,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.divCol,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(title,
                style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          Divider(height: 1, thickness: 0.5, color: divCol),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(r.label,
                          style: TextStyle(
                              color: subCol,
                              fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(r.value,
                          style: TextStyle(
                              color: textCol,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Shared field widgets ──────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color textCol;
  const _FieldLabel(this.text, this.textCol);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                color: textCol,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboardType;
  final bool isDark;
  final Color textCol, cardBg, divCol;
  final String? error;
  const _Field({
    required this.ctrl,
    required this.hint,
    required this.isDark,
    required this.textCol,
    required this.cardBg,
    required this.divCol,
    this.keyboardType,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(color: textCol, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13),
            filled: true,
            fillColor: cardBg,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: error != null
                        ? Colors.redAccent
                        : divCol)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: error != null
                        ? Colors.redAccent
                        : divCol)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary)),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(error!,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 11)),
          ),
      ],
    );
  }
}
