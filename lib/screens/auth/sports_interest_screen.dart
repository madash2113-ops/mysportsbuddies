import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../services/user_service.dart';

class SportsInterestScreen extends StatefulWidget {
  const SportsInterestScreen({super.key});

  @override
  State<SportsInterestScreen> createState() => _SportsInterestScreenState();
}

class _SportsInterestScreenState extends State<SportsInterestScreen> {
  static const _allSports = [
    ('Cricket',     '🏏'),
    ('Football',    '⚽'),
    ('Throwball',   '🎯'),
    ('Handball',    '🤾'),
    ('Badminton',   '🏸'),
    ('Basketball',  '🏀'),
    ('Tennis',      '🎾'),
    ('Volleyball',  '🏐'),
    ('Kabaddi',     '🤼'),
    ('Boxing',      '🥊'),
    ('Hockey',      '🏑'),
    ('Table Tennis','🏓'),
    ('Wrestling',   '🤼'),
    ('Athletics',   '🏃'),
    ('Swimming',    '🏊'),
    ('Cycling',     '🚴'),
    ('Golf',        '⛳'),
    ('Archery',     '🏹'),
    ('Squash',      '🎾'),
    ('Rugby',       '🏉'),
  ];

  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = UserService().profile;
    if (profile != null) {
      await UserService().saveProfile(
        profile.copyWith(favoriteSports: _selected.toList()),
      );
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _skip() => Navigator.pushReplacementNamed(context, '/home');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.sports_outlined,
                        color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'What sports do you love?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Pick your favourites and we'll show them\nat the top of your home screen.",
                    style: TextStyle(
                        color: Colors.white54, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Sports grid ───────────────────────────────────────────────
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size.width > 400 ? 3 : 3,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _allSports.length,
                itemBuilder: (context, i) {
                  final (name, emoji) = _allSports[i];
                  final selected = _selected.contains(name);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selected.remove(name);
                      } else {
                        _selected.add(name);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.white12,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (selected)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Icon(Icons.check_circle,
                                  color: AppColors.primary, size: 14),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Bottom buttons ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  if (_selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_selected.length} sport${_selected.length == 1 ? '' : 's'} selected',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty || _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text("Let's Go!",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Skip for now',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
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
