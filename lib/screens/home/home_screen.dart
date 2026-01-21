import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../features/common/sport_action_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'MySports',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              TextSpan(
                text: 'Buddies',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.card,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          )
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔴 BANNER SLIDER
            SizedBox(
              height: 190,
              child: PageView(
                children: const [
                  _BannerCard(
                    title: 'Basketball League Starting',
                    location: 'Downtown Court Arena',
                  ),
                  _BannerCard(
                    title: 'Football Practice Sessions',
                    location: 'Riverside Sports Ground',
                  ),
                  _BannerCard(
                    title: 'Weekend Cricket Tournament',
                    location: 'Central Sports Complex',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 🔴 BROWSE SPORTS TITLE
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Browse Sports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // 🔴 SPORTS GRID (NO OVERFLOW)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 20,
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
                  SportTile(label: 'Swimming', emoji: '🏊'),
                  SportTile(label: 'Running', emoji: '🏃'),
                  SportTile(label: 'More', emoji: '➕', isMore: true),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 🔴 NEARBY GAMES
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Nearby Games',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
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

/* ------------------------------------------------------------ */
/* --------------------- SPORT TILE ---------------------------- */
/* ------------------------------------------------------------ */

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
    return SizedBox(
      height: 120, // ✅ FIXES OVERFLOW
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => SportActionSheet(sport: label),
          );
        },
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isMore ? AppColors.card : null,
                gradient: isMore
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFF2A0000),
                          Color(0xFF120000),
                        ],
                      ),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ */
/* --------------------- BANNER CARD --------------------------- */
/* ------------------------------------------------------------ */

class _BannerCard extends StatelessWidget {
  final String title;
  final String location;

  const _BannerCard({
    required this.title,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              location,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ */
/* --------------------- NEARBY GAME CARD ---------------------- */
/* ------------------------------------------------------------ */

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
