import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../services/user_service.dart';
import '../../services/venue_service.dart';
import '../home/help_screen.dart';
import '../settings/settings_screen.dart';
import 'add_venue_screen.dart';
import 'merchant_bookings_screen.dart';
import 'my_venues_screen.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    VenueService().listenToMyVenues();
  }

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'My Venues',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.event_note_outlined),
      activeIcon: Icon(Icons.event_note),
      label: 'Bookings',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tab,
        children: [
          _DashboardTab(onTabChange: (i) => setState(() => _tab = i)),
          const MyVenuesScreen(),
          const MerchantBookingsScreen(),
          const _ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white38,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: _navItems,
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final ValueChanged<int> onTabChange;
  const _DashboardTab({required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final name = UserService().profile?.name ?? 'Merchant';
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $name',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Venue Owner Dashboard',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A237E),
                          border: Border.all(
                              color: const Color(0xFF3949AB), width: 1.5),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Stats row ────────────────────────────────────────────
                  ListenableBuilder(
                    listenable: VenueService(),
                    builder: (context, _) {
                      final venues   = VenueService().myVenues;
                      final active   = venues.where((v) => v.status.name == 'active').length;
                      final pending  = venues.where((v) => v.status.name == 'pending').length;
                      return Row(
                        children: [
                          Expanded(child: _StatCard(label: 'Total Venues', value: '${venues.length}', icon: Icons.store, color: AppColors.primary)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Active',  value: '$active',  icon: Icons.check_circle_outline, color: Colors.green)),
                          const SizedBox(width: 12),
                          Expanded(child: _StatCard(label: 'Pending', value: '$pending', icon: Icons.hourglass_top_rounded, color: Colors.orange)),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                  const Text('Quick Actions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // ── Action cards grid ────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: Icons.add_business_outlined,
                  label: 'Add Venue',
                  subtitle: 'Register a new venue',
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddVenueScreen()),
                  ),
                ),
                _ActionCard(
                  icon: Icons.store_outlined,
                  label: 'My Venues',
                  subtitle: 'View & manage venues',
                  color: const Color(0xFF3949AB),
                  onTap: () => onTabChange(1),
                ),
                _ActionCard(
                  icon: Icons.event_note_outlined,
                  label: 'Bookings',
                  subtitle: 'Manage booking requests',
                  color: Colors.teal,
                  onTap: () => onTabChange(2),
                ),
                _ActionCard(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  subtitle: 'App preferences',
                  color: Colors.grey,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Recent venues ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ListenableBuilder(
                listenable: VenueService(),
                builder: (context, _) {
                  final venues = VenueService().myVenues;
                  if (venues.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Venues',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ...venues.take(3).map((v) => _VenueRowCard(venue: v)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _VenueRowCard extends StatelessWidget {
  final dynamic venue;
  const _VenueRowCard({required this.venue});

  @override
  Widget build(BuildContext context) {
    final statusColor = venue.status.name == 'active'
        ? Colors.green
        : venue.status.name == 'pending'
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(venue.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(venue.address,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              venue.status.name,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: UserService(),
            builder: (context, _) {
              final p = UserService().profile;
              final name     = p?.name  ?? 'Merchant';
              final email    = p?.email ?? '';
              final imageUrl = p?.imageUrl;
              return Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF1A237E),
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const Icon(Icons.storefront_rounded,
                            size: 38, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(email,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3949AB)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Venue Owner',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          _ProfileMenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
          ),
          _ProfileMenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _ProfileMenuItem(
            icon: Icons.help_outline,
            label: 'Help & Support',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          const SizedBox(height: 12),
          _ProfileMenuItem(
            icon: Icons.logout,
            label: 'Sign Out',
            iconColor: Colors.red.shade400,
            labelColor: Colors.red.shade400,
            onTap: () => Navigator.pushNamedAndRemoveUntil(
                context, '/welcome', (_) => false),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? Colors.white70, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: labelColor ?? Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
