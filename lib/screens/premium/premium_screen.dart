import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/user_profile.dart';
import '../../design/colors.dart';
import '../../services/user_service.dart';

/// Which persona tab to open the upgrade screen on.
enum PremiumContext { player, organizer }

class PremiumScreen extends StatefulWidget {
  /// Optional single reason shown as a focused banner at the top of the paywall.
  /// Keep it to one short sentence: "Unlock larger tournaments", etc.
  final String? reason;

  /// Override which role tab is shown first. Defaults to the user's own role.
  final PremiumContext? context;

  const PremiumScreen({super.key, this.reason, this.context});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlan = 1; // 0=Monthly, 1=Annual, 2=Lifetime
  late PremiumContext _viewRole;

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
        case 'DE': case 'FR': case 'IT': case 'ES':
        case 'NL': case 'AT': case 'BE': case 'PT':
        case 'FI': case 'GR': return 'EUR';
        case 'AE': case 'SA': case 'QA': case 'KW': return 'AED';
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

  static List<_Feature> _playerFeatures() => const [
    _Feature('Priority Game Alerts',  'First notified about nearby games & open slots',    false, true),
    _Feature('Advanced Stats',        'Batting avg, bowling economy, win rate tracking',    false, true),
    _Feature('PDF Match Reports',     'Export full scorecards as formatted PDFs',           false, true),
    _Feature('Boosted Visibility',    'Your hosted games shown higher in listings',         false, true),
    _Feature('Premium Badge',         'Red \u26A1 badge visible on your profile',           false, true),
    _Feature('Early Access',          'Register in tournaments before general public',      false, true),
  ];

  static List<_Feature> _organizerFeatures() => const [
    _Feature('Tournament Size',    'Max teams you can host',              true,  true,  freeLabel: '4 teams',    proLabel: 'Unlimited'),
    _Feature('Live Scoreboards',   'Simultaneous scoreboard flows',       true,  true,  freeLabel: '1',          proLabel: 'Unlimited'),
    _Feature('AI Banner',          'Auto-generate a tournament banner',   false, true),
    _Feature('Advanced Reports',   'Export bracket, standings & stats',   false, true),
    _Feature('PDF Scorecards',     'Full cricket match reports as PDF',   false, true),
  ];

  List<_Feature> get _features {
    switch (_viewRole) {
      case PremiumContext.organizer: return _organizerFeatures();
      case PremiumContext.player:    return _playerFeatures();
    }
  }

  late final String _currency = _detectCurrency();

  @override
  void initState() {
    super.initState();
    final profile = UserService().profile;
    _viewRole = widget.context ??
        (profile?.role == UserRole.organizer
            ? PremiumContext.organizer
            : PremiumContext.player);
  }
  List<String> get _planPrices => _prices[_currency] ?? _prices['USD']!;

  List<_Plan> get _plans => [
        _Plan('Monthly',  _planPrices[0], '/month',   '',          false),
        _Plan('Annual',   _planPrices[1], '/year',    'Save 58%',  true),
        _Plan('Lifetime', _planPrices[2], 'one-time', 'Best deal', false),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserService(),
      builder: (context, _) {
        final profile = UserService().profile;

        // ── Already premium → show membership card ──────────────────────
        if (profile?.isPremium == true) {
          return _MembershipScreen(profile: profile!);
        }

        // ── Not premium → show upgrade screen ───────────────────────────
        final isDark  = Theme.of(context).brightness == Brightness.dark;
        final bg      = isDark ? const Color(0xFF0A0A0A) : AppColorsLight.background;
        final primary = isDark ? AppColors.primary : AppColorsLight.primary;
        final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final plans   = _plans;
        final canPop  = Navigator.canPop(context);

        return Scaffold(
          backgroundColor: bg,
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      _HeroBanner(isDark: isDark, viewRole: _viewRole),
                      if (canPop)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 4,
                          left: 4,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // ── Reason banner (focused single-reason paywall) ──────────
              if (widget.reason != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: primary.withValues(alpha: 0.30)),
                      ),
                      child: Row(children: [
                        Icon(Icons.lock_open_rounded,
                            color: primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(widget.reason!,
                              style: TextStyle(
                                  color: textCol,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4)),
                        ),
                      ]),
                    ),
                  ),
                ),
              // ── Role picker ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(children: [
                    _RoleChip(
                      label: 'Player',
                      selected: _viewRole == PremiumContext.player,
                      primary: primary,
                      isDark: isDark,
                      onTap: () => setState(
                          () => _viewRole = PremiumContext.player),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(
                      label: 'Organizer',
                      selected: _viewRole == PremiumContext.organizer,
                      primary: primary,
                      isDark: isDark,
                      onTap: () => setState(
                          () => _viewRole = PremiumContext.organizer),
                    ),
                  ]),
                ),
              ),
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
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// "Your Premium" screen — shown when already premium
// ══════════════════════════════════════════════════════════════════════════════

class _MembershipScreen extends StatelessWidget {
  final dynamic profile; // UserProfile
  const _MembershipScreen({required this.profile});

  static const _perks = [
    ('PDF Match Reports',        'Export full scorecards as formatted PDFs',    Icons.picture_as_pdf_outlined),
    ('Advanced Statistics',      'Batting avg, bowling economy, strike rates',  Icons.bar_chart_outlined),
    ('Unlimited Scoreboards',    'Create as many live scoreboards as you need', Icons.scoreboard_outlined),
    ('Premium Badge',            'Red ⚡ badge on your profile',                Icons.verified_outlined),
    ('Priority Alerts',          'First to know about nearby games',            Icons.notifications_active_outlined),
    ('Tournament Early Access',  'Register before general availability',        Icons.emoji_events_outlined),
    ('Live Streaming',           'Stream & watch sports live (coming soon)',    Icons.wifi_tethering),
  ];

  @override
  Widget build(BuildContext context) {
    final canPop   = Navigator.canPop(context);
    final memberId = profile.membershipId as String? ?? '—';
    final name     = (profile.name as String).isNotEmpty
        ? profile.name as String : 'Member';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        automaticallyImplyLeading: canPop,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your Premium',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Subscription card ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(left: 16, top: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Subscription',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(children: [
                    const Text('\uD83C\uDFC6',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    const Text('MySportsBuddies',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text('Premium',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13)),
                ),
                if (memberId != '—')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                    child: Text(memberId,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _ManageSubscriptionScreen(profile: profile),
                        ),
                      ),
                      child: const Text('Manage',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Snapshot of your benefits ─────────────────────────────────────
          const Text('Snapshot of your benefits',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _perks.asMap().entries.map((e) {
                final label = e.value.$1;
                final isLast = e.key == _perks.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      const Icon(Icons.check,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, color: Colors.white10, indent: 50),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Manage Subscription screen
// ══════════════════════════════════════════════════════════════════════════════

class _ManageSubscriptionScreen extends StatelessWidget {
  final dynamic profile;
  const _ManageSubscriptionScreen({required this.profile});


  @override
  Widget build(BuildContext context) {
    final memberId = profile.membershipId as String? ?? '—';
    final name     = (profile.name as String).isNotEmpty
        ? profile.name as String : 'Member';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Manage subscription',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          // ── Plan card ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('\uD83C\uDFC6',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  const Text('MySportsBuddies',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 6),
                const Text('Premium',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('1 Premium account · $name',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Membership ID ──────────────────────────────────────────────────
          if (memberId != '—') ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Membership ID',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(memberId,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  const SizedBox(height: 6),
                  const Text(
                      'Present this ID to claim premium benefits at events.',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Payment info ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text(
                    'Your premium access was granted by your administrator.',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13, height: 1.5)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.primary.withAlpha(80)),
                    ),
                    child: const Text('Active',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Available plans & add-ons ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available plans and add-ons',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                // Explore all benefits
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _AllBenefitsScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('Explore all benefits',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('New',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            const Text(
                                'See everything included in your plan',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.white38, size: 16),
                    ]),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 8),
                // Explore plans
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Explore plans',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text('Affordable options for any situation.',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Cancel subscription ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _CancelSubscriptionScreen(profile: profile),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  const Expanded(
                    child: Text('Cancel Subscription',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white38, size: 16),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// All Benefits screen
// ══════════════════════════════════════════════════════════════════════════════

class _AllBenefitsScreen extends StatelessWidget {
  const _AllBenefitsScreen();

  static const _benefits = [
    ('PDF Match Reports',        'Export full scorecards as formatted PDFs',     Icons.picture_as_pdf_outlined),
    ('Advanced Statistics',      'Batting avg, bowling economy, strike rates',   Icons.bar_chart_outlined),
    ('Unlimited Scoreboards',    'Create as many live scoreboards as you need',  Icons.scoreboard_outlined),
    ('Premium Badge on Profile', 'Red ⚡ badge visible to all players',          Icons.verified_outlined),
    ('Priority Game Alerts',     'First to know about nearby games',             Icons.notifications_active_outlined),
    ('Tournament Early Access',  'Register before general availability',         Icons.emoji_events_outlined),
    ('Live Streaming',           'Stream & watch sports live (coming soon)',      Icons.wifi_tethering),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Your benefits',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _benefits.asMap().entries.map((e) {
                final (title, subtitle, icon) = e.value;
                final isLast = e.key == _benefits.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 20),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, color: Colors.white10, indent: 74),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Cancel Subscription confirmation screen
// ══════════════════════════════════════════════════════════════════════════════

class _CancelSubscriptionScreen extends StatefulWidget {
  final dynamic profile;
  const _CancelSubscriptionScreen({required this.profile});

  @override
  State<_CancelSubscriptionScreen> createState() =>
      _CancelSubscriptionScreenState();
}

class _CancelSubscriptionScreenState
    extends State<_CancelSubscriptionScreen> {
  bool _cancelling = false;

  Future<void> _confirmCancel() async {
    setState(() => _cancelling = true);
    try {
      await UserService().cancelPremium();
      if (!mounted) return;
      // Pop all the way back to the screen that opened Premium
      Navigator.of(context).popUntil((route) {
        return route.isFirst ||
            route.settings.name == '/home' ||
            route.settings.name == '/premium';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your premium subscription has been cancelled.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Cancel subscription',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined,
                  color: Colors.red, size: 32),
            ),
            const SizedBox(height: 20),
            const Text('Are you sure you want to cancel?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'If you cancel, you will lose access to all premium features immediately, including:',
              style: TextStyle(
                  color: Colors.white54, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            _lossItem('PDF Match Reports'),
            _lossItem('Advanced Statistics'),
            _lossItem('Unlimited Scoreboards'),
            _lossItem('Premium Badge'),
            _lossItem('Tournament Early Access'),
            const Spacer(),
            // ── Back to account ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed:
                    _cancelling ? null : () => Navigator.pop(context),
                child: const Text('Keep Premium',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _cancelling ? null : _confirmCancel,
                child: _cancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white38))
                    : const Text('Yes, Cancel Subscription',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _lossItem(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          const Icon(Icons.remove_circle_outline,
              color: Colors.red, size: 16),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14)),
        ]),
      );
}

// ── Role picker chip ──────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected, isDark;
  final Color primary;
  final VoidCallback onTap;
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary
              : (isDark ? const Color(0xFF1C1C1E) : const Color(0x14000000)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? primary
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final bool isDark;
  final PremiumContext viewRole;
  const _HeroBanner({required this.isDark, required this.viewRole});

  @override
  Widget build(BuildContext context) {
    final statusBarH = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
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
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 30, spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5,
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
            const Text('MySportsBuddies',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            const Text('Premium Membership',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
                switch (viewRole) {
                  PremiumContext.organizer => 'Hosting power tools for serious organisers',
                  PremiumContext.player    => 'Unlock the complete sports experience',
                },
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2)),
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

// ── Comparison table ──────────────────────────────────────────────────────────

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
        Text('What You Unlock',
            style: TextStyle(
                color: textCol, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divCol),
          ),
          child: Column(
            children: [
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
              ...features.asMap().entries.map((e) {
                final f = e.value;
                final isLast = e.key == features.length - 1;
                return Container(
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(color: divCol, width: 0.5)),
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
                                    color: subCol, fontSize: 11, height: 1.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: Center(child: _featureCell(
                          f.freeLabel ?? (f.hasFree ? '\u2713' : '\u2717'),
                          active: f.hasFree || f.freeLabel != null,
                          textCol: textCol, subCol: subCol,
                          small: f.freeLabel != null,
                        )),
                      ),
                      SizedBox(
                        width: 60,
                        child: Center(child: _featureCell(
                          f.proLabel ?? (f.hasPro ? '\u2713' : '\u2717'),
                          active: f.hasPro || f.proLabel != null,
                          textCol: primary, subCol: subCol,
                          small: f.proLabel != null,
                        )),
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

  static Widget _featureCell(String text, {
    required bool active,
    required Color textCol,
    required Color subCol,
    required bool small,
  }) =>
      Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? textCol : subCol,
          fontSize: small ? 10 : 16,
          fontWeight: small ? FontWeight.w600 : FontWeight.w700,
        ),
      );
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
        ? (selected ? primary.withValues(alpha: 0.10) : const Color(0xFF111111))
        : (selected ? primary.withValues(alpha: 0.06) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              width: 22, height: 22,
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
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
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
                                : (isDark ? Colors.white54 : Colors.black54),
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
                        color: isDark ? Colors.white38 : Colors.black38,
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

  void _onTap() {
    final urls = {
      'Terms': 'https://mysportsbuddies.com/terms',
      'Privacy': 'https://mysportsbuddies.com/privacy',
      'Restore Purchases': '',
    };
    final url = urls[label];
    if (url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Text(label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 11,
            decoration: TextDecoration.underline,
          )),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _Feature {
  final String title, subtitle;
  final bool hasFree, hasPro;
  /// When set, replaces the ✓/✗ tick in the Free / Pro column with a short label.
  final String? freeLabel, proLabel;
  const _Feature(this.title, this.subtitle, this.hasFree, this.hasPro,
      {this.freeLabel, this.proLabel});
}

class _Plan {
  final String name, price, period, subLabel;
  final bool isBest;
  const _Plan(this.name, this.price, this.period, this.subLabel, this.isBest);
}
