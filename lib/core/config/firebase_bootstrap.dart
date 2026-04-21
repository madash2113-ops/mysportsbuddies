import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  static bool _initialized = false;
  static String? _error;

  static bool get isInitialized => _initialized;
  static String? get error => _error;

  static Future<void> initialize() async {
    try {
      if (kIsWeb) {
        final options = _webOptions;
        if (options == null) {
          throw StateError(
            'Firebase web config is missing. Add the web app values in '
            'lib/core/config/firebase_bootstrap.dart or provide them via '
            '--dart-define.',
          );
        }
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      _initialized = true;
      _error = null;
    } catch (e) {
      _initialized = false;
      _error = e.toString();
    }
  }

  static FirebaseOptions? get _webOptions {
    const apiKey = String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'AIzaSyCV6wjivEXJ23ZGfsOD-Q6BbAzPVbOpqVM',
    );
    const appId = String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: '1:793247401031:web:26f38cddecb1f268645d62',
    );
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      defaultValue: '793247401031',
    );
    const projectId = String.fromEnvironment(
      'FIREBASE_WEB_PROJECT_ID',
      defaultValue: 'mysportsbuddies-4d077',
    );
    const authDomain = String.fromEnvironment(
      'FIREBASE_WEB_AUTH_DOMAIN',
      defaultValue: 'mysportsbuddies-4d077.firebaseapp.com',
    );
    const storageBucket = String.fromEnvironment(
      'FIREBASE_WEB_STORAGE_BUCKET',
      defaultValue: 'mysportsbuddies-4d077.firebasestorage.app',
    );
    const measurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

    if (appId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }
}
