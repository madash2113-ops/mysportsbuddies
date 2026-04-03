import 'package:flutter/material.dart';

import '../../core/models/venue_model.dart';
import '../../design/colors.dart';
import '../../services/venue_service.dart';
import 'add_venue_screen.dart';

class MyVenuesScreen extends StatelessWidget {
  const MyVenuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('My Venues',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddVenueScreen()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: VenueService(),
        builder: (context, _) {
          final venues = VenueService().myVenues;
          if (venues.isEmpty) {
            return _EmptyVenues(
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVenueScreen()),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: venues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _VenueCard(venue: venues[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Venue',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddVenueScreen()),
        ),
      ),
    );
  }
}

class _EmptyVenues extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyVenues({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, color: Colors.white24, size: 72),
          const SizedBox(height: 16),
          const Text('No venues yet',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Register your first sports venue\nto start accepting bookings',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Your First Venue',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final VenueModel venue;
  const _VenueCard({required this.venue});

  Color get _statusColor {
    switch (venue.status) {
      case VenueStatus.active:
        return Colors.green;
      case VenueStatus.pending:
        return Colors.orange;
      case VenueStatus.inactive:
        return Colors.red.shade400;
    }
  }

  String get _statusLabel {
    switch (venue.status) {
      case VenueStatus.active:
        return 'Active';
      case VenueStatus.pending:
        return 'Under Review';
      case VenueStatus.inactive:
        return 'Inactive';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo / header ──────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: venue.photoUrls.isNotEmpty
                ? Image.network(
                    venue.photoUrls.first,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _PlaceholderPhoto(venue: venue),
                  )
                : _PlaceholderPhoto(venue: venue),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name + status ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(venue.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel,
                          style: TextStyle(
                              color: _statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(venue.address,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Sports chips ─────────────────────────────────────────
                if (venue.sports.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: venue.sports
                        .take(4)
                        .map((s) => _SportChip(sport: s))
                        .toList(),
                  ),

                const SizedBox(height: 12),

                // ── Price + actions ──────────────────────────────────────
                Row(
                  children: [
                    Text(
                      '₹${venue.pricePerHour.toStringAsFixed(0)}/hr',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    // Edit
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      color: Colors.white70,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AddVenueScreen(existing: venue)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete
                    _IconBtn(
                      icon: Icons.delete_outline,
                      color: Colors.red.shade400,
                      onTap: () => _confirmDelete(context),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Delete Venue',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${venue.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              VenueService().deleteVenue(venue.id);
            },
            child: Text('Delete',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPhoto extends StatelessWidget {
  final VenueModel venue;
  const _PlaceholderPhoto({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: const Color(0xFF0D1117),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 8),
          Text(venue.name,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String sport;
  const _SportChip({required this.sport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(sport,
          style: const TextStyle(
              color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
