import 'package:flutter/material.dart';
import 'dart:async';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../features/common/sport_action_sheet.dart';
import '../sports/all_sports_screen.dart';
import '../../features/common/app_drawer.dart';
import '../profile/edit_profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ✅ FIX 1: Drawer added (enables ☰)
      drawer: const AppDrawer(),

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,

        // ✅ FIX 2: DO NOT override leading
        // Flutter will automatically show ☰ and open drawer

        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'MySports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: 'Buddies',
                style: TextStyle(
                  color: Color.fromARGB(255, 182, 22, 11),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        centerTitle: false,

        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              debugPrint('Help tapped');
            },
          ),

          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () {
                  debugPrint('Notifications tapped');
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          // ✅ FIX 3: Profile icon now works
          IconButton(
           icon: const Icon(Icons.person_outline, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
            MaterialPageRoute(
            builder: (_) => const EditProfileScreen(),
      ),
    );
  },
),

        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BannerSlider(),
            const SizedBox(height: AppSpacing.lg),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Browse Sports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  SportTile(label: 'Cricket', emoji: '🏏'),
                  SportTile(label: 'Football', emoji: '⚽'),
                  SportTile(label: 'Basketball', emoji: '🏀'),
                  SportTile(label: 'Badminton', emoji: '🏸'),
                  SportTile(label: 'Tennis', emoji: '🎾'),
                  SportTile(label: 'Volleyball', emoji: '🏐'),
                  SportTile(label: 'Table Tennis', emoji: '🏓'),
                  SportTile(label: 'Boxing', emoji: '🥊'),
                  SportTile(label: 'More', emoji: '➕', isMore: true),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 🔴 NEARBY GAMES (UNCHANGED)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Nearby Games',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            const _NearbyGameCard(
              sport: 'Cricket',
              venue: 'Green Park Stadium',
              distance: '2.3 km',
              time: 'Today, 6:00 PM',
              slots: '3 slots left',
            ),

            const _NearbyGameCard(
              sport: 'Football',
              venue: 'City Sports Complex',
              distance: '1.8 km',
              time: 'Today, 5:30 PM',
              slots: '5 slots left',
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/* ---------------- PROFILE SHEET ---------------- */

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Profile actions go here',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/* ---------------- SPORT TILE ---------------- */

class SportTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isMore;

  const SportTile({
    super.key,
    required this.label,
    required this.emoji,
    this.isMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isMore) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AllSportsScreen(),
            ),
          );
        } else {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => SportActionSheet(sport: label),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isMore
                  ? null
                  : const LinearGradient(
                      colors: [
                        Color(0xFF2A0000),
                        Color(0xFF120000),
                      ],
                    ),
              color: isMore ? AppColors.card : null,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.6),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- BANNER SLIDER ---------------- */

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  late PageController _pageController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page?.toInt() ?? 0) + 1;
        _pageController.animateToPage(
          nextPage % 2,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: PageView(
        controller: _pageController,
        children: const [
          BannerImage(imagePath: 'assets/1.jpg'),
          BannerImage(imagePath: 'assets/2.jpg'),
        ],
      ),
    );
  }
}

class BannerImage extends StatelessWidget {
  final String imagePath;

  const BannerImage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/* ---------------- NEARBY GAME CARD ---------------- */

class _NearbyGameCard extends StatelessWidget {
  final String sport;
  final String venue;
  final String distance;
  final String time;
  final String slots;

  const _NearbyGameCard({
    required this.sport,
    required this.venue,
    required this.distance,
    required this.time,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sport,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$venue • $distance',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                Text(
                  slots,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
