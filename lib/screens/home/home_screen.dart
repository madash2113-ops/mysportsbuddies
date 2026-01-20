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
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: const Text(
          'MySportsBuddies',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
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

            // 🔴 BANNER SLIDER (exact top block)
            SizedBox(
              height: 180,
              child: PageView(
                children: [
                  _BannerItem(),
                  _BannerItem(),
                  _BannerItem(),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // SPORTS TITLE
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Sports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // SPORTS GRID (SMALL ICONS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SportIcon(context, Icons.sports_cricket, 'Cricket'),
                  _SportIcon(context, Icons.sports_soccer, 'Football'),
                  _SportIcon(context, Icons.sports_basketball, 'Basketball'),
                  _SportIcon(context, Icons.sports_tennis, 'Tennis'),
                  _SportIcon(context, Icons.sports_volleyball, 'Volleyball'),
                  _SportIcon(context, Icons.sports_hockey, 'Hockey'),
                  _SportIcon(context, Icons.sports_baseball, 'Baseball'),

                  // MORE (IMPORTANT)
                  _SportIcon(
                    context,
                    Icons.more_horiz,
                    'More',
                    isMore: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _SportIcon(
    BuildContext context,
    IconData icon,
    String label, {
    bool isMore = false,
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => SportActionSheet(
            sport: label,
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// 🔴 Banner item (static placeholder, matches screenshot)
class _BannerItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        image: const DecorationImage(
          image: AssetImage('assets/banner_placeholder.jpg'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
