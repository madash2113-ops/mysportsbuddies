import 'package:cloud_firestore/cloud_firestore.dart';

enum VenueStatus { pending, active, inactive }

class VenueModel {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String address;
  final double lat;
  final double lng;
  final List<String> sports;
  final List<String> photoUrls;
  final String phone;
  final String email;
  final double pricePerHour;
  final Map<String, String> timings; // e.g. {'Mon': '6am–10pm'}
  final VenueStatus status;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;

  const VenueModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    required this.address,
    required this.lat,
    required this.lng,
    this.sports = const [],
    this.photoUrls = const [],
    this.phone = '',
    this.email = '',
    this.pricePerHour = 0,
    this.timings = const {},
    this.status = VenueStatus.pending,
    this.isVerified = false,
    this.rating = 0,
    this.reviewCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'description': description,
        'address': address,
        'lat': lat,
        'lng': lng,
        'sports': sports,
        'photoUrls': photoUrls,
        'phone': phone,
        'email': email,
        'pricePerHour': pricePerHour,
        'timings': timings,
        'status': status.name,
        'isVerified': isVerified,
        'rating': rating,
        'reviewCount': reviewCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory VenueModel.fromMap(Map<String, dynamic> map) => VenueModel(
        id: map['id'] as String? ?? '',
        ownerId: map['ownerId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        address: map['address'] as String? ?? '',
        lat: (map['lat'] as num?)?.toDouble() ?? 0,
        lng: (map['lng'] as num?)?.toDouble() ?? 0,
        sports: List<String>.from(map['sports'] as List? ?? []),
        photoUrls: List<String>.from(map['photoUrls'] as List? ?? []),
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        pricePerHour: (map['pricePerHour'] as num?)?.toDouble() ?? 0,
        timings: Map<String, String>.from(map['timings'] as Map? ?? {}),
        status: VenueStatus.values.firstWhere(
          (s) => s.name == (map['status'] as String? ?? 'pending'),
          orElse: () => VenueStatus.pending,
        ),
        isVerified: map['isVerified'] as bool? ?? false,
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
        createdAt: map['createdAt'] != null
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  factory VenueModel.fromFirestore(DocumentSnapshot doc) =>
      VenueModel.fromMap(doc.data() as Map<String, dynamic>);

  VenueModel copyWith({
    String? name,
    String? description,
    String? address,
    double? lat,
    double? lng,
    List<String>? sports,
    List<String>? photoUrls,
    String? phone,
    String? email,
    double? pricePerHour,
    Map<String, String>? timings,
    VenueStatus? status,
    bool? isVerified,
    double? rating,
    int? reviewCount,
  }) =>
      VenueModel(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        description: description ?? this.description,
        address: address ?? this.address,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        sports: sports ?? this.sports,
        photoUrls: photoUrls ?? this.photoUrls,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        pricePerHour: pricePerHour ?? this.pricePerHour,
        timings: timings ?? this.timings,
        status: status ?? this.status,
        isVerified: isVerified ?? this.isVerified,
        rating: rating ?? this.rating,
        reviewCount: reviewCount ?? this.reviewCount,
        createdAt: createdAt,
      );

  /// Distance in km from [lat2],[lng2] (Haversine approximation).
  double distanceTo(double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat);
    final dLng = _rad(lng2 - lng);
    final a = _sin2(dLat / 2) +
        _cos(lat) * _cos(lat2) * _sin2(dLng / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  static double _rad(double deg) => deg * 3.14159265358979 / 180;
  static double _sin2(double x) => _sin(x) * _sin(x);
  static double _sin(double x) => x - x * x * x / 6;
  static double _cos(double x) => 1 - x * x / 2;
  static double _asin(double x) => x + x * x * x / 6;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) { r = (r + x / r) / 2; }
    return r;
  }
}
