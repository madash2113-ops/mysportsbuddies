import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../register/register_game_screen.dart';

// ── Full sports list with emoji ───────────────────────────────────────────────
const _kAllSports = [
  ('Cricket',      '🏏'),
  ('Football',     '⚽'),
  ('Basketball',   '🏀'),
  ('Badminton',    '🏸'),
  ('Tennis',       '🎾'),
  ('Volleyball',   '🏐'),
  ('Table Tennis', '🏓'),
  ('Hockey',       '🏑'),
  ('Boxing',       '🥊'),
  ('Kabaddi',      '🤼'),
  ('Throwball',    '🎯'),
  ('Handball',     '🤾'),
  ('Swimming',     '🏊'),
  ('Cycling',      '🚴'),
  ('Rugby',        '🏉'),
  ('Golf',         '⛳'),
  ('Squash',       '🎾'),
  ('Wrestling',    '🤼'),
  ('Athletics',    '🏃'),
  ('Archery',      '🏹'),
];

/// Sport-picker screen. Selecting any sport navigates directly to
/// [RegisterGameScreen] — the intermediate "Host a X Game" view has been removed.
class HostAGameScreen extends StatefulWidget {
  const HostAGameScreen({super.key});

  @override
  State<HostAGameScreen> createState() => _HostAGameScreenState();
}

class _HostAGameScreenState extends State<HostAGameScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<(String, String)> get _filtered {
    if (_query.isEmpty) return _kAllSports.toList();
    final q = _query.toLowerCase();
    return _kAllSports.where((s) => s.$1.toLowerCase().contains(q)).toList();
  }

  void _onSportTap(String sport) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RegisterGameScreen(sport: sport)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColorsLight.primary;
    final cardBg  = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColorsLight.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.background : AppColorsLight.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Host a Game',
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              fontSize: 17,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: textCol, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search sport…',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: Icon(Icons.search,
                    color: isDark ? Colors.white38 : Colors.black38),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.close,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 18),
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Label ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              filtered.isEmpty ? 'No results' : 'Select a Sport',
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),

          // ── Sport list ──────────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              itemBuilder: (context, i) {
                final (name, emoji) = filtered[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  title: Text(name,
                      style: TextStyle(
                          color: textCol,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? Colors.white24 : Colors.black26),
                  onTap: () => _onSportTap(name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
