import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../design/colors.dart';
import '../design/spacing.dart';

/// Address autocomplete field powered by OpenStreetMap Nominatim.
/// Completely FREE — no API key required.
///
/// Usage:
/// ```dart
/// AddressAutocompleteField(
///   controller: _venueCtrl,
///   label: 'Venue / Ground',
///   hint: 'e.g. Wankhede Stadium, Mumbai',
/// )
/// ```
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.label = 'Venue / Address',
    this.hint = 'Start typing to search...',
    this.autofocus = false,
    this.onSelected,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<_PlaceResult> _results = [];
  bool _loading = false;
  bool _showDropdown = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideDropdown();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    _overlayEntry?.remove();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();
    if (query.length < 3) {
      _hideDropdown();
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'limit': '6',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'MySportsBuddies/1.0',
        'Accept-Language': 'en',
      });

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        setState(() {
          _results = data
              .map((e) => _PlaceResult(
                    displayName: e['display_name'] as String,
                    shortName: _shortName(e),
                  ))
              .toList();
          _loading = false;
        });
        if (_results.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Extracts a short display name from Nominatim response
  String _shortName(dynamic e) {
    final addr = e['address'] as Map<String, dynamic>?;
    if (addr == null) return e['display_name'] as String;

    final parts = <String>[];
    for (final key in [
      'stadium',
      'leisure',
      'sport',
      'amenity',
      'building',
      'road',
      'suburb',
      'city',
      'town',
      'village',
      'state',
      'country'
    ]) {
      final val = addr[key];
      if (val != null && val is String && val.isNotEmpty) {
        parts.add(val);
        if (parts.length >= 3) break;
      }
    }
    return parts.isEmpty ? (e['display_name'] as String) : parts.join(', ');
  }

  void _select(String address) {
    widget.controller.text = address;
    widget.controller.selection =
        TextSelection.collapsed(offset: address.length);
    widget.onSelected?.call(address);
    _hideDropdown();
    _focusNode.unfocus();
  }

  void _showOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showDropdown = true);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _showDropdown = false);
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2235),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return InkWell(
                    onTap: () => _select(r.shortName),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.shortName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                r.displayName,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 16),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 18),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.textMuted, size: 18),
                          onPressed: () {
                            widget.controller.clear();
                            _hideDropdown();
                          },
                        )
                      : null,
            ),
          ),
          if (!_showDropdown)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                '📍 Powered by OpenStreetMap — no API key needed',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceResult {
  final String displayName;
  final String shortName;
  const _PlaceResult({required this.displayName, required this.shortName});
}
