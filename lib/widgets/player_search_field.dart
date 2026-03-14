import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/user_profile.dart';
import '../design/colors.dart';
import '../services/user_service.dart';

/// A text field that live-searches registered players by name or 6-digit ID.
///
/// - Type letters → name-prefix search
/// - Type digits  → numeric ID lookup
/// - Tap a result → fills [controller] with the player's name and fires
///   [onProfileSelected] with the full [UserProfile].
/// - Free-form text (unregistered names) is allowed; [onProfileSelected] just
///   won't fire for those entries.
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
  bool              _confirmed = false; // green check when a profile is linked
  Timer?            _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _debounce?.cancel();
    super.dispose();
  }

  // If controller text is cleared externally, reset state
  void _onControllerChange() {
    if (widget.controller.text.isEmpty && _confirmed) {
      setState(() { _confirmed = false; _results = []; });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() { _confirmed = false; });

    final q = value.trim();
    if (q.isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searching = true);

      List<UserProfile> results;
      final asNum = int.tryParse(q);
      if (asNum != null) {
        final p = await UserService().searchByNumericId(asNum);
        results = p != null ? [p] : [];
      } else {
        results = await UserService().searchByName(q);
      }

      if (!mounted) return;
      setState(() { _results = results; _searching = false; });
    });
  }

  void _select(UserProfile p) {
    widget.controller.text = p.name;
    setState(() { _results = []; _confirmed = true; });
    widget.onProfileSelected?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: _onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.person_search_outlined,
                color: Colors.white38, size: 18),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16, height: 16,
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
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_results.length, (i) {
                final p = _results[i];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
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
                                  Text(p.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (p.numericId != null)
                                    Text('#${p.numericId}',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.add_circle_outline,
                                color: Colors.white24, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (i < _results.length - 1)
                      const Divider(height: 1, color: Colors.white10),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}
