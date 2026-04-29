import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/tournament.dart';
import '../../design/colors.dart';
import '../../services/scoreboard_service.dart';
import '../../services/tournament_link_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../community/user_profile_screen.dart';
import 'bracket_widget.dart';
import 'enroll_team_sheet.dart';
import 'solo_register_sheet.dart';
import 'host_dashboard_screen.dart';
import 'match_detail_screen.dart';
import '../../widgets/match_vs_banner.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TournamentDetailScreen — 6-tab fixed, all users
// ══════════════════════════════════════════════════════════════════════════════

class TournamentDetailScreen extends StatefulWidget {
  final String tournamentId;

  /// If set, `MatchDetailScreen` for this match is automatically pushed
  /// on top of this screen after the first frame — so pressing back from
  /// the match detail lands here rather than jumping straight to Home.
  final String? openMatchId;
  final int openMatchTabIndex;

  /// Deep-link join code — when present and correct, grants access to a
  /// private tournament and auto-opens the enroll sheet.
  final String? joinCode;

  /// When true, automatically opens the registration sheet after the screen
  /// loads (used when arriving via a share link).
  final bool autoEnroll;

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    this.openMatchId,
    this.openMatchTabIndex = 0,
    this.joinCode,
    this.autoEnroll = false,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  // Fixed length — never changes, no disposal errors
  late final TabController _tabs = TabController(length: 6, vsync: this);
  bool _generatingSchedule = false;

  @override
  void initState() {
    super.initState();
    TournamentService().loadDetail(widget.tournamentId).then((_) {
      if (!mounted) return;
      final t = TournamentService().tournaments
          .where((t) => t.id == widget.tournamentId)
          .firstOrNull;
      if (t == null) return;

      // Auto-open enroll sheet when arriving via valid private invite link.
      final isValidPrivateInvite = t.isPrivate &&
          widget.joinCode != null &&
          widget.joinCode == t.joinCode;

      // Auto-open register sheet when arriving via any share link.
      final shouldAutoEnroll = widget.autoEnroll || isValidPrivateInvite;

      if (shouldAutoEnroll) {
        final uid = UserService().userId ?? '';
        final alreadyEnrolled = TournamentService().isRegisteredForTournament(
          widget.tournamentId,
        );
        if (uid.isNotEmpty && !alreadyEnrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showRegisterChoice(t);
          });
        }
      }
    });
    // If launched via Resume, auto-open the target match without animation
    // so the back stack is: TournamentDetail → MatchDetail → LiveScoreboard.
    if (widget.openMatchId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(
              tournamentId: widget.tournamentId,
              matchId: widget.openMatchId!,
              initialTabIndex: widget.openMatchTabIndex,
            ),
          ),
        );
      });
    }
  }

  void _share(Tournament t) {
    TournamentLinkService.shareTournament(
      tournamentId: t.id,
      tournamentName: t.name,
      joinCode: t.isPrivate ? t.joinCode : null,
    );
  }

  void _showRegisterChoice(Tournament t) {
    if (!t.allowSoloRegistration) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EnrollTeamSheet(
          tournamentId: t.id,
          entryFee: t.entryFee,
          serviceFee: t.serviceFee,
          playersPerTeam: t.playersPerTeam,
          sport: t.sport,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogCtx),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white60,
                      size: 16,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Register',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.name,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _ChoiceBtn(
                    label: 'Enroll Team',
                    icon: Icons.groups_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EnrollTeamSheet(
                          tournamentId: t.id,
                          entryFee: t.entryFee,
                          serviceFee: t.serviceFee,
                          playersPerTeam: t.playersPerTeam,
                          sport: t.sport,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _ChoiceBtn(
                    label: 'Join Solo',
                    icon: Icons.person_add_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      SoloRegisterSheet.show(
                        context,
                        tournamentId: t.id,
                        tournamentName: t.name,
                        sport: t.sport,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Tournament? get _t => TournamentService().tournaments
      .where((t) => t.id == widget.tournamentId)
      .firstOrNull;

  bool get _canManage =>
      TournamentService().isHost(widget.tournamentId) ||
      TournamentService().isAdmin(widget.tournamentId);

  void _snack(String msg, [Color color = Colors.green]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Reset match result ───────────────────────────────────────────────────

  void _resetMatch(TournamentMatch m) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Reset Score?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will reset ${m.teamAName ?? "Team A"} vs '
          '${m.teamBName ?? "Team B"} back to 0 – 0 and remove the result.\n\n'
          'Points table will also be adjusted.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      try {
        // Remove the live scoreboard so the scorer can start fresh
        final scoreboardId = 'tourn_${widget.tournamentId}_${m.id}';
        ScoreboardService().removeMatch(scoreboardId);

        await TournamentService().resetMatchResult(
          tournamentId: widget.tournamentId,
          matchId: m.id,
        );
        if (mounted) _snack('Match reset to 0 – 0');
      } catch (e) {
        if (mounted) _snack('Reset failed: $e', Colors.red);
      }
    });
  }

  // ── Result entry sheet (with deuce logic) ────────────────────────────────

  // ── Generate schedule ─────────────────────────────────────────────────────

  Future<void> _generateSchedule() async {
    final teamCount = TournamentService().teamsFor(widget.tournamentId).length;
    if (teamCount == 0) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'No Teams',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Add teams to this tournament before generating a schedule.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _generatingSchedule = true);
    try {
      await TournamentService().generateSchedule(widget.tournamentId);
      if (!mounted) return;
      _snack('Schedule generated!');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _generatingSchedule = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final t = _t;
        if (t == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final canManage = _canManage;
        final tid = widget.tournamentId;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: const Color(0xFF121212),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      color: Colors.white70,
                    ),
                    tooltip: 'Share tournament',
                    onPressed: () => _share(t),
                  ),
                  if (canManage) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.group_add_outlined,
                        color: Colors.white54,
                      ),
                      tooltip: 'Seed 27 dummy teams',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: const Text(
                              'Seed 27 Teams?',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'This will add 27 dummy teams to this tournament for testing.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  'Seed',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await TournamentService().seedDummyTeams(tid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('27 dummy teams added!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.dashboard_outlined,
                        color: Colors.white70,
                      ),
                      tooltip: 'Management',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HostDashboardScreen(tournamentId: tid),
                        ),
                      ),
                    ),
                  ],
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _TournamentBanner(tournament: t),
                ),
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Matches'),
                    Tab(text: 'Table'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Squads'),
                    Tab(text: 'Venues'),
                    Tab(text: 'Forecast'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              // Disable swipe-to-switch-tabs so InteractiveViewer (bracket)
              // owns all horizontal gestures. Users navigate tabs by tapping.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MatchesTab(
                  tournamentId: tid,
                  tournament: t,
                  canManage: canManage,
                  onReset: _resetMatch,
                  onGenerate: canManage ? _generateSchedule : null,
                  generating: _generatingSchedule,
                  joinCode: widget.joinCode,
                ),
                _TableTab(tournamentId: tid, tournament: t),
                _StatsTab(tournamentId: tid, tournament: t),
                _SquadsTab(tournamentId: tid),
                _VenuesTab(tournamentId: tid, canManage: canManage),
                _ForecastTab(tournamentId: tid, tournament: t),
              ],
            ),
          ),
          // Management FAB for host/admin
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HostDashboardScreen(tournamentId: tid),
                    ),
                  ),
                  backgroundColor: Colors.deepOrange,
                  icon: const Icon(
                    Icons.manage_accounts_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Manage',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Banner header
// ══════════════════════════════════════════════════════════════════════════════

class _TournamentBanner extends StatefulWidget {
  final Tournament tournament;
  const _TournamentBanner({required this.tournament});

  @override
  State<_TournamentBanner> createState() => _TournamentBannerState();
}

class _TournamentBannerState extends State<_TournamentBanner> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await TournamentService().uploadBanner(
        widget.tournament.id,
        File(picked.path),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Banner updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournament = widget.tournament;
    final isHost = tournament.createdBy == (UserService().userId ?? '');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        if (tournament.bannerUrl != null)
          Image.network(
            tournament.bannerUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _defaultBg(),
          )
        else
          _defaultBg(),
        // Gradient overlay
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withAlpha(220)],
            ),
          ),
        ),
        // Host edit button (top-right)
        if (isHost)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ),
        // Content
        Positioned(
          bottom: 52,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FormatChip(tournament.format),
                  const SizedBox(width: 8),
                  _StatusPill(tournament.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tournament.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${tournament.sport}  •  ${tournament.location}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _defaultBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

class _FormatChip extends StatelessWidget {
  final TournamentFormat format;
  const _FormatChip(this.format);

  @override
  Widget build(BuildContext context) {
    final labels = {
      TournamentFormat.knockout: 'Knockout',
      TournamentFormat.roundRobin: 'Round Robin',
      TournamentFormat.leagueKnockout: 'League+KO',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        labels[format] ?? format.name,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TournamentStatus status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final configs = {
      TournamentStatus.open: (Colors.green, 'OPEN'),
      TournamentStatus.ongoing: (Colors.orange, 'ONGOING'),
      TournamentStatus.completed: (Colors.white38, 'COMPLETED'),
      TournamentStatus.cancelled: (Colors.red, 'CANCELLED'),
    };
    final (color, label) =
        configs[status] ?? (Colors.grey, status.name.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TournamentStatus.ongoing) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 1: Matches (inner 3 sub-tabs)
// ══════════════════════════════════════════════════════════════════════════════

class _MatchesTab extends StatelessWidget {
  final String tournamentId;
  final Tournament tournament;
  final bool canManage;
  final void Function(TournamentMatch) onReset;
  final VoidCallback? onGenerate;
  final bool generating;
  final String? joinCode;

  const _MatchesTab({
    required this.tournamentId,
    required this.tournament,
    required this.canManage,
    required this.onReset,
    required this.onGenerate,
    required this.generating,
    this.joinCode,
  });

  @override
  Widget build(BuildContext context) {
    final svc = TournamentService();
    final matches = svc.matchesFor(tournamentId);
    final myTeam = svc.myTeamIn(tournamentId);

    if (!tournament.bracketGenerated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _NoScheduleState(
              canManage: canManage,
              format: tournament.format,
              teamCount: svc.teamsFor(tournamentId).length,
              sport: tournament.sport,
              onGenerate: onGenerate,
              generating: generating,
            ),
          ),
        ],
      );
    }

    final upcoming = matches.where((m) => !m.isPlayed).toList();
    final recent = matches.where((m) => m.isPlayed).toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF121212),
            child: const TabBar(
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Upcoming'),
                Tab(text: 'Recent'),
                Tab(text: 'All'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MatchList(
                  matches: upcoming,
                  myTeamId: myTeam?.id,
                  canManage: canManage,
                  onReset: onReset,
                  teams: svc.teamsFor(tournamentId),
                  sport: tournament.sport,
                ),
                _MatchList(
                  matches: [...recent].reversed.toList(),
                  myTeamId: myTeam?.id,
                  canManage: canManage,
                  onReset: onReset,
                  teams: svc.teamsFor(tournamentId),
                  sport: tournament.sport,
                ),
                _MatchList(
                  matches: matches,
                  myTeamId: myTeam?.id,
                  canManage: canManage,
                  onReset: onReset,
                  teams: svc.teamsFor(tournamentId),
                  sport: tournament.sport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoScheduleState extends StatelessWidget {
  final bool canManage;
  final TournamentFormat format;
  final int teamCount;
  final String sport;
  final VoidCallback? onGenerate;
  final bool generating;

  const _NoScheduleState({
    required this.canManage,
    required this.format,
    required this.teamCount,
    required this.sport,
    required this.onGenerate,
    required this.generating,
  });

  @override
  Widget build(BuildContext context) {
    final rec = teamCount >= 2
        ? TournamentService.scheduleRecommendation(teamCount, sport, format)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(
            Icons.calendar_month_outlined,
            color: Colors.white24,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Schedule Not Generated',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            teamCount < 2
                ? 'Need at least 2 registered teams to generate schedule.'
                : 'The tournament schedule hasn\'t been generated yet.',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (rec != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Preview',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rec,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
          if (canManage && onGenerate != null && teamCount >= 2) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: generating ? null : onGenerate,
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                label: Text(
                  generating ? 'Generating…' : 'Generate Schedule',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String? myTeamId;
  final bool canManage;
  final void Function(TournamentMatch) onReset;
  final List<TournamentTeam> teams;
  final String sport;

  const _MatchList({
    required this.matches,
    required this.myTeamId,
    required this.canManage,
    required this.onReset,
    required this.teams,
    required this.sport,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const _EmptyState(
        icon: Icons.sports_score_outlined,
        label: 'No matches here yet',
      );
    }

    // Build teamId → best photo URL and captain name
    final svc = TournamentService();
    final Map<String, String?> photoMap = {
      for (final t in teams)
        t.id: svc.teamRepPhotoFor(captainUserId: t.captainUserId, teamId: t.id),
    };
    final Map<String, String> captainNameMap = {
      for (final t in teams) t.id: t.captainName,
    };

    // Single-player sports: display captain name instead of team name
    const singlePlayerSports = {
      'badminton',
      'tennis',
      'chess',
      'table tennis',
      'squash',
    };
    final isSinglePlayer = singlePlayerSports.contains(sport.toLowerCase());

    // Group by note/label
    final Map<String, List<TournamentMatch>> grouped = {};
    for (final m in matches) {
      final key = m.note ?? 'Matches';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: grouped.entries
          .expand(
            (entry) => [
              _GroupHeader(label: entry.key, matches: entry.value),
              ...entry.value.map((m) {
                // For single-player sports, use captain name as display name
                final rawA = m.teamAName ?? 'TBD';
                final rawB = m.teamBName ?? 'TBD';
                final displayA = isSinglePlayer && m.teamAId != null
                    ? (captainNameMap[m.teamAId]?.isNotEmpty == true
                          ? captainNameMap[m.teamAId]!
                          : rawA)
                    : rawA;
                final displayB = isSinglePlayer && m.teamBId != null
                    ? (captainNameMap[m.teamBId]?.isNotEmpty == true
                          ? captainNameMap[m.teamBId]!
                          : rawB)
                    : rawB;

                return _CricbuzzMatchCard(
                  match: m,
                  myTeamId: myTeamId,
                  canManage: canManage,
                  sport: sport,
                  teamAPhotoUrl: m.teamAId != null ? photoMap[m.teamAId] : null,
                  teamBPhotoUrl: m.teamBId != null ? photoMap[m.teamBId] : null,
                  displayNameA: displayA,
                  displayNameB: displayB,
                  onReset: () => onReset(m),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(
                        tournamentId: m.tournamentId,
                        matchId: m.id,
                      ),
                    ),
                  ),
                );
              }),
            ],
          )
          .toList(),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final List<TournamentMatch> matches;
  const _GroupHeader({required this.label, required this.matches});

  @override
  Widget build(BuildContext context) {
    final played = matches.where((m) => m.isPlayed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$played/${matches.length} played',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Cricbuzz-style Match Card
// ══════════════════════════════════════════════════════════════════════════════

class _CricbuzzMatchCard extends StatelessWidget {
  final TournamentMatch match;
  final String? myTeamId;
  final bool canManage;
  final String sport;
  final String? teamAPhotoUrl;
  final String? teamBPhotoUrl;
  final String displayNameA;
  final String displayNameB;
  final VoidCallback onTap;
  final VoidCallback? onReset;

  const _CricbuzzMatchCard({
    required this.match,
    required this.myTeamId,
    required this.canManage,
    required this.sport,
    required this.displayNameA,
    required this.displayNameB,
    required this.onTap,
    this.teamAPhotoUrl,
    this.teamBPhotoUrl,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final m = match;
    final isMyMatchA = myTeamId != null && myTeamId == m.teamAId;
    final isMyMatchB = myTeamId != null && myTeamId == m.teamBId;
    final isMyMatch = isMyMatchA || isMyMatchB;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyMatch
                ? AppColors.primary.withAlpha(120)
                : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            // ── Top: VS banner ───────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: _MatchVsBanner(
                teamA: displayNameA,
                teamB: displayNameB,
                label: m.note?.isNotEmpty == true
                    ? m.note!
                    : 'Match ${m.round}',
                isLive: m.isLive,
                isPlayed: m.isPlayed,
                sport: sport,
                teamAPhotoUrl: teamAPhotoUrl,
                teamBPhotoUrl: teamBPhotoUrl,
                scheduledAt: m.scheduledAt,
                isMyMatch: isMyMatch,
                tournamentId: m.tournamentId,
              ),
            ),

            // ── Team A ──
            _TeamRow(
              name: m.teamAName ?? 'TBD',
              score: m.scoreA,
              isWinner: m.result == TournamentMatchResult.teamAWin,
              isPlayed: m.isPlayed,
              photoUrl: teamAPhotoUrl,
            ),
            const Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.white12,
              indent: 16,
              endIndent: 16,
            ),
            // ── Team B ──
            _TeamRow(
              name: m.teamBName ?? 'TBD',
              score: m.scoreB,
              isWinner: m.result == TournamentMatchResult.teamBWin,
              isPlayed: m.isPlayed,
              photoUrl: teamBPhotoUrl,
            ),
            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _footerText(m),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Reset button — admin/host only, only when match has a result
                  if (canManage && !m.isBye && m.isPlayed && onReset != null)
                    GestureDetector(
                      onTap: onReset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withAlpha(70)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              color: Colors.redAccent,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Reset',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _footerText(TournamentMatch m) {
    if (m.isBye) return '${m.teamAName ?? "Team"} advances (bye)';
    if (m.isPlayed) {
      if (m.result == TournamentMatchResult.draw) return 'Match drawn';
      return '${m.winnerName ?? "?"} won';
    }
    if (m.venueName != null) return m.venueName!;
    return 'Yet to be played';
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final int? score;
  final bool isWinner;
  final bool isPlayed;
  final String? photoUrl;
  const _TeamRow({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.isPlayed,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Avatar — real photo if available, else initial letter
          if (photoUrl != null && photoUrl!.isNotEmpty)
            CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(photoUrl!),
              backgroundColor: Colors.white12,
              onBackgroundImageError: (_, _) {},
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isWinner
                    ? AppColors.primary.withAlpha(40)
                    : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isWinner ? AppColors.primary : Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isWinner ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPlayed && score != null)
            Text(
              score.toString(),
              style: TextStyle(
                color: isWinner ? Colors.white : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 2: Table — two sub-tabs: Points Table + Bracket
// ══════════════════════════════════════════════════════════════════════════════

class _TableTab extends StatelessWidget {
  final String tournamentId;
  final Tournament tournament;
  const _TableTab({required this.tournamentId, required this.tournament});

  bool get _isKnockoutStyle =>
      tournament.format == TournamentFormat.knockout ||
      tournament.format == TournamentFormat.leagueKnockout;

  @override
  Widget build(BuildContext context) {
    final secondLabel = _isKnockoutStyle ? 'Bracket' : 'Fixtures';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF121212),
            child: TabBar(
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(text: 'Points Table'),
                Tab(text: secondLabel),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              // Disable swipe-to-switch so InteractiveViewer in BracketWidget
              // can own horizontal gestures without fighting the TabBarView.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _PointsTableView(
                  tournamentId: tournamentId,
                  tournament: tournament,
                ),
                _isKnockoutStyle
                    ? ListenableBuilder(
                        listenable: TournamentService(),
                        builder: (context, _) {
                          final rounds = TournamentService().buildRounds(
                            tournamentId,
                          );
                          final isHost = TournamentService().isHost(
                            tournamentId,
                          );
                          if (rounds.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.account_tree_outlined,
                              label: 'No bracket generated yet',
                            );
                          }
                          return BracketWidget(
                            tournamentId: tournamentId,
                            rounds: rounds,
                            isHost: isHost,
                          );
                        },
                      )
                    : _FixturesView(
                        tournamentId: tournamentId,
                        tournament: tournament,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fixtures view (round-robin / league / custom) ─────────────────────────────

class _FixturesView extends StatelessWidget {
  final String tournamentId;
  final Tournament tournament;
  const _FixturesView({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final rounds = TournamentService().buildRounds(tournamentId);
        final teams = TournamentService().teamsFor(tournamentId);

        if (rounds.isEmpty) {
          return const _EmptyState(
            icon: Icons.calendar_today_outlined,
            label: 'No fixtures generated yet',
          );
        }

        // Single-player sports show captain name
        const singlePlayer = {
          'badminton',
          'tennis',
          'chess',
          'table tennis',
          'squash',
        };
        final isSingle = singlePlayer.contains(tournament.sport.toLowerCase());
        final captainMap = {for (final t in teams) t.id: t.captainName};

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: rounds.length,
          itemBuilder: (_, i) {
            final round = rounds[i];
            final played = round.matches.where((m) => m.isPlayed).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Round header
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: i == 0 ? 0 : 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(80),
                          ),
                        ),
                        child: Text(
                          round.label,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$played/${round.matches.length} played',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Match rows
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: round.matches.asMap().entries.map((e) {
                      final idx = e.key;
                      final m = e.value;

                      String nameA = m.teamAName ?? 'TBD';
                      String nameB = m.teamBName ?? 'TBD';
                      if (isSingle) {
                        if (m.teamAId != null &&
                            captainMap[m.teamAId]?.isNotEmpty == true) {
                          nameA = captainMap[m.teamAId]!;
                        }
                        if (m.teamBId != null &&
                            captainMap[m.teamBId]?.isNotEmpty == true) {
                          nameB = captainMap[m.teamBId]!;
                        }
                      }

                      final aWon = m.result == TournamentMatchResult.teamAWin;
                      final bWon = m.result == TournamentMatchResult.teamBWin;

                      return Column(
                        children: [
                          if (idx > 0)
                            const Divider(
                              height: 1,
                              color: Colors.white10,
                              indent: 12,
                              endIndent: 12,
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                // Team A
                                Expanded(
                                  child: Row(
                                    children: [
                                      _MiniAvatar(name: nameA, highlight: aWon),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          nameA,
                                          style: TextStyle(
                                            color: aWon
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 13,
                                            fontWeight: aWon
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Score / VS
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: m.isPlayed
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${m.scoreA ?? 0}',
                                              style: TextStyle(
                                                color: aWon
                                                    ? AppColors.primary
                                                    : Colors.white54,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
                                              child: Text(
                                                '–',
                                                style: TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${m.scoreB ?? 0}',
                                              style: TextStyle(
                                                color: bWon
                                                    ? AppColors.primary
                                                    : Colors.white54,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'vs',
                                          style: TextStyle(
                                            color: Colors.white24,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                                // Team B
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nameB,
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: bWon
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 13,
                                            fontWeight: bWon
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _MiniAvatar(name: nameB, highlight: bWon),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final bool highlight;
  const _MiniAvatar({required this.name, required this.highlight});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: highlight ? AppColors.primary.withAlpha(40) : Colors.white10,
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: highlight ? AppColors.primary : Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

// ── Points table stat accumulator ────────────────────────────────────────────

class _PTStat {
  final String name;
  final String teamId;
  final int wPts, dPts, lPts;
  int played = 0, won = 0, lost = 0, drawn = 0;
  int scoreFor = 0, scoreAgainst = 0;
  _PTStat(
    this.name, {
    required this.teamId,
    this.wPts = 3,
    this.dPts = 1,
    this.lPts = 0,
  });
  int get pts => won * wPts + drawn * dPts + lost * lPts;
  double get nrr =>
      played == 0 ? 0 : (scoreFor - scoreAgainst) / played.toDouble();
}

// ── Points Table View ─────────────────────────────────────────────────────────

class _PointsTableView extends StatelessWidget {
  final String tournamentId;
  final Tournament tournament;
  const _PointsTableView({
    required this.tournamentId,
    required this.tournament,
  });

  Map<String, _PTStat> _buildStats(
    List<TournamentMatch> matches,
    List<TournamentTeam> teams,
  ) {
    final stats = {
      for (final t in teams)
        t.id: _PTStat(
          t.teamName,
          teamId: t.id,
          wPts: tournament.winPoints,
          dPts: tournament.drawPoints,
          lPts: tournament.lossPoints,
        ),
    };
    for (final m in matches) {
      if (!m.isPlayed || m.isBye) continue;
      _accum(stats, m.teamAId, m.scoreA, m.scoreB, m.result, isA: true);
      _accum(stats, m.teamBId, m.scoreB, m.scoreA, m.result, isA: false);
    }
    return stats;
  }

  void _accum(
    Map<String, _PTStat> stats,
    String? id,
    int? sf,
    int? sa,
    TournamentMatchResult result, {
    required bool isA,
  }) {
    if (id == null || !stats.containsKey(id)) return;
    final s = stats[id]!;
    s.played++;
    s.scoreFor += sf ?? 0;
    s.scoreAgainst += sa ?? 0;
    if (result == TournamentMatchResult.teamAWin) {
      if (isA) {
        s.won++;
      } else {
        s.lost++;
      }
    } else if (result == TournamentMatchResult.teamBWin) {
      if (!isA) {
        s.won++;
      } else {
        s.lost++;
      }
    } else if (result == TournamentMatchResult.draw) {
      s.drawn++;
    }
  }

  List<_PTStat> _sorted(Map<String, _PTStat> all, Set<String> ids) =>
      all.entries.where((e) => ids.contains(e.key)).map((e) => e.value).toList()
        ..sort((a, b) {
          final c = b.pts.compareTo(a.pts);
          return c != 0 ? c : b.nrr.compareTo(a.nrr);
        });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TournamentService(),
      builder: (context, _) {
        final svc = TournamentService();
        final teams = svc.teamsFor(tournamentId);
        final matches = svc.matchesFor(tournamentId);
        final groups = svc.groupsFor(tournamentId);

        if (teams.isEmpty) {
          return const _EmptyState(
            icon: Icons.table_chart_outlined,
            label: 'No teams registered yet',
          );
        }

        final allStats = _buildStats(matches, teams);

        if (groups.isNotEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: groups.map((g) {
              final sorted = _sorted(allStats, g.teamIds.toSet());
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GroupTableHeader(groupName: g.name),
                  _CricbuzzTable(
                    stats: sorted,
                    sport: tournament.sport,
                    tournamentId: tournamentId,
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }).toList(),
          );
        }

        final allIds = {for (final t in teams) t.id};
        final sorted = _sorted(allStats, allIds);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _CricbuzzTable(
              stats: sorted,
              sport: tournament.sport,
              tournamentId: tournamentId,
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

// ── Group header for table ────────────────────────────────────────────────────

class _GroupTableHeader extends StatelessWidget {
  final String groupName;
  const _GroupTableHeader({required this.groupName});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Text(
            groupName,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Cricbuzz-style points table ───────────────────────────────────────────────

class _CricbuzzTable extends StatelessWidget {
  final List<_PTStat> stats;
  final String sport;
  final String tournamentId;
  const _CricbuzzTable({
    required this.stats,
    required this.sport,
    required this.tournamentId,
  });

  bool get _isCricket => sport.toLowerCase() == 'cricket';
  String get _diffLabel => _isCricket ? 'NRR' : 'GD';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF222222),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'TEAM',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _th('M'),
                _th('W'),
                _th('L'),
                _th('D'),
                _th('PTS', color: AppColors.primary),
                _th(_diffLabel),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // ── Data rows ─────────────────────────────────────────────────────
          if (stats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No results yet',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ...stats.asMap().entries.map((e) {
              final rank = e.key + 1;
              final s = e.value;
              final top2 = rank <= 2 && s.played > 0;
              return Column(
                children: [
                  if (e.key > 0)
                    const Divider(height: 1, color: Colors.white10),
                  InkWell(
                    onTap: () {
                      final team = TournamentService()
                          .teamsFor(tournamentId)
                          .where((t) => t.id == s.teamId)
                          .firstOrNull;
                      if (team != null) {
                        _TeamDetailSheet.show(
                          context,
                          tournamentId: tournamentId,
                          team: team,
                        );
                      }
                    },
                    child: Container(
                      color: top2
                          ? AppColors.primary.withAlpha(10)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          // Rank
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$rank',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: top2
                                    ? AppColors.primary
                                    : Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Avatar
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: top2
                                  ? AppColors.primary.withAlpha(40)
                                  : Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                s.name.isNotEmpty
                                    ? s.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: top2
                                      ? AppColors.primary
                                      : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Team name
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                color: top2 ? Colors.white : Colors.white70,
                                fontSize: 13,
                                fontWeight: top2
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _td('${s.played}'),
                          _td(
                            '${s.won}',
                            color: s.won > 0 ? Colors.green[300] : null,
                          ),
                          _td(
                            '${s.lost}',
                            color: s.lost > 0 ? Colors.red[300] : null,
                          ),
                          _td('${s.drawn}'),
                          _td('${s.pts}', bold: true, color: AppColors.primary),
                          _td(
                            s.played == 0
                                ? '–'
                                : '${s.nrr >= 0 ? "+" : ""}${s.nrr.toStringAsFixed(2)}',
                            color: s.nrr > 0
                                ? Colors.green
                                : s.nrr < 0
                                ? Colors.red[300]
                                : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _th(String text, {Color color = Colors.white38}) => SizedBox(
    width: 38,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _td(String text, {bool bold = false, Color? color}) => SizedBox(
    width: 38,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? Colors.white54,
        fontSize: 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 3: Stats
// ══════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatelessWidget {
  final String tournamentId;
  final Tournament tournament;
  const _StatsTab({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final matches = TournamentService().matchesFor(tournamentId);
    final played = matches.where((m) => m.isPlayed && !m.isBye).toList();

    if (played.isEmpty) {
      return const _EmptyState(
        icon: Icons.bar_chart_outlined,
        label: 'No results yet',
      );
    }

    // Aggregate team stats from played matches
    final Map<String, _TeamStat> stats = {};
    for (final m in played) {
      if (m.teamAId != null && m.teamAName != null) {
        stats.putIfAbsent(m.teamAId!, () => _TeamStat(m.teamAName!));
        stats[m.teamAId!]!.goalsFor += m.scoreA ?? 0;
        stats[m.teamAId!]!.goalsAgainst += m.scoreB ?? 0;
        if (m.result == TournamentMatchResult.teamAWin)
          stats[m.teamAId!]!.wins++;
      }
      if (m.teamBId != null && m.teamBName != null) {
        stats.putIfAbsent(m.teamBId!, () => _TeamStat(m.teamBName!));
        stats[m.teamBId!]!.goalsFor += m.scoreB ?? 0;
        stats[m.teamBId!]!.goalsAgainst += m.scoreA ?? 0;
        if (m.result == TournamentMatchResult.teamBWin)
          stats[m.teamBId!]!.wins++;
      }
    }

    final sorted = stats.values.toList()
      ..sort((a, b) {
        final wCmp = b.wins.compareTo(a.wins);
        if (wCmp != 0) return wCmp;
        return b.goalsFor.compareTo(a.goalsFor);
      });

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _StatsHeader(sport: tournament.sport),
        const SizedBox(height: 8),
        ...sorted.asMap().entries.map(
          (e) =>
              _StatRow(rank: e.key + 1, stat: e.value, sport: tournament.sport),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _TeamStat {
  final String name;
  int wins = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  _TeamStat(this.name);
  int get goalDiff => goalsFor - goalsAgainst;
}

class _StatsHeader extends StatelessWidget {
  final String sport;
  const _StatsHeader({required this.sport});

  String get _scoreLabel {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return 'Runs';
      case 'basketball':
        return 'Points';
      case 'tennis':
        return 'Sets';
      case 'volleyball':
        return 'Sets';
      default:
        return 'Goals';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Team',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              'W',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              _scoreLabel,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 40,
            child: const Text(
              '+/-',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final int rank;
  final _TeamStat stat;
  final String sport;
  const _StatRow({required this.rank, required this.stat, required this.sport});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rank == 1
            ? AppColors.primary.withAlpha(15)
            : const Color(0xFF161616),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank == 1
              ? AppColors.primary.withAlpha(60)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? AppColors.primary : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stat.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${stat.wins}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${stat.goalsFor}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${stat.goalDiff >= 0 ? "+" : ""}${stat.goalDiff}',
              style: TextStyle(
                color: stat.goalDiff > 0
                    ? Colors.green
                    : stat.goalDiff < 0
                    ? Colors.red
                    : Colors.white38,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 4: Squads
// ══════════════════════════════════════════════════════════════════════════════

class _SquadsTab extends StatefulWidget {
  final String tournamentId;
  const _SquadsTab({required this.tournamentId});

  @override
  State<_SquadsTab> createState() => _SquadsTabState();
}

class _SquadsTabState extends State<_SquadsTab> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final svc = TournamentService();
    final teams = svc.teamsFor(widget.tournamentId);

    if (teams.isEmpty) {
      return const _EmptyState(
        icon: Icons.group_outlined,
        label: 'No teams registered yet',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: teams.map((team) {
        final isOpen = _expanded.contains(team.id);
        final squad = svc.squadFor(widget.tournamentId, team.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              // Team header (tap to expand, long-press for detail)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  setState(() {
                    if (isOpen) {
                      _expanded.remove(team.id);
                    } else {
                      _expanded.add(team.id);
                    }
                  });
                  if (!isOpen) {
                    await svc.loadSquad(widget.tournamentId, team.id);
                  }
                },
                onLongPress: () => _TeamDetailSheet.show(
                  context,
                  tournamentId: widget.tournamentId,
                  team: team,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            team.teamName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.teamName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Captain: ${team.captainName}  •  ${team.players.length} players',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isOpen ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white38,
                      ),
                    ],
                  ),
                ),
              ),
              // Squad list (prefer squad subcollection, fall back to team.players)
              if (isOpen) ...[
                const Divider(height: 1, color: Colors.white12),
                if (squad.isNotEmpty)
                  ...squad.map((p) => _SquadPlayerTile(player: p))
                else if (team.players.isNotEmpty)
                  ...team.players.asMap().entries.map((e) {
                    final name = e.value;
                    final idx = e.key;
                    final userId = idx < team.playerUserIds.length
                        ? team.playerUserIds[idx]
                        : '';
                    return InkWell(
                      onTap: userId.isNotEmpty
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileScreen(userId: userId),
                              ),
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (name == team.captainName) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'C',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            if (userId.isNotEmpty)
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white24,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    );
                  })
                else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No squad members added yet',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SquadPlayerTile extends StatelessWidget {
  final TournamentSquadPlayer player;
  const _SquadPlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    final hasTap = player.userId.isNotEmpty;
    return InkWell(
      onTap: hasTap
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: player.userId),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  player.jerseyNumber > 0
                      ? '${player.jerseyNumber}'
                      : player.playerName.isNotEmpty
                      ? player.playerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.playerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (player.isCaptain) ...[
                        const SizedBox(width: 6),
                        _RoleBadge('C', AppColors.primary),
                      ],
                      if (player.isViceCaptain) ...[
                        const SizedBox(width: 4),
                        _RoleBadge('VC', Colors.orange),
                      ],
                    ],
                  ),
                  if (player.role.isNotEmpty)
                    Text(
                      player.role,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (player.playerId.isNotEmpty)
              Text(
                player.playerId,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            if (hasTap)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white24,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 5: Venues
// ══════════════════════════════════════════════════════════════════════════════

class _VenuesTab extends StatelessWidget {
  final String tournamentId;
  final bool canManage;
  const _VenuesTab({required this.tournamentId, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final venues = TournamentService().venuesFor(tournamentId);

    if (venues.isEmpty) {
      return _EmptyState(
        icon: Icons.location_on_outlined,
        label: 'No venues added yet',
        action: canManage
            ? ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showAddVenueSheet(context),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text(
                  'Add Venue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: venues
              .map(
                (v) => _VenueCard(
                  venue: v,
                  canManage: canManage,
                  onDelete: () async {
                    await TournamentService().removeVenue(tournamentId, v.id);
                  },
                ),
              )
              .toList(),
        ),
        if (canManage)
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'add_venue',
              backgroundColor: AppColors.primary,
              onPressed: () => _showAddVenueSheet(context),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  void _showAddVenueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddVenueSheet(tournamentId: tournamentId),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final TournamentVenue venue;
  final bool canManage;
  final VoidCallback onDelete;
  const _VenueCard({
    required this.venue,
    required this.canManage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.stadium_outlined, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (venue.address.isNotEmpty || venue.city.isNotEmpty)
                  Text(
                    '${venue.address}${venue.city.isNotEmpty ? ", ${venue.city}" : ""}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (venue.pitchType.isNotEmpty)
                      _Tag(venue.pitchType, Colors.purple),
                    if (venue.hasFloodlights) ...[
                      const SizedBox(width: 6),
                      _Tag('Floodlights', Colors.amber),
                    ],
                    if (venue.capacity > 0) ...[
                      const SizedBox(width: 6),
                      _Tag('${venue.capacity} cap', Colors.teal),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}

class _AddVenueSheet extends StatefulWidget {
  final String tournamentId;
  const _AddVenueSheet({required this.tournamentId});

  @override
  State<_AddVenueSheet> createState() => _AddVenueSheetState();
}

class _AddVenueSheetState extends State<_AddVenueSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  String _pitchType = '';
  bool _floodlights = false;
  bool _saving = false;

  static const _pitchTypes = [
    'Grass',
    'Turf',
    'Indoor',
    'Hard Court',
    'Clay',
    'Parquet',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Venue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _Field(controller: _nameCtrl, hint: 'Venue name *'),
          const SizedBox(height: 10),
          _Field(controller: _addressCtrl, hint: 'Address'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Field(controller: _cityCtrl, hint: 'City'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  controller: _capCtrl,
                  hint: 'Capacity',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<String>(
              value: _pitchType.isEmpty ? null : _pitchType,
              hint: const Text(
                'Pitch type',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: _pitchTypes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _pitchType = v ?? ''),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Has Floodlights',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            value: _floodlights,
            onChanged: (v) => setState(() => _floodlights = v),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Add Venue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await TournamentService().addVenue(
        tournamentId: widget.tournamentId,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        capacity: int.tryParse(_capCtrl.text.trim()) ?? 0,
        pitchType: _pitchType,
        hasFloodlights: _floodlights,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab 6: Forecast
// ══════════════════════════════════════════════════════════════════════════════

class _ForecastTab extends StatelessWidget {
  final String tournamentId;
  final Tournament tournament;
  const _ForecastTab({required this.tournamentId, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final svc = TournamentService();
    final matches = svc.matchesFor(tournamentId);
    final teams = svc.teamsFor(tournamentId);

    final upcoming = matches
        .where((m) => !m.isPlayed && !m.isBye && !m.isTBD)
        .toList();
    final played = matches.where((m) => m.isPlayed && !m.isBye).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Next match preview
        if (upcoming.isNotEmpty) ...[
          const _SectionTitle('Next Match'),
          const SizedBox(height: 8),
          _NextMatchCard(match: upcoming.first, teams: teams),
          const SizedBox(height: 24),
        ],

        // Tournament progress
        if (played.isNotEmpty) ...[
          const _SectionTitle('Tournament Progress'),
          const SizedBox(height: 8),
          _ProgressCard(
            played: played.length,
            total: matches.where((m) => !m.isBye).length,
            status: tournament.status,
          ),
          const SizedBox(height: 24),
        ],

        // Team form (win rate)
        if (played.isNotEmpty) ...[
          const _SectionTitle('Team Form'),
          const SizedBox(height: 8),
          _TeamFormCard(played: played, teams: teams),
          const SizedBox(height: 80),
        ],

        if (upcoming.isEmpty && played.isEmpty)
          const _EmptyState(
            icon: Icons.insights_outlined,
            label: 'No data to forecast yet',
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white54,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );
}

class _NextMatchCard extends StatelessWidget {
  final TournamentMatch match;
  final List<TournamentTeam> teams;
  const _NextMatchCard({required this.match, required this.teams});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E1E3A), const Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        children: [
          if (match.note != null)
            Text(
              match.note!.toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamPreview(
                  name: match.teamAName ?? 'TBD',
                  teams: teams,
                  teamId: match.teamAId,
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: _TeamPreview(
                  name: match.teamBName ?? 'TBD',
                  teams: teams,
                  teamId: match.teamBId,
                  alignRight: true,
                ),
              ),
            ],
          ),
          if (match.venueName != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  match.venueName!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamPreview extends StatelessWidget {
  final String name;
  final List<TournamentTeam> teams;
  final String? teamId;
  final bool alignRight;
  const _TeamPreview({
    required this.name,
    required this.teams,
    required this.teamId,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withAlpha(80)),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          textAlign: alignRight ? TextAlign.end : TextAlign.start,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int played;
  final int total;
  final TournamentStatus status;
  const _ProgressCard({
    required this.played,
    required this.total,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? played / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$played / $total matches played',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white12,
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamFormCard extends StatelessWidget {
  final List<TournamentMatch> played;
  final List<TournamentTeam> teams;
  const _TeamFormCard({required this.played, required this.teams});

  @override
  Widget build(BuildContext context) {
    // Calculate win rate per team
    final Map<String, ({String name, int w, int p})> form = {};
    for (final m in played) {
      if (m.teamAId != null) {
        final prev = form[m.teamAId!];
        form[m.teamAId!] = (
          name: m.teamAName ?? '',
          w:
              (prev?.w ?? 0) +
              (m.result == TournamentMatchResult.teamAWin ? 1 : 0),
          p: (prev?.p ?? 0) + 1,
        );
      }
      if (m.teamBId != null) {
        final prev = form[m.teamBId!];
        form[m.teamBId!] = (
          name: m.teamBName ?? '',
          w:
              (prev?.w ?? 0) +
              (m.result == TournamentMatchResult.teamBWin ? 1 : 0),
          p: (prev?.p ?? 0) + 1,
        );
      }
    }
    final sorted = form.values.toList()
      ..sort((a, b) {
        final ra = a.p > 0 ? a.w / a.p : 0.0;
        final rb = b.p > 0 ? b.w / b.p : 0.0;
        return rb.compareTo(ra);
      });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: sorted.map((f) {
          final rate = f.p > 0 ? f.w / f.p : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    f.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${f.w}W/${f.p}G',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: Colors.white12,
                      color: rate >= 0.6
                          ? Colors.green
                          : rate >= 0.4
                          ? Colors.orange
                          : Colors.red,
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? action;
  const _EmptyState({required this.icon, required this.label, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withAlpha(35), size: 56),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Deuce Result Sheet — live point tracker with deuce / advantage / game logic
// ══════════════════════════════════════════════════════════════════════════════

class _DeuceResultSheet extends StatefulWidget {
  final TournamentMatch match;
  final Tournament tournament;
  final Future<void> Function(int sA, int sB) onSave;

  const _DeuceResultSheet({
    required this.match,
    required this.tournament,
    required this.onSave,
  });

  @override
  State<_DeuceResultSheet> createState() => _DeuceResultSheetState();
}

class _DeuceResultSheetState extends State<_DeuceResultSheet> {
  // For bestOfSets: track each completed set and current-set live score
  // For standard: track one game score
  int _scoreA = 0;
  int _scoreB = 0;

  // Completed sets: list of (scoreA, scoreB)
  final List<(int, int)> _sets = [];

  // Point history for undo — true = A scored, false = B scored
  final List<bool> _history = [];

  bool _saving = false;

  int get _ptw => widget.tournament.pointsToWin;
  bool get _isBestOfSets =>
      widget.tournament.scoringType == ScoringType.bestOfSets;
  int get _bestOf => widget.tournament.bestOf;

  // ── Deuce helpers ──────────────────────────────────────────────────────────

  bool get _inDeuceZone => _scoreA >= _ptw - 1 && _scoreB >= _ptw - 1;
  bool get _isDeuce => _inDeuceZone && _scoreA == _scoreB;

  // 0 = A has advantage, 1 = B has advantage, null = none
  int? get _advantage {
    if (!_inDeuceZone) return null;
    if (_scoreA == _scoreB + 1) return 0;
    if (_scoreB == _scoreA + 1) return 1;
    return null;
  }

  // 0 = A won current game/set, 1 = B won, null = ongoing
  int? get _gameWinner {
    if (_scoreA >= _ptw && _scoreA >= _scoreB + 2) return 0;
    if (_scoreB >= _ptw && _scoreB >= _scoreA + 2) return 1;
    return null;
  }

  // Sets won
  int get _setsA => _sets.where((s) => s.$1 > s.$2).length;
  int get _setsB => _sets.where((s) => s.$2 > s.$1).length;
  int get _setsNeeded => (_bestOf / 2).ceil();

  // Match winner (only for bestOfSets)
  int? get _matchWinner {
    if (!_isBestOfSets) return null;
    if (_setsA >= _setsNeeded) return 0;
    if (_setsB >= _setsNeeded) return 1;
    return null;
  }

  bool get _canSave {
    if (_isBestOfSets) return _matchWinner != null;
    return _gameWinner != null;
  }

  // ── Status label ───────────────────────────────────────────────────────────

  String get _statusLabel {
    final nameA = widget.match.teamAName ?? 'Team A';
    final nameB = widget.match.teamBName ?? 'Team B';

    if (_isBestOfSets) {
      final mw = _matchWinner;
      if (mw == 0) return 'MATCH — $nameA wins!';
      if (mw == 1) return 'MATCH — $nameB wins!';
      final gw = _gameWinner;
      if (gw == 0) return 'SET — $nameA wins';
      if (gw == 1) return 'SET — $nameB wins';
    } else {
      final gw = _gameWinner;
      if (gw == 0) return 'GAME — $nameA wins!';
      if (gw == 1) return 'GAME — $nameB wins!';
    }
    if (_isDeuce) return 'DEUCE';
    final adv = _advantage;
    if (adv == 0) return 'ADV: ${widget.match.teamAName ?? "Team A"}';
    if (adv == 1) return 'ADV: ${widget.match.teamBName ?? "Team B"}';
    return '';
  }

  Color get _statusColor {
    if (_statusLabel.startsWith('MATCH') || _statusLabel.startsWith('GAME')) {
      return AppColors.primary;
    }
    if (_statusLabel == 'DEUCE') return Colors.orange;
    if (_statusLabel.startsWith('ADV')) return Colors.amber;
    return Colors.transparent;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _addPoint(bool isA) {
    // If set/game is over in bestOfSets, auto-advance to next set
    if (_isBestOfSets && _gameWinner != null && _matchWinner == null) return;
    if (_gameWinner != null && !_isBestOfSets) return;
    setState(() {
      if (isA) {
        _scoreA++;
      } else {
        _scoreB++;
      }
      _history.add(isA);
    });
    // Auto-advance set when a set winner is found
    if (_isBestOfSets && _gameWinner != null && _matchWinner == null) {
      Future.delayed(const Duration(milliseconds: 600), _nextSet);
    }
  }

  void _nextSet() {
    if (!mounted) return;
    setState(() {
      _sets.add((_scoreA, _scoreB));
      _scoreA = 0;
      _scoreB = 0;
      _history.clear();
    });
  }

  void _undo() {
    if (_history.isEmpty) {
      // Restore previous set
      if (_sets.isNotEmpty) {
        setState(() {
          final last = _sets.removeLast();
          _scoreA = last.$1;
          _scoreB = last.$2;
        });
      }
      return;
    }
    setState(() {
      final wasA = _history.removeLast();
      if (wasA) {
        _scoreA--;
      } else {
        _scoreB--;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      int finalA, finalB;
      if (_isBestOfSets) {
        // For bestOfSets save as sets won
        final allSets = [..._sets];
        if (_gameWinner != null) allSets.add((_scoreA, _scoreB));
        finalA = allSets.where((s) => s.$1 > s.$2).length;
        finalB = allSets.where((s) => s.$2 > s.$1).length;
      } else {
        finalA = _scoreA;
        finalB = _scoreB;
      }
      await widget.onSave(finalA, finalB);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nameA = widget.match.teamAName ?? 'Team A';
    final nameB = widget.match.teamBName ?? 'Team B';
    final label = _statusLabel;
    final matchDone = _isBestOfSets
        ? _matchWinner != null
        : _gameWinner != null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _isBestOfSets
                ? 'Best of $_bestOf  •  First to $_setsNeeded sets'
                : 'First to $_ptw  (win by 2)',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter Result',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),

          // Set history (bestOfSets only)
          if (_isBestOfSets && _sets.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _sets.asMap().entries.map((e) {
                final aWon = e.value.$1 > e.value.$2;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    'Set ${e.key + 1}:  ${e.value.$1}–${e.value.$2}',
                    style: TextStyle(
                      color: aWon ? AppColors.primary : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Sets won indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sets: ',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                Text(
                  '$_setsA',
                  style: TextStyle(
                    color: _setsA > _setsB ? AppColors.primary : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  ' – ',
                  style: TextStyle(color: Colors.white24, fontSize: 14),
                ),
                Text(
                  '$_setsB',
                  style: TextStyle(
                    color: _setsB > _setsA ? AppColors.primary : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Status badge
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: label.isEmpty
                ? const SizedBox(height: 28, key: ValueKey('empty'))
                : Container(
                    key: ValueKey(label),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor.withAlpha(100)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Score display + tap buttons
          Row(
            children: [
              // Team A
              Expanded(
                child: _ScorePanel(
                  name: nameA,
                  score: _scoreA,
                  canAdd: !matchDone && (_gameWinner == null || _isBestOfSets),
                  isWinner: _gameWinner == 0 || _matchWinner == 0,
                  onAdd: () => _addPoint(true),
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Undo
                    GestureDetector(
                      onTap: _history.isEmpty && _sets.isEmpty ? null : _undo,
                      child: Icon(
                        Icons.undo_rounded,
                        color: (_history.isEmpty && _sets.isEmpty)
                            ? Colors.white12
                            : Colors.white38,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // Team B
              Expanded(
                child: _ScorePanel(
                  name: nameB,
                  score: _scoreB,
                  canAdd: !matchDone && (_gameWinner == null || _isBestOfSets),
                  isWinner: _gameWinner == 1 || _matchWinner == 1,
                  onAdd: () => _addPoint(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSave ? AppColors.primary : Colors.white12,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: (_canSave && !_saving) ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _canSave ? 'Save Result' : 'Keep scoring…',
                      style: TextStyle(
                        color: _canSave ? Colors.white : Colors.white30,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score panel (one side) ────────────────────────────────────────────────────

class _ScorePanel extends StatelessWidget {
  final String name;
  final int score;
  final bool canAdd;
  final bool isWinner;
  final VoidCallback onAdd;

  const _ScorePanel({
    required this.name,
    required this.score,
    required this.canAdd,
    required this.isWinner,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: isWinner ? AppColors.primary : Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        // Score
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Text(
            '$score',
            key: ValueKey(score),
            style: TextStyle(
              color: isWinner ? AppColors.primary : Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // +1 button
        GestureDetector(
          onTap: canAdd ? onAdd : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: canAdd
                  ? AppColors.primary.withAlpha(30)
                  : Colors.white.withAlpha(8),
              border: Border.all(
                color: canAdd ? AppColors.primary : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: canAdd ? AppColors.primary : Colors.white12,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}

// ── Procedural banner generator — unique gradient per tournament ──────────────
// Uses the tournament ID hash to pick a deterministic color palette per sport.

class TournamentBannerPainter extends CustomPainter {
  final String tournamentId;
  final String sport;
  final String tournamentName;

  TournamentBannerPainter({
    required this.tournamentId,
    required this.sport,
    required this.tournamentName,
  });

  // Map sport → list of palette pairs [dark, mid, accent]
  static const Map<String, List<List<int>>> _sportPalettes = {
    'cricket': [
      [0xFF0D3B1E, 0xFF1B6B35, 0xFF4CAF50],
      [0xFF0A2744, 0xFF1565C0, 0xFF42A5F5],
      [0xFF3E1A00, 0xFF8D4A00, 0xFFFFB300],
    ],
    'football': [
      [0xFF0D1B2A, 0xFF1A3A5C, 0xFF2196F3],
      [0xFF1A0A00, 0xFF6D2E00, 0xFFFF6F00],
      [0xFF1B0033, 0xFF4A0080, 0xFF9C27B0],
    ],
    'basketball': [
      [0xFF2A0A00, 0xFF8B3000, 0xFFFF6D00],
      [0xFF1A1A00, 0xFF5C4A00, 0xFFFFD600],
      [0xFF0A0A2A, 0xFF1A1A6B, 0xFF3F51B5],
    ],
    'badminton': [
      [0xFF001A2A, 0xFF00506B, 0xFF00BCD4],
      [0xFF1A2A00, 0xFF4A6B00, 0xFF8BC34A],
      [0xFF2A001A, 0xFF6B0050, 0xFFE91E63],
    ],
    'tennis': [
      [0xFF1A2A00, 0xFF4A6B00, 0xFF9CCC65],
      [0xFF2A1A00, 0xFF6B4500, 0xFFFF9800],
      [0xFF001A1A, 0xFF006B6B, 0xFF26C6DA],
    ],
    'volleyball': [
      [0xFF1A0033, 0xFF5C0099, 0xFFAB47BC],
      [0xFF001A33, 0xFF004D99, 0xFF42A5F5],
      [0xFF2A1500, 0xFF6B3800, 0xFFFF8F00],
    ],
    'chess': [
      [0xFF111111, 0xFF333333, 0xFF888888],
      [0xFF1A0A00, 0xFF4A2500, 0xFFD4A017],
      [0xFF0A001A, 0xFF2E0057, 0xFF7E57C2],
    ],
  };

  static const Map<String, String> _sportEmoji = {
    'cricket': '🏏',
    'football': '⚽',
    'basketball': '🏀',
    'badminton': '🏸',
    'tennis': '🎾',
    'volleyball': '🏐',
    'chess': '♟️',
  };

  List<Color> _pickPalette() {
    final key = sport.toLowerCase();
    final palettes = _sportPalettes[key] ?? _sportPalettes['football']!;
    // Use hash of tournamentId to deterministically pick a palette
    final hash = tournamentId.codeUnits.fold(0, (a, b) => a + b);
    final picked = palettes[hash % palettes.length];
    return picked.map((c) => Color(c)).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _pickPalette();
    final dark = palette[0];
    final mid = palette[1];
    final accent = palette[2];

    // Background gradient — left dark, right mid
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [dark, mid],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Diagonal accent band from bottom-left
    final bandPaint = Paint()..color = accent.withValues(alpha: 0.12);
    final bandPath = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.65, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(0, size.height * 0.78)
      ..close();
    canvas.drawPath(bandPath, bandPaint);

    // Subtle circle decoration top-right
    final circlePaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.2),
      size.height * 0.9,
      circlePaint,
    );

    // Accent line at bottom
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      linePaint,
    );

    // Sport emoji watermark
    final emoji = _sportEmoji[sport.toLowerCase()] ?? '🏆';
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.height * 0.55,
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(
      canvas,
      Offset(
        size.width / 2 - emojiPainter.width / 2,
        size.height / 2 - emojiPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Match VS banner (IPL-style: players at left/right edges) ─────────────────

class _MatchVsBanner extends StatelessWidget {
  final String teamA;
  final String teamB;
  final String label;
  final bool isLive;
  final bool isPlayed;
  final String sport;
  final String? teamAPhotoUrl;
  final String? teamBPhotoUrl;
  final DateTime? scheduledAt;
  final bool isMyMatch;
  final String tournamentId;

  const _MatchVsBanner({
    required this.teamA,
    required this.teamB,
    required this.label,
    required this.isLive,
    required this.isPlayed,
    required this.sport,
    required this.isMyMatch,
    required this.tournamentId,
    this.teamAPhotoUrl,
    this.teamBPhotoUrl,
    this.scheduledAt,
  });

  String _sportBadge() {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return 'T20';
      case 'football':
        return 'Football';
      case 'basketball':
        return 'Basketball';
      case 'badminton':
        return 'Badminton';
      case 'tennis':
        return 'Tennis';
      case 'volleyball':
        return 'Volleyball';
      default:
        return sport;
    }
  }

  String _scheduledLabel() {
    if (scheduledAt == null) return '';
    final now = DateTime.now();
    final date = scheduledAt!;
    final time = _fmtTime(date);
    final diff = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today • $time';
    if (diff == 1) return 'Tomorrow • $time';
    if (diff == -1) return 'Yesterday • $time';
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[(date.weekday - 1) % 7]} ${date.day} ${mo[date.month - 1]} • $time';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    const double bannerH = 168;
    const double photoD = 76;

    return SizedBox(
      height: bannerH,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Background: fixed app-theme banner ──
          Positioned.fill(
            child: CustomPaint(painter: MatchCardBannerPainter()),
          ),

          // ── Live overlay tint ──
          if (isLive)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.35),
                      Colors.red.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),

          // ── Full layout in a Column ──
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                children: [
                  // ── Row 1: status badge + match label + sport badge ──
                  Row(
                    children: [
                      if (isLive)
                        _Badge(
                          label: 'LIVE',
                          icon: Icons.circle,
                          iconColor: Colors.red,
                          bgColor: Colors.red.withValues(alpha: 0.25),
                          borderColor: Colors.red.withValues(alpha: 0.6),
                          textColor: Colors.red,
                        )
                      else if (isMyMatch)
                        _Badge(
                          label: 'YOUR MATCH',
                          bgColor: AppColors.primary.withValues(alpha: 0.25),
                          borderColor: AppColors.primary.withValues(alpha: 0.4),
                          textColor: AppColors.primary,
                        )
                      else
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      _Badge(
                        label: _sportBadge(),
                        bgColor: Colors.white.withValues(alpha: 0.12),
                        borderColor: Colors.white.withValues(alpha: 0.2),
                        textColor: Colors.white,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── Row 2: [Photo + Name]  VS  [Photo + Name] ──
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Team A — photo left, name below
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PlayerSilhouette(
                                name: teamA,
                                photoUrl: teamAPhotoUrl,
                                diameter: photoD,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                teamA,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // VS center
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              // Scheduled time shown below VS for upcoming
                              if (!isLive &&
                                  !isPlayed &&
                                  scheduledAt != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.amber,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _scheduledLabel(),
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Team B — photo right, name below
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PlayerSilhouette(
                                name: teamB,
                                photoUrl: teamBPhotoUrl,
                                diameter: photoD,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                teamB,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player silhouette — large circle at card edge ─────────────────────────────

class _PlayerSilhouette extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double diameter;

  const _PlayerSilhouette({
    required this.name,
    required this.diameter,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final Widget avatar = photoUrl != null && photoUrl!.isNotEmpty
        ? CircleAvatar(
            radius: diameter / 2,
            backgroundImage: NetworkImage(photoUrl!),
            backgroundColor: Colors.white12,
            onBackgroundImageError: (_, _) {},
          )
        : CircleAvatar(
            radius: diameter / 2,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: diameter * 0.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          );

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: avatar,
    );
  }
}

// ── Reusable badge ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;
  final Color? iconColor;

  const _Badge({
    required this.label,
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 6),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Team Detail Sheet — shows team info, players, and their matches
// ══════════════════════════════════════════════════════════════════════════════

class _TeamDetailSheet extends StatelessWidget {
  final String tournamentId;
  final TournamentTeam team;
  final ScrollController scrollCtrl;

  const _TeamDetailSheet({
    required this.tournamentId,
    required this.team,
    required this.scrollCtrl,
  });

  static void show(
    BuildContext context, {
    required String tournamentId,
    required TournamentTeam team,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _TeamDetailSheet(
            tournamentId: tournamentId,
            team: team,
            scrollCtrl: scroll,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = TournamentService();
    final matches = svc.matchesFor(tournamentId);

    // Filter matches involving this team
    final teamMatches = matches
        .where((m) => m.teamAId == team.id || m.teamBId == team.id)
        .toList();
    final played = teamMatches.where((m) => m.isPlayed).toList();
    final upcoming = teamMatches.where((m) => !m.isPlayed && !m.isBye).toList();

    // Stats
    int wins = 0, losses = 0, draws = 0, goalsFor = 0, goalsAgainst = 0;
    for (final m in played) {
      if (m.isBye) continue;
      final isA = m.teamAId == team.id;
      goalsFor += (isA ? m.scoreA : m.scoreB) ?? 0;
      goalsAgainst += (isA ? m.scoreB : m.scoreA) ?? 0;
      if (m.winnerId == team.id) {
        wins++;
      } else if (m.result == TournamentMatchResult.draw) {
        draws++;
      } else {
        losses++;
      }
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Team header
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  team.teamName.isNotEmpty
                      ? team.teamName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.teamName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Captain: ${team.captainName}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Stats row
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              _StatBox('P', '${played.length}'),
              _StatBox('W', '$wins', color: Colors.green),
              _StatBox('L', '$losses', color: Colors.red[300]),
              _StatBox('D', '$draws'),
              _StatBox('GF', '$goalsFor', color: AppColors.primary),
              _StatBox('GA', '$goalsAgainst'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Players
        if (team.players.isNotEmpty) ...[
          const Text(
            'SQUAD',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...team.players.asMap().entries.map((e) {
            final name = e.value;
            final idx = e.key;
            final userId = idx < team.playerUserIds.length
                ? team.playerUserIds[idx]
                : '';
            final isCaptain = name == team.captainName;

            return InkWell(
              onTap: userId.isNotEmpty
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: userId),
                      ),
                    )
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isCaptain
                            ? AppColors.primary.withAlpha(30)
                            : Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: isCaptain
                                ? AppColors.primary
                                : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isCaptain)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'C',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (userId.isNotEmpty)
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Matches
        const Text(
          'MATCHES',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        if (teamMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No matches scheduled yet',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          ...teamMatches.map((m) {
            final isA = m.teamAId == team.id;
            final opp = isA ? (m.teamBName ?? 'TBD') : (m.teamAName ?? 'TBD');
            final myScore = isA ? m.scoreA : m.scoreB;
            final oppScore = isA ? m.scoreB : m.scoreA;
            final won = m.winnerId == team.id;
            final lost =
                m.isPlayed && !won && m.result != TournamentMatchResult.draw;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: won
                      ? Colors.green.withAlpha(60)
                      : lost
                      ? Colors.red.withAlpha(40)
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  // Result badge
                  if (m.isPlayed && !m.isBye)
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: won
                            ? Colors.green.withAlpha(40)
                            : lost
                            ? Colors.red.withAlpha(30)
                            : Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          won
                              ? 'W'
                              : lost
                              ? 'L'
                              : 'D',
                          style: TextStyle(
                            color: won
                                ? Colors.green
                                : lost
                                ? Colors.red[300]
                                : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  else if (m.isBye)
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'BYE',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Opponent + score
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.isBye ? 'Bye' : 'vs $opp',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (m.isPlayed && !m.isBye)
                          Text(
                            '$myScore - $oppScore',
                            style: TextStyle(
                              color: won ? Colors.green : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Round label
                  Text(
                    'R${m.round}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${upcoming.length} upcoming match${upcoming.length > 1 ? "es" : ""}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBox(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ChoiceBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 13),
        ],
      ),
    ),
  );
}
