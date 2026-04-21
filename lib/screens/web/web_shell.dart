import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/user_service.dart';

// ── Landing-page design tokens ─────────────────────────────────────────────
const _bg   = Color(0xFF080808);
const _s1   = Color(0xFF0F0F0F);
const _s2   = Color(0xFF141414);
const _bd   = Color(0xFF1E1E1E);
const _bd2  = Color(0xFF2A2A2A);
const _tx   = Color(0xFFF0F0F0);
const _m1   = Color(0xFF888888);
const _red  = Color(0xFFFB3640);
const _r3   = Color(0x1FFB3640);  // red 12%

// ── Nav items ─────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _navItems = [
  _NavItem(Icons.home_outlined,           Icons.home_rounded,         'Home'),
  _NavItem(Icons.emoji_events_outlined,   Icons.emoji_events,         'Tournaments'),
  _NavItem(Icons.dynamic_feed_outlined,   Icons.dynamic_feed,         'Feed'),
  _NavItem(Icons.scoreboard_outlined,     Icons.scoreboard,           'Scorecard'),
  _NavItem(Icons.person_outline,          Icons.person,               'Profile'),
];

// ── Shell ─────────────────────────────────────────────────────────────────
class WebShell extends StatefulWidget {
  final List<Widget> pages;
  const WebShell({super.key, required this.pages});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
          // vertical divider
          Container(width: 1, color: _bd),
          // content
          Expanded(
            child: IndexedStack(
              index: _index,
              children: widget.pages,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final userSvc = context.watch<UserService>();
    final profile = userSvc.profile;

    return Container(
      width: 220,
      color: _s1,
      child: Column(
        children: [
          // ── Logo ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _red.withValues(alpha: .35), blurRadius: 18)],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏅', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w900,
                        color: _tx, letterSpacing: -.3,
                      ),
                      children: const [
                        TextSpan(text: 'My'),
                        TextSpan(text: 'Sports', style: TextStyle(color: _red)),
                        TextSpan(text: 'Buddies'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item = _navItems[i];
                final active = i == selectedIndex;
                return _SideNavTile(
                  icon: active ? item.activeIcon : item.icon,
                  label: item.label,
                  active: active,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),

          // ── User card ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _s2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bd2),
            ),
            child: Row(
              children: [
                _Avatar(name: profile?.name ?? '?', url: profile?.imageUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile?.name ?? 'Player',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _tx,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profile?.role.name ?? 'player',
                        style: GoogleFonts.inter(fontSize: 11, color: _m1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single nav tile ───────────────────────────────────────────────────────
class _SideNavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SideNavTile({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  State<_SideNavTile> createState() => _SideNavTileState();
}

class _SideNavTileState extends State<_SideNavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? _r3
        : _hover
            ? const Color(0x0DFFFFFF)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: widget.active
                ? Border.all(color: _red.withValues(alpha: .25))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.active ? _red : _m1,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
                  color: widget.active ? _tx : _m1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar helper ─────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _red,
        image: url != null
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white,
              ),
            )
          : null,
    );
  }
}
