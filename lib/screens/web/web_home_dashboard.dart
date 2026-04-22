import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/game_listing.dart';
import '../../services/game_listing_service.dart';
import '../../services/user_service.dart';
import '../venues/venues_list_screen.dart';
import 'web_avatar.dart';
import 'web_game_detail_dialog.dart';

// ── Design tokens ───────────────────────────────────────────────────────────────
const _bg = Color(0xFF080808);
const _card = Color(0xFF111111);
const _panel = Color(0xFF0E0E0E);
const _tx = Color(0xFFF2F2F2);
const _m1 = Color(0xFF888888);
const _m2 = Color(0xFF3A3A3A);
const _red = Color(0xFFDE313B);
const _border = Color(0xFF1C1C1C);
const _green = Color(0xFF30D158);
const _orange = Color(0xFFFF9F0A);

TextStyle _t({
  double size = 13,
  FontWeight weight = FontWeight.w400,
  Color color = _tx,
  double height = 1.5,
}) => GoogleFonts.inter(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

// ── Sport helpers ───────────────────────────────────────────────────────────────
const _kSports = [
  'Cricket',
  'Football',
  'Basketball',
  'Badminton',
  'Tennis',
  'Volleyball',
  'Hockey',
  'Kabaddi',
  'Boxing',
  'Table Tennis',
  'Throwball',
  'Handball',
  'Swimming',
  'Rugby',
  'Golf',
  'Athletics',
  'Cycling',
  'Archery',
  'Squash',
];

IconData _sportIcon(String sport) {
  const icons = {
    'Cricket': Icons.sports_cricket_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Basketball': Icons.sports_basketball_rounded,
    'Badminton': Icons.sports_tennis_rounded,
    'Tennis': Icons.sports_tennis_rounded,
    'Volleyball': Icons.sports_volleyball_rounded,
    'Hockey': Icons.sports_hockey_rounded,
    'Kabaddi': Icons.sports_kabaddi_rounded,
    'Boxing': Icons.sports_mma_rounded,
    'Table Tennis': Icons.sports_tennis_rounded,
    'Throwball': Icons.sports_handball_rounded,
    'Handball': Icons.sports_handball_rounded,
    'Swimming': Icons.pool_rounded,
    'Rugby': Icons.sports_rugby_rounded,
    'Golf': Icons.sports_golf_rounded,
    'Athletics': Icons.directions_run_rounded,
    'Cycling': Icons.directions_bike_rounded,
    'Archery': Icons.gps_fixed_rounded,
    'Squash': Icons.sports_tennis_rounded,
  };
  return icons[sport] ?? Icons.sports_rounded;
}

(List<Color>, Color) _sportTheme(String sport) {
  const t = {
    'Cricket': ([Color(0xFF0D2414), Color(0xFF060E09)], Color(0xFF4CAF50)),
    'Football': ([Color(0xFF0D1830), Color(0xFF06090F)], Color(0xFF42A5F5)),
    'Basketball': ([Color(0xFF2A1200), Color(0xFF100700)], Color(0xFFFF9800)),
    'Badminton': ([Color(0xFF061A30), Color(0xFF020A14)], Color(0xFF29B6F6)),
    'Tennis': ([Color(0xFF1A2600), Color(0xFF0A1200)], Color(0xFFCDDC39)),
    'Volleyball': ([Color(0xFF12062A), Color(0xFF080310)], Color(0xFF7E57C2)),
    'Hockey': ([Color(0xFF2A0E00), Color(0xFF100600)], Color(0xFFFF7043)),
    'Kabaddi': ([Color(0xFF28061C), Color(0xFF100309)], Color(0xFFEC407A)),
    'Boxing': ([Color(0xFF2A0606), Color(0xFF100303)], Color(0xFFEF5350)),
    'Table Tennis': ([Color(0xFF041E2E), Color(0xFF020C14)], Color(0xFF26C6DA)),
  };
  return t[sport] ??
      const ([Color(0xFF141420), Color(0xFF080810)], Color(0xFF888888));
}

String _fmtDate(DateTime dt) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
}

String _fmtTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  return '$h:$min ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

// ── Root widget ─────────────────────────────────────────────────────────────────
class WebHomeDashboard extends StatefulWidget {
  const WebHomeDashboard({super.key});

  @override
  State<WebHomeDashboard> createState() => _WebHomeDashboardState();
}

class _WebHomeDashboardState extends State<WebHomeDashboard> {
  String? _sport;
  int _mainTab = 0; // 0=Sports 1=Venues

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          _TopTabSwitch(
            selected: _mainTab,
            onSelect: (i) => setState(() => _mainTab = i),
          ),
          Expanded(
            child: _mainTab == 0
                ? _SportsLayout(
                    sport: _sport,
                    onSportChange: (s) => setState(() => _sport = s),
                  )
                : const VenuesListScreen(),
          ),
        ],
      ),
    );
  }
}

// ── Sports | Venues tab ─────────────────────────────────────────────────────────
class _TopTabSwitch extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _TopTabSwitch({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TopTab(
            label: 'Sports',
            active: selected == 0,
            onTap: () => onSelect(0),
          ),
          Container(
            width: 1,
            height: 18,
            color: _border,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _TopTab(
            label: 'Venues',
            active: selected == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TopTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: _t(
                size: 14,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _tx : _m1,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: active ? 32 : 0,
              decoration: BoxDecoration(
                color: _red,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sports layout ───────────────────────────────────────────────────────────────
class _SportsLayout extends StatefulWidget {
  final String? sport;
  final ValueChanged<String?> onSportChange;
  const _SportsLayout({required this.sport, required this.onSportChange});

  @override
  State<_SportsLayout> createState() => _SportsLayoutState();
}

class _SportsLayoutState extends State<_SportsLayout> {
  bool _dropdownOpen = false;
  String _query = '';

  void _selectSport(String? sport) {
    widget.onSportChange(sport);
    setState(() {
      _dropdownOpen = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              const _DashboardGreetingBar(),
              Expanded(
                child: Stack(
                  children: [
                    ListenableBuilder(
                      listenable: GameListingService(),
                      builder: (context, _) {
                        final all = GameListingService().openGames;
                        final filtered = widget.sport == null
                            ? all
                            : all
                                  .where((g) => g.sport == widget.sport)
                                  .toList();
                        final sorted = [...filtered]
                          ..sort(
                            (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
                          );
                        return _NearbyGamesContent(
                          games: sorted,
                          sport: widget.sport,
                        );
                      },
                    ),
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: _SportDropdown(
                        selected: widget.sport,
                        open: _dropdownOpen,
                        query: _query,
                        onToggle: () =>
                            setState(() => _dropdownOpen = !_dropdownOpen),
                        onQueryChanged: (value) =>
                            setState(() => _query = value),
                        onSelect: _selectSport,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(width: .8, color: _border),
        _RightPanel(sport: widget.sport),
      ],
    );
  }
}

class _DashboardGreetingBar extends StatelessWidget {
  const _DashboardGreetingBar();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserService>().profile;
    final controller = context.watch<ProfileController>();
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : 'Player';
    final imageUrl = controller.networkImageUrl ?? profile?.imageUrl;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: .8)),
      ),
      child: Row(
        children: [
          WebAvatar(
            imageUrl: imageUrl,
            displayName: name,
            size: 42,
            backgroundColor: _red,
            textColor: Colors.white,
            borderColor: Colors.white.withValues(alpha: .12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(size: 15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.location.isNotEmpty == true
                      ? profile!.location
                      : 'Find nearby players, games, and venues',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(size: 12, color: _m1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _RedBtn(
            icon: Icons.add_rounded,
            label: 'Create Game',
            onTap: () => _openCreateGameDialog(context),
          ),
        ],
      ),
    );
  }
}

Future<void> _openCreateGameDialog(BuildContext context) async {
  final created = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .68),
    builder: (_) => const _WebCreateGameDialog(),
  );
  if (created == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Game created and listed under Nearby Games'),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _WebCreateGameDialog extends StatefulWidget {
  const _WebCreateGameDialog();

  @override
  State<_WebCreateGameDialog> createState() => _WebCreateGameDialogState();
}

class _WebCreateGameDialogState extends State<_WebCreateGameDialog> {
  final _venueCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _playersCtrl = TextEditingController(text: '10');
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _sportSearchCtrl = TextEditingController();

  String _sport = 'Cricket';
  String _sportQuery = '';
  bool _allSportsOpen = false;
  DateTime? _date;
  TimeOfDay? _time;
  bool _splitCost = false;
  bool _saving = false;

  @override
  void dispose() {
    _venueCtrl.dispose();
    _addressCtrl.dispose();
    _playersCtrl.dispose();
    _costCtrl.dispose();
    _noteCtrl.dispose();
    _sportSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _red, surface: _card),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _red, surface: _card),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final players = int.tryParse(_playersCtrl.text.trim()) ?? 0;
    final totalCost = double.tryParse(_costCtrl.text.trim()) ?? 0;
    if (_venueCtrl.text.trim().isEmpty ||
        _date == null ||
        _time == null ||
        players < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add venue, date, time, and at least 2 players'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final scheduledAt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );

    try {
      await GameListingService().createListing(
        sport: _sport,
        scheduledAt: scheduledAt,
        maxPlayers: players,
        splitCost: _splitCost,
        totalCost: totalCost,
        venueName: _venueCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create game: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null ? 'Select date' : _fmtDate(_date!);
    final timeLabel = _time == null ? 'Select time' : _time!.format(context);
    final accent = _sportTheme(_sport).$2;
    final topPicks = _kSports.take(6).toList();
    final filteredSports = _kSports
        .where(
          (sport) => sport.toLowerCase().contains(_sportQuery.toLowerCase()),
        )
        .toList();

    return Dialog(
      backgroundColor: const Color(0xFF101010),
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _border, width: .8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_sportIcon(_sport), color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Game',
                          style: _t(size: 18, weight: FontWeight.w900),
                        ),
                        Text(
                          'List a game for players nearby',
                          style: _t(size: 12, color: _m1),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _m1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sport',
                      style: _t(size: 11, color: _red, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Top Picks',
                      style: _t(size: 12, color: _m1, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sport in topPicks)
                          _SportChoiceChip(
                            sport: sport,
                            selected: sport == _sport,
                            onTap: () => setState(() {
                              _sport = sport;
                              _allSportsOpen = false;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AllSportsDropdown(
                      selected: _sport,
                      open: _allSportsOpen,
                      queryController: _sportSearchCtrl,
                      filteredSports: filteredSports,
                      onToggle: () =>
                          setState(() => _allSportsOpen = !_allSportsOpen),
                      onSearchChanged: (value) =>
                          setState(() => _sportQuery = value),
                      onSelect: (sport) => setState(() {
                        _sport = sport;
                        _allSportsOpen = false;
                        _sportQuery = '';
                        _sportSearchCtrl.clear();
                      }),
                    ),
                    const SizedBox(height: 22),
                    _WebField(
                      controller: _venueCtrl,
                      label: 'Venue / Ground',
                      hint: 'Ground name, stadium, or court',
                      icon: Icons.stadium_outlined,
                    ),
                    const SizedBox(height: 14),
                    _WebField(
                      controller: _addressCtrl,
                      label: 'Address',
                      hint: 'Street, area, city',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerBox(
                            label: 'Date',
                            value: dateLabel,
                            icon: Icons.calendar_today_outlined,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerBox(
                            label: 'Time',
                            value: timeLabel,
                            icon: Icons.access_time_rounded,
                            onTap: _pickTime,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WebField(
                            controller: _playersCtrl,
                            label: 'Max Players',
                            hint: '10',
                            icon: Icons.groups_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            value: _splitCost,
                            onChanged: (value) =>
                                setState(() => _splitCost = value),
                            activeThumbColor: _red,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Split venue cost',
                              style: _t(size: 13, weight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'Optional total cost for the group',
                              style: _t(size: 11, color: _m1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WebField(
                            controller: _costCtrl,
                            label: 'Total Cost',
                            hint: '0',
                            icon: Icons.payments_outlined,
                            enabled: _splitCost,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _WebField(
                      controller: _noteCtrl,
                      label: 'Notes',
                      hint: 'Skill level, rules, equipment, or anything useful',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border, width: .8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Created games appear in Nearby Games immediately.',
                      style: _t(size: 12, color: _m1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  _RedBtn(
                    icon: Icons.add_rounded,
                    label: _saving ? 'Creating...' : 'Create Game',
                    onTap: _saving ? () {} : _save,
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

class _SportChoiceChip extends StatefulWidget {
  final String sport;
  final bool selected;
  final VoidCallback onTap;
  const _SportChoiceChip({
    required this.sport,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SportChoiceChip> createState() => _SportChoiceChipState();
}

class _SportChoiceChipState extends State<_SportChoiceChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = _sportTheme(widget.sport).$2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withValues(alpha: .16)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.white.withValues(alpha: .03)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? accent.withValues(alpha: .45)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_sportIcon(widget.sport), color: accent, size: 16),
              const SizedBox(width: 7),
              Text(
                widget.sport,
                style: _t(
                  size: 12,
                  weight: FontWeight.w700,
                  color: widget.selected ? _tx : _m1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllSportsDropdown extends StatelessWidget {
  final String selected;
  final bool open;
  final TextEditingController queryController;
  final List<String> filteredSports;
  final VoidCallback onToggle;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelect;

  const _AllSportsDropdown({
    required this.selected,
    required this.open,
    required this.queryController,
    required this.filteredSports,
    required this.onToggle,
    required this.onSearchChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _sportTheme(selected).$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .035),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: open
                      ? _red.withValues(alpha: .45)
                      : Colors.white.withValues(alpha: .08),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.grid_view_rounded, color: _red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All Sports',
                      style: _t(size: 13, weight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: accent.withValues(alpha: .28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_sportIcon(selected), color: accent, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          selected,
                          style: _t(
                            size: 11,
                            color: accent,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _m1,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF101010),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _red.withValues(alpha: .25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .42),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: queryController,
                    autofocus: true,
                    onChanged: onSearchChanged,
                    style: _t(size: 13),
                    decoration: InputDecoration(
                      hintText: 'Search all sports...',
                      hintStyle: _t(size: 13, color: _m1),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _m1,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _red),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                Container(height: .8, color: _border),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: filteredSports.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No sports found',
                            style: _t(size: 13, color: _m1),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(10),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 190,
                                mainAxisExtent: 44,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: filteredSports.length,
                          itemBuilder: (context, index) {
                            final sport = filteredSports[index];
                            return _SportDropdownTile(
                              sport: sport,
                              selected: sport == selected,
                              onTap: () => onSelect(sport),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SportDropdownTile extends StatefulWidget {
  final String sport;
  final bool selected;
  final VoidCallback onTap;
  const _SportDropdownTile({
    required this.sport,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SportDropdownTile> createState() => _SportDropdownTileState();
}

class _SportDropdownTileState extends State<_SportDropdownTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = _sportTheme(widget.sport).$2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withValues(alpha: .15)
                : (_hover
                      ? Colors.white.withValues(alpha: .05)
                      : Colors.white.withValues(alpha: .025)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? accent.withValues(alpha: .42)
                  : Colors.white.withValues(alpha: .06),
            ),
          ),
          child: Row(
            children: [
              Icon(_sportIcon(widget.sport), color: accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.sport,
                  overflow: TextOverflow.ellipsis,
                  style: _t(
                    size: 12,
                    color: widget.selected || _hover ? _tx : _m1,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check_rounded, color: _red, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool enabled;
  final int maxLines;

  const _WebField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: _t(size: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _t(size: 13, color: _m2),
            prefixIcon: Icon(icon, color: enabled ? _red : _m2, size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: enabled ? .04 : .025),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _red),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerBox extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _PickerBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PickerBox> createState() => _PickerBoxState();
}

class _PickerBoxState extends State<_PickerBox> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: _t(size: 12, color: _m1, weight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _hover ? .06 : .04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hover
                      ? _red.withValues(alpha: .4)
                      : Colors.white.withValues(alpha: .08),
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: _red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.value,
                      overflow: TextOverflow.ellipsis,
                      style: _t(size: 13, color: _m1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SportDropdown extends StatelessWidget {
  final String? selected;
  final bool open;
  final String query;
  final VoidCallback onToggle;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onSelect;

  const _SportDropdown({
    required this.selected,
    required this.open,
    required this.query,
    required this.onToggle,
    required this.onQueryChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final sports = _kSports
        .where((sport) => sport.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final label = selected ?? 'All Sports';
    final icon = selected == null
        ? Icons.grid_view_rounded
        : _sportIcon(selected!);

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onToggle,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101010),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: open ? _red.withValues(alpha: .55) : _border,
                    ),
                    boxShadow: [
                      if (open)
                        BoxShadow(
                          color: _red.withValues(alpha: .16),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: selected == null ? _m1 : _red,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: _t(size: 13, weight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        open
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _m1,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _red.withValues(alpha: .28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .48),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        autofocus: true,
                        onChanged: onQueryChanged,
                        style: _t(size: 13),
                        decoration: InputDecoration(
                          hintText: 'Search sport...',
                          hintStyle: _t(size: 13, color: _m1),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _m1,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: .04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _red),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    Container(height: .8, color: _border),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        children: [
                          _SportDropdownItem(
                            label: 'All Sports',
                            icon: Icons.grid_view_rounded,
                            active: selected == null,
                            onTap: () => onSelect(null),
                          ),
                          for (final sport in sports)
                            _SportDropdownItem(
                              label: sport,
                              icon: _sportIcon(sport),
                              active: selected == sport,
                              onTap: () => onSelect(sport),
                            ),
                        ],
                      ),
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

class _SportDropdownItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SportDropdownItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SportDropdownItem> createState() => _SportDropdownItemState();
}

class _SportDropdownItemState extends State<_SportDropdownItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active
                ? _red.withValues(alpha: .14)
                : _hover
                ? Colors.white.withValues(alpha: .05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.active || _hover ? _red : _m1,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: _t(
                    size: 13,
                    weight: widget.active ? FontWeight.w800 : FontWeight.w600,
                    color: widget.active || _hover ? _tx : _m1,
                  ),
                ),
              ),
              if (widget.active)
                const Icon(Icons.check_rounded, color: _red, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nearby games main content ───────────────────────────────────────────────────
class _NearbyGamesContent extends StatelessWidget {
  final List<GameListing> games;
  final String? sport;
  const _NearbyGamesContent({required this.games, required this.sport});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        if (games.isEmpty)
          SliverToBoxAdapter(child: _buildEmpty())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 460,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.65,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _GameCard(game: games[i]),
                childCount: games.take(6).length,
              ),
            ),
          ),
        if (games.length > 6)
          SliverToBoxAdapter(child: _buildViewMore(context)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 84, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nearby Games', style: _t(size: 22, weight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            sport != null
                ? '$sport games near you. Join and play.'
                : 'Games near you based on your location and selected sport.',
            style: _t(size: 13, color: _m1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stadium_rounded, color: _m2, size: 48),
            const SizedBox(height: 16),
            Text(
              'No games available right now',
              style: _t(size: 16, weight: FontWeight.w700, color: _m1),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back soon or host a game yourself',
              style: _t(size: 13, color: _m2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMore(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _OutlineBtn(
        label: 'View More Games',
        icon: Icons.arrow_forward_rounded,
        onTap: () {},
      ),
    );
  }
}

// ── Game card ───────────────────────────────────────────────────────────────────
class _GameCard extends StatefulWidget {
  final GameListing game;
  const _GameCard({required this.game});
  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final (colors, accent) = _sportTheme(g.sport);
    final spots = g.spotsLeft;
    final spotColor = spots <= 2
        ? _red
        : spots <= 5
        ? _orange
        : _green;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => openWebGameDetail(context, listing: g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: .45)
                  : accent.withValues(alpha: .18),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .18),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_sportIcon(g.sport), color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    g.sport,
                    style: _t(size: 12, weight: FontWeight.w700, color: accent),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: spotColor.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: spotColor.withValues(alpha: .4),
                      ),
                    ),
                    child: Text(
                      '$spots Spots Left',
                      style: _t(
                        size: 10,
                        weight: FontWeight.w700,
                        color: spotColor,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                g.venueName.isNotEmpty ? g.venueName : 'Open ${g.sport} Game',
                style: _t(size: 15, weight: FontWeight.w800, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Hosted by ${g.organizerName}',
                style: _t(size: 11, color: _m1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  _Meta(
                    icon: Icons.calendar_today_outlined,
                    label: _fmtDate(g.scheduledAt),
                  ),
                  const SizedBox(width: 10),
                  _Meta(
                    icon: Icons.access_time_rounded,
                    label: _fmtTime(g.scheduledAt),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Meta(
                icon: Icons.location_on_outlined,
                label: g.address.isNotEmpty ? g.address : g.venueName,
                maxWidth: 300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final double maxWidth;
  const _Meta({required this.icon, required this.label, this.maxWidth = 120});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: _m1),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(
            label,
            style: _t(size: 11, color: _m1),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Right panel ─────────────────────────────────────────────────────────────────
class _RightPanel extends StatefulWidget {
  final String? sport;
  const _RightPanel({required this.sport});

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  bool _open = false;
  int _tab = 0; // 0=Upcoming 1=MySchedule

  void _onTabTap(int index) {
    setState(() {
      if (_open && _tab == index) {
        _open = false; // same tab again → close
      } else {
        _tab = index;
        _open = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Slide-in content panel ──────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: _open ? 320 : 0,
          child: OverflowBox(
            minWidth: 0,
            maxWidth: 320,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: Container(
                color: _panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: _border, width: .8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _tab == 0 ? 'Upcoming Matches' : 'My Schedule',
                            style: _t(size: 15, weight: FontWeight.w800),
                          ),
                          const Spacer(),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() => _open = false),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _m1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: GameListingService(),
                        builder: (context, _) {
                          final all = GameListingService().openGames;
                          List<GameListing> items = _tab == 1
                              ? GameListingService().myGames
                              : (widget.sport != null
                                    ? all
                                          .where((g) => g.sport == widget.sport)
                                          .toList()
                                    : all);
                          items = [...items]
                            ..sort(
                              (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
                            );

                          if (items.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      color: _m2,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _tab == 0
                                          ? 'No upcoming matches'
                                          : 'No games in your schedule',
                                      style: _t(size: 13, color: _m1),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: items.take(8).length,
                            separatorBuilder: (_, _) =>
                                Container(height: .8, color: _border),
                            itemBuilder: (ctx, i) => _MatchRow(game: items[i]),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: _border, width: .8),
                        ),
                      ),
                      child: _OutlineBtn(
                        label: 'View All Matches',
                        icon: Icons.arrow_forward_rounded,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Vertical edge tabs (always visible) ────────────────────────────
        Container(
          width: 48,
          decoration: BoxDecoration(
            color: _card,
            border: Border(left: BorderSide(color: _border, width: .8)),
          ),
          child: Column(
            children: [
              _VertTab(
                label: 'Upcoming Matches',
                active: _open && _tab == 0,
                onTap: () => _onTabTap(0),
              ),
              Container(height: .8, color: _border),
              _VertTab(
                label: 'My Schedule',
                active: _open && _tab == 1,
                onTap: () => _onTabTap(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchRow extends StatefulWidget {
  final GameListing game;
  const _MatchRow({required this.game});
  @override
  State<_MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<_MatchRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final (_, accent) = _sportTheme(g.sport);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => openWebGameDetail(context, listing: g),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          color: _hover
              ? Colors.white.withValues(alpha: .03)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: .25)),
                ),
                alignment: Alignment.center,
                child: Icon(_sportIcon(g.sport), color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.venueName.isNotEmpty ? g.venueName : '${g.sport} Game',
                      style: _t(size: 12, weight: FontWeight.w700, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      g.sport,
                      style: _t(
                        size: 11,
                        color: accent,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmtDate(g.scheduledAt),
                    style: _t(size: 10, color: _m1),
                  ),
                  Text(
                    _fmtTime(g.scheduledAt),
                    style: _t(size: 10, color: _m1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VertTab extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _VertTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_VertTab> createState() => _VertTabState();
}

class _VertTabState extends State<_VertTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: active
                ? _red.withValues(alpha: .14)
                : (_hover
                      ? Colors.white.withValues(alpha: .04)
                      : Colors.transparent),
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    widget.label,
                    style: _t(
                      size: 13,
                      weight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? _red : (_hover ? _tx : _m1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared buttons ──────────────────────────────────────────────────────────────
class _RedBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _RedBtn({required this.label, this.icon, required this.onTap});

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
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFC82030) : _red,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _hover ? .4 : .2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: _t(
                  size: 13,
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

class _OutlineBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, this.icon, required this.onTap});
  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: _hover
                ? Colors.white.withValues(alpha: .05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover ? _m1.withValues(alpha: .35) : _border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: _t(
                  size: 13,
                  weight: FontWeight.w600,
                  color: _hover ? _tx : _m1,
                ),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 6),
                Icon(widget.icon, size: 14, color: _hover ? _tx : _m1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
