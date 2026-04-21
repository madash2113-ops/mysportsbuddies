import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens (landing page palette) ────────────────────────────────────
const _bg   = Color(0xFF080808);
const _bd   = Color(0xFF1E1E1E);
const _bd2  = Color(0xFF2A2A2A);
const _tx   = Color(0xFFF0F0F0);
const _m1   = Color(0xFF888888);
const _red  = Color(0xFFFB3640);
const _green = Color(0xFF34C759);

// ── Entry point ──────────────────────────────────────────────────────────────
class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavBar(),
            _HeroSection(),
          ],
        ),
      ),
    );
  }
}

// ── Top navigation bar ───────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: const Color(0xE1080808),
        border: Border(bottom: BorderSide(color: _bd)),
      ),
      child: Row(
        children: [
          // Logo
          _Logo(),
          const SizedBox(width: 28),
          // Nav links
          ..._navLinks.map((l) => _NavLink(label: l)),
          const Spacer(),
          // Auth buttons
          _OutlineBtn(
            label: 'Log In',
            onTap: () => Navigator.pushNamed(context, '/login'),
          ),
          const SizedBox(width: 10),
          _RedBtn(
            label: 'Get Started',
            onTap: () => Navigator.pushNamed(context, '/welcome'),
          ),
        ],
      ),
    );
  }
}

const _navLinks = ['About Us', 'Player', 'Admin', 'Venue Merchant', 'Game Host'];

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _red.withValues(alpha: .4), blurRadius: 18)],
          ),
          alignment: Alignment.center,
          child: const Text('🏅', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -.3,
            ),
            children: const [
              TextSpan(text: 'My',      style: TextStyle(color: _tx)),
              TextSpan(text: 'Sports',  style: TextStyle(color: _red)),
              TextSpan(text: 'Buddies', style: TextStyle(color: _tx)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  const _NavLink({required this.label});
  @override
  State<_NavLink> createState() => _NavLinkState();
}
class _NavLinkState extends State<_NavLink> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: _hover ? const Color(0x0DFFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _hover ? _tx : _m1,
            )),
            const SizedBox(width: 4),
            Text('▼', style: TextStyle(fontSize: 9, color: _m1)),
          ],
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});
  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}
class _OutlineBtnState extends State<_OutlineBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hover ? _red : _bd2),
          ),
          child: Text(widget.label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: _hover ? _red : _tx,
          )),
        ),
      ),
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
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFE02A33) : _red,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hover
                ? [BoxShadow(color: _red.withValues(alpha: .4), blurRadius: 20)]
                : [],
          ),
          child: Text(widget.label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
          )),
        ),
      ),
    );
  }
}

// ── Hero section ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height - 68;

    return SizedBox(
      width: w,
      height: h.clamp(600, 900),
      child: Stack(
        children: [
          // Background grid
          Positioned.fill(child: _GridBackground()),

          // Red glows
          Positioned(
            top: -100, left: -100,
            child: _Glow(size: 600, color: _red.withValues(alpha: .18)),
          ),
          Positioned(
            bottom: -100, right: -100,
            child: _Glow(size: 500, color: _red.withValues(alpha: .12)),
          ),

          // Floating cards — left
          Positioned(top: h * .10, left: w * .02,  child: _GameCard(card: _cards[0])),
          Positioned(top: h * .38, left: w * .01,  child: _GameCard(card: _cards[1])),
          Positioned(top: h * .65, left: w * .015, child: _GameCard(card: _cards[2])),

          // Floating cards — right
          Positioned(top: h * .08, right: w * .02,  child: _GameCard(card: _cards[3])),
          Positioned(top: h * .36, right: w * .015, child: _GameCard(card: _cards[4])),
          Positioned(top: h * .63, right: w * .02,  child: _GameCard(card: _cards[5])),

          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x1FFB3640),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _red.withValues(alpha: .25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇮🇳', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text("India's #1 Sports Social Platform",
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _red,
                        )),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Heading
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 72, fontWeight: FontWeight.w900,
                      height: 1.06, letterSpacing: -2,
                    ),
                    children: const [
                      TextSpan(text: 'Where ', style: TextStyle(color: _tx)),
                      TextSpan(text: 'Sports\n', style: TextStyle(color: _red)),
                      TextSpan(text: 'Comes Alive', style: TextStyle(color: _tx)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Subtitle
                SizedBox(
                  width: 520,
                  child: Text(
                    'Discover games, host tournaments, book venues, track live scores & connect with your sports community — all in one place.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 17, color: _m1, height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // CTA buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _heroPrimaryBtn(context),
                    const SizedBox(width: 14),
                    _HeroOutlineBtn(),
                  ],
                ),
                const SizedBox(height: 48),

                // Stats
                _StatsRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _red.withValues(alpha: .07)
      ..strokeWidth = 1;
    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0, .65],
        ),
      ),
    );
  }
}

Widget _heroPrimaryBtn(BuildContext context) {
  return GestureDetector(
    onTap: () => Navigator.pushNamed(context, '/welcome'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: _red.withValues(alpha: .35), blurRadius: 24)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚀', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Text('Get Started Free', style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
          )),
        ],
      ),
    ),
  );
}

class _HeroOutlineBtn extends StatefulWidget {
  @override
  State<_HeroOutlineBtn> createState() => _HeroOutlineBtnState();
}
class _HeroOutlineBtnState extends State<_HeroOutlineBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: _hover ? _red : _bd2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('▶ ', style: TextStyle(fontSize: 14, color: _hover ? _red : _tx)),
            Text('How It Works', style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: _hover ? _red : _tx,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const stats = [
      ('50K+', 'Players'), ('5K+', 'Tournaments'),
      ('800', 'Venues'),   ('22+', 'Sports'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) Container(width: 1, height: 36, color: _bd2,
              margin: const EdgeInsets.symmetric(horizontal: 32)),
          Column(
            children: [
              Text(stats[i].$1, style: GoogleFonts.inter(
                fontSize: 28, fontWeight: FontWeight.w900, color: _red,
              )),
              const SizedBox(height: 2),
              Text(stats[i].$2, style: GoogleFonts.inter(
                fontSize: 11, color: _m1, fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Game cards ────────────────────────────────────────────────────────────────
class _CardData {
  final String sport, emoji, name, location, time, status, extra;
  final bool isLive;
  const _CardData({
    required this.sport, required this.emoji, required this.name,
    required this.location, required this.time, required this.status,
    required this.extra, this.isLive = false,
  });
}

const _cards = [
  _CardData(sport: 'FOOTBALL', emoji: '⚽', name: 'Sunday 5-a-Side',
    location: 'Gachibowli', time: 'Sun 7AM', status: 'Open', extra: '4/10'),
  _CardData(sport: 'TENNIS', emoji: '🎾', name: 'Doubles Round Robin',
    location: 'Banjara Hills', time: 'Sun 8AM', status: 'LIVE', extra: '6-4, 3-2', isLive: true),
  _CardData(sport: 'BADMINTON', emoji: '🏸', name: 'Club Tournament',
    location: 'Hitex', time: 'Sat 9AM', status: 'Open', extra: '12/16'),
  _CardData(sport: 'CRICKET', emoji: '🏏', name: 'T20 League Final',
    location: 'LB Stadium', time: 'Sat 6PM', status: 'LIVE', extra: '186/4 — 16.2 ov', isLive: true),
  _CardData(sport: 'VOLLEYBALL', emoji: '🏐', name: 'Beach Volleyball',
    location: 'HICC', time: 'Fri 5PM', status: 'Open', extra: '8/12'),
  _CardData(sport: 'BASKETBALL', emoji: '🏀', name: '3×3 Streetball',
    location: 'Jubilee Hills', time: 'Mon 6PM', status: 'Open', extra: '5/6'),
];

class _GameCard extends StatelessWidget {
  final _CardData card;
  const _GameCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xC8141414),
        border: Border.all(color: _red.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 32),
          BoxShadow(color: Colors.white.withValues(alpha: .04), blurRadius: 0,
              spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sport + emoji row
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0x1FFB3640),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(card.emoji, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.sport, style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _red, letterSpacing: .5,
                )),
                Text(card.name, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w800, color: _tx,
                )),
              ],
            ),
          ]),
          const SizedBox(height: 8),

          // Location + time
          Text('📍 ${card.location} · ${card.time}',
            style: GoogleFonts.inter(fontSize: 11, color: _m1)),
          const SizedBox(height: 7),

          // Status + extra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              card.isLive
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFB3640),
                        border: Border.all(color: _red.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 5, height: 5,
                          decoration: const BoxDecoration(
                            color: _red, shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text('LIVE', style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800, color: _red,
                        )),
                      ]),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: .15),
                        border: Border.all(color: _green.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('● Open', style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w800, color: _green,
                      )),
                    ),
              Text(card.extra, style: GoogleFonts.inter(
                fontSize: 10, color: _m1, fontWeight: FontWeight.w700,
              )),
            ],
          ),

          // Progress bar (for Open cards)
          if (!card.isLive) ...[
            const SizedBox(height: 7),
            _ProgressBar(text: card.extra),
          ],
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String text; // "4/10"
  const _ProgressBar({required this.text});
  @override
  Widget build(BuildContext context) {
    final parts = text.split('/');
    final pct = parts.length == 2
        ? (int.tryParse(parts[0]) ?? 0) / (int.tryParse(parts[1]) ?? 1)
        : 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: pct.clamp(0.0, 1.0),
        backgroundColor: _bd2,
        valueColor: const AlwaysStoppedAnimation(_red),
        minHeight: 3,
      ),
    );
  }
}
