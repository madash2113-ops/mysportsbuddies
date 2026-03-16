import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    _FaqSection(
      title: 'Getting Started',
      icon: Icons.rocket_launch_outlined,
      items: [
        _FaqItem(
          q: 'How do I register a game?',
          a: 'Tap any sport on the home screen → "Register Game". Fill in the venue, date, time and optional details. The game will appear in Nearby Games for others to find.',
        ),
        _FaqItem(
          q: 'How do I find games near me?',
          a: 'Tap a sport on the home screen → "Nearby Games". Games are sorted by how recently they were added. Location-based sorting is coming soon.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Scoring',
      icon: Icons.scoreboard_outlined,
      items: [
        _FaqItem(
          q: 'How do I create a scoreboard?',
          a: 'Tap any sport → "Create Scoreboard". The setup wizard will guide you through entering team names, format, venue and other details.',
        ),
        _FaqItem(
          q: 'How does cricket strike rotation work?',
          a: 'Strike automatically rotates on odd runs (1, 3, 5) mid-over and always at the end of every over. For a No Ball: the penalty run is added and the bat runs determine rotation.',
        ),
        _FaqItem(
          q: 'Can I swap batsmen manually?',
          a: 'Yes! In the cricket scoreboard, tap the "Swap ⇌" button to manually switch striker and non-striker at any time.',
        ),
        _FaqItem(
          q: 'What does "Ret. Hurt" mean?',
          a: '"Retired Hurt" marks a batsman as injured. Tap it, enter the injured batsman\'s name and a replacement name. The replacement continues with the same strike position.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Profile',
      icon: Icons.person_outline,
      items: [
        _FaqItem(
          q: 'How do I update my profile picture?',
          a: 'Tap the profile icon in the top right of the home screen. On the edit screen, tap your avatar to choose Camera or Gallery. The image is saved automatically.',
        ),
        _FaqItem(
          q: 'Is my profile data saved?',
          a: 'Yes, once Firebase is connected your profile details (name, email, photo) are stored in the cloud and available across sessions.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Community Feed',
      icon: Icons.forum_outlined,
      items: [
        _FaqItem(
          q: 'What is the Community Feed?',
          a: 'A social wall where players share sports moments, post scores, and celebrate match results. Tap "Community Feed" in the side menu to open it.',
        ),
        _FaqItem(
          q: 'How do I share a match result?',
          a: 'When a match is completed, tap "Share Result" on the scoreboard screen. A score card post is automatically generated and shared to the feed.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Nearby Games',
      icon: Icons.location_on_outlined,
      items: [
        _FaqItem(
          q: 'Why don\'t I see games near me?',
          a: 'Make sure location permission is granted. Also, Nearby Games shows games registered by other players — if nobody has registered one yet, the list will be empty.',
        ),
        _FaqItem(
          q: 'How far does "Nearby" mean?',
          a: 'Currently all registered games are shown. Location-based filtering with distance sorting is coming in the next update.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Help & FAQ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Search hint banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Browse the topics below or contact us if you need more help.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // FAQ sections
          ..._faqs.map((s) => _FaqSectionWidget(section: s)),

          const SizedBox(height: AppSpacing.lg),

          // Contact support
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.headset_mic_outlined,
                    color: Colors.white54, size: 36),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Still need help?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Our support team is ready to assist you',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('mailto:support@mysportsbuddies.com?subject=App%20Support'),
                    ),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _FaqSection {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;
  const _FaqSection(
      {required this.title, required this.icon, required this.items});
}

class _FaqItem {
  final String q, a;
  const _FaqItem({required this.q, required this.a});
}

class _FaqSectionWidget extends StatelessWidget {
  final _FaqSection section;
  const _FaqSectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(section.icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: section.items.asMap().entries.map((e) {
              final isLast = e.key == section.items.length - 1;
              return Column(
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      iconColor: AppColors.primary,
                      collapsedIconColor: Colors.white38,
                      title: Text(
                        e.value.q,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                      children: [
                        Text(
                          e.value.a,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, color: Colors.white10, indent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
