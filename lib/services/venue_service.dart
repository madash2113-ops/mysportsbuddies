import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/models/venue_model.dart';
import 'user_service.dart';

class VenueService extends ChangeNotifier {
  VenueService._();
  static final VenueService _instance = VenueService._();
  factory VenueService() => _instance;

  static const _col = 'venues';

  FirebaseFirestore get _db      => FirebaseFirestore.instance;
  FirebaseStorage   get _storage => FirebaseStorage.instanceFor(
    bucket: 'gs://mysportsbuddies-4d077.firebasestorage.app',
  );

  // ── State ──────────────────────────────────────────────────────────────────
  final List<VenueModel> _venues   = [];
  final List<VenueModel> _myVenues = [];

  List<VenueModel> get venues   => List.unmodifiable(_venues);
  List<VenueModel> get myVenues => List.unmodifiable(_myVenues);

  // ── Listeners ──────────────────────────────────────────────────────────────

  /// Listen to all active/verified venues (player-facing).
  void listenToVenues() {
    _db
        .collection(_col)
        .where('status', isEqualTo: VenueStatus.active.name)
        .snapshots()
        .listen(
      (snap) {
        _venues
          ..clear()
          ..addAll(snap.docs.map(VenueModel.fromFirestore));
        notifyListeners();
      },
      onError: (e) => debugPrint('VenueService.listenToVenues error: $e'),
    );
  }

  /// Listen to venues owned by the current merchant.
  void listenToMyVenues() {
    final myId = UserService().userId;
    if (myId == null) return;
    _db
        .collection(_col)
        .where('ownerId', isEqualTo: myId)
        .snapshots()
        .listen(
      (snap) {
        _myVenues
          ..clear()
          ..addAll(snap.docs.map(VenueModel.fromFirestore));
        notifyListeners();
      },
      onError: (e) => debugPrint('VenueService.listenToMyVenues error: $e'),
    );
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<VenueModel> registerVenue({
    required String name,
    required String description,
    required String address,
    required double lat,
    required double lng,
    required List<String> sports,
    required String phone,
    required String email,
    required double pricePerHour,
    required Map<String, String> timings,
  }) async {
    final myId  = UserService().userId ?? 'unknown';
    final docRef = _db.collection(_col).doc();
    final venue = VenueModel(
      id:           docRef.id,
      ownerId:      myId,
      name:         name,
      description:  description,
      address:      address,
      lat:          lat,
      lng:          lng,
      sports:       sports,
      phone:        phone,
      email:        email,
      pricePerHour: pricePerHour,
      timings:      timings,
      status:       VenueStatus.pending,
      createdAt:    DateTime.now(),
    );
    await docRef.set(venue.toMap());
    _myVenues.insert(0, venue);
    notifyListeners();
    return venue;
  }

  Future<void> updateVenue(VenueModel venue) async {
    await _db.collection(_col).doc(venue.id).set(venue.toMap());
    final idx = _myVenues.indexWhere((v) => v.id == venue.id);
    if (idx >= 0) {
      _myVenues[idx] = venue;
      notifyListeners();
    }
  }

  Future<void> deleteVenue(String venueId) async {
    await _db.collection(_col).doc(venueId).delete();
    _myVenues.removeWhere((v) => v.id == venueId);
    notifyListeners();
  }

  // ── Photo upload ───────────────────────────────────────────────────────────

  Future<String> uploadVenuePhoto(String venueId, Uint8List bytes) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('venue_images').child(venueId).child(fileName);
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> addPhotoToVenue(String venueId, String photoUrl) async {
    await _db.collection(_col).doc(venueId).update({
      'photoUrls': FieldValue.arrayUnion([photoUrl]),
    });
    final idx = _myVenues.indexWhere((v) => v.id == venueId);
    if (idx >= 0) {
      _myVenues[idx] = _myVenues[idx].copyWith(
        photoUrls: [..._myVenues[idx].photoUrls, photoUrl],
      );
      notifyListeners();
    }
  }

  // ── Bookings ───────────────────────────────────────────────────────────────

  Future<void> requestBooking({
    required String venueId,
    required String venueName,
    required String date,
    required String slot,
    required String sport,
  }) async {
    final myId   = UserService().userId ?? '';
    final myName = UserService().profile?.name ?? 'Player';
    await _db.collection('venue_bookings').add({
      'venueId':   venueId,
      'venueName': venueName,
      'userId':    myId,
      'userName':  myName,
      'date':      date,
      'slot':      slot,
      'sport':     sport,
      'status':    'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> bookingsForVenue(String venueId) {
    return _db
        .collection('venue_bookings')
        .where('venueId', isEqualTo: venueId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> myBookings() {
    final myId = UserService().userId ?? '';
    return _db
        .collection('venue_bookings')
        .where('userId', isEqualTo: myId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await _db.collection('venue_bookings').doc(bookingId).update({
      'status': status,
    });
  }

  // ── Filter helpers ─────────────────────────────────────────────────────────

  List<VenueModel> nearbyVenues(double lat, double lng, {double radiusKm = 20}) {
    return _venues
        .where((v) => v.distanceTo(lat, lng) <= radiusKm)
        .toList()
      ..sort((a, b) =>
          a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
  }

  List<VenueModel> bySport(String sport) =>
      _venues.where((v) => v.sports.contains(sport)).toList();
}
