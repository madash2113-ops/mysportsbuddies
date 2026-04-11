import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/venue_model.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/venue_service.dart';

// List of common sports
const _kSports = [
  'Cricket', 'Football', 'Basketball', 'Badminton',
  'Tennis', 'Volleyball', 'Table Tennis', 'Swimming',
  'Kabaddi', 'Hockey', 'Boxing', 'Gym',
];

class AddVenueScreen extends StatefulWidget {
  /// Pass an existing venue to edit it; null = create new.
  final VenueModel? existing;
  const AddVenueScreen({super.key, this.existing});

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends State<AddVenueScreen> {
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl     = TextEditingController();
  final _lngCtrl     = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _priceCtrl   = TextEditingController();

  final List<String> _selectedSports = [];
  bool    _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    if (v != null) {
      _nameCtrl.text    = v.name;
      _descCtrl.text    = v.description;
      _addressCtrl.text = v.address;
      _latCtrl.text     = v.lat == 0 ? '' : v.lat.toString();
      _lngCtrl.text     = v.lng == 0 ? '' : v.lng.toString();
      _phoneCtrl.text   = v.phone;
      _emailCtrl.text   = v.email;
      _priceCtrl.text   = v.pricePerHour == 0 ? '' : v.pricePerHour.toStringAsFixed(0);
      _selectedSports.addAll(v.sports);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _descCtrl, _addressCtrl, _latCtrl, _lngCtrl,
      _phoneCtrl, _emailCtrl, _priceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name    = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter the venue name.');
      return;
    }
    if (address.isEmpty) {
      setState(() => _error = 'Please enter the venue address.');
      return;
    }
    if (_selectedSports.isEmpty) {
      setState(() => _error = 'Please select at least one sport.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final lat   = double.tryParse(_latCtrl.text.trim()) ?? 0;
      final lng   = double.tryParse(_lngCtrl.text.trim()) ?? 0;
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name:         name,
          description:  _descCtrl.text.trim(),
          address:      address,
          lat:          lat,
          lng:          lng,
          sports:       List.from(_selectedSports),
          phone:        _phoneCtrl.text.trim(),
          email:        _emailCtrl.text.trim(),
          pricePerHour: price,
        );
        await VenueService().updateVenue(updated);
      } else {
        await VenueService().registerVenue(
          name:         name,
          description:  _descCtrl.text.trim(),
          address:      address,
          lat:          lat,
          lng:          lng,
          sports:       List.from(_selectedSports),
          phone:        _phoneCtrl.text.trim(),
          email:        _emailCtrl.text.trim(),
          pricePerHour: price,
          timings:      {},
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Venue updated successfully!'
              : 'Venue submitted for review!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _error  = 'Failed to save venue. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditing ? 'Edit Venue' : 'Add New Venue',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Basic Info ────────────────────────────────────────────────
            _SectionLabel('Basic Information'),
            const SizedBox(height: 10),
            _Field(controller: _nameCtrl, hint: 'Venue Name *', icon: Icons.store_outlined),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _descCtrl,
              hint: 'Description (optional)',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel('Location'),
            const SizedBox(height: 10),
            _Field(
              controller: _addressCtrl,
              hint: 'Full Address *',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _latCtrl,
                    hint: 'Latitude',
                    icon: Icons.map_outlined,
                    inputType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _lngCtrl,
                    hint: 'Longitude',
                    icon: Icons.map_outlined,
                    inputType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tip: Open Google Maps → long press your venue → copy the coordinates.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel('Sports Available *'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kSports.map((sport) {
                final selected = _selectedSports.contains(sport);
                return FilterChip(
                  label: Text(sport),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedSports.add(sport);
                    } else {
                      _selectedSports.remove(sport);
                    }
                  }),
                  backgroundColor: const Color(0xFF1C1C1E),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : Colors.white24,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel('Contact & Pricing'),
            const SizedBox(height: 10),
            _Field(
              controller: _phoneCtrl,
              hint: 'Phone Number',
              icon: Icons.phone_outlined,
              inputType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _emailCtrl,
              hint: 'Email Address',
              icon: Icons.email_outlined,
              inputType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _priceCtrl,
              hint: 'Price per Hour (₹)',
              icon: Icons.currency_rupee_outlined,
              inputType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),

            // ── Error ────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade400, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            // ── Save button ──────────────────────────────────────────────
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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Submit Venue',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),

            if (!_isEditing) ...[
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Your venue will be reviewed within 24–48 hours.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType inputType;
  final List<TextInputFormatter>? formatters;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.inputType = TextInputType.text,
    this.formatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:      controller,
      keyboardType:    inputType,
      inputFormatters: formatters,
      maxLines:        maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText:   hint,
        hintStyle:  const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 22),
        filled:     true,
        fillColor:  AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
