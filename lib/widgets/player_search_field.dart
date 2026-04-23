import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/player_entry.dart';
import '../core/search/player_search_service.dart';
import '../design/colors.dart';

/// Drop-in player search field with a floating dropdown powered by OverlayPortal.
///
/// Works correctly inside modal bottom sheets, drawers, and nested navigators.
/// Search by full name (any word order), 6-digit player ID, phone, or email.
class PlayerSearchField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(PlayerEntry entry) onSelected;
  final String hint;
  final bool showManualOption;
  final int maxResults;

  const PlayerSearchField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.hint = 'Search by name, ID or email',
    this.showManualOption = true,
    this.maxResults = 8,
  });

  @override
  State<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends State<PlayerSearchField> {
  // OverlayPortal is Flutter's correct API for dropdowns in any widget context.
  // Unlike raw Overlay.of(), it stays linked to the widget tree (Provider/Theme
  // available) and works correctly inside modal bottom sheets.
  final _overlayCtrl = OverlayPortalController();
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();

  List<PlayerSearchResult> _results = [];
  bool _loading = false;
  bool _confirmed = false;
  bool _ignoreNextChange = false; // set before programmatic text write
  Timer? _debounce;
  int _gen = 0;

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
    // OverlayPortal cleans itself up; just hide it
    if (_overlayCtrl.isShowing) _overlayCtrl.hide();
    super.dispose();
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onControllerChange() {
    if (widget.controller.text.isEmpty && _confirmed) {
      setState(() {
        _confirmed = false;
        _results = [];
      });
      _hideDropdown();
    }
  }

  void _onFocusChange() {
    // Do NOT hide the dropdown when focus is lost (e.g. keyboard "Done" pressed).
    // The dropdown should only be dismissed via:
    //   • _select() — user picked a result
    //   • onTapOutside — user tapped outside the field + dropdown area
    //   • _onChanged() with empty text
  }

  void _onChanged(String value) {
    // Ignore the onChange that Flutter fires when _select sets controller.text
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }
    _debounce?.cancel();
    setState(() {
      _confirmed = false;
    });

    final q = value.trim();
    if (q.isEmpty) {
      _gen++;
      setState(() {
        _results = [];
        _loading = false;
      });
      _hideDropdown();
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 200), () => _startSearch(q));
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<void> _startSearch(String q) async {
    final gen = ++_gen;

    await PlayerSearchService().searchStreaming(
      q,
      includeManual: widget.showManualOption,
      onResults: (results) {
        if (!mounted || gen != _gen) return;
        final capped = results.take(widget.maxResults).toList();
        setState(() {
          _results = capped;
          _loading = false;
        });
        if (capped.isNotEmpty) {
          _showDropdown();
        } else {
          _hideDropdown();
        }
      },
    );

    if (mounted && gen == _gen) setState(() => _loading = false);
  }

  // ── Dropdown show / hide ───────────────────────────────────────────────────

  void _showDropdown() {
    if (!_overlayCtrl.isShowing) {
      _overlayCtrl.show();
    } else {
      // Already showing — just mark dirty so it rebuilds with new _results
      setState(() {});
    }
  }

  void _hideDropdown() {
    if (mounted && _overlayCtrl.isShowing) _overlayCtrl.hide();
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _select(PlayerSearchResult result) {
    final entry = result.entry;
    // Guard so Flutter's programmatic-text onChange callback doesn't re-trigger search
    _ignoreNextChange = true;
    // Show "Full Name (ID)" in the field when the player has an ID
    widget.controller.text = entry.numericId != null
        ? '${entry.displayName} (${entry.numericId})'
        : entry.displayName;
    setState(() {
      _results = [];
      _confirmed = true;
    });
    _hideDropdown();
    widget.onSelected(entry);
  }

  // ── Dropdown content (rendered inside OverlayPortal) ──────────────────────

  Widget _buildDropdown() {
    final query = widget.controller.text.trim();
    final fieldWidth = _layerLink.leaderSize?.width ?? 300.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = fieldWidth.clamp(260.0, screenWidth - 48.0).toDouble();

    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _results.isEmpty
                  // ── Loading indicator ─────────────────────────────────
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Searching...',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  // ── Results list ──────────────────────────────────────
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return _ResultTile(
                          result: r,
                          query: query,
                          isFirst: i == 0,
                          isLast: i == _results.length - 1,
                          onTap: () => _select(r),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayCtrl,
        overlayChildBuilder: (_) => _buildDropdown(),
        child: TapRegion(
          onTapOutside: (_) {
            _focusNode.unfocus();
            // Short delay so a tap on a result row fires before we hide
            Future.delayed(const Duration(milliseconds: 200), _hideDropdown);
          },
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(
                Icons.person_search_outlined,
                color: Colors.white38,
                size: 18,
              ),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : _confirmed
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    )
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
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Result tile ───────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final PlayerSearchResult result;
  final String query;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.query,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    final isManual = !entry.isRegistered;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isFirst ? 12 : 0),
        bottom: Radius.circular(isLast ? 12 : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Avatar / add-new icon ──────────────────────────────────
            isManual
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                    backgroundImage: entry.imageUrl != null
                        ? NetworkImage(entry.imageUrl!)
                        : null,
                    child: entry.imageUrl == null
                        ? Text(
                            entry.displayName.isNotEmpty
                                ? entry.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),

            const SizedBox(width: 10),

            // ── Name · Player ID · subtitle ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Row 1: full name + #ID badge ────────────────────
                  isManual
                      ? RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13),
                            children: [
                              const TextSpan(
                                text: 'Add  ',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: '"${entry.displayName}"',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(
                                text: '  as new player',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: _HighlightText(
                                text: entry.displayName,
                                query: query,
                              ),
                            ),
                            if (entry.numericId != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${entry.numericId}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ],
              ),
            ),

            // ── Chevron / add icon ─────────────────────────────────────
            Icon(
              isManual ? Icons.add_circle_outline : Icons.chevron_right_rounded,
              color: isManual
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : Colors.white24,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Highlighted name text ─────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    if (query.isEmpty) {
      return Text(
        text,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx = lowerText.indexOf(lowerQuery);

    if (idx < 0) {
      return Text(
        text,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          if (idx > 0)
            TextSpan(
              text: text.substring(0, idx),
              style: const TextStyle(color: Colors.white70),
            ),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(
              text: text.substring(idx + query.length),
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
