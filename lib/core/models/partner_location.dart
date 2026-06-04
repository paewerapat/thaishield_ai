import 'package:cloud_firestore/cloud_firestore.dart';

class PartnerLocation {
  const PartnerLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.rating,
    required this.isVerified,
    required this.priceTier,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type;
  final double rating;
  final bool isVerified;
  final String priceTier;
  final String imageUrl;

  factory PartnerLocation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PartnerLocation(
      id:          doc.id,
      name:        d['name'] ?? '',
      lat:         (d['lat'] as num?)?.toDouble() ?? 0,
      lng:         (d['lng'] as num?)?.toDouble() ?? 0,
      type:        d['type'] ?? 'restaurant',
      rating:      (d['rating'] as num?)?.toDouble() ?? 0,
      isVerified:  d['is_verified'] ?? false,
      priceTier:   d['price_tier'] ?? 'fair',
      imageUrl:    d['image_url'] ?? '',
    );
  }
}
