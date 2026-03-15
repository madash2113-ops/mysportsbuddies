import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../controllers/profile_controller.dart';
import '../../services/user_service.dart';
import '../home/scheduled_matches_screen.dart';
import '../home/my_matches_screen.dart';
import '../home/help_screen.dart';
import '../scoreboard/scoreboard_menu_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserService(),
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
                              onTap: () {
                                if (profile?.numericId != null) {
                                  Clipboard.setData(ClipboardData(
                                      text: '${profile!.numericId}'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Player ID copied!'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
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
                                          ? 'ID: #${profile!.numericId}'
                                          : 'ID: ------',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy_rounded,
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
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (_, _, _) =>
                              const ScoreboardMenuScreen(),
                          transitionsBuilder: (_, animation, _, child) =>
                              FadeTransition(opacity: animation, child: child),
                        ),
                      );
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
