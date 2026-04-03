import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a bottom sheet letting the user pick a maps app for directions.
/// Falls back to address-based query if [lat]/[lng] are null.
Future<void> showMapPickerSheet(
  BuildContext context, {
  double? lat,
  double? lng,
  required String label,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _MapPickerSheet(lat: lat, lng: lng, label: label),
  );
}

class _MapPickerSheet extends StatelessWidget {
  final double? lat;
  final double? lng;
  final String label;

  const _MapPickerSheet({this.lat, this.lng, required this.label});

  bool get _hasCoords => lat != null && lng != null;

  String get _coordStr => '${lat!},${lng!}';
  String get _encodedLabel => Uri.encodeComponent(label);

  Uri get _googleMapsUri => _hasCoords
      ? Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$_coordStr')
      : Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$_encodedLabel');

  Uri get _appleMapsUri => _hasCoords
      ? Uri.parse('https://maps.apple.com/?daddr=$_coordStr')
      : Uri.parse('https://maps.apple.com/?q=$_encodedLabel');

  Uri get _wazeUri => _hasCoords
      ? Uri.parse('waze://?ll=$_coordStr&navigate=yes')
      : Uri.parse('waze://?q=$_encodedLabel&navigate=yes');

  Uri get _wazeFallbackUri => _hasCoords
      ? Uri.parse('https://waze.com/ul?ll=$_coordStr&navigate=yes')
      : Uri.parse('https://waze.com/ul?q=$_encodedLabel&navigate=yes');

  Future<void> _launch(BuildContext context, Uri uri, {Uri? fallback}) async {
    Navigator.pop(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && fallback != null) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (fallback != null) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),

            // ── Google Maps ──────────────────────────────────────────────
            _MapTile(
              color: const Color(0xFF4285F4),
              icon: Icons.map_outlined,
              label: 'Google Maps',
              onTap: () => _launch(context, _googleMapsUri),
            ),

            // ── Apple Maps (iOS only) ────────────────────────────────────
            if (Platform.isIOS)
              _MapTile(
                color: const Color(0xFF555555),
                icon: Icons.map,
                label: 'Apple Maps',
                onTap: () => _launch(context, _appleMapsUri),
              ),

            // ── Waze ─────────────────────────────────────────────────────
            _MapTile(
              color: const Color(0xFF33CCFF),
              icon: Icons.navigation_outlined,
              label: 'Waze',
              onTap: () => _launch(context, _wazeUri, fallback: _wazeFallbackUri),
            ),

            // ── Copy address ─────────────────────────────────────────────
            _MapTile(
              color: Colors.white30,
              icon: Icons.copy_outlined,
              label: 'Copy Address',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: label));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Address copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}
