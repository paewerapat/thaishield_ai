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
    this.nameTh = '',
    this.nameZh = '',
    this.nameKo = '',
    this.nameRu = '',
    this.nameJa = '',
    this.descriptionZh = '',
    this.descriptionKo = '',
    this.descriptionRu = '',
    this.descriptionJa = '',
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

  /// Added 2026-08-29. Zones written before then have none of these, and the
  /// CMS does not force staff to backfill, so they default to empty and fall
  /// back to English rather than showing a blank advisory.
  final String descriptionZh;
  final String descriptionKo;
  final String descriptionRu;
  final String descriptionJa;


  /// Optional official names. Empty is the normal case — see [localizedName].
  final String nameTh;
  final String nameZh;
  final String nameKo;
  final String nameRu;
  final String nameJa;

  final List<LatLng> polygon;


  /// The place's name in the reader's language, falling back to [name].
  ///
  /// Unlike the advisory text, these are **optional in the CMS**: a business
  /// name usually has no translation, and forcing six would produce either the
  /// English copied five times or — worse — an invented name for a real
  /// business. They are filled only where an official name exists in that
  /// language (Siam Square as 暹罗广场), and [name] carries every other case.
  String localizedName(String langCode) {
    final byLang = {
      'th': nameTh,
      'zh': nameZh,
      'ko': nameKo,
      'ru': nameRu,
      'ja': nameJa,
    };
    final own = byLang[langCode];
    if (own != null && own.trim().isNotEmpty) return own;
    return name;
  }

  /// The description in the reader's language, falling back to English.
  ///
  /// This text is the one thing on the map a tourist reads as advice about a
  /// real place, so an untranslated zone shows the English a staff member
  /// actually wrote rather than an empty card — English they may not read is
  /// still better than nothing where an advisory should be.
  String localizedDescription(String langCode) {
    final byLang = {
      'th': descriptionTh,
      'zh': descriptionZh,
      'ko': descriptionKo,
      'ru': descriptionRu,
      'ja': descriptionJa,
    };
    final own = byLang[langCode];
    if (own != null && own.trim().isNotEmpty) return own;
    return descriptionEn;
  }

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
      nameTh:           d['name_th'] ?? '',
      nameZh:           d['name_zh'] ?? '',
      nameKo:           d['name_ko'] ?? '',
      nameRu:           d['name_ru'] ?? '',
      nameJa:           d['name_ja'] ?? '',
      descriptionZh:    d['description_zh'] ?? '',
      descriptionKo:    d['description_ko'] ?? '',
      descriptionRu:    d['description_ru'] ?? '',
      descriptionJa:    d['description_ja'] ?? '',
      polygon: polygonRaw
              ?.whereType<GeoPoint>()
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList() ??
          const [],
    );
  }
}
