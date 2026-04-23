import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A utility class to generate dummy data for testing the MySportsBuddies web app.
class TestDataGenerator {
  static const List<String> _teamSuffixes = [
    'Titans', 'Warriors', 'Strikers', 'Kings', 'United', 'Eagles', 'Panthers', 
    'Wolves', 'Stars', 'Hawks', 'Bulls', 'Blaze', 'Storm', 'Raiders', 'Knights'
  ];

  /// Creates a dummy tournament and populates it with 30 dummy teams.
  /// [hostUserId] should be your Firebase UID (refer to TEST_ACCOUNTS.md).
  static Future<String?> hostDummyTournament(String hostUserId) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final WriteBatch batch = db.batch();
    final Random random = Random();

    try {
      // 1. Create the Tournament Document
      final tournamentRef = db.collection('tournaments').doc();
      final tournamentId = tournamentRef.id;

      final tournamentData = {
        'name': 'Elite Web Test Tournament 2026',
        'sport': 'Football',
        'isPrivate': false,
        'createdBy': hostUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'A massive tournament created for testing the web dashboard and search features.',
        'location': 'Digital Arena',
        'status': 'open',
        'maxTeams': 32,
      };

      batch.set(tournamentRef, tournamentData);

      // 2. Create 30 Dummy Teams in a subcollection
      for (int i = 1; i <= 30; i++) {
        final teamRef = tournamentRef.collection('teams').doc();
        final suffix = _teamSuffixes[random.nextInt(_teamSuffixes.length)];
        
        batch.set(teamRef, {
          'id': teamRef.id,
          'name': 'Team $i $suffix',
          'shortName': 'T$i',
          'imageUrl': 'https://api.dicebear.com/7.x/initials/svg?seed=T$i',
          'captainId': hostUserId, // Placeholder captain
          'registeredAt': FieldValue.serverTimestamp(),
          'points': 0,
          'played': 0,
          'matches': [],
        });
      }

      await batch.commit();
      print('Successfully hosted tournament $tournamentId with 30 teams.');
      return tournamentId;
    } catch (e) {
      print('Error generating test data: $e');
      return null;
    }
  }
}