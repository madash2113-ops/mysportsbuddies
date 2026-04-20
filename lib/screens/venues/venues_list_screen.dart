import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/models/venue_model.dart';
import '../../design/colors.dart';
import '../../services/location_service.dart';
import '../../services/venue_service.dart';
import 'venue_detail_screen.dart';

const _kAllSports = [
  'All', 'Cricket', 'Football', 'Basketball', 'Badminton',
  'Tennis', 'Volleyball', 'Table Tennis', 'Swimming',
  'Kabaddi', 'Hockey',
];

class VenuesListScreen extends StatefulWidget {
  const VenuesListScreen({super.key});

  @override
  State<VenuesListScreen> createState() => _VenuesListScreenState();
}

class _VenuesListScreenState extends State<VenuesListScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedSport = 'All';
  String _query = '';
  Position? _userPos;

  @override
  void initState() {
    super.initState();
    VenueService().listenToVenues();
    // Fast first render from cached position, then refine with accurate fix.
    LocationService().getLastKnownPosition().then((pos) {
      if (pos != null && mounted) setState(() => _userPos = pos);
    });
    LocationService().getCurrentPosition().then((pos) {
      if (pos != null && mounted) setState(() => _userPos = pos);
    });
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<VenueModel> get _filtered {
    var list = VenueService().venues;
    if (_selectedSport != 'All') {
      list = list.where((v) => v.sports.contains(_selectedSport)).toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((v) =>
              v.name.toLowerCase().contains(_query) ||
              v.address.toLowerCase().contains(_query))
          .toList();
    }
    final pos = _userPos;
    if (pos != null) {
      list = [...list]..sort((a, b) {
          final da = (a.lat == 0 && a.lng == 0)
              ? double.infinity
              : a.distanceTo(pos.latitude, pos.longitude);
          final db = (b.lat == 0 && b.lng == 0)
              ? double.infinity
              : b.distanceTo(pos.latitude, pos.longitude);
          return da.compareTo(db);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Sports Venues',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search venues, areas…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38, size: 22),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.clear, color: Colors.white38, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Sport filter chips ─────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _kAllSports.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sport    = _kAllSports[i];
                final selected = sport == _selectedSport;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSport = sport),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.white24,
                      ),
                    ),
                    child: Text(sport,
                        style: TextStyle(
                            color:
                                selected ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),

          // ── Venue list ─────────────────────────────────────────────────
          Expanded(
            child: ListenableBuilder(
              listenable: VenueService(),
              builder: (context, _) {
                final venues = _filtered;
                if (venues.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off_outlined,
                            color: Colors.white24, size: 64),
                        const SizedBox(height: 16),
                        const Text('No venues found',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          _query.isNotEmpty || _selectedSport != 'All'
                              ? 'Try changing your search or filter'
                              : 'Venues will appear here once approved',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: venues.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) =>
                      _VenueCard(venue: venues[i], userPos: _userPos),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final VenueModel venue;
  final Position?  userPos;
  const _VenueCard({required this.venue, this.userPos});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VenueDetailScreen(venue: venue)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo ──────────────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: venue.photoUrls.isNotEmpty
                  ? Image.network(
                      venue.photoUrls.first,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _Placeholder(name: venue.name),
                    )
                  : _Placeholder(name: venue.name),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(venue.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (venue.rating > 0) ...[
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 3),
                        Text(venue.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(venue.address,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (userPos != null &&
                          !(venue.lat == 0 && venue.lng == 0)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            LocationService().formatDistance(
                                venue.distanceTo(
                                    userPos!.latitude, userPos!.longitude)),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Sports chips
                  if (venue.sports.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: venue.sports
                          .take(3)
                          .map((s) => _Chip(label: s))
                          .toList(),
                    ),
                  const SizedBox(height: 10),
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
                      if (venue.isVerified)
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded,
                                color: Colors.blueAccent, size: 14),
                            SizedBox(width: 4),
                            Text('Verified',
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 11)),
                          ],
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Book',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
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

class _Placeholder extends StatelessWidget {
  final String name;
  const _Placeholder({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      color: const Color(0xFF0D1117),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, color: Colors.white24, size: 44),
          const SizedBox(height: 6),
          Text(name,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
