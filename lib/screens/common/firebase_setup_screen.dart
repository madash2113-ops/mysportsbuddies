import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/colors.dart';

class FirebaseSetupScreen extends StatelessWidget {
  final String? error;
  const FirebaseSetupScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Firebase Setup Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isWeb
                        ? 'The web app cannot start because this project does not have a Firebase web app configuration yet.'
                        : 'Firebase failed to initialize for this app.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isWeb) ...[
                    const Text(
                      'Add these values from Firebase Console -> Project settings -> Your apps -> Web app:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _CodeLine('FIREBASE_WEB_APP_ID'),
                    const _CodeLine('FIREBASE_WEB_API_KEY'),
                    const _CodeLine('FIREBASE_WEB_AUTH_DOMAIN'),
                    const _CodeLine('FIREBASE_WEB_PROJECT_ID'),
                    const _CodeLine('FIREBASE_WEB_MESSAGING_SENDER_ID'),
                    const _CodeLine('FIREBASE_WEB_STORAGE_BUCKET'),
                    const _CodeLine('FIREBASE_WEB_MEASUREMENT_ID (optional)'),
                    const SizedBox(height: 16),
                    const Text(
                      'Run example:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SelectableText(
                      'flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 '
                      '--dart-define=FIREBASE_WEB_APP_ID=1:793247401031:web:YOUR_WEB_APP_ID',
                      style: TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Startup error:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  final String value;

  const _CodeLine(this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText(
        value,
        style: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }
}
