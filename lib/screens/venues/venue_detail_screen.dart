import 'package:flutter/material.dart';

import '../../core/models/venue_model.dart';
import '../../design/colors.dart';
import '../../services/user_service.dart';
import '../../services/venue_service.dart';
import '../games/create_game_screen.dart';

class VenueDetailScreen extends StatefulWidget {
  final VenueModel venue;
  const VenueDetailScreen({super.key, required this.venue});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  int _photoIndex = 0;

  void _openBookingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BookingSheet(venue: widget.venue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Photo header ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.background,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: v.photoUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: v.photoUrls.length,
                      onPageChanged: (i) =>
                          setState(() => _photoIndex = i),
                      itemBuilder: (context, i) => Image.network(
                        v.photoUrls[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _PhotoPlaceholder(name: v.name),
                      ),
                    )
                  : _PhotoPlaceholder(name: v.name),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo indicator dots
                  if (v.photoUrls.length > 1) ...[
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          v.photoUrls.length,
                          (i) => Container(
                            width: i == _photoIndex ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i == _photoIndex
                                  ? AppColors.primary
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Name + verified badge ────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(v.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (v.isVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: const [
                              Icon(Icons.verified_rounded,
                                  color: Colors.blueAccent, size: 18),
                              SizedBox(width: 4),
                              Text('Verified',
                                  style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Rating + price ───────────────────────────────────
                  Row(
                    children: [
                      if (v.rating > 0) ...[
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text('${v.rating.toStringAsFixed(1)} (${v.reviewCount} reviews)',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 16),
                      ],
                      Text('₹${v.pricePerHour.toStringAsFixed(0)}/hr',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Address ──────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white38, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(v.address,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ),
                    ],
                  ),

                  // ── Contact ──────────────────────────────────────────
                  if (v.phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            color: Colors.white38, size: 16),
                        const SizedBox(width: 6),
                        Text(v.phone,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ],
                  if (v.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            color: Colors.white38, size: 16),
                        const SizedBox(width: 6),
                        Text(v.email,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Sports ───────────────────────────────────────────
                  if (v.sports.isNotEmpty) ...[
                    const Text('Available Sports',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: v.sports
                          .map((s) => _SportChip(sport: s))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Description ──────────────────────────────────────
                  if (v.description.isNotEmpty) ...[
                    const Text('About',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(v.description,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // ── Timings ──────────────────────────────────────────
                  if (v.timings.isNotEmpty) ...[
                    const Text('Timings',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...v.timings.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(e.key,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13)),
                            ),
                            Text(e.value,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 80), // space above sticky button
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Sticky Book button ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openBookingSheet,
              child: const Text('Book a Slot',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String name;
  const _PhotoPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, color: Colors.white24, size: 56),
          const SizedBox(height: 10),
          Text(name,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 15),
              textAlign: TextAlign.center),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(sport,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Booking bottom sheet ──────────────────────────────────────────────────────

class _BookingSheet extends StatefulWidget {
  final VenueModel venue;
  const _BookingSheet({required this.venue});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  String?  _selectedSport;
  DateTime? _selectedDate;
  String?  _selectedSlot;
  bool     _submitting = false;
  String?  _error;

  static const _slots = [
    '6:00 AM – 7:00 AM', '7:00 AM – 8:00 AM', '8:00 AM – 9:00 AM',
    '9:00 AM – 10:00 AM', '10:00 AM – 11:00 AM', '11:00 AM – 12:00 PM',
    '12:00 PM – 1:00 PM', '2:00 PM – 3:00 PM', '3:00 PM – 4:00 PM',
    '4:00 PM – 5:00 PM', '5:00 PM – 6:00 PM', '6:00 PM – 7:00 PM',
    '7:00 PM – 8:00 PM', '8:00 PM – 9:00 PM', '9:00 PM – 10:00 PM',
  ];

  String get _formattedDate {
    if (_selectedDate == null) return 'Select Date';
    final d = _selectedDate!;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _submit() async {
    if (_selectedSport == null) {
      setState(() => _error = 'Please select a sport.');
      return;
    }
    if (_selectedDate == null) {
      setState(() => _error = 'Please select a date.');
      return;
    }
    if (_selectedSlot == null) {
      setState(() => _error = 'Please select a time slot.');
      return;
    }
    if (UserService().userId == null) {
      setState(() => _error = 'Please sign in to book.');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      await VenueService().requestBooking(
        venueId:   widget.venue.id,
        venueName: widget.venue.name,
        date:      _formattedDate,
        slot:      _selectedSlot!,
        sport:     _selectedSport!,
      );

      if (!mounted) return;
      Navigator.pop(context); // close booking sheet

      // ── Offer to list an open game ─────────────────────────────────
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.sports_outlined, color: AppColors.primary),
              SizedBox(width: 10),
              Text('List an Open Game?',
                  style: TextStyle(color: Colors.white, fontSize: 17)),
            ],
          ),
          content: const Text(
            'Want to invite other players to join you?\n'
            'You can split the venue cost among all players.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateGameScreen(
                      venue:           widget.venue,
                      prefilledDate:   _formattedDate,
                      prefilledSlot:   _selectedSlot,
                      prefilledSport:  _selectedSport,
                    ),
                  ),
                );
              },
              child: const Text('Yes, List Game',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Failed to submit booking. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book at ${v.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('₹${v.pricePerHour.toStringAsFixed(0)}/hr',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),

                  // ── Sport picker ───────────────────────────────────
                  const Text('Select Sport',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: v.sports.map((s) {
                      final sel = s == _selectedSport;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSport = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // ── Date picker ────────────────────────────────────
                  const Text('Select Date',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedDate != null
                              ? AppColors.primary
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              color: _selectedDate != null
                                  ? AppColors.primary
                                  : Colors.white38,
                              size: 18),
                          const SizedBox(width: 10),
                          Text(_formattedDate,
                              style: TextStyle(
                                  color: _selectedDate != null
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Slot picker ────────────────────────────────────
                  const Text('Select Time Slot',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _slots.map((slot) {
                      final sel = slot == _selectedSlot;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedSlot = slot),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(slot,
                              style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── Error ──────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: TextStyle(
                            color: Colors.red.shade400, fontSize: 13)),
                  ],

                  const SizedBox(height: 24),

                  // ── Submit ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text('Request Booking',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
