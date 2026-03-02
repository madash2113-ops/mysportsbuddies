import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../services/feed_service.dart';

// ── Photo filter definitions ───────────────────────────────────────────────

class _Filter {
  final String name;
  final List<double> matrix; // 4×5 ColorMatrix
  const _Filter(this.name, this.matrix);
}

/// Identity matrix — no filter
const List<double> _identityMatrix = [
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

const List<double> _sepiaMatrix = [
  0.393, 0.769, 0.189, 0, 0,
  0.349, 0.686, 0.168, 0, 0,
  0.272, 0.534, 0.131, 0, 0,
  0,     0,     0,     1, 0,
];

const List<double> _coolMatrix = [
  0.8, 0,   0,   0, 0,
  0,   0.9, 0,   0, 0,
  0,   0,   1.3, 0, 0,
  0,   0,   0,   1, 0,
];

const List<double> _warmMatrix = [
  1.3, 0,   0,   0, 0,
  0,   1.1, 0,   0, 0,
  0,   0,   0.8, 0, 0,
  0,   0,   0,   1, 0,
];

const List<double> _bwMatrix = [
  0.33, 0.59, 0.11, 0, 0,
  0.33, 0.59, 0.11, 0, 0,
  0.33, 0.59, 0.11, 0, 0,
  0,    0,    0,    1, 0,
];

const List<double> _vividMatrix = [
  1.4, 0,   0,   0, -20,
  0,   1.4, 0,   0, -20,
  0,   0,   1.4, 0, -20,
  0,   0,   0,   1,   0,
];

const List<double> _fadeMatrix = [
  0.8, 0,   0,   0, 30,
  0,   0.8, 0,   0, 30,
  0,   0,   0.8, 0, 30,
  0,   0,   0,   1,  0,
];

const List<double> _dramaticMatrix = [
  1.5, 0,   0,   0, -30,
  0,   1.2, 0,   0, -10,
  0,   0,   0.9, 0, -10,
  0,   0,   0,   1,   0,
];

const _filters = [
  _Filter('Normal',   _identityMatrix),
  _Filter('Sepia',    _sepiaMatrix),
  _Filter('Cool',     _coolMatrix),
  _Filter('Warm',     _warmMatrix),
  _Filter('B&W',      _bwMatrix),
  _Filter('Vivid',    _vividMatrix),
  _Filter('Fade',     _fadeMatrix),
  _Filter('Dramatic', _dramaticMatrix),
];

// ── Music stubs ────────────────────────────────────────────────────────────

class _MusicTrack {
  final String title, artist, emoji;
  const _MusicTrack(this.title, this.artist, this.emoji);
}

const _musicTracks = [
  _MusicTrack('Eye of the Tiger',   'Survivor',           '🎸'),
  _MusicTrack('We Are the Champions','Queen',             '🏆'),
  _MusicTrack('Thunderstruck',       'AC/DC',             '⚡'),
  _MusicTrack('Seven Nation Army',   'The White Stripes',  '🥁'),
  _MusicTrack('Welcome to the Jungle','Guns N\' Roses',   '🎵'),
  _MusicTrack('Can\'t Stop the Feeling','Justin Timberlake','💃'),
  _MusicTrack('Lose Yourself',       'Eminem',            '🎤'),
  _MusicTrack('Jump',                'Van Halen',         '🎶'),
];

// ── Main widget ────────────────────────────────────────────────────────────

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _textCtrl = TextEditingController();
  File?   _image;
  String? _selectedSport;
  int     _filterIndex = 0;          // 0 = Normal (no filter)
  _MusicTrack? _selectedMusic;
  bool    _posting = false;
  bool    _showFilters = false;      // expand filter strip

  static const _sports = [
    'Cricket', 'Football', 'Basketball', 'Badminton',
    'Tennis', 'Volleyball', 'Table Tennis', 'Hockey',
    'Boxing', 'Running', 'Swimming', 'Cycling',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // close the source picker if open
    final picked = await ImagePicker().pickImage(
        source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _image = File(picked.path);
        _showFilters = true; // auto-show filters when image is added
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white),
              title: const Text('Camera',
                  style: TextStyle(color: Colors.white)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white),
              title: const Text('Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  // ── Music picker ──────────────────────────────────────────────────────────

  void _openMusicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (_, ctrl) => Column(
          children: [
            // Handle + title
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Add Music',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: _musicTracks.length,
                itemBuilder: (_, i) {
                  final track = _musicTracks[i];
                  final selected = _selectedMusic == track;
                  return ListTile(
                    leading: Text(track.emoji,
                        style: const TextStyle(fontSize: 28)),
                    title: Text(track.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(track.artist,
                        style: const TextStyle(color: Colors.white54)),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary)
                        : const Icon(Icons.play_circle_outline,
                            color: Colors.white38),
                    onTap: () {
                      setState(() =>
                          _selectedMusic = selected ? null : track);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Post ──────────────────────────────────────────────────────────────────

  Future<void> _post() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _image == null) return;

    setState(() => _posting = true);
    try {
      // Append music tag to text if a track is selected
      final fullText = _selectedMusic != null
          ? '$text\n🎵 ${_selectedMusic!.title} — ${_selectedMusic!.artist}'
          : text;

      await context.read<FeedService>().createPost(
            text: fullText,
            imageFile: _image,
            sport: _selectedSport,
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Post failed: $e'),
            backgroundColor: Colors.red.shade900),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filter      = _filters[_filterIndex];

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Title row
            Row(
              children: [
                const Text('New Post',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                // Music button
                GestureDetector(
                  onTap: _openMusicPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedMusic != null
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedMusic != null
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedMusic != null
                              ? Icons.music_note
                              : Icons.music_note_outlined,
                          color: _selectedMusic != null
                              ? AppColors.primary
                              : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedMusic != null
                              ? _selectedMusic!.title
                              : 'Add Music',
                          style: TextStyle(
                              color: _selectedMusic != null
                                  ? AppColors.primary
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Text input
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's happening in your sports world?",
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 10),

            // Image preview with active filter
            if (_image != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(filter.matrix),
                      child: Image.file(_image!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                  ),
                  // Remove image
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _image = null;
                        _filterIndex = 0;
                        _showFilters = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  // Filter toggle button
                  Positioned(
                    bottom: 8, right: 8,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showFilters = !_showFilters),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_high_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _filterIndex == 0
                                  ? 'Filters'
                                  : filter.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Filter strip (shown when image is loaded)
            if (_image != null && _showFilters) ...[
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (_, i) {
                    final f       = _filters[i];
                    final active  = _filterIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _filterIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: active
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: ColorFiltered(
                                  colorFilter:
                                      ColorFilter.matrix(f.matrix),
                                  child: Image.file(_image!,
                                      fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(f.name,
                                style: TextStyle(
                                    color: active
                                        ? AppColors.primary
                                        : Colors.white54,
                                    fontSize: 10,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.normal)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Sport tag row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _sports.map((s) {
                  final selected = _selectedSport == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 12)),
                      selected: selected,
                      onSelected: (_) => setState(() =>
                          _selectedSport = selected ? null : s),
                      selectedColor: AppColors.primary,
                      backgroundColor: const Color(0xFF1A1A1A),
                      side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.1)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Action row
            Row(
              children: [
                // Photo
                IconButton(
                  onPressed: _posting ? null : _showImageSourceSheet,
                  icon: Icon(Icons.image_outlined,
                      color: _image != null
                          ? AppColors.primary
                          : Colors.white54),
                  tooltip: 'Add photo',
                ),
                // Music
                IconButton(
                  onPressed: _posting ? null : _openMusicPicker,
                  icon: Icon(Icons.music_note_outlined,
                      color: _selectedMusic != null
                          ? AppColors.primary
                          : Colors.white54),
                  tooltip: 'Add music',
                ),
                const Spacer(),
                SizedBox(
                  width: 110,
                  child: ElevatedButton(
                    onPressed: _posting ? null : _post,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _posting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Post',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
