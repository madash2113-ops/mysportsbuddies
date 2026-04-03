import 'package:flutter/material.dart';

class ProfileImageSheet extends StatelessWidget {
  final VoidCallback onView;
  final VoidCallback onChange;

  const ProfileImageSheet({
    super.key,
    required this.onView,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility, color: Colors.white),
            title: const Text('View picture', style: TextStyle(color: Colors.white)),
            onTap: onView,
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: const Text('Change picture', style: TextStyle(color: Colors.white)),
            onTap: onChange,
          ),
        ],
      ),
    );
  }
}
