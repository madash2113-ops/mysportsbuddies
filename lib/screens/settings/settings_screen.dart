import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../design/colors.dart';
import '../premium/premium_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../home/help_screen.dart';
import '../home/notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifGames     = true;
  bool _notifScores    = true;
  bool _notifCommunity = false;
  bool _notifTourneys  = true;
  bool _privateProfile = false;
  bool _showLocation   = true;

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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── AppBar ─────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: bg,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new,
                    color: textCol, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Settings',
                  style: TextStyle(
                      color: textCol,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),

            // ── Profile card ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ListenableBuilder(
                  listenable: UserService(),
                  builder: (ctx2, _) {
                    final prof   = UserService().profile;
                    final pc     = ctx2.watch<ProfileController>();
                    final avatar = pc.avatarImage;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: divCol),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: primary.withValues(alpha: 0.15),
                              backgroundImage: avatar,
                              child: avatar == null
                                  ? Icon(Icons.person, color: primary, size: 30)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (prof != null && prof.name.isNotEmpty)
                                        ? prof.name
                                        : 'My Profile',
                                    style: TextStyle(
                                        color: textCol,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (prof != null && prof.email.isNotEmpty)
                                        ? prof.email
                                        : 'Tap to edit name, photo & bio',
                                    style: TextStyle(color: subCol, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: subCol, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Notifications ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Section(
                label: 'Notifications',
                icon: Icons.notifications_outlined,
                isDark: isDark,
                textCol: textCol,
                subCol: subCol,
                cardBg: cardBg,
                divCol: divCol,
                primary: primary,
                children: [
                  _ToggleTile(
                    title: 'Nearby Games',
                    subtitle: 'When a game opens near you',
                    value: _notifGames,
                    primary: primary,
                    textCol: textCol,
                    subCol: subCol,
                    onChanged: (v) => setState(() => _notifGames = v),
                  ),
                  _Divider(color: divCol),
                  _ToggleTile(
                    title: 'Live Score Updates',
                    subtitle: 'Ball-by-ball alerts for matches you follow',
                    value: _notifScores,
                    primary: primary,
                    textCol: textCol,
                    subCol: subCol,
                    onChanged: (v) => setState(() => _notifScores = v),
                  ),
                  _Divider(color: divCol),
                  _ToggleTile(
                    title: 'Community Posts',
                    subtitle: 'New posts and mentions',
                    value: _notifCommunity,
                    primary: primary,
                    textCol: textCol,
                    subCol: subCol,
                    onChanged: (v) =>
                        setState(() => _notifCommunity = v),
                  ),
                  _Divider(color: divCol),
                  _ToggleTile(
                    title: 'Tournament Alerts',
                    subtitle: 'Registration opens, results & updates',
                    value: _notifTourneys,
                    primary: primary,
                    textCol: textCol,
                    subCol: subCol,
                    onChanged: (v) =>
                        setState(() => _notifTourneys = v),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Privacy ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Section(
                label: 'Privacy',
                icon: Icons.lock_outline,
                isDark: isDark,
                textCol: textCol,
                subCol: subCol,
                cardBg: cardBg,
                divCol: divCol,
                primary: primary,
                children: [
                  _ToggleTile(
                    title: 'Private Profile',
                    subtitle: 'Only your connections see your activity',
                    value: _privateProfile,
                    primary: primary,
                    textCol: textCol,
                    subCol: subCol,
                    onChanged: (v) =>
                        setState(() => _privateProfile = v),
                  ),
                  _Divider(color: divCol),
                  _ToggleTile(
                    title: 'Show Location',
                    subtitle: 'Show your city on your public profile',
                    value: _showLocation,
                    primary: primary,
                    textCol: textCol,
                    subCol: subCol,
                    onChanged: (v) =>
                        setState(() => _showLocation = v),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── App Preferences ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Section(
                label: 'App',
                icon: Icons.tune_outlined,
                isDark: isDark,
                textCol: textCol,
                subCol: subCol,
                cardBg: cardBg,
                divCol: divCol,
                primary: primary,
                children: [
                  _NavTile(
                    title: 'Notifications',
                    subtitle: 'View all notifications',
                    icon: Icons.notifications_none,
                    textCol: textCol,
                    subCol: subCol,
                    primary: primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  _Divider(color: divCol),
                  _InfoTile(
                    title: 'App Version',
                    subtitle: '1.0.0 (Build 1)',
                    textCol: textCol,
                    subCol: subCol,
                    icon: Icons.info_outline,
                    primary: primary,
                  ),
                  _Divider(color: divCol),
                  _InfoTile(
                    title: 'Region',
                    subtitle: _regionLabel(),
                    textCol: textCol,
                    subCol: subCol,
                    icon: Icons.language_outlined,
                    primary: primary,
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Membership ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Section(
                label: 'Membership',
                icon: Icons.workspace_premium_outlined,
                isDark: isDark,
                textCol: textCol,
                subCol: subCol,
                cardBg: cardBg,
                divCol: divCol,
                primary: primary,
                children: [
                  _NavTile(
                    title: 'Go Premium',
                    subtitle: 'Unlock PDF reports, live streaming & more',
                    icon: Icons.workspace_premium_outlined,
                    textCol: primary,
                    subCol: subCol,
                    primary: primary,
                    showChevron: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    ),
                  ),
                  _Divider(color: divCol),
                  _NavTile(
                    title: 'Restore Purchases',
                    subtitle: 'Recover your existing subscription',
                    icon: Icons.restore_outlined,
                    textCol: textCol,
                    subCol: subCol,
                    primary: primary,
                    onTap: () => ScaffoldMessenger.of(context)
                        .showSnackBar(_snack('Restore Purchases coming soon', primary)),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Support ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Section(
                label: 'Support',
                icon: Icons.help_outline,
                isDark: isDark,
                textCol: textCol,
                subCol: subCol,
                cardBg: cardBg,
                divCol: divCol,
                primary: primary,
                children: [
                  _NavTile(
                    title: 'Help & FAQ',
                    subtitle: 'Common questions answered',
                    icon: Icons.help_outline,
                    textCol: textCol,
                    subCol: subCol,
                    primary: primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HelpScreen()),
                    ),
                  ),
                  _Divider(color: divCol),
                  _NavTile(
                    title: 'Contact Support',
                    subtitle: 'support@mysportsbuddies.app',
                    icon: Icons.mail_outline,
                    textCol: textCol,
                    subCol: subCol,
                    primary: primary,
                    onTap: () => ScaffoldMessenger.of(context)
                        .showSnackBar(_snack('Opening email…', primary)),
                  ),
                  _Divider(color: divCol),
                  _NavTile(
                    title: 'Rate the App',
                    subtitle: 'Enjoying MySportsBuddies? Leave a review!',
                    icon: Icons.star_outline,
                    textCol: textCol,
                    subCol: subCol,
                    primary: primary,
                    onTap: () => ScaffoldMessenger.of(context)
                        .showSnackBar(_snack('Redirecting to store…', primary)),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Account ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Section(
                label: 'Account',
                icon: Icons.manage_accounts_outlined,
                isDark: isDark,
                textCol: textCol,
                subCol: subCol,
                cardBg: cardBg,
                divCol: divCol,
                primary: primary,
                children: [
                  _NavTile(
                    title: 'Sign Out',
                    subtitle: 'You can sign back in anytime',
                    icon: Icons.logout,
                    textCol: Colors.redAccent,
                    subCol: subCol,
                    primary: Colors.redAccent,
                    onTap: () => _confirmSignOut(context, primary),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _regionLabel() {
    try {
      final locale = Platform.localeName;
      final country = locale.split('_').last.toUpperCase();
      final names = <String, String>{
        'IN': 'India (\u20B9 INR)',
        'US': 'United States (\u0024 USD)',
        'GB': 'United Kingdom (\u00A3 GBP)',
        'AU': 'Australia (A\u0024 AUD)',
        'DE': 'Germany (\u20AC EUR)',
        'FR': 'France (\u20AC EUR)',
        'AE': 'UAE (AED)',
        'SG': 'Singapore (S\u0024 SGD)',
        'PK': 'Pakistan (Rs PKR)',
        'BD': 'Bangladesh (\u09F3 BDT)',
        'LK': 'Sri Lanka (Rs LKR)',
        'NP': 'Nepal (Rs NPR)',
        'JP': 'Japan (\u00A5 JPY)',
        'CN': 'China (\u00A5 CNY)',
        'KR': 'South Korea (\u20A9 KRW)',
      };
      return names[country] ?? locale;
    } catch (_) {
      return 'Unknown';
    }
  }

  void _confirmSignOut(BuildContext context, Color primary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1A1A)
                : Colors.white,
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              }
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  SnackBar _snack(String msg, Color color) => SnackBar(
        content: Text(msg,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      );
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final Color textCol, subCol, cardBg, divCol, primary;
  final List<Widget> children;
  const _Section({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.textCol,
    required this.subCol,
    required this.cardBg,
    required this.divCol,
    required this.primary,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(icon, size: 13, color: subCol),
                const SizedBox(width: 5),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: subCol,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: divCol),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final Color primary, textCol, subCol;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.primary,
    required this.textCol,
    required this.subCol,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: subCol, fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primary,
            activeTrackColor: primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Nav tile (tap to navigate) ────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color textCol, subCol, primary;
  final VoidCallback onTap;
  final bool showChevron;
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.textCol,
    required this.subCol,
    required this.primary,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: textCol, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textCol,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(color: subCol, fontSize: 12)),
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right, color: subCol, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Info tile (read-only) ─────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color textCol, subCol, primary;
  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.textCol,
    required this.subCol,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: subCol, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(color: subCol, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thin divider ──────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        color: color,
        indent: 16,
        endIndent: 16,
      );
}
