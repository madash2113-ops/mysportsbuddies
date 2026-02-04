import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          // RED HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            color: const Color(0xFFB71C1C),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avinash Kumar Maddini',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'maddiniavinashkumar82@email.com',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // MENU
          Expanded(
            child: ListView(
              children: [
                _item(Icons.home, 'Home'),
                _item(Icons.calendar_today, 'My Schedules'),
                _item(Icons.emoji_events, 'My Matches'),
                _item(Icons.group, 'Teams'),
                _item(Icons.wifi_tethering, 'Live Streaming'),
                _item(Icons.bar_chart, 'Scorecards'),
                _item(Icons.app_registration, 'Register League'),
                _item(Icons.forum, 'Community Feed'),
                const Divider(color: Colors.white24),
                _item(Icons.workspace_premium, 'Go Premium'),
                _item(Icons.settings, 'Settings'),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _item(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {},
    );
  }
}
