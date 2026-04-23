import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/game_listing_service.dart';
import '../../services/stats_service.dart';
import '../../services/tournament_service.dart';
import '../../services/user_service.dart';
import '../profile/edit_profile_screen.dart';
import '../settings/settings_screen.dart';
import 'web_avatar.dart';

const _kRed = Color(0xFFE53935);
const _kSurface = Color(0xFF14141C);
const _kCard = Color(0xFF1C1C28);
const _kBorder = Color(0xFF2A2A3A);
const _kMuted = Color(0xFF8888AA);
const _kText = Color(0xFFEEEEF5);

const _kSportColors = <String, Color>{
  'Cricket': Color(0xFF4CAF50),
  'Football': Color(0xFF66BB6A),
  'Basketball': Color(0xFFFF9800),
  'Badminton': Color(0xFF29B6F6),
  'Tennis': Color(0xFFFFEB3B),
  'Table Tennis': Color(0xFF26C6DA),
  'Volleyball': Color(0xFFAB47BC),
  'Hockey': Color(0xFFEF5350),
  'Swimming': Color(0xFF42A5F5),
  'Athletics': Color(0xFFFFCA28),
};

Color _sportColor(String sport) => _kSportColors[sport] ?? _kRed;

class WebProfilePage extends StatefulWidget {
  const WebProfilePage({super.key});

  @override
  State<WebProfilePage> createState() => _WebProfilePageState();
}

class _WebProfilePageState extends State<WebProfilePage> {
  bool _idCopied = false;

  @override
  void initState() {
    super.initState();
    StatsService().load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        UserService(),
        StatsService(),
        TournamentService(),
      ]),
      builder: (_, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final profile = UserService().profile;
    final name = profile?.name ?? 'Your Name';
    final email = profile?.email ?? '';
    final location = profile?.location ?? '';
    final bio = profile?.bio ?? '';
    final numId = profile?.numericId;
    final favSports = profile?.favoriteSports ?? [];
    final tournamentsPlayed = profile?.tournamentsPlayed ?? 0;
    final matchesPlayed = profile?.matchesPlayed ?? 0;
    final matchesWon = profile?.matchesWon ?? 0;

    final statsSvc = StatsService();
    final activeSports = statsSvc.activeSports;

    final allTournaments = TournamentService().tournaments;
    final userId = UserService().userId;
    final myGames = userId == null
        ? []
        : (GameListingService().openGames
              .where(
                (g) => g.organizerId == userId || g.playerIds.contains(userId),
              )
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)));
    final myTournaments = allTournaments.where((t) {
      final teams = TournamentService().teamsFor(t.id);
      return teams.any((team) => team.enrolledBy == userId);
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main content ───────────────────────────────────────────────────────
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileHeader(
                        name: name,
                        email: email,
                        location: location,
                        bio: bio,
                        numId: numId,
                        idCopied: _idCopied,
                        onCopyId: () async {
                          if (numId == null) return;
                          await Clipboard.setData(
                            ClipboardData(text: '$numId'),
                          );
                          await HapticFeedback.lightImpact();
                          if (!mounted) return;
                          setState(() => _idCopied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _idCopied = false);
                          });
                        },
                      ),
                      const SizedBox(height: 28),
                      // ── Stats overview row ─────────────────────────────────
                      Row(
                        children: [
                          _StatCard(
                            label: 'Tournaments',
                            value: '$tournamentsPlayed',
                            icon: Icons.emoji_events_rounded,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            label: 'Matches',
                            value: '$matchesPlayed',
                            icon: Icons.sports_rounded,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            label: 'Win Rate',
                            value: matchesPlayed > 0
                                ? '${((matchesWon / matchesPlayed) * 100).round()}%'
                                : '—',
                            icon: Icons.trending_up_rounded,
                          ),
                          const SizedBox(width: 16),
                          _StatCard(
                            label: 'Wins',
                            value: '$matchesWon',
                            icon: Icons.workspace_premium_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // ── Sport stats ────────────────────────────────────────
                      if (activeSports.isNotEmpty) ...[
                        _SectionLabel('Sport Statistics'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: activeSports.map((sport) {
                            final raw = statsSvc.statsForSport(sport);
                            return _SportStatCard(sport: sport, raw: raw);
                          }).toList(),
                        ),
                        const SizedBox(height: 28),
                      ],
                      // ── Favorite sports ────────────────────────────────────
                      if (favSports.isNotEmpty) ...[
                        _SectionLabel('Favorite Sports'),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: favSports.map((s) {
                            final c = _sportColor(s);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: c.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: c,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 28),
                      ],
                      // ── Upcoming Games ────────────────────────────────────
                      _SectionLabel('Upcoming Schedule'),
                      const SizedBox(height: 14),
                      if (myGames.isEmpty)
                        _EmptyCard(
                          icon: Icons.sports_rounded,
                          message: 'No upcoming games. Join or host a game!',
                        )
                      else
                        ...myGames
                            .take(4)
                            .map((g) => _UpcomingGameRow(game: g)),
                      const SizedBox(height: 28),
                      // ── My Tournaments ────────────────────────────────────
                      _SectionLabel('My Tournaments'),
                      const SizedBox(height: 14),
                      if (myTournaments.isEmpty)
                        _EmptyCard(
                          icon: Icons.emoji_events_outlined,
                          message: 'No tournaments enrolled yet.',
                        )
                      else
                        ...myTournaments.take(4).map((t) {
                          final color = _sportColor(t.sport);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _kCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.emoji_events_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.name,
                                        style: const TextStyle(
                                          color: _kText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        t.sport,
                                        style: const TextStyle(
                                          color: _kMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _StatusBadge(t.status.name),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Right panel ────────────────────────────────────────────────────────
        _RightPanel(name: name, email: email),
      ],
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.location,
    required this.bio,
    required this.numId,
    required this.idCopied,
    required this.onCopyId,
  });

  final String name, email, location, bio;
  final int? numId;
  final bool idCopied;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with camera overlay
          Builder(
            builder: (ctx) {
              final controller = ctx.watch<ProfileController>();
              final imageUrl =
                  controller.networkImageUrl ??
                  ctx.watch<UserService>().profile?.imageUrl;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  child: Stack(
                    children: [
                      WebAvatar(
                        imageUrl: imageUrl,
                        displayName: name,
                        size: 104,
                        backgroundColor: _kRed.withValues(alpha: 0.15),
                        textColor: _kRed,
                        borderColor: Colors.white.withValues(alpha: .08),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _kRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kSurface, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 24),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _kText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (numId != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onCopyId,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _kRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _kRed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ID: $numId',
                                style: const TextStyle(
                                  color: _kRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                idCopied
                                    ? Icons.check_rounded
                                    : Icons.copy_rounded,
                                color: _kRed,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(color: _kMuted, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (email.isNotEmpty)
                      _InfoChip(icon: Icons.email_outlined, label: email),
                    if (location.isNotEmpty)
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: location,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Right panel ───────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.name, required this.email});

  final String name, email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.fromLTRB(0, 28, 32, 0),
      child: Column(
        children: [
          // Account shortcuts card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _AccountItem(
                  icon: Icons.edit_outlined,
                  label: 'Edit Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                _AccountItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                _AccountItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () {},
                ),
                _AccountItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () {},
                ),
                const SizedBox(height: 4),
                const Divider(color: _kBorder),
                const SizedBox(height: 4),
                _AccountItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  labelColor: _kRed,
                  iconColor: _kRed,
                  onTap: () async {
                    final nav = Navigator.of(context, rootNavigator: true);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: _kSurface,
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(color: _kText),
                        ),
                        content: const Text(
                          'Are you sure you want to sign out?',
                          style: TextStyle(color: _kMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: _kMuted),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(color: _kRed),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await AuthService().signOut();
                      if (!nav.mounted) return;
                      nav.pushNamedAndRemoveUntil('/web-landing', (_) => false);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Membership card
          _MembershipCard(),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final planTier = UserService().planTier;
    final isPremium = planTier != PlanTier.free;
    final label = switch (planTier) {
      PlanTier.playerPremium => 'Player Premium',
      PlanTier.organizerPremium => 'Organizer Premium',
      _ => 'Free Plan',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFF2A1A0A), const Color(0xFF1A0A05)]
              : [const Color(0xFF1A1A2A), const Color(0xFF0F0F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFFF9800).withValues(alpha: 0.4)
              : _kBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPremium
                ? Icons.workspace_premium_rounded
                : Icons.star_border_rounded,
            color: isPremium ? const Color(0xFFFF9800) : _kMuted,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isPremium ? const Color(0xFFFFB74D) : _kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'All premium features unlocked'
                      : 'Upgrade for full access',
                  style: const TextStyle(color: _kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _kRed, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: _kText,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: _kMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SportStatCard extends StatelessWidget {
  const _SportStatCard({required this.sport, required this.raw});
  final String sport;
  final Map<String, dynamic>? raw;

  @override
  Widget build(BuildContext context) {
    final color = _sportColor(sport);
    final stats =
        (raw?['regular'] as Map?)?.cast<String, dynamic>() ?? raw ?? {};

    final entries = <MapEntry<String, String>>[];
    if (stats['batting'] != null) {
      final b = (stats['batting'] as Map).cast<String, dynamic>();
      if (b['runs'] != null) {
        entries.add(MapEntry('Runs', '${b['runs']}'));
      }
      if (b['innings'] != null) {
        entries.add(MapEntry('Innings', '${b['innings']}'));
      }
      if (b['highestScore'] != null) {
        entries.add(MapEntry('High Score', '${b['highestScore']}'));
      }
    }
    if (stats['bowling'] != null) {
      final bw = (stats['bowling'] as Map).cast<String, dynamic>();
      if (bw['wickets'] != null) {
        entries.add(MapEntry('Wickets', '${bw['wickets']}'));
      }
    }
    if (stats['matches'] != null) {
      entries.add(MapEntry('Matches', '${stats['matches']}'));
    }
    if (stats['wins'] != null) {
      entries.add(MapEntry('Wins', '${stats['wins']}'));
    }
    if (stats['goals'] != null) {
      entries.add(MapEntry('Goals', '${stats['goals']}'));
    }
    if (stats['assists'] != null) {
      entries.add(MapEntry('Assists', '${stats['assists']}'));
    }
    if (stats['points'] != null) {
      entries.add(MapEntry('Points', '${stats['points']}'));
    }

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sport,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No stats yet',
                style: TextStyle(color: _kMuted, fontSize: 12),
              ),
            )
          else
            ...entries
                .take(4)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(color: _kMuted, fontSize: 11),
                        ),
                        Text(
                          e.value,
                          style: const TextStyle(
                            color: _kText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _kMuted),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: _kMuted, fontSize: 12)),
      ],
    );
  }
}

class _AccountItem extends StatelessWidget {
  const _AccountItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? _kMuted),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: labelColor ?? _kText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: iconColor ?? _kMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status.toLowerCase()) {
      'ongoing' || 'active' => (const Color(0xFF4CAF50), 'Live'),
      'upcoming' => (_kRed, 'Upcoming'),
      'completed' => (_kMuted, 'Done'),
      _ => (_kMuted, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _kText,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _UpcomingGameRow extends StatelessWidget {
  final dynamic game;
  const _UpcomingGameRow({required this.game});

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    final dt = game.scheduledAt as DateTime;
    final sport = game.sport as String;
    final color = _sportColor(sport);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _months[dt.month - 1],
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${dt.day}',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sport,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dt.hour > 12
                      ? dt.hour - 12
                      : dt.hour == 0
                      ? 12
                      : dt.hour}'
                  ':${dt.minute.toString().padLeft(2, '0')} '
                  '${dt.hour >= 12 ? 'PM' : 'AM'}'
                  '${(game.venueName as String).isNotEmpty ? '  ·  ${game.venueName}' : ''}',
                  style: const TextStyle(color: _kMuted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: .35)),
            ),
            child: Text(
              sport,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _kMuted),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: _kMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
