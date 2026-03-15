import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/user_profile.dart';
import '../design/colors.dart';
import '../services/user_service.dart';

/// A text field that live-searches registered players by name, 6-digit ID,
/// phone number, or email.  Results float in an [Overlay] so they are always
/// visible regardless of the parent scroll context (bottom sheets, ListViews…).
class PlayerSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(UserProfile profile)? onProfileSelected;

  const PlayerSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search by name or player ID',
    this.onProfileSelected,
  });

  @override
  State<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends State<PlayerSearchField> {
  List<UserProfile> _results   = [];
  bool              _searching = false;
  bool              _confirmed = false;
  Timer?            _debounce;

  OverlayEntry? _overlay;
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onControllerChange() {
    if (widget.controller.text.isEmpty && _confirmed) {
      setState(() { _confirmed = false; _results = []; });
      _removeOverlay();
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Small delay so tapping a result fires before overlay is removed
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() { _confirmed = false; });

    final q = value.trim();
    if (q.isEmpty) {
      setState(() { _results = []; _searching = false; });
      _removeOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _searching = true);

      List<UserProfile> results = [];
      final svc = UserService();

      try {
        if (q.contains('@')) {
          final p = await svc.searchByEmail(q);
          results = p != null ? [p] : [];
        } else {
          final digits     = q.replaceAll(RegExp(r'\D'), '');
          final isAllDigits = digits == q;

          if (isAllDigits && q.length == 6) {
            final asNum = int.tryParse(q);
            if (asNum != null) {
              final p = await svc.searchByNumericId(asNum);
              results = p != null ? [p] : [];
            }
          } else if (isAllDigits && q.length >= 10) {
            final p = await svc.searchByPhone(q);
            results = p != null ? [p] : [];
          } else {
            results = await svc.searchByName(q);
          }
        }
      } catch (_) {
        results = [];
      }

      if (!mounted) return;
      setState(() { _results = results; _searching = false; });
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _select(UserProfile p) {
    widget.controller.text = p.name;
    setState(() { _results = []; _confirmed = true; });
    _removeOverlay();
    widget.onProfileSelected?.call(p);
  }

  // ── Overlay management ──────────────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (_) => _buildDropdown());
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildDropdown() {
    return Positioned(
      width: 0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52), // below the text field (~48px + gap)
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Colors.white10),
              itemBuilder: (_, i) {
                final p = _results[i];
                return InkWell(
                  onTap: () => _select(p),
                  borderRadius: BorderRadius.vertical(
                    top:    Radius.circular(i == 0 ? 10 : 0),
                    bottom: Radius.circular(
                        i == _results.length - 1 ? 10 : 0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          backgroundImage: p.imageUrl != null
                              ? NetworkImage(p.imageUrl!)
                              : null,
                          child: p.imageUrl == null
                              ? Text(
                                  p.name.isNotEmpty
                                      ? p.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (p.numericId != null)
                                Text(
                                  '#${p.numericId}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.add_circle_outline,
                            color: Colors.white24, size: 18),
                      ],
                    ),
                  ),
                );
              },
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
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle:
              const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.person_search_outlined,
              color: Colors.white38, size: 18),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : _confirmed
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 18)
                  : null,
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
