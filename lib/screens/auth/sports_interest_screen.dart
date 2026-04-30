import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../services/tournament_link_service.dart';
import '../../services/user_service.dart';

class SportsInterestScreen extends StatefulWidget {
  const SportsInterestScreen({super.key});

  @override
  State<SportsInterestScreen> createState() => _SportsInterestScreenState();
}

class _SportsInterestScreenState extends State<SportsInterestScreen> {
  static const _allSports = [
    ('Cricket', '🏏'),
    ('Football', '⚽'),
    ('Throwball', '🎯'),
    ('Handball', '🤾'),
    ('Badminton', '🏸'),
    ('Basketball', '🏀'),
    ('Tennis', '🎾'),
    ('Volleyball', '🏐'),
    ('Kabaddi', '🤼'),
    ('Boxing', '🥊'),
    ('Hockey', '🏑'),
    ('Table Tennis', '🏓'),
    ('Wrestling', '🤼'),
    ('Athletics', '🏃'),
    ('Swimming', '🏊'),
    ('Cycling', '🚴'),
    ('Golf', '⛳'),
    ('Archery', '🏹'),
    ('Squash', '🎾'),
    ('Rugby', '🏉'),
  ];

  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = UserService().profile;
    if (profile != null) {
      await UserService().saveProfile(
        profile.copyWith(
          favoriteSports: _selected.toList(),
          sportsIdentityCompleted: true,
        ),
      );
    }
    if (!mounted) return;
    if (TournamentLinkService.openPendingIfAny(context)) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _skip() async {
    final profile = UserService().profile;
    if (profile != null) {
      await UserService().saveProfile(
        profile.copyWith(sportsIdentityCompleted: true),
      );
    }
    if (!mounted) return;
    if (TournamentLinkService.openPendingIfAny(context)) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width >= 1400
        ? 6
        : size.width >= 1100
        ? 5
        : size.width >= 800
        ? 4
        : 3;
    final sidePadding = size.width >= 1100 ? 227.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _AmbientGlow(
              size: 340,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 120,
            right: -100,
            child: _AmbientGlow(
              size: 280,
              color: const Color(0xFFFF7A00).withValues(alpha: 0.12),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(sidePadding, 28, sidePadding, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.24),
                              AppColors.primary.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 28,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_outlined,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Choose Your Sports Identity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Pick your favourites and we'll shape your home experience around the games you care about most.",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _selected.isEmpty
                              ? 'Select at least one sport to personalize your feed'
                              : '${_selected.length} sport${_selected.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                            color: _selected.isEmpty
                                ? Colors.white60
                                : AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: size.width >= 1100 ? 1.2 : 1.05,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
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
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.22),
                                      const Color(0xFF3A0E12),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF1A1A1A),
                                      Color(0xFF161616),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.85)
                                  : Colors.white12,
                              width: selected ? 1.8 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 24,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 14,
                                right: 14,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  opacity: selected ? 1 : 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      emoji,
                                      style: TextStyle(
                                        fontSize: selected ? 34 : 32,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.88,
                                                ),
                                          fontSize: 18,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          letterSpacing: -0.2,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    sidePadding,
                    12,
                    sidePadding,
                    20,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selected.isEmpty || _saving
                              ? null
                              : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Let's Go!",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _skip,
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

class _AmbientGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
