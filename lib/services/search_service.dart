import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchResult {
  final String type; // 'user' | 'tournament' | 'game' | 'venue'
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });
}

class SearchService extends ChangeNotifier {
  SearchService._();
  static final SearchService _instance = SearchService._();
  factory SearchService() => _instance;

  List<SearchResult> results = [];
  bool loading = false;
  String _lastQuery = '';
  int _generation = 0;

  String get lastQuery => _lastQuery;

  Future<void> search(String query) async {
    final q = query.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.length < 2) {
      results = [];
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    final gen = ++_generation;
    final end = q.substring(0, q.length - 1) +
        String.fromCharCode(q.codeUnitAt(q.length - 1) + 1);
    final db = FirebaseFirestore.instance;
    try {
      final futures = await Future.wait([
        db
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThan: end)
            .limit(5)
            .get(),
        db
            .collection('tournaments')
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThan: end)
            .limit(5)
            .get(),
        db
            .collection('games')
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThan: end)
            .limit(5)
            .get(),
        db
            .collection('venues')
            .where('name', isGreaterThanOrEqualTo: q)
            .where('name', isLessThan: end)
            .limit(5)
            .get(),
      ]);
      if (gen != _generation) return; // superseded — discard stale response
      const types = ['user', 'tournament', 'game', 'venue'];
      final newResults = <SearchResult>[];
      for (int i = 0; i < futures.length; i++) {
        for (final doc in futures[i].docs) {
          final d = doc.data();
          newResults.add(SearchResult(
            type: types[i],
            id: doc.id,
            title: (d['name'] as String?) ?? '',
            subtitle: _subtitle(types[i], d),
            imageUrl: (d['imageUrl'] as String?) ??
                (d['photoUrl'] as String?) ??
                ((d['photoUrls'] as List?)?.firstOrNull as String?),
          ));
        }
      }
      results = newResults;
    } catch (_) {
      if (gen != _generation) return;
      results = [];
    }
    loading = false;
    notifyListeners();
  }

  void clear() {
    results = [];
    _lastQuery = '';
    loading = false;
    notifyListeners();
  }

  String _subtitle(String type, Map<String, dynamic> d) {
    switch (type) {
      case 'user':
        return (d['sport'] as String?) ??
            (d['location'] as String?) ??
            'Player';
      case 'tournament':
        return (d['sport'] as String?) ?? 'Tournament';
      case 'game':
        return (d['sport'] as String?) ?? 'Game';
      case 'venue':
        return (d['location'] as String?) ?? 'Venue';
      default:
        return '';
    }
  }
}
