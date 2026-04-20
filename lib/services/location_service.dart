import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around the geolocator package.
///
/// Caches the last known position so distance calculations
/// don't need to re-request GPS on every list rebuild.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  // ── Permission + Position ─────────────────────────────────────────────────

  /// Returns the last cached position instantly — no GPS wait.
  /// Use for a fast first render, then call [getCurrentPosition] to refine.
  Future<Position?> getLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        _lastPosition = pos;
        notifyListeners();
      }
      return pos;
    } catch (e) {
      debugPrint('LocationService.getLastKnownPosition error: $e');
      return null;
    }
  }

  /// Returns the current GPS position or null if permission denied / service off.
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: location services disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('LocationService: permission denied');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: permission permanently denied');
        return null;
      }

      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      notifyListeners();
      return _lastPosition;
    } catch (e) {
      debugPrint('LocationService.getCurrentPosition error: $e');
      return null;
    }
  }

  // ── Distance ──────────────────────────────────────────────────────────────

  /// Returns distance in kilometres between two lat/lng points.
  double distanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Human-readable distance string, e.g. "1.2 km" or "850 m".
  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
