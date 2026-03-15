import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedPostType { manual, scoreCard }

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? userImageUrl;
  final String text;
  final String? imageUrl;
  final String? sport;
  final int likes;
  final bool likedByMe;
  final List<String> likedBy; // UIDs who liked — persisted in Firestore
  final int commentCount;
  final DateTime createdAt;
  final FeedPostType type;

  const FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImageUrl,
    required this.text,
    this.imageUrl,
    this.sport,
    this.likes = 0,
    this.likedByMe = false,
    this.likedBy = const [],
    this.commentCount = 0,
    required this.createdAt,
    this.type = FeedPostType.manual,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userImageUrl': userImageUrl,
        'text': text,
        'imageUrl': imageUrl,
        'sport': sport,
        'likes': likes,
        'likedBy': likedBy,
        'commentCount': commentCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'type': type.name,
      };

  factory FeedPost.fromMap(Map<String, dynamic> map, {String? myUserId}) {
    final likedBy = List<String>.from(map['likedBy'] as List? ?? []);
    return FeedPost(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Anonymous',
      userImageUrl: map['userImageUrl'] as String?,
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      sport: map['sport'] as String?,
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      likedBy: likedBy,
      likedByMe: myUserId != null && likedBy.contains(myUserId),
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      type: FeedPostType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FeedPostType.manual,
      ),
    );
  }

  factory FeedPost.fromFirestore(DocumentSnapshot doc, {String? myUserId}) =>
      FeedPost.fromMap(doc.data() as Map<String, dynamic>, myUserId: myUserId);

  FeedPost copyWith({
    String? imageUrl,
    int? likes,
    bool? likedByMe,
    List<String>? likedBy,
    int? commentCount,
  }) =>
      FeedPost(
        id: id,
        userId: userId,
        userName: userName,
        userImageUrl: userImageUrl,
        text: text,
        imageUrl: imageUrl,
        sport: sport,
        likes: likes ?? this.likes,
        likedByMe: likedByMe ?? this.likedByMe,
        likedBy: likedBy ?? this.likedBy,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt,
        type: type,
      );
}
