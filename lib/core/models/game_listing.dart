import 'package:cloud_firestore/cloud_firestore.dart';

enum GameListingStatus { open, full, cancelled, completed }

class GameListing {
  final String id;
  final String organizerId;
  final String organizerName;
  final String? organizerImageUrl;
  final String? venueId;
  final String venueName;
  final String address;
  final String sport;
  final DateTime scheduledAt;
  final int maxPlayers;
  final List<String> playerIds;
  final List<String> playerNames;
  final bool splitCost;
  final double totalCost;
  final GameListingStatus status;
  final String? note;
  final DateTime createdAt;

  const GameListing({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    this.organizerImageUrl,
    this.venueId,
    this.venueName = '',
    this.address = '',
    required this.sport,
    required this.scheduledAt,
    required this.maxPlayers,
    this.playerIds = const [],
    this.playerNames = const [],
    this.splitCost = false,
    this.totalCost = 0,
    this.status = GameListingStatus.open,
    this.note,
    required this.createdAt,
  });

  /// Cost each joining player owes (0 if no split).
  double get costPerPlayer =>
      splitCost && maxPlayers > 1 ? totalCost / maxPlayers : 0;

  int get spotsLeft => maxPlayers - playerIds.length;
  bool get isFull   => playerIds.length >= maxPlayers;

  Map<String, dynamic> toMap() => {
        'id':                id,
        'organizerId':       organizerId,
        'organizerName':     organizerName,
        'organizerImageUrl': organizerImageUrl,
        'venueId':           venueId,
        'venueName':         venueName,
        'address':           address,
        'sport':             sport,
        'scheduledAt':       Timestamp.fromDate(scheduledAt),
        'maxPlayers':        maxPlayers,
        'playerIds':         playerIds,
        'playerNames':       playerNames,
        'splitCost':         splitCost,
        'totalCost':         totalCost,
        'status':            status.name,
        'note':              note,
        'createdAt':         Timestamp.fromDate(createdAt),
      };

  factory GameListing.fromMap(Map<String, dynamic> m) => GameListing(
        id:                m['id']            as String? ?? '',
        organizerId:       m['organizerId']   as String? ?? '',
        organizerName:     m['organizerName'] as String? ?? '',
        organizerImageUrl: m['organizerImageUrl'] as String?,
        venueId:           m['venueId']       as String?,
        venueName:         m['venueName']     as String? ?? '',
        address:           m['address']       as String? ?? '',
        sport:             m['sport']         as String? ?? '',
        scheduledAt: m['scheduledAt'] != null
            ? (m['scheduledAt'] as Timestamp).toDate()
            : DateTime.now(),
        maxPlayers:  (m['maxPlayers']  as num?)?.toInt()    ?? 10,
        playerIds:   List<String>.from(m['playerIds']   as List? ?? []),
        playerNames: List<String>.from(m['playerNames'] as List? ?? []),
        splitCost:   m['splitCost']   as bool?   ?? false,
        totalCost:   (m['totalCost']  as num?)?.toDouble() ?? 0,
        status: GameListingStatus.values.firstWhere(
          (s) => s.name == (m['status'] as String? ?? 'open'),
          orElse: () => GameListingStatus.open,
        ),
        note:      m['note']      as String?,
        createdAt: m['createdAt'] != null
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory GameListing.fromFirestore(DocumentSnapshot doc) =>
      GameListing.fromMap(doc.data() as Map<String, dynamic>);
}
