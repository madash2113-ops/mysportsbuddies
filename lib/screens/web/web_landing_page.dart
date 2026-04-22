import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF030303);
const _surf = Color(0xFF070707);
const _card = Color(0xFF0D0D0D);
const _bd = Color(0xFF1A1A1A);
const _bd2 = Color(0xFF222222);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _red = Color(0xFFFF2B2B); // true red — not orange
const _redDeep = Color(0xFFB3001B); // deep crimson
const _green = Color(0xFF34C759);

// ── Shared text style helpers ─────────────────────────────────────────────────
TextStyle _inter({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
  double letterSpacing = 0,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

// ── Liquid glass container ────────────────────────────────────────────────────
class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  final double blur;

  const _Glass({
    required this.child,
    this.radius = 16,
    this.padding,
    this.blur = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Badge pill ────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  const _Badge(this.label, {this.color});
  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 99,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Text(
        label,
        style: _inter(size: 11, weight: FontWeight.w600, color: color ?? _m1),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
          child: Column(children: children),
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String badge;
  final String title;
  final String? sub;
  final Color? badgeColor;
  const _SectionHeader({
    required this.badge,
    required this.title,
    this.sub,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Badge(badge, color: badgeColor),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: _inter(
            size: 42,
            weight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -1.5,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 520,
            child: Text(
              sub!,
              textAlign: TextAlign.center,
              style: _inter(size: 15, color: _m1, height: 1.7),
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY POINT
// ══════════════════════════════════════════════════════════════════════════════
class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});
  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  final _scroll = ScrollController();
  double _navOpacity = 0;
  Offset _cursor = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final op = (_scroll.offset / 60).clamp(0.0, 1.0);
      if ((op - _navOpacity).abs() > 0.01) setState(() => _navOpacity = op);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showRolePicker() {
    showDialog(context: context, builder: (_) => _RolePickerDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: MouseRegion(
        onHover: (e) => setState(() => _cursor = e.localPosition),
        child: Stack(
          children: [
            // Global ambient grid
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),

            // Cursor-follow glow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              left: _cursor.dx - 450,
              top: _cursor.dy - 450,
              child: IgnorePointer(child: _CursorGlow(900)),
            ),

            SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  const SizedBox(height: 64),
                  _HeroSection(onGetStarted: _showRolePicker),
                  _HowItWorksSection(),
                  _FeaturesSection(),
                  _WhyUsSection(),
                  _StatsSection(),
                  _TestimonialsSection(),
                  _CtaFooterSection(onGetStarted: _showRolePicker),
                ],
              ),
            ),
            // Fixed navbar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _NavBar(
                scrollOpacity: _navOpacity,
                onGetStarted: _showRolePicker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NAVBAR
// ══════════════════════════════════════════════════════════════════════════════
class _NavBar extends StatelessWidget {
  final double scrollOpacity;
  final VoidCallback onGetStarted;
  const _NavBar({required this.scrollOpacity, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.transparent,
          const Color(0xE6080808),
          scrollOpacity,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06 * scrollOpacity),
          ),
        ),
      ),
      child: Row(
        children: [
          _Logo(),
          const SizedBox(width: 32),
          ..._navLinks.map((l) => _NavLink(label: l)),
          const Spacer(),
          _OutlineBtn(
            label: 'Log In',
            onTap: () => Navigator.pushNamed(context, '/login'),
          ),
          const SizedBox(width: 10),
          _RedBtn(label: 'Get Started', onTap: onGetStarted),
        ],
      ),
    );
  }
}

const _navLinks = ['About Us'];

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(color: _red.withValues(alpha: .35), blurRadius: 14),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('🏅', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: _inter(
              size: 14,
              weight: FontWeight.w900,
              letterSpacing: -.3,
            ),
            children: const [
              TextSpan(
                text: 'My',
                style: TextStyle(color: _tx),
              ),
              TextSpan(
                text: 'Sports',
                style: TextStyle(color: _red),
              ),
              TextSpan(
                text: 'Buddies',
                style: TextStyle(color: _tx),
              ),
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
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _hover
              ? Colors.white.withValues(alpha: .05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: _inter(
                size: 13,
                weight: FontWeight.w600,
                color: _hover ? _tx : _m1,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              '▾',
              style: TextStyle(fontSize: 10, color: _hover ? _m1 : _bd2),
            ),
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
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _hover ? _red : _bd2),
          ),
          child: Text(
            widget.label,
            style: _inter(
              size: 13,
              weight: FontWeight.w600,
              color: _hover ? _red : _tx,
            ),
          ),
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
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_red, _hover ? _redDeep : const Color(0xFFCC1020)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _red.withValues(alpha: .45),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: _inter(
              size: 13,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO SECTION
// ══════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _HeroSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = (MediaQuery.of(context).size.height - 64).clamp(600.0, 920.0);

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // Grid
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // Glows
          Positioned(
            top: -80,
            left: -80,
            child: _GlowCircle(500, _red.withValues(alpha: .15)),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: _GlowCircle(420, _red.withValues(alpha: .10)),
          ),

          // Left cards
          Positioned(
            top: h * .10,
            left: w * .015,
            child: _GameCard(card: _cards[0]),
          ),
          Positioned(
            top: h * .40,
            left: w * .010,
            child: _GameCard(card: _cards[1]),
          ),
          Positioned(
            top: h * .68,
            left: w * .015,
            child: _GameCard(card: _cards[2]),
          ),

          // Right cards
          Positioned(
            top: h * .08,
            right: w * .015,
            child: _GameCard(card: _cards[3]),
          ),
          Positioned(
            top: h * .38,
            right: w * .010,
            child: _GameCard(card: _cards[4]),
          ),
          Positioned(
            top: h * .66,
            right: w * .015,
            child: _GameCard(card: _cards[5]),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _bg],
                ),
              ),
            ),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Badge
                _Glass(
                  radius: 99,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇮🇳', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        "India's #1 Sports Social Platform",
                        style: _inter(
                          size: 12,
                          weight: FontWeight.w700,
                          color: _red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Heading
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: _inter(
                      size: 78,
                      weight: FontWeight.w900,
                      height: 1.03,
                      letterSpacing: -2.5,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Where ',
                        style: TextStyle(color: _tx),
                      ),
                      TextSpan(
                        text: 'Sports\n',
                        style: TextStyle(color: _red),
                      ),
                      TextSpan(
                        text: 'Comes Alive',
                        style: TextStyle(color: _tx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Subtitle
                SizedBox(
                  width: 500,
                  child: Text(
                    'Discover games, host tournaments, book venues, track live scores'
                    ' & connect with your sports community — all in one place.',
                    textAlign: TextAlign.center,
                    style: _inter(size: 16, color: _m1, height: 1.75),
                  ),
                ),
                const SizedBox(height: 38),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeroPrimaryBtn(onTap: onGetStarted),
                    const SizedBox(width: 14),
                    const _HeroOutlineBtn(),
                  ],
                ),
                const SizedBox(height: 52),

                // Stats
                _HeroStats(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPrimaryBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _HeroPrimaryBtn({required this.onTap});
  @override
  State<_HeroPrimaryBtn> createState() => _HeroPrimaryBtnState();
}

class _HeroPrimaryBtnState extends State<_HeroPrimaryBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hover
                  ? [_red, _redDeep]
                  : [_red, const Color(0xFFCC1020)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: .40),
                blurRadius: _hover ? 30 : 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                'Get Started Free',
                style: _inter(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroOutlineBtn extends StatefulWidget {
  const _HeroOutlineBtn();
  @override
  State<_HeroOutlineBtn> createState() => _HeroOutlineBtnState();
}

class _HeroOutlineBtnState extends State<_HeroOutlineBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: _hover ? _red : _bd2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('▶ ', style: _inter(size: 13, color: _hover ? _red : _tx)),
            Text(
              'How It Works',
              style: _inter(
                size: 15,
                weight: FontWeight.w600,
                color: _hover ? _red : _tx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const stats = [
      ('50K+', 'Players'),
      ('5K+', 'Tournaments'),
      ('800', 'Venues'),
      ('22+', 'Sports'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 36,
              color: _bd2,
              margin: const EdgeInsets.symmetric(horizontal: 32),
            ),
          Column(
            children: [
              Text(
                stats[i].$1,
                style: _inter(
                  size: 30,
                  weight: FontWeight.w900,
                  color: _red,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                stats[i].$2,
                style: _inter(size: 11, color: _m1, weight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HOW IT WORKS
// ══════════════════════════════════════════════════════════════════════════════
class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        '🔍',
        '01',
        'Find Your Game',
        'Browse hundreds of active games near you. Filter by sport, skill level, location and time — then join in seconds.',
      ),
      (
        '📅',
        '02',
        'Book & Confirm',
        'Reserve your spot or a venue instantly. Secure payments, instant confirmations, and reminders keep everything on track.',
      ),
      (
        '🏆',
        '03',
        'Play & Track',
        'Show up, compete, and watch live scores update in real time. Track your stats, wins, and progress across every sport.',
      ),
      (
        '👥',
        '04',
        'Grow Your Circle',
        'Connect with players, follow athletes, join sport communities and build lasting relationships on and off the field.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: _bg,
      child: _Section(
        children: [
          _SectionHeader(
            badge: 'How It Works',
            title: 'From zero to game day\nin minutes.',
            sub:
                'We made it ridiculously simple. No calls, no confusion — just show up and play.',
          ),
          const SizedBox(height: 56),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: steps
                .map(
                  (s) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _StepCard(
                        emoji: s.$1,
                        step: s.$2,
                        title: s.$3,
                        body: s.$4,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatefulWidget {
  final String emoji, step, title, body;
  const _StepCard({
    required this.emoji,
    required this.step,
    required this.title,
    required this.body,
  });
  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hover ? _surf : _card.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hover ? _red.withValues(alpha: .25) : _bd),
          boxShadow: _hover
              ? [BoxShadow(color: _red.withValues(alpha: .08), blurRadius: 24)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 26)),
                Text(
                  widget.step,
                  style: _inter(
                    size: 38,
                    weight: FontWeight.w900,
                    color: _red.withValues(alpha: .12),
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: _inter(size: 16, weight: FontWeight.w800, height: 1.3),
            ),
            const SizedBox(height: 10),
            Text(widget.body, style: _inter(size: 13, color: _m1, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURES (alternating chess rows)
// ══════════════════════════════════════════════════════════════════════════════
class _FeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: _Section(
        children: [
          _SectionHeader(
            badge: 'Platform Features',
            title: "Everything sport needs.\nNothing it doesn't.",
          ),
          const SizedBox(height: 64),
          _FeatureRow(
            badge: 'Live Scoreboards',
            title: 'Every match. Every point. Live.',
            body:
                'Track scores in real time across cricket, football, badminton and 19 other sports. ICC-standard stats, ball-by-ball updates, and team dashboards — all built in.',
            cta: 'See Live Scores',
            preview: _ScoreboardPreview(),
          ),
          const SizedBox(height: 32),
          _FeatureRow(
            badge: 'Smart Matchmaking',
            title: 'It finds the right game. Automatically.',
            body:
                'Our algorithm matches you with games at your skill level, preferred location, and available time. No scrolling through irrelevant listings. Just the right game.',
            cta: 'Find a Game',
            preview: _MatchmakingPreview(),
            reverse: true,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String badge, title, body, cta;
  final Widget preview;
  final bool reverse;
  const _FeatureRow({
    required this.badge,
    required this.title,
    required this.body,
    required this.cta,
    required this.preview,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final textCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Glass(
          radius: 99,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            badge,
            style: _inter(size: 11, weight: FontWeight.w600, color: _red),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: _inter(
            size: 32,
            weight: FontWeight.w900,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 16),
        Text(body, style: _inter(size: 14, color: _m1, height: 1.8)),
        const SizedBox(height: 28),
        _GlassBtn(label: cta),
      ],
    );

    final imgCol = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _bd),
        ),
        child: preview,
      ),
    );

    return Row(
      children: reverse
          ? [
              Expanded(child: imgCol),
              const SizedBox(width: 64),
              Expanded(child: textCol),
            ]
          : [
              Expanded(child: textCol),
              const SizedBox(width: 64),
              Expanded(child: imgCol),
            ],
    );
  }
}

class _GlassBtn extends StatefulWidget {
  final String label;
  const _GlassBtn({required this.label});
  @override
  State<_GlassBtn> createState() => _GlassBtnState();
}

class _GlassBtnState extends State<_GlassBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .08)
                : Colors.white.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: _hover ? Colors.white.withValues(alpha: .25) : _bd2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: _inter(size: 13, weight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              const Text('↗', style: TextStyle(fontSize: 13, color: _tx)),
            ],
          ),
        ),
      ),
    );
  }
}

// Scoreboard preview widget
class _ScoreboardPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏏', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'T20 League Final — LIVE',
                style: _inter(size: 12, weight: FontWeight.w700, color: _red),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LIVE',
                  style: _inter(size: 10, weight: FontWeight.w800, color: _red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ScoreRow('Mumbai XI', '186/4', '16.2 ov', isLead: true),
          const SizedBox(height: 8),
          _ScoreRow('Hyderabad SC', '142/6', '14.0 ov'),
          const Divider(color: _bd, height: 24),
          Text(
            'Last wicket: R. Sharma c. Patel b. Rao — 42',
            style: _inter(size: 11, color: _m1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in ['6', '1', 'W', '4', '2', '0']) ...[
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: s == 'W'
                        ? _red.withValues(alpha: .2)
                        : s == '4' || s == '6'
                        ? _green.withValues(alpha: .15)
                        : _bd,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s,
                    style: _inter(
                      size: 11,
                      weight: FontWeight.w800,
                      color: s == 'W'
                          ? _red
                          : s == '4' || s == '6'
                          ? _green
                          : _m1,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Text('This over', style: _inter(size: 10, color: _m1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String team, score, overs;
  final bool isLead;
  const _ScoreRow(this.team, this.score, this.overs, {this.isLead = false});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          team,
          style: _inter(
            size: 13,
            weight: FontWeight.w700,
            color: isLead ? _tx : _m1,
          ),
        ),
        const Spacer(),
        Text(
          score,
          style: _inter(
            size: 18,
            weight: FontWeight.w900,
            color: isLead ? _red : _m1,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(overs, style: _inter(size: 11, color: _m1)),
      ],
    );
  }
}

// Matchmaking preview widget
class _MatchmakingPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final games = [
      ('⚽', 'Sunday 5-a-Side', 'Gachibowli · 2.1 km', 'Open', '4/10'),
      ('🏸', 'Club Tournament', 'Hitex · 3.4 km', 'Open', '12/16'),
      ('🏀', '3×3 Streetball', 'Jubilee Hills · 5.2 km', 'Filling', '5/6'),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bd.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _bd2),
            ),
            child: Row(
              children: [
                const Text('🔍', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Text(
                  'Football · Hyderabad · Sunday',
                  style: _inter(size: 12, color: _m1),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Search',
                    style: _inter(
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...games.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bd.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _bd),
                ),
                child: Row(
                  children: [
                    Text(g.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.$2,
                            style: _inter(size: 12, weight: FontWeight.w700),
                          ),
                          Text(g.$3, style: _inter(size: 10, color: _m1)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            g.$4,
                            style: _inter(
                              size: 9,
                              weight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          g.$5,
                          style: _inter(
                            size: 10,
                            color: _m1,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WHY US GRID
// ══════════════════════════════════════════════════════════════════════════════
class _WhyUsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const cards = [
      (
        '⚡',
        'Instant Matchmaking',
        'Find a game in under 60 seconds. Smart filters surface the best options near you based on skill, sport, and schedule.',
      ),
      (
        '📍',
        '800+ Venues Nationwide',
        'Browse, compare, and book courts, fields, and arenas across India. Real-time availability. Zero phone calls.',
      ),
      (
        '📊',
        'Pro-Level Stats',
        'ICC batting averages. Football heat maps. Badminton rally analytics. Track every metric that makes you better.',
      ),
      (
        '🔒',
        'Secure Payments',
        'Pay for bookings, tournament entries, and memberships safely. UPI, cards, and wallets — instant receipts.',
      ),
    ];

    return Container(
      color: _bg,
      child: _Section(
        children: [
          _SectionHeader(
            badge: 'Why MySportsBuddies',
            title: 'The platform built for\nathletes.',
            badgeColor: _red,
          ),
          const SizedBox(height: 56),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _WhyCard(emoji: c.$1, title: c.$2, body: c.$3),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WhyCard extends StatefulWidget {
  final String emoji, title, body;
  const _WhyCard({
    required this.emoji,
    required this.title,
    required this.body,
  });
  @override
  State<_WhyCard> createState() => _WhyCardState();
}

class _WhyCardState extends State<_WhyCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _hover ? _surf : _card.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hover ? _red.withValues(alpha: .25) : _bd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withValues(alpha: .2)),
              ),
              alignment: Alignment.center,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: _inter(size: 14, weight: FontWeight.w800, height: 1.3),
            ),
            const SizedBox(height: 8),
            Text(widget.body, style: _inter(size: 12, color: _m1, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATS NUMBERS
// ══════════════════════════════════════════════════════════════════════════════
class _StatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const stats = [
      ('50K+', 'Active Players'),
      ('5K+', 'Tournaments Hosted'),
      ('800+', 'Verified Venues'),
      ('22+', 'Sports Supported'),
    ];

    return Container(
      color: _bg,
      child: _Section(
        children: [
          _Badge('By the Numbers'),
          const SizedBox(height: 40),
          _Glass(
            radius: 24,
            blur: 16,
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 52),
            child: Row(
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.white.withValues(alpha: .1),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          stats[i].$1,
                          style: _inter(
                            size: 52,
                            weight: FontWeight.w900,
                            color: _red,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stats[i].$2,
                          style: _inter(
                            size: 12,
                            color: _m1,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TESTIMONIALS
// ══════════════════════════════════════════════════════════════════════════════
class _TestimonialsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const testimonials = [
      (
        '⚽',
        '"Found a football game 10 minutes from my place on a Sunday morning. Played with strangers, made five new friends. Genuinely addictive."',
        'Arjun Mehta',
        'Football Player · Hyderabad',
      ),
      (
        '🏟️',
        '"As a venue owner, bookings went up 3x after listing on MySportsBuddies. The dashboard is clean, payouts are instant, and support is brilliant."',
        'Priya Sharma',
        'Venue Owner · Gachibowli Arena',
      ),
      (
        '🏏',
        '"We ran a 64-team cricket tournament through the app. Scheduling, scorekeeping, live updates — handled automatically. We just focused on cricket."',
        'Rohit Nair',
        'Tournament Organizer · Chennai',
      ),
    ];

    return Container(
      color: _bg,
      child: _Section(
        children: [
          _SectionHeader(
            badge: 'Community Stories',
            title: 'Real players.\nReal games. Real love.',
          ),
          const SizedBox(height: 56),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final cards = testimonials
                  .map(
                    (t) => _TestimonialCard(
                      emoji: t.$1,
                      quote: t.$2,
                      name: t.$3,
                      role: t.$4,
                    ),
                  )
                  .toList();

              if (isNarrow) {
                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      cards[i],
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatefulWidget {
  final String emoji, quote, name, role;
  const _TestimonialCard({
    required this.emoji,
    required this.quote,
    required this.name,
    required this.role,
  });
  @override
  State<_TestimonialCard> createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<_TestimonialCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(minHeight: 260),
        decoration: BoxDecoration(
          color: _hover ? _surf : _card.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hover ? _red.withValues(alpha: .2) : _bd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 16),
            Text(
              widget.quote,
              style: _inter(
                size: 13,
                color: _tx.withValues(alpha: .8),
                height: 1.75,
              ),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: _bd),
            const SizedBox(height: 16),
            Text(widget.name, style: _inter(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.role, style: _inter(size: 11, color: _m1)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CTA + FOOTER
// ══════════════════════════════════════════════════════════════════════════════
class _CtaFooterSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaFooterSection({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(child: _GlowCircle(700, _red.withValues(alpha: .08))),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 100, 48, 0),
                child: Column(
                  children: [
                    // Heading
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: _inter(
                          size: 64,
                          weight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -2,
                        ),
                        children: const [
                          TextSpan(text: 'Your next game '),
                          TextSpan(
                            text: 'starts here.',
                            style: TextStyle(color: _red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 480,
                      child: Text(
                        'Join 50,000+ athletes already playing smarter. Create a free account and find your first game in under 60 seconds.',
                        textAlign: TextAlign.center,
                        style: _inter(size: 16, color: _m1, height: 1.75),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _HeroPrimaryBtn(onTap: onGetStarted),
                        const SizedBox(width: 14),
                        _GlassBtn(label: 'View All Sports'),
                      ],
                    ),
                    const SizedBox(height: 100),
                    // Footer bar
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: _bd)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '© 2026 MySportsBuddies. All rights reserved.',
                            style: _inter(
                              size: 12,
                              color: _m1.withValues(alpha: .5),
                            ),
                          ),
                          const Spacer(),
                          for (final l in [
                            'Privacy',
                            'Terms',
                            'Contact',
                            'Blog',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  l,
                                  style: _inter(
                                    size: 12,
                                    color: _m1.withValues(alpha: .5),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ROLE PICKER DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _RolePickerDialog extends StatefulWidget {
  @override
  State<_RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<_RolePickerDialog> {
  String _role = 'player';

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_role', _role);
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _bd2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .6),
              blurRadius: 60,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how to continue',
              style: _inter(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Select your role to get the right experience.',
              style: _inter(size: 13, color: _m1),
            ),
            const SizedBox(height: 24),

            // Player
            _RoleOption(
              emoji: '⚽',
              title: "I'm a Player",
              sub: 'Find games, join tournaments, track scores.',
              selected: _role == 'player',
              onTap: () => setState(() => _role = 'player'),
              activeColor: _red,
            ),
            const SizedBox(height: 12),
            // Venue Owner
            _RoleOption(
              emoji: '🏟️',
              title: "I'm a Venue Owner",
              sub: 'List your ground, court or turf. Manage bookings.',
              selected: _role == 'merchant',
              onTap: () => setState(() => _role = 'merchant'),
              activeColor: const Color(0xFF3949AB),
            ),
            const SizedBox(height: 28),

            // Continue button
            GestureDetector(
              onTap: _continue,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _role == 'player' ? _red : const Color(0xFF3949AB),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_role == 'player' ? _red : const Color(0xFF3949AB))
                              .withValues(alpha: .35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: _inter(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String emoji, title, sub;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  const _RoleOption({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: .08) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor.withValues(alpha: .4) : _bd,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _inter(size: 14, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub, style: _inter(size: 12, color: _m1)),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED PRIMITIVES
// ══════════════════════════════════════════════════════════════════════════════

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle(this.size, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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

class _CursorGlow extends StatelessWidget {
  final double size;
  const _CursorGlow(this.size);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Outer soft halo
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_red.withValues(alpha: .38), Colors.transparent],
                stops: const [0, .7],
              ),
            ),
          ),
          // Inner hot core
          Center(
            child: Container(
              width: size * .35,
              height: size * .35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_red.withValues(alpha: .65), Colors.transparent],
                  stops: const [0, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _red.withValues(alpha: .06)
      ..strokeWidth = 1;
    const step = 64.0;
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

// ── Game cards ─────────────────────────────────────────────────────────────────
class _CardData {
  final String sport, emoji, name, location, time, status, extra;
  final bool isLive;
  const _CardData({
    required this.sport,
    required this.emoji,
    required this.name,
    required this.location,
    required this.time,
    required this.status,
    required this.extra,
    this.isLive = false,
  });
}

const _cards = [
  _CardData(
    sport: 'FOOTBALL',
    emoji: '⚽',
    name: 'Sunday 5-a-Side',
    location: 'Gachibowli',
    time: 'Sun 7AM',
    status: 'Open',
    extra: '4/10',
  ),
  _CardData(
    sport: 'TENNIS',
    emoji: '🎾',
    name: 'Doubles Round Robin',
    location: 'Banjara Hills',
    time: 'Sun 8AM',
    status: 'LIVE',
    extra: '6-4, 3-2',
    isLive: true,
  ),
  _CardData(
    sport: 'BADMINTON',
    emoji: '🏸',
    name: 'Club Tournament',
    location: 'Hitex',
    time: 'Sat 9AM',
    status: 'Open',
    extra: '12/16',
  ),
  _CardData(
    sport: 'CRICKET',
    emoji: '🏏',
    name: 'T20 League Final',
    location: 'LB Stadium',
    time: 'Sat 6PM',
    status: 'LIVE',
    extra: '186/4 — 16.2 ov',
    isLive: true,
  ),
  _CardData(
    sport: 'VOLLEYBALL',
    emoji: '🏐',
    name: 'Beach Volleyball',
    location: 'HICC',
    time: 'Fri 5PM',
    status: 'Open',
    extra: '8/12',
  ),
  _CardData(
    sport: 'BASKETBALL',
    emoji: '🏀',
    name: '3×3 Streetball',
    location: 'Jubilee Hills',
    time: 'Mon 6PM',
    status: 'Open',
    extra: '5/6',
  ),
];

class _GameCard extends StatelessWidget {
  final _CardData card;
  const _GameCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 195,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xCC141414),
        border: Border.all(color: _red.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 32),
          BoxShadow(
            color: Colors.white.withValues(alpha: .03),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0x1FFB3640),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(card.emoji, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.sport,
                      style: _inter(
                        size: 9,
                        weight: FontWeight.w700,
                        color: _red,
                        letterSpacing: .5,
                      ),
                    ),
                    Text(
                      card.name,
                      style: _inter(size: 11, weight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📍 ${card.location} · ${card.time}',
            style: _inter(size: 10, color: _m1),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              card.isLive
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFB3640),
                        border: Border.all(color: _red.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: _red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'LIVE',
                            style: _inter(
                              size: 9,
                              weight: FontWeight.w800,
                              color: _red,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: .15),
                        border: Border.all(color: _green.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '● Open',
                        style: _inter(
                          size: 9,
                          weight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                    ),
              Text(
                card.extra,
                style: _inter(size: 10, color: _m1, weight: FontWeight.w700),
              ),
            ],
          ),
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
  final String text;
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
