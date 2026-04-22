import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/venue_model.dart';
import '../../services/venue_service.dart';
import '../venues/venue_detail_screen.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _bg     = Color(0xFF080808);
const _card   = Color(0xFF111111);
const _panel  = Color(0xFF0E0E0E);
const _tx     = Color(0xFFF2F2F2);
const _m1     = Color(0xFF888888);
const _m2     = Color(0xFF3A3A3A);
const _red    = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _green  = Color(0xFF30D158);
const _orange = Color(0xFFFF9F0A);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);

// ── Page ───────────────────────────────────────────────────────────────────────

class WebVenuesPage extends StatefulWidget {
  const WebVenuesPage({super.key});

  @override
  State<WebVenuesPage> createState() => _WebVenuesPageState();
}

class _WebVenuesPageState extends State<WebVenuesPage> {
  String? _sport;
  VenueModel? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: Consumer<VenueService>(
              builder: (context, svc, _) {
                var venues = svc.venues
                    .where((v) => v.status == VenueStatus.active)
                    .toList();
                if (_sport != null) {
                  venues = venues
                      .where((v) => v.sports.contains(_sport))
                      .toList();
                }
                final featured =
                    venues.isNotEmpty ? venues.first : null;
                final rest = venues.length > 1 ? venues.sublist(1) : <VenueModel>[];

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildFilterRow(svc.venues)),
                    if (featured != null)
                      SliverToBoxAdapter(
                          child: _FeaturedVenueBanner(
                            venue: featured,
                            onTap: () => setState(() => _selected = featured),
                          )),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(children: [
                          Text('All Venues',
                              style: _t(size: 16, weight: FontWeight.w800)),
                          Text('  ${venues.length} venues found',
                              style: _t(size: 13, color: _m1)),
                          const Spacer(),
                          _SortPill(),
                        ]),
                      ),
                    ),
                    _VenueGrid(
                      venues: rest,
                      onTap: (v) => setState(() => _selected = v),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                  ],
                );
              },
            ),
          ),
          // ── Right panel ───────────────────────────────────────────────────
          _RightPanel(selected: _selected),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Venues', style: _t(size: 26, weight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Discover and book the best sports venues near you.',
            style: _t(size: 14, color: _m1)),
      ]),
    );
  }

  Widget _buildFilterRow(List<VenueModel> all) {
    // Collect all sports across venues
    final sports = <String>{};
    for (final v in all) {
      sports.addAll(v.sports);
    }
    final sortedSports = sports.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _FilterChip(
            label: 'All Sports',
            active: _sport == null,
            onTap: () => setState(() => _sport = null),
          ),
          for (final s in sortedSports.take(8))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterChip(
                label: s,
                active: _sport == s,
                onTap: () => setState(() => _sport = s),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Featured venue banner ──────────────────────────────────────────────────────

class _FeaturedVenueBanner extends StatefulWidget {
  final VenueModel venue;
  final VoidCallback onTap;
  const _FeaturedVenueBanner(
      {required this.venue, required this.onTap});

  @override
  State<_FeaturedVenueBanner> createState() => _FeaturedVenueBannerState();
}

class _FeaturedVenueBannerState extends State<_FeaturedVenueBanner> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit:  (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 180,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hover
                    ? _red.withValues(alpha: .3)
                    : Colors.white.withValues(alpha: .06),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(children: [
              // Photo or gradient
              Container(
                width: 280,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2A3A), Color(0xFF0A1018)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: v.photoUrls.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(v.photoUrls.first),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: .3),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: Stack(children: [
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: .9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('FEATURED',
                          style: _t(size: 9, weight: FontWeight.w800,
                              color: Colors.white, height: 1)),
                    ),
                  ),
                ]),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(v.name,
                          style: _t(size: 20, weight: FontWeight.w800,
                              height: 1.2)),
                      const SizedBox(height: 6),
                      if (v.description.isNotEmpty)
                        Text(v.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _t(size: 13, color: _m1)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: v.sports.take(4).map((s) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _border),
                            ),
                            child: Text(s,
                                style: _t(size: 10, color: _m1)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (v.rating > 0) ...[
                          Icon(Icons.star_rounded,
                              color: _orange, size: 14),
                          const SizedBox(width: 4),
                          Text(v.rating.toStringAsFixed(1),
                              style: _t(size: 12, weight: FontWeight.w700,
                                  color: _orange)),
                          const SizedBox(width: 4),
                          Text('(${v.reviewCount})',
                              style: _t(size: 11, color: _m1)),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.location_on_outlined,
                            size: 12, color: _m2),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(v.address,
                              overflow: TextOverflow.ellipsis,
                              style: _t(size: 12, color: _m1)),
                        ),
                        if (v.pricePerHour > 0) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Starting at',
                            style: _t(size: 10, color: _m2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '₹${v.pricePerHour.toStringAsFixed(0)}/hr',
                            style: _t(size: 13, weight: FontWeight.w800,
                                color: _tx),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: _RedBtn(
                  label: 'View Details',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => VenueDetailScreen(venue: v))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Venue grid ─────────────────────────────────────────────────────────────────

class _VenueGrid extends StatelessWidget {
  final List<VenueModel> venues;
  final ValueChanged<VenueModel> onTap;
  const _VenueGrid({required this.venues, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.stadium_outlined, color: _m2, size: 48),
              const SizedBox(height: 12),
              Text('No venues found',
                  style: _t(size: 15, color: _m1,
                      weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Try a different sport filter or check back later',
                  style: _t(size: 13, color: _m2)),
            ]),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: .85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              _VenueCard(venue: venues[i], onTap: () => onTap(venues[i])),
          childCount: venues.length,
        ),
      ),
    );
  }
}

class _VenueCard extends StatefulWidget {
  final VenueModel venue;
  final VoidCallback onTap;
  const _VenueCard({required this.venue, required this.onTap});

  @override
  State<_VenueCard> createState() => _VenueCardState();
}

class _VenueCardState extends State<_VenueCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? Colors.white.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .06),
            ),
            boxShadow: _hover
                ? [BoxShadow(
                    color: Colors.black.withValues(alpha: .3),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo area
              Expanded(
                flex: 5,
                child: Stack(children: [
                  // Image / gradient
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2030), Color(0xFF080C14)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      image: v.photoUrls.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(v.photoUrls.first),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: .2),
                                BlendMode.darken,
                              ),
                            )
                          : null,
                    ),
                    child: v.photoUrls.isEmpty
                        ? Center(
                            child: Icon(Icons.stadium_outlined,
                                color: _m2, size: 40))
                        : null,
                  ),
                  // Available badge
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Available Today',
                          style: _t(size: 9, weight: FontWeight.w800,
                              color: Colors.white, height: 1)),
                    ),
                  ),
                ]),
              ),
              // Content
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(size: 14, weight: FontWeight.w800,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      if (v.sports.isNotEmpty)
                        Text(v.sports.take(2).join(' · '),
                            style: _t(size: 11, color: _m1)),
                      if (v.rating > 0) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.star_rounded,
                              color: _orange, size: 12),
                          const SizedBox(width: 3),
                          Text(v.rating.toStringAsFixed(1),
                              style: _t(size: 11,
                                  weight: FontWeight.w700, color: _orange)),
                          const SizedBox(width: 4),
                          Text('(${v.reviewCount})',
                              style: _t(size: 10, color: _m2)),
                          const SizedBox(width: 6),
                          Icon(Icons.location_on_outlined,
                              size: 11, color: _m2),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(v.address,
                                overflow: TextOverflow.ellipsis,
                                style: _t(size: 10, color: _m2)),
                          ),
                        ]),
                      ],
                      const Spacer(),
                      Row(children: [
                        if (v.pricePerHour > 0) ...[
                          Text(
                            '₹${v.pricePerHour.toStringAsFixed(0)}/hr',
                            style: _t(size: 14, weight: FontWeight.w800),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        _BookBtn(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      VenueDetailScreen(venue: v))),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Right panel ────────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final VenueModel? selected;
  const _RightPanel({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _border, width: .8)),
      ),
      child: selected == null
          ? _MapPlaceholder()
          : _VenueDetail(venue: selected!),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        height: 200,
        width: double.infinity,
        color: const Color(0xFF0D1520),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined, color: _m2, size: 40),
            const SizedBox(height: 8),
            Text('Select a venue\nto see it on the map',
                textAlign: TextAlign.center,
                style: _t(size: 12, color: _m2)),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tip', style: _t(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Click on any venue card to view availability and quick booking options.',
              style: _t(size: 12, color: _m1, height: 1.6),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _VenueDetail extends StatelessWidget {
  final VenueModel venue;
  const _VenueDetail({required this.venue});

  @override
  Widget build(BuildContext context) {
    final v = venue;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Selected Venue',
            style: _t(size: 14, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        // Venue info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo thumb
              if (v.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    v.photoUrls.first,
                    height: 100, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(height: 100, color: _m2),
                  ),
                ),
              const SizedBox(height: 10),
              Text(v.name,
                  style: _t(size: 14, weight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 4),
              if (v.sports.isNotEmpty)
                Text(v.sports.take(2).join(' · '),
                    style: _t(size: 11, color: _m1)),
              if (v.rating > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.star_rounded, color: _orange, size: 13),
                  const SizedBox(width: 4),
                  Text(v.rating.toStringAsFixed(1),
                      style: _t(size: 12, weight: FontWeight.w700,
                          color: _orange)),
                  const SizedBox(width: 4),
                  Text('(${v.reviewCount})',
                      style: _t(size: 11, color: _m1)),
                ]),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 12, color: _m2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(v.address,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 11, color: _m1)),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Amenity tags
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in v.sports.take(4))
            _Tag(s),
          if (v.isVerified) _Tag('Verified ✓'),
          if (v.pricePerHour > 0)
            _Tag('₹${v.pricePerHour.toStringAsFixed(0)}/hr'),
        ]),
        const SizedBox(height: 20),
        Text('Next Available Slots',
            style: _t(size: 14, weight: FontWeight.w800)),
        const SizedBox(height: 10),
        // Placeholder slots
        for (int h = 9; h <= 13; h++)
          _SlotRow(
            time: '${h > 12 ? h - 12 : h}:00 ${h >= 12 ? 'PM' : 'AM'} '
                '– ${(h + 1) > 12 ? h + 1 - 12 : h + 1}:00 '
                '${(h + 1) >= 12 ? 'PM' : 'AM'}',
            price: v.pricePerHour > 0
                ? '₹${v.pricePerHour.toStringAsFixed(0)}/hr'
                : 'Free',
            onBook: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => VenueDetailScreen(venue: v))),
          ),
        const SizedBox(height: 16),
        _FullWidthBtn(
          label: 'View Full Schedule',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => VenueDetailScreen(venue: v))),
        ),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Text(label, style: _t(size: 11, color: _m1)),
    );
  }
}

class _SlotRow extends StatefulWidget {
  final String time;
  final String price;
  final VoidCallback onBook;
  const _SlotRow({required this.time, required this.price, required this.onBook});

  @override
  State<_SlotRow> createState() => _SlotRowState();
}

class _SlotRowState extends State<_SlotRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Expanded(
          child: Text(widget.time,
              style: _t(size: 12, weight: FontWeight.w600)),
        ),
        Text(widget.price,
            style: _t(size: 12, weight: FontWeight.w700, color: _m1)),
        const SizedBox(width: 10),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit:  (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onBook,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _hover ? const Color(0xFFC82030) : _red,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('Book',
                  style: _t(size: 11, weight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FullWidthBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _FullWidthBtn({required this.label, required this.onTap});

  @override
  State<_FullWidthBtn> createState() => _FullWidthBtnState();
}

class _FullWidthBtnState extends State<_FullWidthBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 40,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .06)
                : Colors.white.withValues(alpha: .03),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _border),
          ),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(widget.label,
                style: _t(size: 12, weight: FontWeight.w600, color: _m1)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, color: _m1, size: 13),
          ]),
        ),
      ),
    );
  }
}

// ── Shared components ──────────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.active
                ? _red.withValues(alpha: .15)
                : (_hover
                    ? Colors.white.withValues(alpha: .05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: widget.active
                  ? _red.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Text(widget.label,
              style: _t(
                size: 12,
                weight: widget.active ? FontWeight.w700 : FontWeight.w500,
                color: widget.active ? _red : _m1,
              )),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Sort by: Recommended', style: _t(size: 12, color: _m1)),
        const SizedBox(width: 6),
        Icon(Icons.keyboard_arrow_down_rounded, color: _m1, size: 16),
      ]),
    );
  }
}

class _RedBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _RedBtn({required this.label, required this.onTap});

  @override
  State<_RedBtn> createState() => _RedBtnState();
}

class _RedBtnState extends State<_RedBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
              color: _red.withValues(alpha: _hover ? .4 : .2),
              blurRadius: 12,
            )],
          ),
          child: Text(widget.label,
              style: _t(size: 13, weight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }
}

class _BookBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BookBtn({required this.onTap});

  @override
  State<_BookBtn> createState() => _BookBtnState();
}

class _BookBtnState extends State<_BookBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Book Now',
              style: _t(size: 11, weight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }
}
