import 'dart:convert';
import 'package:country_picker/country_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Detects user's country code based on location.
/// Uses IP geolocation as fallback, then device GPS for accuracy.
class LocationCountryService {
  static final LocationCountryService _instance = LocationCountryService._();

  factory LocationCountryService() => _instance;

  LocationCountryService._();

  // Country code to phone code mapping
  static const Map<String, String> _countryCodeToPhone = {
    'IN': '+91',  // India
    'US': '+1',   // USA
    'CA': '+1',   // Canada
    'GB': '+44',  // United Kingdom
    'AU': '+61',  // Australia
    'NZ': '+64',  // New Zealand
    'ZA': '+27',  // South Africa
    'PK': '+92',  // Pakistan
    'LK': '+94',  // Sri Lanka
    'BD': '+880', // Bangladesh
    'AF': '+93',  // Afghanistan
    'NP': '+977', // Nepal
    'MY': '+60',  // Malaysia
    'SG': '+65',  // Singapore
    'AE': '+971', // UAE
    'OM': '+968', // Oman
    'QA': '+974', // Qatar
    'BH': '+973', // Bahrain
    'SA': '+966', // Saudi Arabia
    'DE': '+49',  // Germany
    'FR': '+33',  // France
    'IT': '+39',  // Italy
    'ES': '+34',  // Spain
    'NL': '+31',  // Netherlands
    'JP': '+81',  // Japan
    'CN': '+86',  // China
    'KR': '+82',  // South Korea
    'BR': '+55',  // Brazil
    'MX': '+52',  // Mexico
    'NG': '+234', // Nigeria
    'KE': '+254', // Kenya
    'IE': '+353', // Ireland
    'ZW': '+263', // Zimbabwe
  };

  static const String _cachedPhoneCodeKey = 'cached_phone_code';
  static const String _cachedPhoneCodeTimestampKey = 'cached_phone_code_ts';
  static const Duration _cacheTTL = Duration(hours: 24);

  Future<String?> getCachedPhoneCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cachedPhoneCodeKey);
    } catch (e) {
      debugPrint('Cache read error: $e');
      return null;
    }
  }

  Future<void> _cachePhoneCode(String phoneCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedPhoneCodeKey, phoneCode);
      await prefs.setInt(
        _cachedPhoneCodeTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Cache write error: $e');
    }
  }

  Future<String> getCachedOrDetectCountryCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCode = prefs.getString(_cachedPhoneCodeKey);
      if (cachedCode != null && cachedCode.isNotEmpty) {
        final tsMillis = prefs.getInt(_cachedPhoneCodeTimestampKey) ?? 0;
        final cacheAge = DateTime.now().millisecondsSinceEpoch - tsMillis;
        if (cacheAge < _cacheTTL.inMilliseconds) {
          debugPrint('✅ Location: Using cached phone code $cachedCode');
          return cachedCode;
        }
        debugPrint('⏱ Location: Cache expired, re-detecting');
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
    return detectCountryCode();
  }

  /// Detects country code from device location or IP geolocation.
  /// Returns country code like '+91' for India, '+1' for USA.
  /// Falls back to '+91' (India) if detection fails.
  Future<String> detectCountryCode() async {
    try {
      // First try IP geolocation because it is fast and does not require permissions.
      final ipCountry = await _detectViaIP();
      if (ipCountry != null && ipCountry.isNotEmpty) {
        debugPrint('✅ Location: Country detected via IP: $ipCountry');
        await _cachePhoneCode(ipCountry);
        return ipCountry;
      }

      // Fallback to GPS if IP fails.
      final gpsCountry = await _detectViaGPS();
      if (gpsCountry != null && gpsCountry.isNotEmpty) {
        debugPrint('✅ Location: Country detected via GPS: $gpsCountry');
        await _cachePhoneCode(gpsCountry);
        return gpsCountry;
      }

      debugPrint('⚠️ Location: Detection failed, defaulting to +91');
      return '+91';
    } catch (e) {
      debugPrint('❌ Location detection error: $e');
      return '+91';
    }
  }

  /// Detect country via device GPS (requires location permission).
  Future<String?> _detectViaGPS() async {
    try {
      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 1),
        onTimeout: () => LocationPermission.denied,
      );
      
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permission denied, trying IP geolocation');
        return null;
      }

      // Request permission if not yet asked (non-blocking)
      if (permission == LocationPermission.unableToDetermine) {
        final requested = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 1),
          onTimeout: () => LocationPermission.denied,
        );
        if (requested != LocationPermission.whileInUse &&
            requested != LocationPermission.always) {
          return null;
        }
      }

      // Ensure location services are enabled first.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 Location services disabled, skipping GPS detection');
        return null;
      }

      // Get device position with aggressive timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 0,
        ),
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Location request timeout'),
      );

      // Reverse geocode to get country
      final country = await _reverseGeocodeToCountry(
        position.latitude,
        position.longitude,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );

      return country;
    } catch (e) {
      debugPrint('📍 GPS detection failed: $e');
      return null;
    }
  }

  /// Detect country via IP geolocation (no permission needed).
  /// Uses free IP Geolocation API.
  Future<String?> _detectViaIP() async {
    try {
      // Try multiple free IP geolocation APIs
      final urls = [
        'https://ipapi.co/json/', // Most reliable, no API key needed
        'https://ip-api.com/json/',
      ];

      for (final url in urls) {
        try {
          final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 2),
          );

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final countryCode = json['country_code'] as String? ?? json['countryCode'] as String?;

            if (countryCode != null && countryCode.isNotEmpty) {
              final phoneCode = _countryCodeToPhone[countryCode.toUpperCase()];
              if (phoneCode != null) {
                return phoneCode;
              }
            }
          }
        } catch (e) {
          debugPrint('IP API error for $url: $e');
          continue;
        }
      }

      return null;
    } catch (e) {
      debugPrint('IP geolocation error: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to country using Nominatim (free, no API key).
  Future<String?> _reverseGeocodeToCountry(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=$latitude&lon=$longitude';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'MySportsBuddies/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;
        final countryCode = address?['country_code'] as String?;

        if (countryCode != null && countryCode.isNotEmpty) {
          return _countryCodeToPhone[countryCode.toUpperCase()];
        }
      }

      return null;
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return null;
    }
  }

  /// Synchronously detect country from device locale.
  /// Returns the detected [Country], or null if locale has no country code.
  /// This is instant (no network, no permissions) — the preferred primary source.
  static Country? detectFromLocale() {
    try {
      final locale = PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode;
      if (countryCode == null || countryCode.isEmpty) return null;
      return CountryParser.parseCountryCode(countryCode);
    } catch (e) {
      debugPrint('🌍 Locale detection failed: $e');
      return null;
    }
  }

  /// Get Country object from country code (e.g., 'IN' -> India).
  static Country getCountryFromCode(String phoneCode) {
    try {
      // Map phone code to country code
      const phoneToCountryCode = {
        '+91': 'IN',
        '+1': 'US',
        '+44': 'GB',
        '+61': 'AU',
        '+64': 'NZ',
        '+27': 'ZA',
        '+92': 'PK',
        '+94': 'LK',
        '+880': 'BD',
        '+93': 'AF',
        '+977': 'NP',
        '+60': 'MY',
        '+65': 'SG',
        '+971': 'AE',
        '+968': 'OM',
        '+974': 'QA',
        '+973': 'BH',
        '+966': 'SA',
        '+49': 'DE',
        '+33': 'FR',
        '+39': 'IT',
        '+34': 'ES',
        '+31': 'NL',
        '+81': 'JP',
        '+86': 'CN',
        '+82': 'KR',
        '+55': 'BR',
        '+52': 'MX',
        '+234': 'NG',
        '+254': 'KE',
        '+353': 'IE',
        '+263': 'ZW',
      };

      final countryCode = phoneToCountryCode[phoneCode] ?? 'IN';
      return CountryParser.parseCountryCode(countryCode);
    } catch (e) {
      debugPrint('Error parsing country from code $phoneCode: $e');
      return CountryParser.parseCountryCode('IN'); // Fallback to India
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
