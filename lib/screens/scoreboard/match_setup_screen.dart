import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/match_score.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/scoreboard_service.dart';
import '../../widgets/address_autocomplete_field.dart';
import 'live_scoreboard_screen.dart';

/// Step-by-step scoreboard setup wizard.
/// Asks one question at a time with smooth slide animation.
class MatchSetupScreen extends StatefulWidget {
  final String sportName;
  const MatchSetupScreen({super.key, required this.sportName});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  // ── Common ────────────────────────────────────────────────────────────────
  final _teamACtrl = TextEditingController();
  final _teamBCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  // ── Cricket ───────────────────────────────────────────────────────────────
  String _cricketFormat = 'T20';
  String _playersPerSide = '11';
  bool _teamABatsFirst = true;

  // Custom format
  final _customFormatCtrl = TextEditingController();
  final _customOversCtrl = TextEditingController(text: '20');

  // Player rosters (for cricket — rebuilt when _playersPerSide changes)
  List<TextEditingController> _teamACtrlrs =
      List.generate(11, (_) => TextEditingController());
  List<TextEditingController> _teamBCtrlrs =
      List.generate(11, (_) => TextEditingController());

  // Opening batsmen / bowler selections (dropdown)
  String? _selectedBat1;
  String? _selectedBat2;
  String? _selectedBowler1;

  // ── Football family ───────────────────────────────────────────────────────
  int _footballDuration = 90;
  String _footballFormat = '11-a-side';

  // ── Basketball ────────────────────────────────────────────────────────────
  int _basketballQuarterMins = 10;

  // ── Rally sports ──────────────────────────────────────────────────────────
  String _rallyFormat = 'Best of 3';
  String _volleyballFormat = 'Best of 5';
  String _tennisFormat = 'Best of 3';

  // ── Hockey ────────────────────────────────────────────────────────────────
  String _hockeyFormat = 'Field Hockey';

  // ── Combat ────────────────────────────────────────────────────────────────
  int _boxingRounds = 12;
  int _boxingRoundMin = 3;

  // ── E-sports ──────────────────────────────────────────────────────────────
  String _esportsGame = 'CS:GO';

  // ── Wizard state ──────────────────────────────────────────────────────────
  int _step = 0;
  bool _isForward = true;
  bool _isLoading = false;

  late final MatchSport _sport = sportFromName(widget.sportName);

  // ── Step count per sport ──────────────────────────────────────────────────
  // Cricket: names(0), venue(1), format(2), players/side(3),
  //          Team A players(4), Team B players(5), who bats first(6),
  //          opening batsmen(7), opening bowler(8)  → 9 steps
  int get _totalSteps {
    switch (_sport) {
      case MatchSport.cricket:
        return 9;
      case MatchSport.football:
      case MatchSport.futsal:
      case MatchSport.americanFootball:
      case MatchSport.rugbyUnion:
      case MatchSport.rugbyLeague:
      case MatchSport.afl:
      case MatchSport.handball:
        return 4; // names, venue, format, duration
      case MatchSport.boxing:
      case MatchSport.mma:
      case MatchSport.wrestling:
      case MatchSport.fencing:
        return 4; // names, venue, rounds, round duration
      default:
        return 3; // names, venue, sport-specific option
    }
  }

  bool get _isLastStep => _step == _totalSteps - 1;

  // ── Question text ─────────────────────────────────────────────────────────
  String get _question {
    if (_step == 0) {
      switch (_sport) {
        case MatchSport.boxing:
        case MatchSport.mma:
        case MatchSport.wrestling:
        case MatchSport.fencing:
          return '🥊 Who are the fighters?';
        case MatchSport.badminton:
        case MatchSport.tennis:
        case MatchSport.tableTennis:
        case MatchSport.squash:
        case MatchSport.padel:
        case MatchSport.golf:
        case MatchSport.darts:
        case MatchSport.snooker:
          return '🏆 Player names?';
        default:
          return '🏆 Team names?';
      }
    }
    if (_step == 1) return '📍 Where is the match?';

    final s = _step - 2;
    switch (_sport) {
      case MatchSport.cricket:
        switch (s) {
          case 0:
            return '🏏 Match format?';
          case 1:
            return '👥 Players per side?';
          case 2:
            final a = _teamACtrl.text.trim();
            return '👤 ${a.isEmpty ? 'Team A' : a} — player names?';
          case 3:
            final b = _teamBCtrl.text.trim();
            return '👤 ${b.isEmpty ? 'Team B' : b} — player names?';
          case 4:
            return '🪙 Who bats first?';
          case 5:
            return '🧢 Opening batsmen?';
          case 6:
            return '⚡ Opening bowler?';
          default:
            return '?';
        }

      case MatchSport.football:
      case MatchSport.futsal:
        return s == 0 ? '⚽ Match format?' : '⏱ Match duration?';

      case MatchSport.americanFootball:
        return s == 0 ? '🏈 Match format?' : '⏱ Quarter duration?';

      case MatchSport.rugbyUnion:
      case MatchSport.rugbyLeague:
      case MatchSport.afl:
        return s == 0 ? '🏉 Match format?' : '⏱ Half duration?';

      case MatchSport.handball:
        return s == 0 ? '🤾 Match format?' : '⏱ Half duration?';

      case MatchSport.basketball:
        return '⏱ Quarter duration?';
      case MatchSport.netball:
        return '⏱ Quarter duration?';
      case MatchSport.badminton:
        return '🏸 Best of how many games?';
      case MatchSport.tableTennis:
        return '🏓 Best of how many games?';
      case MatchSport.tennis:
        return '🎾 Best of how many sets?';
      case MatchSport.squash:
        return '🎾 Best of how many games?';
      case MatchSport.padel:
        return '🎾 Best of how many sets?';
      case MatchSport.volleyball:
        return '🏐 Best of how many sets?';
      case MatchSport.beachVolleyball:
        return '🏐 Best of how many sets?';
      case MatchSport.hockey:
      case MatchSport.iceHockey:
        return '🏑 Type of hockey?';
      case MatchSport.boxing:
      case MatchSport.mma:
      case MatchSport.wrestling:
      case MatchSport.fencing:
        return s == 0 ? '🥊 Total rounds?' : '⏱ Round duration?';
      case MatchSport.csgo:
      case MatchSport.valorant:
      case MatchSport.leagueOfLegends:
      case MatchSport.dota2:
      case MatchSport.fifaEsports:
        return '🎮 Which game?';
      default:
        return '✅ Ready to start!';
    }
  }

  // ── Hint text ─────────────────────────────────────────────────────────────
  String? get _hint {
    if (_step == 1) return 'Optional — press Next to skip';
    if (_sport == MatchSport.cricket) {
      final s = _step - 2;
      if (s == 0 && _cricketFormat == 'Custom') {
        return 'Enter a name and over count for your custom format';
      }
      if (s == 2) {
        final a = _teamACtrl.text.trim();
        return 'Enter all $_cricketPlayers player names for ${a.isEmpty ? 'Team A' : a}';
      }
      if (s == 3) {
        final b = _teamBCtrl.text.trim();
        return 'Enter all $_cricketPlayers player names for ${b.isEmpty ? 'Team B' : b}';
      }
      if (s == 5) return 'Select the two players who will open the batting';
      if (s == 6) return 'The bowler bowling the first over';
    }
    return null;
  }

  // ── Validation ────────────────────────────────────────────────────────────
  String? _validate() {
    // Step 0: team / player / fighter names
    if (_step == 0) {
      if (_teamACtrl.text.trim().isEmpty) {
        final label = _isCombat ? 'Fighter A' : _isIndividual ? 'Player A' : 'Team A';
        return 'Enter $label name';
      }
      if (_teamBCtrl.text.trim().isEmpty) {
        final label = _isCombat ? 'Fighter B' : _isIndividual ? 'Player B' : 'Team B';
        return 'Enter $label name';
      }
    }

    if (_sport == MatchSport.cricket) {
      // Step 2 (s=0): format — validate Custom fields
      if (_step == 2 && _cricketFormat == 'Custom') {
        if (_customFormatCtrl.text.trim().isEmpty) return 'Enter a format name';
        final ov = int.tryParse(_customOversCtrl.text.trim());
        if (ov == null || ov < 1 || ov > 999) return 'Enter valid overs (1–999)';
      }
      // Step 4 (s=2): Team A player names — all mandatory
      if (_step == 4) {
        final teamName = _teamACtrl.text.trim().isEmpty ? 'Team A' : _teamACtrl.text.trim();
        for (int i = 0; i < _teamACtrlrs.length; i++) {
          if (_teamACtrlrs[i].text.trim().isEmpty) {
            return 'Enter name for Player ${i + 1} of $teamName';
          }
        }
      }
      // Step 5 (s=3): Team B player names — all mandatory
      if (_step == 5) {
        final teamName = _teamBCtrl.text.trim().isEmpty ? 'Team B' : _teamBCtrl.text.trim();
        for (int i = 0; i < _teamBCtrlrs.length; i++) {
          if (_teamBCtrlrs[i].text.trim().isEmpty) {
            return 'Enter name for Player ${i + 1} of $teamName';
          }
        }
      }
      // Step 7 (s=5): Opening batsmen — both mandatory
      if (_step == 7) {
        if (_selectedBat1 == null) return 'Select the Striker (Batsman 1)';
        if (_selectedBat2 == null) return 'Select the Non-Striker (Batsman 2)';
      }
      // Step 8 (s=6): Opening bowler — mandatory
      if (_step == 8) {
        if (_selectedBowler1 == null) return 'Select the opening bowler';
      }
    }
    return null;
  }

  bool get _isCombat => [
        MatchSport.boxing,
        MatchSport.mma,
        MatchSport.wrestling,
        MatchSport.fencing
      ].contains(_sport);

  bool get _isIndividual => [
        MatchSport.badminton,
        MatchSport.tennis,
        MatchSport.tableTennis,
        MatchSport.squash,
        MatchSport.padel,
        MatchSport.golf,
        MatchSport.darts,
        MatchSport.snooker,
      ].contains(_sport);

  // ── Navigation ────────────────────────────────────────────────────────────
  void _next() {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.primary),
      );
      return;
    }
    if (_isLastStep) {
      _startMatch();
      return;
    }
    setState(() {
      _isForward = true;
      _step++;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isForward = false;
      _step--;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: Colors.white, onPressed: _back),
        title: Text(
          widget.sportName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Step counter + dots
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(children: [
              Text('Step ${_step + 1} of $_totalSteps',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const Spacer(),
              Row(
                children: List.generate(
                    _totalSteps,
                    (i) => Container(
                          width: i == _step ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
              ),
            ]),
          ),

          // Animated step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: _isForward
                      ? const Offset(1.0, 0.0)
                      : const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(position: slide, child: child);
              },
              child: _StepPage(
                key: ValueKey(_step),
                question: _question,
                hint: _hint,
                child: _buildStepContent(),
              ),
            ),
          ),

          // Bottom nav
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(children: [
                if (_step > 0) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('← Back'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isLastStep ? '🏆  Start Match' : 'Next  →',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step content ──────────────────────────────────────────────────────────
  Widget _buildStepContent() {
    if (_step == 0) return _teamNamesContent();
    if (_step == 1) return _venueContent();
    final s = _step - 2;

    switch (_sport) {
      // ── CRICKET ───────────────────────────────────────────────────────────
      case MatchSport.cricket:
        switch (s) {
          case 0:
            return _cricketFormatContent();
          case 1:
            // Test cricket is always 11-a-side
            final sideOptions =
                _cricketFormat == 'Test' ? ['11'] : ['6', '8', '11'];
            return _bigChips(
                sideOptions,
                _playersPerSide,
                (v) {
                  // Recreate player controllers for new count
                  for (final c in [..._teamACtrlrs, ..._teamBCtrlrs]) {
                    c.dispose();
                  }
                  final n = int.tryParse(v) ?? 11;
                  _teamACtrlrs =
                      List.generate(n, (_) => TextEditingController());
                  _teamBCtrlrs =
                      List.generate(n, (_) => TextEditingController());
                  _selectedBat1 = null;
                  _selectedBat2 = null;
                  _selectedBowler1 = null;
                  _playersPerSide = v;
                },
                icons: sideOptions.map((_) => '🏃').toList(),
                desc: {
                  '6': '6 players per team',
                  '8': '8 players per team',
                  '11': _cricketFormat == 'Test'
                      ? '11 players per side — standard for Test matches'
                      : '11 players per team (standard)',
                });
          case 2:
            // Enter Team A player names
            final aName = _teamACtrl.text.trim();
            return _playerNamesContent(
                aName.isEmpty ? 'Team A' : aName, _teamACtrlrs);
          case 3:
            // Enter Team B player names
            final bName = _teamBCtrl.text.trim();
            return _playerNamesContent(
                bName.isEmpty ? 'Team B' : bName, _teamBCtrlrs);
          case 4:
            return _whoBatsFirstContent();
          case 5:
            return _openingBatsmenDropdownContent();
          case 6:
            return _openingBowlerDropdownContent();
        }
        break;

      // ── FOOTBALL FAMILY ───────────────────────────────────────────────────
      case MatchSport.football:
      case MatchSport.futsal:
        if (s == 0) {
          return _bigChips(
            ['11-a-side', '7-a-side', '5-a-side'],
            _footballFormat,
            (v) => _footballFormat = v,
            icons: const ['⚽', '⚽', '⚽'],
            desc: const {
              '11-a-side': 'Full standard match',
              '7-a-side': 'Small-sided game',
              '5-a-side': 'Futsal / mini format',
            },
          );
        }
        return _bigChips(
          ['45', '60', '90'],
          _footballDuration.toString(),
          (v) => _footballDuration = int.parse(v),
          icons: const ['⚡', '⏱', '🏟'],
          desc: const {
            '45': '45 min match',
            '60': '60 min match',
            '90': '90 min (standard FIFA)',
          },
        );

      case MatchSport.americanFootball:
        if (s == 0) {
          return _bigChips(
              ['NFL', 'College', 'Flag Football'],
              _footballFormat,
              (v) => _footballFormat = v,
              icons: const ['🏈', '🏈', '🏈'],
              desc: const {
                'NFL': '15 min quarters',
                'College': '15 min quarters',
                'Flag Football': 'Casual format',
              });
        }
        return _bigChips(
            ['12', '15'],
            _basketballQuarterMins.toString(),
            (v) => _basketballQuarterMins = int.parse(v),
            icons: const ['⚡', '🏟'],
            desc: const {
              '12': '12 min quarters',
              '15': '15 min quarters (standard)',
            });

      case MatchSport.rugbyUnion:
      case MatchSport.rugbyLeague:
      case MatchSport.afl:
      case MatchSport.handball:
        if (s == 0) {
          return _bigChips(['Standard', 'Shortened', 'Indoor'], _footballFormat,
              (v) => _footballFormat = v,
              icons: const ['🏉', '⚡', '🏟'],
              desc: const {
                'Standard': 'Full match format',
                'Shortened': 'Reduced time format',
                'Indoor': 'Indoor / 5-a-side format',
              });
        }
        return _bigChips(['30', '40', '45'], _footballDuration.toString(),
            (v) => _footballDuration = int.parse(v),
            icons: const ['⚡', '⏱', '🏟'],
            desc: const {
              '30': '30 min halves',
              '40': '40 min halves',
              '45': '45 min halves',
            });

      // ── BASKETBALL / NETBALL ──────────────────────────────────────────────
      case MatchSport.basketball:
      case MatchSport.netball:
        return _bigChips(['10', '12'], _basketballQuarterMins.toString(),
            (v) => _basketballQuarterMins = int.parse(v),
            icons: const ['🏀', '🏀'],
            desc: const {
              '10': '10 min quarters (FIBA)',
              '12': '12 min quarters (NBA)',
            });

      // ── RALLY SPORTS ──────────────────────────────────────────────────────
      case MatchSport.badminton:
      case MatchSport.tableTennis:
      case MatchSport.squash:
        return _bigChips(['Best of 3', 'Best of 5'], _rallyFormat,
            (v) => _rallyFormat = v,
            icons: const ['🏸', '🏆'],
            desc: const {
              'Best of 3': 'First to win 2 sets',
              'Best of 5': 'First to win 3 sets',
            });

      case MatchSport.tennis:
      case MatchSport.padel:
        return _bigChips(['Best of 3', 'Best of 5'], _tennisFormat,
            (v) => _tennisFormat = v,
            icons: const ['🎾', '🏆'],
            desc: const {
              'Best of 3': 'First to 2 sets (WTA standard)',
              'Best of 5': 'First to 3 sets (Grand Slams)',
            });

      case MatchSport.volleyball:
      case MatchSport.beachVolleyball:
        return _bigChips(['Best of 5', 'Best of 3'], _volleyballFormat,
            (v) => _volleyballFormat = v,
            icons: const ['🏐', '🏐'],
            desc: const {
              'Best of 5': 'First to 3 sets · 5th set to 15 pts',
              'Best of 3': 'First to 2 sets',
            });

      // ── HOCKEY ────────────────────────────────────────────────────────────
      case MatchSport.hockey:
      case MatchSport.iceHockey:
        return _bigChips(
          ['Field Hockey', 'Ice Hockey', 'Street Hockey'],
          _hockeyFormat,
          (v) => _hockeyFormat = v,
          icons: const ['🏑', '🧊', '🛣'],
          desc: const {
            'Field Hockey': '4 quarters × 15 min',
            'Ice Hockey': '3 periods × 20 min',
            'Street Hockey': 'Casual format',
          },
        );

      // ── COMBAT ────────────────────────────────────────────────────────────
      case MatchSport.boxing:
      case MatchSport.mma:
      case MatchSport.wrestling:
      case MatchSport.fencing:
        if (s == 0) {
          return _bigChips(
            ['3', '4', '6', '8', '10', '12'],
            _boxingRounds.toString(),
            (v) => _boxingRounds = int.parse(v),
            icons: const ['🥊', '🥊', '🥊', '🥊', '🥊', '🥊'],
            desc: const {
              '3': 'Amateur / exhibition',
              '4': 'Pro debut',
              '6': 'Regional bouts',
              '8': 'Mid-level pro',
              '10': 'Main event',
              '12': 'World title fight',
            },
          );
        }
        return _bigChips(
          ['2', '3', '5'],
          _boxingRoundMin.toString(),
          (v) => _boxingRoundMin = int.parse(v),
          icons: const ['⚡', '⏱', '🏆'],
          desc: const {
            '2': '2 min rounds (amateur / women)',
            '3': '3 min rounds (professional)',
            '5': '5 min rounds (MMA)',
          },
        );

      // ── E-SPORTS ──────────────────────────────────────────────────────────
      case MatchSport.csgo:
      case MatchSport.valorant:
      case MatchSport.leagueOfLegends:
      case MatchSport.dota2:
      case MatchSport.fifaEsports:
        return _bigChips(
          ['CS:GO', 'Valorant', 'League of Legends', 'Dota 2'],
          _esportsGame,
          (v) => _esportsGame = v,
          icons: const ['🎮', '🔺', '🎮', '🎮'],
          desc: const {
            'CS:GO': 'First to 13 rounds wins',
            'Valorant': 'First to 13 rounds wins',
            'League of Legends': 'Best of 3 / 5 maps',
            'Dota 2': 'Best of 3 / 5 maps',
          },
        );

      default:
        break;
    }
    return const SizedBox.shrink();
  }

  // ── Step sub-builders ─────────────────────────────────────────────────────

  Widget _teamNamesContent() {
    final labelA =
        _isCombat ? 'Fighter A' : _isIndividual ? 'Player A' : 'Team A';
    final labelB = labelA.replaceAll('A', 'B');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _inputField(labelA, _teamACtrl,
          hint: 'e.g. Mumbai XI', autofocus: true),
      const SizedBox(height: AppSpacing.md),
      _inputField(labelB, _teamBCtrl, hint: 'e.g. Delhi SC'),
    ]);
  }

  Widget _venueContent() => AddressAutocompleteField(
        controller: _venueCtrl,
        label: 'Venue / Ground',
        hint: 'e.g. Wankhede Stadium, Mumbai',
      );

  /// Cricket format step — includes Custom option with text fields.
  Widget _cricketFormatContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bigChips(
          ['T20', 'ODI', 'Test', 'T10', 'Custom'],
          _cricketFormat,
          (v) => setState(() => _cricketFormat = v),
          icons: const ['🎯', '🏏', '👑', '⚡', '✏️'],
          desc: const {
            'T20': '20 overs per side',
            'ODI': '50 overs per side',
            'Test': 'Unlimited overs',
            'T10': '10 overs per side',
            'Custom': 'Set your own overs & format name',
          },
        ),
        if (_cricketFormat == 'Custom') ...[
          const SizedBox(height: AppSpacing.md),
          _inputField('Format Name', _customFormatCtrl,
              hint: 'e.g. 15 Over Challenge'),
          const SizedBox(height: AppSpacing.sm),
          _inputField('Overs per side', _customOversCtrl,
              hint: 'e.g. 15'),
        ],
      ],
    );
  }

  /// Enter all player names for one team (scrollable list of N text fields).
  Widget _playerNamesContent(
      String teamLabel, List<TextEditingController> controllers) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: controllers.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _inputField(
            'Player ${e.key + 1}',
            e.value,
            hint: 'e.g. ${_samplePlayerName(e.key)}',
            autofocus: e.key == 0,
          ),
        );
      }).toList(),
    );
  }

  String _samplePlayerName(int index) {
    const samples = [
      'Rohit Sharma', 'Virat Kohli', 'Shubman Gill', 'Shreyas Iyer',
      'KL Rahul', 'Hardik Pandya', 'Ravindra Jadeja', 'MS Dhoni',
      'Jasprit Bumrah', 'Mohammed Shami', 'Kuldeep Yadav',
    ];
    return index < samples.length ? samples[index] : 'Player ${index + 1}';
  }

  Widget _whoBatsFirstContent() {
    final teamA =
        _teamACtrl.text.trim().isEmpty ? 'Team A' : _teamACtrl.text.trim();
    final teamB =
        _teamBCtrl.text.trim().isEmpty ? 'Team B' : _teamBCtrl.text.trim();
    return _bigChips([teamA, teamB], _teamABatsFirst ? teamA : teamB,
        (v) => setState(() => _teamABatsFirst = v == teamA),
        icons: const ['🏏', '🏏'],
        desc: {
          teamA: 'Will bat first (home side)',
          teamB: 'Will bat first (away side)',
        });
  }

  /// Opening batsmen selection using player roster dropdowns.
  Widget _openingBatsmenDropdownContent() {
    final ctrls = _teamABatsFirst ? _teamACtrlrs : _teamBCtrlrs;
    final allPlayers = ctrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final forBat2 =
        allPlayers.where((p) => p != _selectedBat1).toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _dropdownField(
        'Striker (Batsman 1) *',
        allPlayers,
        _selectedBat1,
        (v) => setState(() {
          _selectedBat1 = v;
          if (_selectedBat2 == v) _selectedBat2 = null;
        }),
      ),
      const SizedBox(height: AppSpacing.md),
      _dropdownField(
        'Non-Striker (Batsman 2) *',
        forBat2,
        _selectedBat2,
        (v) => setState(() => _selectedBat2 = v),
      ),
    ]);
  }

  /// Opening bowler selection using bowling team roster dropdown.
  Widget _openingBowlerDropdownContent() {
    final ctrls = _teamABatsFirst ? _teamBCtrlrs : _teamACtrlrs;
    final allPlayers = ctrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return _dropdownField(
      'Opening Bowler *',
      allPlayers,
      _selectedBowler1,
      (v) => setState(() => _selectedBowler1 = v),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _bigChips(
    List<String> options,
    String selected,
    ValueChanged<String> onSelect, {
    required List<String> icons,
    required Map<String, String> desc,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: options.asMap().entries.map((entry) {
        final opt = entry.value;
        final icon = icons.length > entry.key ? icons[entry.key] : '•';
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => setState(() => onSelect(opt)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opt,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        )),
                    if (desc[opt] != null)
                      Text(desc[opt]!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textMuted,
                            fontSize: 12,
                          )),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 22),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {String hint = '', bool autofocus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          autofocus: autofocus,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 16),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 18),
          ),
        ),
      ],
    );
  }

  /// Dropdown field for selecting from a player roster list.
  Widget _dropdownField(
    String label,
    List<String> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected != null
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.1),
              width: selected != null ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              hint: Text(
                'Select player',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 16),
              ),
              dropdownColor: AppColors.card,
              isExpanded: true,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              icon: const Icon(Icons.expand_more, color: Colors.white54),
              items: options
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: options.isEmpty ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ── Start match ───────────────────────────────────────────────────────────
  void _startMatch() {
    setState(() => _isLoading = true);
    final teamA = _teamACtrl.text.trim();
    final teamB = _teamBCtrl.text.trim();
    final venue = _venueCtrl.text.trim();
    final matchId = DateTime.now().millisecondsSinceEpoch.toString();
    final match = _buildMatch(matchId, teamA, teamB, venue);
    context.read<ScoreboardService>().addMatch(match);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LiveScoreboardScreen(matchId: matchId, isScorer: true),
      ),
    );
  }

  // ── Match builder helpers ─────────────────────────────────────────────────
  int get _cricketTotalOvers {
    if (_cricketFormat == 'Custom') {
      return int.tryParse(_customOversCtrl.text.trim()) ?? 20;
    }
    switch (_cricketFormat) {
      case 'T20':
        return 20;
      case 'ODI':
        return 50;
      case 'T10':
        return 10;
      case 'Test':
        return 999;
      default:
        return 20;
    }
  }

  int get _cricketPlayers =>
      _cricketFormat == 'Test' ? 11 : (int.tryParse(_playersPerSide) ?? 11);

  int get _rallyPointsToWin {
    switch (_sport) {
      case MatchSport.badminton:
        return 21;
      case MatchSport.tableTennis:
        return 11;
      case MatchSport.volleyball:
      case MatchSport.beachVolleyball:
        return 25;
      case MatchSport.squash:
        return 11;
      default:
        return 21;
    }
  }

  int get _rallySetsToWin {
    final fmt = (_sport == MatchSport.volleyball ||
            _sport == MatchSport.beachVolleyball)
        ? _volleyballFormat
        : (_sport == MatchSport.tennis || _sport == MatchSport.padel)
            ? _tennisFormat
            : _rallyFormat;
    switch (fmt) {
      case 'Best of 3':
        return 2;
      case 'Best of 5':
        return 3;
      default:
        return 2;
    }
  }

  int? get _maxPointCap => (_sport == MatchSport.badminton) ? 30 : null;

  bool get _isTennis =>
      _sport == MatchSport.tennis || _sport == MatchSport.padel;

  String _buildFormat() {
    switch (_sport) {
      case MatchSport.cricket:
        if (_cricketFormat == 'Custom') {
          final name = _customFormatCtrl.text.trim();
          return name.isEmpty ? 'Custom' : name;
        }
        return _cricketFormat;
      case MatchSport.football:
      case MatchSport.futsal:
        return '$_footballDuration min · $_footballFormat';
      case MatchSport.americanFootball:
      case MatchSport.rugbyUnion:
      case MatchSport.rugbyLeague:
      case MatchSport.afl:
      case MatchSport.handball:
        return _footballFormat;
      case MatchSport.basketball:
      case MatchSport.netball:
        return '$_basketballQuarterMins min quarters';
      case MatchSport.badminton:
      case MatchSport.tableTennis:
      case MatchSport.squash:
        return _rallyFormat;
      case MatchSport.tennis:
      case MatchSport.padel:
        return _tennisFormat;
      case MatchSport.volleyball:
      case MatchSport.beachVolleyball:
        return _volleyballFormat;
      case MatchSport.hockey:
      case MatchSport.iceHockey:
        return _hockeyFormat;
      case MatchSport.boxing:
      case MatchSport.mma:
      case MatchSport.wrestling:
      case MatchSport.fencing:
        return '$_boxingRounds Rds × $_boxingRoundMin min';
      case MatchSport.csgo:
      case MatchSport.valorant:
      case MatchSport.leagueOfLegends:
      case MatchSport.dota2:
      case MatchSport.fifaEsports:
        return _esportsGame;
      default:
        return '';
    }
  }

  LiveMatch _buildMatch(String id, String teamA, String teamB, String venue) {
    final format = _buildFormat();
    final now = DateTime.now();

    switch (engineForSport(_sport)) {
      case SportEngine.cricket:
        final score = CricketScore(
          format: _cricketFormat == 'Custom'
              ? _customFormatCtrl.text.trim()
              : _cricketFormat,
          totalOvers: _cricketTotalOvers,
          playersPerSide: _cricketPlayers,
          teamA: teamA,
          teamB: teamB,
          teamABatFirst: _teamABatsFirst,
        );
        final inn = score.currentInnings;
        inn.batsmen.addAll([
          CricketBatsman(
              name: _selectedBat1 ?? '', order: 1, isStriker: true),
          CricketBatsman(
              name: _selectedBat2 ?? '', order: 2, isStriker: false),
        ]);
        inn.bowlers
            .add(CricketBowler(name: _selectedBowler1 ?? '', isCurrent: true));
        return LiveMatch(
          id: id,
          sport: _sport,
          teamA: teamA,
          teamB: teamB,
          venue: venue,
          format: format,
          createdAt: now,
          cricket: score,
          teamAPlayers:
              _teamACtrlrs.map((c) => c.text.trim()).toList(),
          teamBPlayers:
              _teamBCtrlrs.map((c) => c.text.trim()).toList(),
        );

      case SportEngine.football:
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            football: FootballScore(matchDurationMin: _footballDuration));

      case SportEngine.basketball:
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            basketball:
                BasketballScore(quarterMinutes: _basketballQuarterMins));

      case SportEngine.rally:
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            rally: RallyScore(
              pointsToWin: _rallyPointsToWin,
              setsToWin: _rallySetsToWin,
              winByTwo: true,
              maxPointCap: _maxPointCap,
              isTennis: _isTennis,
              lastSetPoints: (_sport == MatchSport.volleyball ||
                      _sport == MatchSport.beachVolleyball)
                  ? 15
                  : null,
            ));

      case SportEngine.hockey:
        final isIce =
            _hockeyFormat == 'Ice Hockey' || _sport == MatchSport.iceHockey;
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            hockey: HockeyScore(
              quarterMinutes: isIce ? 20 : 15,
              totalPeriods: isIce ? 3 : 4,
            ));

      case SportEngine.combat:
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            combat: CombatScore(
              totalRounds: _boxingRounds,
              roundDurationMin: _boxingRoundMin,
            ));

      case SportEngine.esports:
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            esports: EsportsScore(roundsToWin: 13, maxRounds: 24));

      case SportEngine.generic:
        return LiveMatch(
            id: id,
            sport: _sport,
            teamA: teamA,
            teamB: teamB,
            venue: venue,
            format: format,
            createdAt: now,
            genericScore: GenericScore());
    }
  }

  @override
  void dispose() {
    _teamACtrl.dispose();
    _teamBCtrl.dispose();
    _venueCtrl.dispose();
    _customFormatCtrl.dispose();
    _customOversCtrl.dispose();
    for (final c in [..._teamACtrlrs, ..._teamBCtrlrs]) {
      c.dispose();
    }
    super.dispose();
  }
}

// ── Step page wrapper ─────────────────────────────────────────────────────────
class _StepPage extends StatelessWidget {
  final String question;
  final String? hint;
  final Widget child;

  const _StepPage({
    super.key,
    required this.question,
    this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(hint!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }
}
