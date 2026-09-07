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
    this.mtPending = const [],
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

  /// Field names (`description_ko`, …) whose text the CMS filled by machine
  /// translation and **no person has reviewed yet** (added 2026-09-06, CMS
  /// `mt_pending`). A pending translation is treated exactly like a blank one:
  /// the reader gets English. This is the whole safety argument for letting
  /// staff press "auto-translate" at all — the machine types, a human reads,
  /// and nothing reaches a tourist in between. Never show a pending field.
  final List<String> mtPending;

  bool _isPending(String field) => mtPending.contains(field);

  /// Parses the Firestore `mt_pending` value. Absent, null, or not a list all
  /// mean "nothing pending" — the state of every zone written before the field
  /// existed — and non-string entries are dropped rather than crashing a read.
  static List<String> mtPendingFrom(dynamic raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];


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
  ///
  /// A machine translation still waiting for review ([mtPending]) is treated
  /// as blank, so it also falls back to English. English itself is never
  /// pending in practice — staff type it — but if it ever were, it is still the
  /// only fallback there is, so it is returned regardless.
  String localizedDescription(String langCode) {
    final byLang = {
      'th': descriptionTh,
      'zh': descriptionZh,
      'ko': descriptionKo,
      'ru': descriptionRu,
      'ja': descriptionJa,
    };
    final own = byLang[langCode];
    if (own != null &&
        own.trim().isNotEmpty &&
        !_isPending('description_$langCode')) {
      return own;
    }
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
      mtPending:        mtPendingFrom(d['mt_pending']),
      polygon: polygonRaw
              ?.whereType<GeoPoint>()
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList() ??
          const [],
    );
  }
}
