import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import '../../design/colors.dart';
import 'package:provider/provider.dart';
import '../../controllers/profile_controller.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../admin/admin_panel_screen.dart';
import '../home/scheduled_matches_screen.dart';
import '../home/my_matches_screen.dart';
import '../home/help_screen.dart';
import '../scoreboard/live_matches_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/settings_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _idCopied = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([UserService(), AdminService()]),
      builder: (context, _) {
        final profile  = UserService().profile;
        final imageUrl = profile?.imageUrl;

        // Also watch ProfileController so the drawer updates immediately
        // after the user picks or saves a new photo.
        final pc = context.watch<ProfileController>();
        final ImageProvider? avatar = pc.profileImage != null
            ? FileImage(pc.profileImage!)
            : (imageUrl != null && imageUrl.isNotEmpty
                // Key on the URL so Flutter doesn't serve a stale cached copy
                // when the Firebase Storage token changes after re-upload.
                ? NetworkImage(imageUrl)
                : null);

        return Drawer(
          backgroundColor: Colors.black,
          child: Column(
            children: [
              // ── Profile Header ─────────────────────────────────────
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/edit_profile');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 52, 8, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7B0000), Color(0xFFB71C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with white border ring
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatar,
                          child: avatar == null
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 30)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + App ID + email
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              (profile != null && profile.name.isNotEmpty)
                                  ? profile.name
                                  : 'Your Name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            // App ID pill with copy button
                            GestureDetector(
                              onTap: () async {
                                if (profile?.numericId == null) return;
                                await Clipboard.setData(ClipboardData(
                                    text: '${profile!.numericId}'));
                                await HapticFeedback.lightImpact();
                                if (!mounted) return;
                                setState(() => _idCopied = true);
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) setState(() => _idCopied = false);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      profile?.numericId != null
                                          ? 'ID: ${profile!.numericId}'
                                          : 'ID: ------',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _idCopied
                                        ? const Text(
                                            'Copied!',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : const Icon(Icons.copy_rounded,
                                            color: Colors.white70, size: 11),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (profile != null && profile.email.isNotEmpty)
                                  ? profile.email
                                  : 'Tap to edit profile',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Close
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Menu Items ────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),
                    _item(context, Icons.home_outlined, 'Home', () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (r) => false);
                    }),
                    _item(context, Icons.history_outlined, 'Game History',
                        () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyMatchesScreen()));
                    }),
                    _item(context, Icons.calendar_today_outlined,
                        'Upcoming Schedule', () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScheduledMatchesScreen()));
                    }),
                    _item(context, Icons.bar_chart_outlined, 'My Scorecards', () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const LiveMatchesScreen(),
                      ));
                    }),
                    _item(context, Icons.group_outlined, 'Teams', () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teams — coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }),
                    // Live Streaming — disabled for now, code preserved
                    Opacity(
                      opacity: 0.35,
                      child: _item(
                          context, Icons.wifi_tethering, 'Live Streaming', () {
                        // disabled — show coming-soon message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Live Streaming — coming soon!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }),
                    ),
                    const Divider(
                        color: Colors.white12,
                        height: 24,
                        indent: 16,
                        endIndent: 16),
                    // ── Admin Panel (only for admins) ──────────────────
                    if (AdminService().isCurrentUserAdmin) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Divider(color: Colors.white12),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 0),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary.withAlpha(80)),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded,
                              color: AppColors.primary, size: 16),
                        ),
                        title: const Text('Admin Panel',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        subtitle: const Text('Control panel',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminPanelScreen()));
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                        child: Divider(color: Colors.white12),
                      ),
                    ],
                    _item(context, Icons.workspace_premium_outlined,
                        'Go Premium', () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PremiumScreen()));
                    }),
                    _item(context, Icons.settings_outlined, 'Settings', () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()));
                    }),
                    _item(context, Icons.help_outline, 'Help & FAQ', () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HelpScreen()));
                    }),
                  ],
                ),
              ),

              // ── Logout ───────────────────────────────────────────
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: const Icon(Icons.logout,
                    color: Colors.redAccent, size: 21),
                title: const Text('Sign Out',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                onTap: () => _confirmSignOut(context),
              ),

              // ── Footer ────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Sign Out',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              navigator.pop(); // close dialog
              await AuthService().signOut();
              if (!context.mounted) return;
              navigator.pushNamedAndRemoveUntil('/login', (_) => false);
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  static Widget _item(BuildContext context, IconData icon, String title,
      VoidCallback onTap) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Icon(icon, color: Colors.white60, size: 21),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: onTap,
    );
  }
}
