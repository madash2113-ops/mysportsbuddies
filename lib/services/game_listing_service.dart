import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/models/game_listing.dart';
import '../core/models/player_entry.dart';
import 'notification_service.dart';
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
        .listen((snap) {
          _openGames
            ..clear()
            ..addAll(snap.docs.map(GameListing.fromFirestore));
          notifyListeners();
        }, onError: (e) => debugPrint('GameListingService error: $e'));
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<String?> uploadGamePhoto(File photo, String listingId) async {
    final ref = FirebaseStorage.instance.ref('game_photos/$listingId.jpg');
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
    double? latitude,
    double? longitude,
  }) async {
    final svc = UserService();
    final myId = svc.userId ?? '';
    final myName = svc.profile?.name ?? 'Player';
    final myImg = svc.profile?.imageUrl;

    final docRef = _db.collection(_col).doc();
    final listing = GameListing(
      id: docRef.id,
      organizerId: myId,
      organizerName: myName,
      organizerImageUrl: myImg,
      venueId: venueId,
      venueName: venueName,
      address: address,
      sport: sport,
      scheduledAt: scheduledAt,
      maxPlayers: maxPlayers,
      playerIds: [myId],
      playerNames: [myName],
      splitCost: splitCost,
      totalCost: totalCost,
      status: GameListingStatus.open,
      note: note,
      photoUrl: photoUrl,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );
    await docRef.set(listing.toMap());
    final existingIndex = _openGames.indexWhere((g) => g.id == listing.id);
    if (existingIndex == -1) {
      _openGames.add(listing);
      _openGames.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } else {
      _openGames[existingIndex] = listing;
    }
    notifyListeners();
    return listing;
  }

  Future<void> joinListing(GameListing listing) async {
    final svc = UserService();
    final myId = svc.userId ?? '';
    final myName = svc.profile?.name ?? 'Player';

    if (listing.playerIds.contains(myId)) return;
    if (listing.isFull) return;
    await addPlayers(listing, [
      PlayerEntry(
        entryId: myId,
        isRegistered: true,
        displayName: myName,
        userId: myId,
        imageUrl: svc.profile?.imageUrl,
        numericId: svc.profile?.numericId,
        email: svc.profile?.email,
        phone: svc.profile?.phone,
      ),
    ], actorName: myName);
  }

  Future<void> addPlayers(
    GameListing listing,
    List<PlayerEntry> players, {
    required String actorName,
  }) async {
    if (listing.isFull || players.isEmpty) return;

    final newIds = [...listing.playerIds];
    final newNames = [...listing.playerNames];
    final available = listing.maxPlayers - newIds.length;
    final added = <PlayerEntry>[];

    for (final player in players) {
      if (added.length >= available) break;
      final id = player.userId ?? player.entryId;
      final name = player.displayName.trim();
      if (id.isEmpty || name.isEmpty) continue;
      if (newIds.contains(id)) continue;
      if (!player.isRegistered && newNames.contains(name)) continue;
      newIds.add(id);
      newNames.add(name);
      added.add(player);
    }

    if (added.isEmpty) return;

    final status = newIds.length >= listing.maxPlayers
        ? GameListingStatus.full
        : GameListingStatus.open;

    await _db.collection(_col).doc(listing.id).update({
      'playerIds': newIds,
      'playerNames': newNames,
      'status': status.name,
    });

    _replaceLocal(_copyListing(listing, newIds, newNames, status));
    await _notifyPlayersAdded(listing, added, actorName: actorName);
  }

  Future<void> leaveListing(GameListing listing) async {
    final myId = UserService().userId ?? '';
    if (listing.organizerId == myId) {
      return; // organizer can't leave, only cancel
    }

    final newIds = listing.playerIds.where((id) => id != myId).toList();
    final newNames = <String>[];
    for (int i = 0; i < listing.playerIds.length; i++) {
      if (listing.playerIds[i] != myId) {
        newNames.add(listing.playerNames[i]);
      }
    }

    await _db.collection(_col).doc(listing.id).update({
      'playerIds': newIds,
      'playerNames': newNames,
      'status': GameListingStatus.open.name,
    });
    _replaceLocal(
      _copyListing(listing, newIds, newNames, GameListingStatus.open),
    );
  }

  Future<void> cancelListing(String listingId) async {
    await _db.collection(_col).doc(listingId).update({
      'status': GameListingStatus.cancelled.name,
    });
    _openGames.removeWhere((g) => g.id == listingId);
    notifyListeners();
  }

  void _replaceLocal(GameListing listing) {
    final index = _openGames.indexWhere((g) => g.id == listing.id);
    if (index == -1) return;
    _openGames[index] = listing;
    notifyListeners();
  }

  GameListing _copyListing(
    GameListing listing,
    List<String> playerIds,
    List<String> playerNames,
    GameListingStatus status,
  ) {
    return GameListing(
      id: listing.id,
      organizerId: listing.organizerId,
      organizerName: listing.organizerName,
      organizerImageUrl: listing.organizerImageUrl,
      venueId: listing.venueId,
      venueName: listing.venueName,
      address: listing.address,
      sport: listing.sport,
      scheduledAt: listing.scheduledAt,
      maxPlayers: listing.maxPlayers,
      playerIds: playerIds,
      playerNames: playerNames,
      splitCost: listing.splitCost,
      totalCost: listing.totalCost,
      status: status,
      note: listing.note,
      photoUrl: listing.photoUrl,
      latitude: listing.latitude,
      longitude: listing.longitude,
      createdAt: listing.createdAt,
    );
  }

  Future<void> _notifyPlayersAdded(
    GameListing listing,
    List<PlayerEntry> added, {
    required String actorName,
  }) async {
    final actorId = UserService().userId ?? '';
    final addedNames = added.map((p) => p.displayName).join(', ');
    final gameName = listing.venueName.isNotEmpty
        ? listing.venueName
        : '${listing.sport} game';

    final recipients = <String>{listing.organizerId, ...listing.playerIds}
      ..removeWhere((id) => id.isEmpty || id == actorId);

    for (final userId in recipients) {
      await NotificationService.send(
        toUserId: userId,
        type: NotifType.rsvpUpdate,
        title: 'Player joined game',
        body: '$actorName added $addedNames to $gameName.',
        targetId: listing.id,
      );
    }

    for (final player in added) {
      final userId = player.userId;
      if (userId == null || userId.isEmpty || userId == actorId) continue;
      await NotificationService.send(
        toUserId: userId,
        type: NotifType.gameInvite,
        title: 'You were added to a game',
        body: '$actorName added you to $gameName.',
        targetId: listing.id,
      );
    }
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
