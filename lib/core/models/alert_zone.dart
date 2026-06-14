import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AlertZone {
  const AlertZone({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    required this.riskLevel,
    required this.descriptionEn,
    required this.descriptionTh,
    this.polygon = const [],
  });

  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final String riskLevel;
  final String descriptionEn;
  final String descriptionTh;
  final List<LatLng> polygon;

  String localizedDescription(String langCode) =>
      langCode == 'th' ? descriptionTh : descriptionEn;

  factory AlertZone.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final polygonRaw = d['polygon'] as List<dynamic>?;
    return AlertZone(
      id:               doc.id,
      name:             d['name'] ?? '',
      centerLat:        (d['center_lat'] as num?)?.toDouble() ?? 0,
      centerLng:        (d['center_lng'] as num?)?.toDouble() ?? 0,
      radiusKm:         (d['radius_km'] as num?)?.toDouble() ?? 1,
      riskLevel:        d['risk_level'] ?? 'safe',
      descriptionEn:    d['description_en'] ?? '',
      descriptionTh:    d['description_th'] ?? '',
      polygon: polygonRaw
              ?.whereType<GeoPoint>()
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList() ??
          const [],
    );
  }
}
