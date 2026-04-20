import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../design/colors.dart';
import '../../services/venue_service.dart';
import '../../services/user_service.dart';

class MerchantBookingsScreen extends StatelessWidget {
  const MerchantBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('Bookings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Confirmed'),
              Tab(text: 'All'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.download_outlined, color: Colors.white),
          label: const Text('Export',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export coming soon — stay tuned!'),
              behavior: SnackBarBehavior.floating,
            ),
          ),
        ),
        body: _BookingsBody(),
      ),
    );
  }
}

class _BookingsBody extends StatelessWidget {
  const _BookingsBody();

  @override
  Widget build(BuildContext context) {
    final myId = UserService().userId ?? '';

    // Stream all bookings for venues owned by current merchant
    final stream = FirebaseFirestore.instance
        .collection('venue_bookings')
        .where('merchantId', isEqualTo: myId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        final all       = snap.data ?? [];
        final pending   = all.where((b) => b['status'] == 'pending').toList();
        final confirmed = all.where((b) => b['status'] == 'confirmed').toList();

        return TabBarView(
          children: [
            _BookingList(bookings: pending,   emptyMsg: 'No pending bookings'),
            _BookingList(bookings: confirmed, emptyMsg: 'No confirmed bookings'),
            _BookingList(bookings: all,       emptyMsg: 'No bookings yet'),
          ],
        );
      },
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final String emptyMsg;

  const _BookingList({required this.bookings, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_outlined,
                color: Colors.white24, size: 56),
            const SizedBox(height: 14),
            Text(emptyMsg,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) =>
          _BookingCard(booking: bookings[i]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'declined':  return Colors.red.shade400;
      default:          return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status    = booking['status'] as String? ?? 'pending';
    final userName  = booking['userName']  as String? ?? 'Player';
    final venueName = booking['venueName'] as String? ?? '';
    final date      = booking['date']      as String? ?? '';
    final slot      = booking['slot']      as String? ?? '';
    final sport     = booking['sport']     as String? ?? '';

    final ts = booking['createdAt'];
    String timeAgo = '';
    if (ts is Timestamp) {
      final diff = DateTime.now().difference(ts.toDate());
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (timeAgo.isNotEmpty)
                      Text(timeAgo,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Details ───────────────────────────────────────────────────
          _InfoRow(Icons.store_outlined, venueName),
          if (date.isNotEmpty) _InfoRow(Icons.calendar_today_outlined, date),
          if (slot.isNotEmpty) _InfoRow(Icons.access_time_outlined, slot),
          if (sport.isNotEmpty) _InfoRow(Icons.sports_outlined, sport),

          // ── Actions ───────────────────────────────────────────────────
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Decline',
                    color: Colors.red.shade400,
                    onTap: () => _updateStatus(context, 'declined'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: 'Confirm',
                    color: Colors.green,
                    onTap: () => _updateStatus(context, 'confirmed'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, String newStatus) {
    VenueService().updateBookingStatus(
      booking['id'] as String,
      newStatus,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
