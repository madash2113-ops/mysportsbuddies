import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/profile_controller.dart';
import '../../core/models/user_profile.dart';
import '../../services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  File? _profileImage;
  Uint8List?
  _imageBytes; // bytes read immediately after crop — survives temp cleanup
  bool _saving = false;
  bool _imageChanged = false;

  // ── Location autocomplete ──────────────────────────────────────────────────
  Timer? _locationDebounce;
  bool _locationLoading = false;
  List<String> _locationSuggestions = [];
  bool _showLocationSuggestions = false;

  // ── Country code ──────────────────────────────────────────────────────────
  String _countryFlag = '\u{1F1EE}\u{1F1F3}'; // 🇮🇳
  String _countryCode = '+91';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _prefillFromController();
  }

  void _prefillFromController() {
    final prof = UserService().profile;
    _nameCtrl.text = prof?.name ?? '';
    _emailCtrl.text = prof?.email ?? '';
    _locationCtrl.text = prof?.location ?? '';
    _dobCtrl.text = prof?.dob ?? '';
    _bioCtrl.text = prof?.bio ?? '';

    // Split stored phone into country-code prefix + number
    final rawPhone = prof?.phone ?? '';
    final matched = _CountryData.all.where((c) => rawPhone.startsWith(c.code));
    if (matched.isNotEmpty) {
      final c = matched.first;
      _countryFlag = c.flag;
      _countryCode = c.code;
      _phoneCtrl.text = rawPhone.substring(c.code.length).trim();
    } else {
      _phoneCtrl.text = rawPhone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _dobCtrl.dispose();
    _bioCtrl.dispose();
    _locationDebounce?.cancel();
    super.dispose();
  }

  // ── Date Picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    // Parse existing date or default to 25 years ago
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 25));
    if (_dobCtrl.text.isNotEmpty) {
      final parts = _dobCtrl.text.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          initial = DateTime(y, m, d);
        }
      }
    }

    DateTime selected = initial;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const Text(
                    'Date of Birth',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dobCtrl.text =
                            '${selected.day.toString().padLeft(2, '0')}/'
                            '${selected.month.toString().padLeft(2, '0')}/'
                            '${selected.year}';
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Drum-roll picker
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                maximumDate: DateTime.now(),
                minimumYear: 1900,
                backgroundColor: const Color(0xFF1A1A1A),
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ── Location Autocomplete ─────────────────────────────────────────────────

  void _onLocationChanged(String query) {
    _locationDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _locationSuggestions = [];
        _locationLoading = false;
        _showLocationSuggestions = false;
      });
      return;
    }
    setState(() {
      _locationLoading = true;
      _showLocationSuggestions = true;
    });
    _locationDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchLocations(query.trim()),
    );
  }

  Future<void> _fetchLocations(String query) async {
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=7&lang=en',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>? ?? []);
        final results = <String>[];
        for (final f in features) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final name = props['name'] as String? ?? '';
          final city = props['city'] as String? ?? '';
          final state = props['state'] as String? ?? '';
          final country = props['country'] as String? ?? '';
          final parts = <String>[];
          if (name.isNotEmpty) parts.add(name);
          if (city.isNotEmpty && city != name) parts.add(city);
          if (state.isNotEmpty && state != city && state != name) {
            parts.add(state);
          }
          if (country.isNotEmpty) parts.add(country);
          final label = parts.join(', ');
          if (label.isNotEmpty && !results.contains(label)) results.add(label);
        }
        setState(() {
          _locationSuggestions = results;
          _locationLoading = false;
        });
      } else {
        setState(() => _locationLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // ── Country Picker ────────────────────────────────────────────────────────

  Future<void> _showCountryPicker() async {
    String query = '';
    List<_CountryData> filtered = _CountryData.all;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) => Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search country...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) {
                        query = v.toLowerCase();
                        setSheet(() {
                          filtered = _CountryData.all
                              .where(
                                (c) =>
                                    c.name.toLowerCase().contains(query) ||
                                    c.code.contains(query),
                              )
                              .toList();
                        });
                      },
                    ),
                  ),
                  // List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final selected = c.code == _countryCode;
                        return ListTile(
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Text(
                            c.code,
                            style: TextStyle(
                              color: selected ? Colors.red : Colors.white54,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _countryFlag = c.flag;
                              _countryCode = c.code;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Image Pick + Crop ─────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profileImage = null;
        _imageBytes = bytes;
        _imageChanged = true;
      });
      return;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
      ],
    );
    if (cropped == null) return;
    if (!mounted) return;

    final file = File(cropped.path);
    // Read bytes immediately — the cropper writes to a temp dir that the OS
    // can delete before the user taps Save, causing object-not-found on upload.
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    context.read<ProfileController>().setProfileImage(file);
    setState(() {
      _profileImage = file;
      _imageBytes = bytes;
      _imageChanged = true;
    });
  }

  // ── Image Options ─────────────────────────────────────────────────────────

  void _openProfileOptions() {
    _showResponsiveProfileMenu(
      mobileChild: _ProfileActionList(
        children: [
          _ProfileActionTile(
            icon: Icons.visibility,
            label: 'View picture',
            onTap: () {
              Navigator.pop(context);
              _openCurrentPhotoViewer();
            },
          ),
          _ProfileActionTile(
            icon: Icons.camera_alt,
            label: 'Change picture',
            onTap: () {
              Navigator.pop(context);
              _showSourcePicker();
            },
          ),
        ],
      ),
      webChild: _WebPhotoActionsDialog(
        onViewPicture: () {
          Navigator.pop(context);
          _openCurrentPhotoViewer();
        },
        onChangePicture: () {
          Navigator.pop(context);
          _showSourcePicker();
        },
      ),
      webMaxWidth: 460,
    );
  }

  void _showSourcePicker() {
    _showResponsiveProfileMenu(
      mobileChild: _ProfileActionList(
        children: [
          _ProfileActionTile(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          _ProfileActionTile(
            icon: Icons.photo,
            label: 'Gallery',
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
      webChild: _WebUploadPhotoDialog(
        onUploadFromComputer: () async {
          await _pickImage(ImageSource.gallery);
          if (mounted) Navigator.pop(context);
        },
        onTakePhoto: () async {
          await _pickImage(ImageSource.camera);
          if (mounted) Navigator.pop(context);
        },
      ),
      webMaxWidth: 560,
    );
  }

  Future<void> _showResponsiveProfileMenu({
    required Widget mobileChild,
    required Widget webChild,
    required double webMaxWidth,
  }) {
    final isWebLayout = MediaQuery.sizeOf(context).width >= 900;
    if (!isWebLayout) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => mobileChild,
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0E0E0E),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: webMaxWidth),
          child: webChild,
        ),
      ),
    );
  }

  void _openCurrentPhotoViewer() {
    final url =
        context.read<ProfileController>().networkImageUrl ??
        UserService().profile?.imageUrl;
    if (_profileImage == null &&
        _imageBytes == null &&
        (url == null || url.trim().isEmpty)) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(
          image: _profileImage,
          imageBytes: _imageBytes,
          networkUrl: url,
        ),
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final userSvc = UserService();
      final userId = userSvc.userId ?? 'local';

      final phoneNumber = _phoneCtrl.text.trim();
      final fullPhone = phoneNumber.isEmpty ? '' : '$_countryCode $phoneNumber';

      // Use existing imageUrl for now — image upload happens in background
      final existingImageUrl = userSvc.profile?.imageUrl;

      final profile = UserProfile(
        id: userId,
        numericId: userSvc.profile?.numericId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: fullPhone,
        location: _locationCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        imageUrl: existingImageUrl,
        updatedAt: DateTime.now(),
      );

      // ── Step 1: Save text data to Firestore (fast, ~200ms) ───────────────
      await userSvc.saveProfile(profile);

      // ── Step 2: Sync to ProfileController so drawer updates immediately ──
      if (!mounted) return;
      context.read<ProfileController>().setProfile(
        name: profile.name,
        email: profile.email,
        phone: profile.phone,
        location: profile.location,
        dob: profile.dob,
        bio: profile.bio,
        networkImageUrl: existingImageUrl,
        numericId: profile.numericId,
      );

      // ── Step 3: Upload image and store URL in Firestore ─────────────────
      if (_imageChanged && _imageBytes != null) {
        String? imageUrl;
        try {
          imageUrl = await userSvc.uploadProfileImageBytes(_imageBytes!);
        } catch (e) {
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text(
                  'Photo Upload Failed',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  '$e\n\nMake sure Firebase Storage is enabled in the '
                  'Firebase Console and your rules allow writes.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        if (imageUrl != null) {
          try {
            // Store the new photo URL in Firestore
            final updated = profile.copyWith(imageUrl: imageUrl);
            await userSvc.saveProfile(updated);
            if (mounted) {
              context.read<ProfileController>().setProfile(
                name: updated.name,
                email: updated.email,
                phone: updated.phone,
                location: updated.location,
                dob: updated.dob,
                bio: updated.bio,
                networkImageUrl: imageUrl,
                numericId: updated.numericId,
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not save photo URL: $e'),
                  backgroundColor: Colors.red.shade900,
                ),
              );
            }
          }
        }
      }

      // ── Step 4: Pop with success ─────────────────────────────────────────
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved \u2713'),
          backgroundColor: Color(0xFFB71C1C),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAvatar = ListenableBuilder(
      listenable: context.read<ProfileController>(),
      builder: (context, _) => _ProfileAvatar(
        image: _profileImage,
        imageBytes: _imageBytes,
        // Fallback to Firestore value so photo shows even if
        // ProfileController hasn't synced yet (e.g. cold start).
        networkUrl:
            context.read<ProfileController>().networkImageUrl ??
            UserService().profile?.imageUrl,
        onTap: _openProfileOptions,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWebLayout = constraints.maxWidth >= 900;
          final horizontalPadding = isWebLayout ? 40.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isWebLayout ? 28 : 16,
              horizontalPadding,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: isWebLayout
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 280,
                            child: Column(
                              children: [
                                profileAvatar,
                                const SizedBox(height: 28),
                                const _StatsRow(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(child: _buildProfileForm(isWebLayout: true)),
                        ],
                      )
                    : Column(
                        children: [
                          profileAvatar,
                          const SizedBox(height: 24),
                          _buildProfileForm(isWebLayout: false),
                          const SizedBox(height: 24),
                          const _StatsRow(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileForm({required bool isWebLayout}) {
    final nameField = _Field(
      controller: _nameCtrl,
      label: 'Full Name',
      hint: 'John Doe',
      icon: Icons.person,
    );
    final emailField = _Field(
      controller: _emailCtrl,
      label: 'Email',
      hint: 'john.doe@email.com',
      icon: Icons.email,
      keyboardType: TextInputType.emailAddress,
    );
    final phoneField = _PhoneField(
      controller: _phoneCtrl,
      countryFlag: _countryFlag,
      countryCode: _countryCode,
      onCountryTap: _showCountryPicker,
    );
    final dobField = _DobField(controller: _dobCtrl, onTap: _pickDate);

    if (!isWebLayout) {
      return Column(
        children: [
          nameField,
          emailField,
          phoneField,
          _buildLocationField(),
          dobField,
          const SizedBox(height: 4),
          _BioField(controller: _bioCtrl),
        ],
      );
    }

    return Column(
      children: [
        _FormRow(children: [nameField, emailField]),
        _FormRow(children: [phoneField, dobField]),
        _buildLocationField(),
        const SizedBox(height: 4),
        _BioField(controller: _bioCtrl),
      ],
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
          controller: _locationCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.location_on,
              color: Colors.white54,
              size: 22,
            ),
            hintText: 'City, area or address...',
            hintStyle: const TextStyle(color: Colors.white38),
            suffixIcon: _locationLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    ),
                  )
                : const Icon(Icons.search, color: Colors.white38, size: 20),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          onChanged: _onLocationChanged,
        ),
        if (_showLocationSuggestions && _locationSuggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _locationSuggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Colors.white12, height: 1),
              itemBuilder: (_, i) => InkWell(
                onTap: () {
                  setState(() {
                    _locationCtrl.text = _locationSuggestions[i];
                    _locationSuggestions = [];
                    _showLocationSuggestions = false;
                  });
                  FocusScope.of(context).unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationSuggestions[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

class _FormRow extends StatelessWidget {
  final List<Widget> children;

  const _FormRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 20),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class _ProfileActionList extends StatelessWidget {
  final List<Widget> children;

  const _ProfileActionList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

class _WebPhotoActionsDialog extends StatelessWidget {
  final VoidCallback onViewPicture;
  final VoidCallback onChangePicture;

  const _WebPhotoActionsDialog({
    required this.onViewPicture,
    required this.onChangePicture,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WebDialogHeader(
            title: 'Profile photo',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 22),
          _WebUploadOption(
            icon: Icons.visibility_outlined,
            title: 'View current photo',
            subtitle: 'Open your profile image in a larger preview.',
            onTap: onViewPicture,
          ),
          const SizedBox(height: 12),
          _WebUploadOption(
            icon: Icons.add_photo_alternate_outlined,
            title: 'Change photo',
            subtitle: 'Upload a new profile image from this device.',
            onTap: onChangePicture,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _WebUploadPhotoDialog extends StatelessWidget {
  final VoidCallback onUploadFromComputer;
  final VoidCallback onTakePhoto;

  const _WebUploadPhotoDialog({
    required this.onUploadFromComputer,
    required this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WebDialogHeader(
            title: 'Upload profile photo',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a clear photo from your computer. Square images work best.',
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          _WebUploadOption(
            icon: Icons.upload_file_outlined,
            title: 'Upload from computer',
            subtitle: 'Browse for a JPG, PNG, or HEIC image file.',
            onTap: onUploadFromComputer,
            isPrimary: true,
          ),
          const SizedBox(height: 12),
          _WebUploadOption(
            icon: Icons.photo_camera_outlined,
            title: 'Take a photo',
            subtitle: 'Use your camera if your browser allows access.',
            onTap: onTakePhoto,
          ),
        ],
      ),
    );
  }
}

class _WebDialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _WebDialogHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white70),
        ),
      ],
    );
  }
}

class _WebUploadOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  const _WebUploadOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isPrimary ? Colors.red : Colors.white12;
    final iconColor = isPrimary ? Colors.red : Colors.white70;

    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isPrimary ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, color: iconColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Avatar ────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  final File? image;
  final Uint8List? imageBytes;
  final String? networkUrl;
  final VoidCallback onTap;

  const _ProfileAvatar({
    required this.image,
    required this.imageBytes,
    required this.networkUrl,
    required this.onTap,
  });

  ImageProvider? _resolveImage() {
    if (image != null) return FileImage(image!);
    if (imageBytes != null) return MemoryImage(imageBytes!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final img = _resolveImage();
    final url = networkUrl?.trim();
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: img != null
                    ? Image(image: img, fit: BoxFit.cover)
                    : url != null && url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _fallbackIcon(),
                        errorBuilder: (_, _, _) => _fallbackIcon(),
                      )
                    : _fallbackIcon(),
              ),
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.red,
                child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap to change photo',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _fallbackIcon() {
    return const Center(
      child: Icon(Icons.person, size: 60, color: Colors.white),
    );
  }
}

// ── Input Field ───────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Bio Field ─────────────────────────────────────────────────────────────────

class _BioField extends StatelessWidget {
  final TextEditingController controller;

  const _BioField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bio', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tell us about yourself...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserService(),
      builder: (ctx, _) {
        final p = UserService().profile;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(
              value: '${p?.tournamentsPlayed ?? 0}',
              label: 'Tournaments\nPlayed',
            ),
            _StatItem(
              value: '${p?.matchesPlayed ?? 0}',
              label: 'Matches\nPlayed',
            ),
            _StatItem(value: '${p?.matchesWon ?? 0}', label: 'Matches\nWon'),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Full Image Viewer ─────────────────────────────────────────────────────────

class _FullImageViewer extends StatelessWidget {
  final File? image;
  final Uint8List? imageBytes;
  final String? networkUrl;

  const _FullImageViewer({
    required this.image,
    required this.imageBytes,
    required this.networkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = networkUrl?.trim();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 4,
          child: imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.contain)
              : image != null
              ? Image.file(image!, fit: BoxFit.contain)
              : url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                )
              : const Icon(Icons.person, color: Colors.white54, size: 72),
        ),
      ),
    );
  }
}

// ── DOB Field (tap-to-scroll) ──────────────────────────────────────────────────

class _DobField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onTap;

  const _DobField({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of Birth', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (ctx, val, child) => Text(
                      val.text.isEmpty ? 'dd/mm/yyyy' : val.text,
                      style: TextStyle(
                        color: val.text.isEmpty ? Colors.white38 : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Phone Field with Country Code ─────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String countryFlag;
  final String countryCode;
  final VoidCallback onCountryTap;

  const _PhoneField({
    required this.controller,
    required this.countryFlag,
    required this.countryCode,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phone Number', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        Row(
          children: [
            // Country code button
            GestureDetector(
              onTap: onCountryTap,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(countryFlag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      countryCode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Icon(
                      Icons.expand_more,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Phone number input
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '9876543210',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Country Data ───────────────────────────────────────────────────────────────

class _CountryData {
  final String flag;
  final String name;
  final String code;

  const _CountryData(this.flag, this.name, this.code);

  static const List<_CountryData> all = [
    _CountryData('\u{1F1EE}\u{1F1F3}', 'India', '+91'),
    _CountryData('\u{1F1FA}\u{1F1F8}', 'United States', '+1'),
    _CountryData('\u{1F1EC}\u{1F1E7}', 'United Kingdom', '+44'),
    _CountryData('\u{1F1E6}\u{1F1FA}', 'Australia', '+61'),
    _CountryData('\u{1F1E8}\u{1F1E6}', 'Canada', '+1'),
    _CountryData('\u{1F1E6}\u{1F1EA}', 'United Arab Emirates', '+971'),
    _CountryData('\u{1F1F8}\u{1F1EC}', 'Singapore', '+65'),
    _CountryData('\u{1F1F3}\u{1F1FF}', 'New Zealand', '+64'),
    _CountryData('\u{1F1F8}\u{1F1E6}', 'South Africa', '+27'),
    _CountryData('\u{1F1F5}\u{1F1F0}', 'Pakistan', '+92'),
    _CountryData('\u{1F1E7}\u{1F1E9}', 'Bangladesh', '+880'),
    _CountryData('\u{1F1F1}\u{1F1F0}', 'Sri Lanka', '+94'),
    _CountryData('\u{1F1F3}\u{1F1F5}', 'Nepal', '+977'),
    _CountryData('\u{1F1F2}\u{1F1FE}', 'Malaysia', '+60'),
    _CountryData('\u{1F1F3}\u{1F1EC}', 'Nigeria', '+234'),
    _CountryData('\u{1F1F0}\u{1F1EA}', 'Kenya', '+254'),
    _CountryData('\u{1F1E9}\u{1F1EA}', 'Germany', '+49'),
    _CountryData('\u{1F1EB}\u{1F1F7}', 'France', '+33'),
    _CountryData('\u{1F1EE}\u{1F1F9}', 'Italy', '+39'),
    _CountryData('\u{1F1EA}\u{1F1F8}', 'Spain', '+34'),
    _CountryData('\u{1F1E7}\u{1F1F7}', 'Brazil', '+55'),
    _CountryData('\u{1F1F2}\u{1F1FD}', 'Mexico', '+52'),
    _CountryData('\u{1F1EF}\u{1F1F5}', 'Japan', '+81'),
    _CountryData('\u{1F1F0}\u{1F1F7}', 'South Korea', '+82'),
    _CountryData('\u{1F1E8}\u{1F1F3}', 'China', '+86'),
  ];
}
