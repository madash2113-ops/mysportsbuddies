import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/models/game.dart';

/// Game store backed by Cloud Firestore.
///
/// All writes go to Firestore AND mirror locally so the UI updates instantly.
class GameService extends ChangeNotifier {
  GameService._();
  static final GameService _instance = GameService._();
  factory GameService() => _instance;

  static const _col = 'games';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final List<Game> _games = [];

  // ── Read ─────────────────────────────────────────────────────────────────
  List<Game> get all {
    final sorted = [..._games];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<Game> bySport(String sport) => _games
      .where((g) => g.sport.toLowerCase() == sport.toLowerCase())
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<Game> byStatus(ParticipationStatus status) =>
      _games.where((g) => g.status == status).toList();

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Add a new game locally and persist to Firestore.
  Future<void> addGame(Game game) async {
    _games.add(game);
    notifyListeners();

    try {
      await _db.collection(_col).doc(game.id).set(game.toMap());
    } catch (e) {
      debugPrint('GameService.addGame Firestore error: $e');
    }
  }

  /// Replace an existing game (edit). Matches by ID.
  Future<void> updateGame(Game game) async {
    final idx = _games.indexWhere((g) => g.id == game.id);
    if (idx < 0) return;
    _games[idx] = game;
    notifyListeners();

    try {
      await _db.collection(_col).doc(game.id).set(game.toMap());
    } catch (e) {
      debugPrint('GameService.updateGame Firestore error: $e');
    }
  }

  /// Update only the RSVP status for a game (opt in / out / tentative).
  Future<void> updateGameStatus(
      String id, ParticipationStatus status) async {
    final idx = _games.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    _games[idx] = _games[idx].copyWith(status: status);
    notifyListeners();

    try {
      await _db.collection(_col).doc(id).update({'status': status.name});
    } catch (e) {
      debugPrint('GameService.updateGameStatus Firestore error: $e');
    }
  }

  /// Delete a game locally and from Firestore.
  Future<void> deleteGame(String id) async {
    _games.removeWhere((g) => g.id == id);
    notifyListeners();
    try {
      await _db.collection(_col).doc(id).delete();
    } catch (e) {
      debugPrint('GameService.deleteGame Firestore error: $e');
    }
  }

  /// Upload a photo for a game, store in Firebase Storage and update Firestore.
  /// Returns the download URL.
  Future<String> uploadGamePhoto(String gameId, File image) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('game_photos/$gameId/$timestamp.jpg');
    await ref.putFile(image);
    final url = await ref.getDownloadURL();

    // Append URL to photoUrls array in Firestore
    await _db.collection(_col).doc(gameId).update({
      'photoUrls': FieldValue.arrayUnion([url]),
    });

    // Update local cache
    final idx = _games.indexWhere((g) => g.id == gameId);
    if (idx >= 0) {
      final updated = List<String>.from(_games[idx].photoUrls)..add(url);
      _games[idx] = _games[idx].copyWith(photoUrls: updated);
      notifyListeners();
    }
    return url;
  }

  // ── Sync from Firestore ────────────────────────────────────────────────────

  /// Call once on app startup (after Firebase.initializeApp) to load saved games.
  Future<void> loadFromFirestore() async {
    try {
      final snap = await _db
          .collection(_col)
          .orderBy('createdAt', descending: true)
          .get();
      final remote = snap.docs.map(Game.fromFirestore).toList();
      _games
        ..clear()
        ..addAll(remote);
      notifyListeners();
    } catch (e) {
      debugPrint('GameService.loadFromFirestore error: $e');
    }
  }

  /// Real-time stream listener — call once to keep games live.
  void listenToFirestore() {
    _db
        .collection(_col)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      _games
        ..clear()
        ..addAll(snap.docs.map(Game.fromFirestore));
      notifyListeners();
    });
  }
}
