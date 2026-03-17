import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/models/game_listing.dart';
import 'user_service.dart';

class GameListingService extends ChangeNotifier {
  GameListingService._();
  static final GameListingService _instance = GameListingService._();
  factory GameListingService() => _instance;

  static const _col = 'game_listings';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final List<GameListing> _openGames = [];
  List<GameListing> get openGames => List.unmodifiable(_openGames);

  // ── Listener ───────────────────────────────────────────────────────────────

  void listenToOpenGames() {
    _db
        .collection(_col)
        .where('status', isEqualTo: GameListingStatus.open.name)
        .orderBy('scheduledAt')
        .snapshots()
        .listen(
          (snap) {
            _openGames
              ..clear()
              ..addAll(snap.docs.map(GameListing.fromFirestore));
            notifyListeners();
          },
          onError: (e) => debugPrint('GameListingService error: $e'),
        );
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<String?> uploadGamePhoto(File photo, String listingId) async {
    final ref = FirebaseStorage.instance
        .ref('game_photos/$listingId.jpg');
    await ref.putFile(photo);
    return ref.getDownloadURL();
  }

  Future<GameListing> createListing({
    required String sport,
    required DateTime scheduledAt,
    required int maxPlayers,
    required bool splitCost,
    required double totalCost,
    String? venueId,
    String venueName = '',
    String address = '',
    String? note,
    String? photoUrl,
  }) async {
    final svc    = UserService();
    final myId   = svc.userId ?? '';
    final myName = svc.profile?.name ?? 'Player';
    final myImg  = svc.profile?.imageUrl;

    final docRef = _db.collection(_col).doc();
    final listing = GameListing(
      id:                docRef.id,
      organizerId:       myId,
      organizerName:     myName,
      organizerImageUrl: myImg,
      venueId:           venueId,
      venueName:         venueName,
      address:           address,
      sport:             sport,
      scheduledAt:       scheduledAt,
      maxPlayers:        maxPlayers,
      playerIds:         [myId],
      playerNames:       [myName],
      splitCost:         splitCost,
      totalCost:         totalCost,
      status:            GameListingStatus.open,
      note:              note,
      photoUrl:          photoUrl,
      createdAt:         DateTime.now(),
    );
    await docRef.set(listing.toMap());
    return listing;
  }

  Future<void> joinListing(GameListing listing) async {
    final svc    = UserService();
    final myId   = svc.userId ?? '';
    final myName = svc.profile?.name ?? 'Player';

    if (listing.playerIds.contains(myId)) return;
    if (listing.isFull) return;

    final newIds   = [...listing.playerIds,   myId];
    final newNames = [...listing.playerNames, myName];
    final newStatus = newIds.length >= listing.maxPlayers
        ? GameListingStatus.full.name
        : GameListingStatus.open.name;

    await _db.collection(_col).doc(listing.id).update({
      'playerIds':   newIds,
      'playerNames': newNames,
      'status':      newStatus,
    });
  }

  Future<void> leaveListing(GameListing listing) async {
    final myId = UserService().userId ?? '';
    if (listing.organizerId == myId) return; // organizer can't leave, only cancel

    final newIds   = listing.playerIds.where((id) => id != myId).toList();
    final newNames = <String>[];
    for (int i = 0; i < listing.playerIds.length; i++) {
      if (listing.playerIds[i] != myId) newNames.add(listing.playerNames[i]);
    }

    await _db.collection(_col).doc(listing.id).update({
      'playerIds':   newIds,
      'playerNames': newNames,
      'status':      GameListingStatus.open.name,
    });
  }

  Future<void> cancelListing(String listingId) async {
    await _db.collection(_col).doc(listingId).update({
      'status': GameListingStatus.cancelled.name,
    });
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  List<GameListing> bySport(String sport) =>
      _openGames.where((g) => g.sport == sport).toList();

  List<GameListing> get myGames {
    final myId = UserService().userId ?? '';
    return _openGames.where((g) => g.playerIds.contains(myId)).toList();
  }

  bool hasJoined(GameListing listing) {
    final myId = UserService().userId ?? '';
    return listing.playerIds.contains(myId);
  }
}
