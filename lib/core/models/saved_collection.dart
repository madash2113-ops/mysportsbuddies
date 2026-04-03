import 'package:cloud_firestore/cloud_firestore.dart';

class SavedCollection {
  final String id;
  final String name;
  final List<String> postIds;
  final DateTime createdAt;

  const SavedCollection({
    required this.id,
    required this.name,
    required this.postIds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'postIds': postIds,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory SavedCollection.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SavedCollection(
      id: doc.id,
      name: d['name'] as String? ?? 'Saved',
      postIds: List<String>.from(d['postIds'] as List? ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
