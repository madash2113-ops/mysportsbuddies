import 'dart:io';
import 'package:flutter/material.dart';
import '../../design/colors.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlan = 1; // 0=Monthly, 1=Annual, 2=Lifetime

  // ── Currency detection ──────────────────────────────────────────────────────

  static String _detectCurrency() {
    try {
      final locale = Platform.localeName;
      final country = locale.split('_').last.toUpperCase();
      switch (country) {
        case 'IN': return 'INR';
        case 'US': return 'USD';
        case 'GB': return 'GBP';
        case 'AU':
        case 'NZ': return 'AUD';
        case 'DE':
        case 'FR':
        case 'IT':
        case 'ES':
        case 'NL':
        case 'AT':
        case 'BE':
        case 'PT':
        case 'FI':
        case 'GR': return 'EUR';
        case 'AE':
        case 'SA':
        case 'QA':
        case 'KW': return 'AED';
        case 'SG': return 'SGD';
        case 'MY': return 'MYR';
        case 'PK': return 'PKR';
        case 'BD': return 'BDT';
        case 'LK': return 'LKR';
        case 'NP': return 'NPR';
        case 'JP': return 'JPY';
        case 'CN': return 'CNY';
        case 'KR': return 'KRW';
        case 'CA': return 'CAD';
        default:   return 'USD';
      }
    } catch (_) {
      return 'USD';
    }
  }

  // prices[currency] = [monthly, annual, lifetime]
  static const _prices = <String, List<String>>{
    'INR': ['\u20B9199',   '\u20B9999',    '\u20B92,499'],
    'USD': ['\u00243.99',  '\u002429.99',  '\u002449.99'],
    'GBP': ['\u00A33.29',  '\u00A324.99',  '\u00A342.99'],
    'AUD': ['\u00246.49',  '\u002447.99',  '\u002479.99'],
    'EUR': ['\u20AC3.69',  '\u20AC27.99',  '\u20AC46.99'],
    'AED': ['AED 14',      'AED 109',      'AED 183'],
    'SGD': ['S\u00245.49', 'S\u002440.99', 'S\u002467.99'],
    'MYR': ['RM 17',       'RM 129',       'RM 215'],
    'PKR': ['Rs 1,099',    'Rs 8,299',     'Rs 13,799'],
    'BDT': ['\u09F3349',   '\u09F32,649',  '\u09F34,399'],
    'LKR': ['Rs 1,299',    'Rs 9,799',     'Rs 16,299'],
    'NPR': ['Rs 529',      'Rs 3,999',     'Rs 6,649'],
    'JPY': ['\u00A5650',   '\u00A54,899',  '\u00A58,149'],
    'CNY': ['\u00A528',    '\u00A5212',    '\u00A5352'],
    'KRW': ['\u20A95,400', '\u20A940,899', '\u20A967,999'],
    'CAD': ['\u00245.49',  '\u002439.99',  '\u002466.99'],
  };

  static const _features = [
    _Feature('PDF Match Reports',
        'Export full scorecards as formatted PDFs', false, true),
    _Feature('Advanced Statistics',
        'Batting avg, bowling economy, strike rates', false, true),
    _Feature('Unlimited Scoreboards',
        'Create as many live scoreboards as you need', true, true),
    _Feature('Premium Badge',
        'Gold \u26A1 badge on your profile', false, true),
    _Feature('Priority Alerts',
        'First to know about nearby games', false, true),
    _Feature('Live Streaming',
        'Stream & watch sports live', false, true),
    _Feature('Tournament Priority',
        'Early access to register in tournaments', false, true),
  ];

  late final String _currency = _detectCurrency();

  List<String> get _planPrices =>
      _prices[_currency] ?? _prices['USD']!;

  List<_Plan> get _plans => [
        _Plan('Monthly',  _planPrices[0], '/month',   '',           false),
        _Plan('Annual',   _planPrices[1], '/year',    'Save 58%',   true),
        _Plan('Lifetime', _planPrices[2], 'one-time', 'Best deal',  false),
      ];

  void _subscribe() {
    final plan = _plans[_selectedPlan];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\u26A1 ${plan.name} plan coming soon — stay tuned!',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0A0A0A) : AppColorsLight.background;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final plans   = _plans;
    final canPop  = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                _HeroBanner(isDark: isDark),
                if (canPop)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 4,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
              ],
            ),
          ),

          // ── Free vs Premium comparison ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: _ComparisonTable(
                features: _features,
                isDark: isDark,
                primary: primary,
                textCol: textCol,
              ),
            ),
          ),

          // ── Plan selector ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose Your Plan',
                      style: TextStyle(
                          color: textCol,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ...plans.asMap().entries.map(
                        (e) => _PlanCard(
                          plan: e.value,
                          selected: _selectedPlan == e.key,
                          primary: primary,
                          textCol: textCol,
                          isDark: isDark,
                          onTap: () =>
                              setState(() => _selectedPlan = e.key),
                        ),
                      ),
                ],
              ),
            ),
          ),

          // ── CTA ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            primary.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _subscribe,
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('\u26A1',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  'Get ${plans[_selectedPlan].name} — ${plans[_selectedPlan].price}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cancel anytime \u00B7 Secure payment \u00B7 No hidden fees',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TextLink('Restore Purchases', isDark),
                      const SizedBox(width: 16),
                      _TextLink('Terms', isDark),
                      const SizedBox(width: 16),
                      _TextLink('Privacy', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 100 + MediaQuery.of(context).padding.bottom,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final bool isDark;
  const _HeroBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Container(
      height: 260 + statusBarH,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF4A0000),
                  const Color(0xFF2D0000),
                  const Color(0xFF1A0000),
                ]
              : [
                  const Color(0xFFE53935),
                  const Color(0xFFC62828),
                  const Color(0xFF8B0000),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text('\uD83D\uDC51',
                        style: TextStyle(fontSize: 34)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'MySportsBuddies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Premium Membership',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock the complete sports experience',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: const Text(
                '\u2B50  Trusted by 10,000+ sports enthusiasts',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comparison table — ticks & crosses only, no colour coding ─────────────────

class _ComparisonTable extends StatelessWidget {
  final List<_Feature> features;
  final bool isDark;
  final Color primary, textCol;
  const _ComparisonTable({
    required this.features,
    required this.isDark,
    required this.primary,
    required this.textCol,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final subCol = isDark ? Colors.white54 : Colors.black54;
    final divCol = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What You Unlock',
          style: TextStyle(
            color: textCol,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divCol),
          ),
          child: Column(
            children: [
              // Header row
              Container(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Feature',
                          style: TextStyle(
                              color: subCol,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text('Free',
                          style: TextStyle(
                              color: subCol,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text('Pro',
                          style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),

              // Feature rows — only ✓ / ✗, no color coding
              ...features.asMap().entries.map((e) {
                final f = e.value;
                final isLast = e.key == features.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: divCol,
                              width: 0.5,
                            ),
                          ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.title,
                                style: TextStyle(
                                    color: textCol,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(f.subtitle,
                                style: TextStyle(
                                    color: subCol,
                                    fontSize: 11,
                                    height: 1.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Free column — plain ✓ or ✗
                      SizedBox(
                        width: 52,
                        child: Center(
                          child: Text(
                            f.hasFree ? '\u2713' : '\u2717',
                            style: TextStyle(
                              color: f.hasFree ? textCol : subCol,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Pro column — plain ✓ or ✗
                      SizedBox(
                        width: 60,
                        child: Center(
                          child: Text(
                            f.hasPro ? '\u2713' : '\u2717',
                            style: TextStyle(
                              color: f.hasPro ? textCol : subCol,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected, isDark;
  final Color primary, textCol;
  final VoidCallback onTap;
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.primary,
    required this.textCol,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? (selected
            ? primary.withValues(alpha: 0.10)
            : const Color(0xFF111111))
        : (selected
            ? primary.withValues(alpha: 0.06)
            : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primary
                : (isDark ? Colors.white12 : Colors.black12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? primary
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 2,
                ),
                color: selected ? primary : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.name,
                          style: TextStyle(
                              color: textCol,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      if (plan.isBest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFB300),
                                Color(0xFFFF6F00),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('MOST POPULAR',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  if (plan.subLabel.isNotEmpty)
                    Text(plan.subLabel,
                        style: TextStyle(
                            color: selected
                                ? primary
                                : (isDark
                                    ? Colors.white54
                                    : Colors.black54),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(plan.price,
                    style: TextStyle(
                        color: selected ? primary : textCol,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text(plan.period,
                    style: TextStyle(
                        color: isDark
                            ? Colors.white38
                            : Colors.black38,
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text link ─────────────────────────────────────────────────────────────────

class _TextLink extends StatelessWidget {
  final String label;
  final bool isDark;
  const _TextLink(this.label, this.isDark);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 11,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _Feature {
  final String title, subtitle;
  final bool hasFree, hasPro;
  const _Feature(this.title, this.subtitle, this.hasFree, this.hasPro);
}

class _Plan {
  final String name, price, period, subLabel;
  final bool isBest;
  const _Plan(
      this.name, this.price, this.period, this.subLabel, this.isBest);
}
