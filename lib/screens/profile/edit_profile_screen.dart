import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

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
            onPressed: () {},
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
          children: const [
            _ProfileAvatar(),
            SizedBox(height: 24),

            _InputField(label: 'Full Name', hint: 'John Doe', icon: Icons.person),
            _InputField(label: 'Email', hint: 'john.doe@email.com', icon: Icons.email),
            _InputField(label: 'Phone Number', hint: '+1 234 567 8900', icon: Icons.phone),
            _InputField(label: 'Location', hint: 'New York, USA', icon: Icons.location_on),
            _InputField(label: 'Date of Birth', hint: 'mm/dd/yyyy', icon: Icons.calendar_today),

            SizedBox(height: 16),
            _BioField(),

            SizedBox(height: 24),
            _StatsRow(),
          ],
        ),
      ),
    );
  }
}

/* -------- helpers -------- */

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: const [
            CircleAvatar(
              radius: 55,
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red,
              child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Tap to change photo',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}

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
