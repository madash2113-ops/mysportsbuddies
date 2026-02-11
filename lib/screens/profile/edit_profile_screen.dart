import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
// 👆 Provider for syncing profile image globally

import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_view/photo_view.dart';

import '../../controllers/profile_controller.dart'; 
// 👆 Global profile controller

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _profileImage; 
  // 👆 Local copy for this screen (kept for UI stability)

  /* ============================================================
   * SYNC IMAGE FROM GLOBAL STATE WHEN SCREEN OPENS
   * ============================================================ */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = context.read<ProfileController>();

    // If local image is null but global image exists, sync it
    if (_profileImage == null && controller.profileImage != null) {
      _profileImage = controller.profileImage;
    }
  }

  /* ============================================================
   * IMAGE PICK + CROP
   * ============================================================ */
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);

    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
      ],
    );

    if (cropped == null) return;

    // ============================================================
    // UPDATE GLOBAL + LOCAL STATE (SYNC POINT)
    // ============================================================
    final imageFile = File(cropped.path);

    // Update global profile image (HomeScreen will auto-update)
    context.read<ProfileController>().setProfileImage(imageFile);

    // Update local UI state
    setState(() {
      _profileImage = imageFile;
    });
  }

  /* ============================================================
   * PROFILE IMAGE OPTIONS (VIEW / CHANGE)
   * ============================================================ */
  void _openProfileOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility, color: Colors.white),
            title: const Text(
              'View picture',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              // ================= VIEW PROFILE IMAGE =================
final image = context.read<ProfileController>().profileImage;

if (image != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _FullImageViewer(image: image),
    ),
  );
}

            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: const Text(
              'Change picture',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _openChangeSource();
            },
          ),
        ],
      ),
    );
  }

  void _openChangeSource() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  /* ============================================================
   * UI
   * ============================================================ */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Save profile data later (name, email, etc.)
            },
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

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ProfileAvatar(
              image: _profileImage,
              onTap: _openProfileOptions,
            ),

            const SizedBox(height: 24),

            const _InputField(
              label: 'Full Name',
              hint: 'John Doe',
              icon: Icons.person,
            ),
            const _InputField(
              label: 'Email',
              hint: 'john.doe@email.com',
              icon: Icons.email,
            ),
            const _InputField(
              label: 'Phone Number',
              hint: '+1 234 567 8900',
              icon: Icons.phone,
            ),
            const _InputField(
              label: 'Location',
              hint: 'New York, USA',
              icon: Icons.location_on,
            ),
            const _InputField(
              label: 'Date of Birth',
              hint: 'mm/dd/yyyy',
              icon: Icons.calendar_today,
            ),

            const SizedBox(height: 16),
            const _BioField(),

            const SizedBox(height: 24),
            const _StatsRow(),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 * PROFILE AVATAR
 * ============================================================ */
class _ProfileAvatar extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;

  const _ProfileAvatar({
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.redAccent,
                backgroundImage: image != null ? FileImage(image!) : null,
                child: image == null
                    ? const Icon(Icons.person,
                        size: 60, color: Colors.white)
                    : null,
              ),
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.red,
                child: Icon(Icons.camera_alt,
                    size: 16, color: Colors.white),
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
}

/* ============================================================
 * INPUT FIELDS
 * ============================================================ */
class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;

  const _InputField({
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
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

class _BioField extends StatelessWidget {
  const _BioField();

  @override
  Widget build(BuildContext context) {
    return TextField(
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
    );
  }
}

/* ============================================================
 * STATS
 * ============================================================ */
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _StatItem(value: '24', label: 'Games\nPlayed'),
        _StatItem(value: '156', label: 'Buddies'),
        _StatItem(value: '18', label: 'Wins'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

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
            style:
                const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
 * FULL IMAGE VIEWER
 * ============================================================ */
class _FullImageViewer extends StatelessWidget {
  final File image;

  const _FullImageViewer({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ✅ BACK BUTTON IN TOP LEFT
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ✅ IMAGE (NO TAP TO CLOSE)
      body: PhotoView(
        imageProvider: FileImage(image),
        backgroundDecoration:
            const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

