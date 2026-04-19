import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  String _selected = 'player'; // 'player' | 'merchant'
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _pick(String role) {
    if (_selected == role) return;
    _anim.reverse().then((_) {
      setState(() => _selected = role);
      _anim.forward();
    });
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_role', _selected);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ── Role metadata ──────────────────────────────────────────────────────────

  static const _roles = {
    'player': (
      icon: Icons.sports_soccer_rounded,
      label: 'Player',
      title: "I'm a Player",
      subtitle:
          'Find games, join tournaments,\ndiscover sports buddies near you.',
      activeDark: Color(0xFF8B0000),
      activeColor: Color(0xFFCC1F1F),
      activeBg: Color(0xFF1A0000),
      glowColor: Color(0xFFCC1F1F),
    ),
    'merchant': (
      icon: Icons.storefront_rounded,
      label: 'Venue Owner',
      title: "I'm a Venue Owner",
      subtitle:
          'List your ground, court or turf\nand manage bookings easily.',
      activeDark: Color(0xFF1A237E),
      activeColor: Color(0xFF3949AB),
      activeBg: Color(0xFF050D2A),
      glowColor: Color(0xFF3949AB),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final r = _roles[_selected]!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo ──────────────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.activeColor.withValues(alpha: 0.15),
                  border:
                      Border.all(color: r.activeColor.withValues(alpha: 0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: r.glowColor.withValues(alpha: 0.35),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(r.icon, size: 46, color: r.activeColor),
              ),

              const SizedBox(height: 20),

              // ── Brand name ────────────────────────────────────────────────
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'MySports',
                      style: TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: 'Buddies',
                      style: TextStyle(
                          fontSize: 26,
                          color: Color(0xFFCC1F1F),
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              const Text(
                'Choose how you want to continue',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),

              const Spacer(flex: 2),

              // ── Toggle pill ───────────────────────────────────────────────
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _ToggleOption(
                      icon: Icons.sports_soccer_rounded,
                      label: 'Player',
                      selected: _selected == 'player',
                      activeDark: const Color(0xFF8B0000),
                      activeColor: const Color(0xFFCC1F1F),
                      onTap: () => _pick('player'),
                    ),
                    _ToggleOption(
                      icon: Icons.storefront_rounded,
                      label: 'Venue Owner',
                      selected: _selected == 'merchant',
                      activeDark: const Color(0xFF1A237E),
                      activeColor: const Color(0xFF3949AB),
                      onTap: () => _pick('merchant'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Detail card (fades when switching) ────────────────────────
              FadeTransition(
                opacity: _fade,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: r.activeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: r.activeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: r.activeColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(r.icon, color: r.activeColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.subtitle,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Continue button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _selected == 'player'
                          ? [const Color(0xFF8B0000), const Color(0xFFCC1F1F)]
                          : [const Color(0xFF1A237E), const Color(0xFF3949AB)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: r.glowColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _continue,
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              const Text(
                'You can switch roles later from Settings',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single toggle option inside the pill ─────────────────────────────────────

class _ToggleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color activeDark;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeDark,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [activeDark, activeColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 16,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
