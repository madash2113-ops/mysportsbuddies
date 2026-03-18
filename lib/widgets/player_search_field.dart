import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/player_entry.dart';
import '../core/search/player_search_service.dart';
import '../design/colors.dart';

/// Drop-in player search field with a floating overlay dropdown.
///
/// Plug into any screen — supply [onSelected] and you're done.
///
/// Behaviour:
///  - Searches by name, 6-digit player ID, phone, or email simultaneously
///  - Results stream progressively (first hit renders immediately)
///  - "Add [name] as new player" always appears at the bottom for name queries
///  - Selecting a registered player fills the field and fires [onSelected]
///    with a full [PlayerEntry]; selecting manual fires it with name-only entry
class PlayerSearchField extends StatefulWidget {
  final TextEditingController controller;

  /// Called when the user selects any result (registered or manual).
  final void Function(PlayerEntry entry) onSelected;

  final String hint;
  final bool   showManualOption; // show "Add new player" row — default true
  final int    maxResults;       // cap on dropdown rows  — default 8

  const PlayerSearchField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.hint             = 'Name, ID, phone or email',
    this.showManualOption = true,
    this.maxResults       = 8,
  });

  @override
  State<PlayerSearchField> createState() => _PlayerSearchFieldState();
}

class _PlayerSearchFieldState extends State<PlayerSearchField> {
  List<PlayerSearchResult> _results  = [];
  bool                     _loading  = false;
  bool                     _confirmed = false;
  Timer?                   _debounce;
  int                      _gen      = 0; // discard stale callbacks

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

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onControllerChange() {
    if (widget.controller.text.isEmpty && _confirmed) {
      setState(() { _confirmed = false; _results = []; });
      _removeOverlay();
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() { _confirmed = false; });

    final q = value.trim();
    if (q.isEmpty) {
      _gen++;
      setState(() { _results = []; _loading = false; });
      _removeOverlay();
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(
      const Duration(milliseconds: 180),
      () => _startSearch(q),
    );
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
          _showOrUpdateOverlay();
        } else {
          _removeOverlay();
        }
      },
    );

    if (mounted && gen == _gen) setState(() => _loading = false);
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _select(PlayerSearchResult result) {
    widget.controller.text = result.entry.displayName;
    setState(() { _results = []; _confirmed = true; });
    _removeOverlay();
    widget.onSelected(result.entry);
  }

  // ── Overlay ────────────────────────────────────────────────────────────────

  void _showOrUpdateOverlay() {
    if (_overlay == null) {
      _overlay = OverlayEntry(builder: (_) => _buildDropdown());
      Overlay.of(context, rootOverlay: true).insert(_overlay!);
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildDropdown() {
    final query = widget.controller.text.trim();
    final width = _layerLink.leaderSize?.width ?? 280;

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
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _results.isEmpty
                  // ── Still loading ─────────────────────────────────────
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
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
                          Text('Searching...',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    )
                  // ── Results list ──────────────────────────────────────
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return _ResultTile(
                          result:  r,
                          query:   query,
                          isFirst: i == 0,
                          isLast:  i == _results.length - 1,
                          onTap:   () => _select(r),
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
      child: TextField(
        controller:         widget.controller,
        focusNode:          _focusNode,
        onChanged:          _onChanged,
        autocorrect:        false,
        enableSuggestions:  false,
        keyboardType:       TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText:  widget.hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.person_search_outlined,
              color: Colors.white38, size: 18),
          suffixIcon: _loading
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
          filled:     true,
          fillColor:  const Color(0xFF1E1E1E),
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
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ── Result tile ───────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final PlayerSearchResult result;
  final String             query;
  final bool               isFirst;
  final bool               isLast;
  final VoidCallback       onTap;

  const _ResultTile({
    required this.result,
    required this.query,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry    = result.entry;
    final isManual = !entry.isRegistered;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top:    Radius.circular(isFirst ? 12 : 0),
        bottom: Radius.circular(isLast  ? 12 : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Avatar / add icon ──────────────────────────────────────
            isManual
                ? Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_outlined,
                        color: AppColors.primary, size: 18),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.18),
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

            // ── Name + ID badge + subtitle ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row — with player-ID badge for registered players
                  isManual
                      ? RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13),
                            children: [
                              const TextSpan(
                                text: 'Add  ',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: '"${entry.displayName}"',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(
                                text: '  as new player',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: _HighlightText(
                                text:  entry.displayName,
                                query: query,
                              ),
                            ),
                            if (entry.numericId != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${entry.numericId}',
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

                  // Subtitle — full phone / email
                  if (!isManual && entry.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── Right icon ─────────────────────────────────────────────
            Icon(
              isManual
                  ? Icons.add_circle_outline
                  : Icons.chevron_right_rounded,
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

// ── Highlighted name text (matching part shown in primary color) ──────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600);

    if (query.isEmpty) {
      return Text(text,
          style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final lowerText  = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx        = lowerText.indexOf(lowerQuery);

    if (idx < 0) {
      return Text(text,
          style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Text.rich(
      TextSpan(children: [
        if (idx > 0)
          TextSpan(
            text: text.substring(0, idx),
            style: const TextStyle(color: Colors.white70),
          ),
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w800),
        ),
        if (idx + query.length < text.length)
          TextSpan(
            text: text.substring(idx + query.length),
            style: const TextStyle(color: Colors.white70),
          ),
      ]),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
