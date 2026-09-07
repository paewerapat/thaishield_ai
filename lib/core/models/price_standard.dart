import 'package:cloud_firestore/cloud_firestore.dart';

class PriceStandard {
  const PriceStandard({
    required this.id,
    required this.nameEn,
    required this.nameTh,
    required this.nameZh,
    required this.nameKo,
    required this.nameRu,
    required this.nameJa,
    required this.minPrice,
    required this.maxPrice,
    required this.category,
    required this.updatedAt,
    this.imageUrl = '',
    this.mtPending = const [],
  });

  final String id;
  final String nameEn;
  final String nameTh;
  final String nameZh;
  final String nameKo;
  final String nameRu;
  final String nameJa;
  final double minPrice;
  final double maxPrice;
  final String category;
  final DateTime updatedAt;
  final String imageUrl;

  /// Name fields (`name_ko`, …) the CMS filled by machine translation that no
  /// person has reviewed yet (added 2026-09-06, CMS `mt_pending`). Treated as
  /// absent by [localizedName], which then shows the English name — the same
  /// rule `AlertZone` applies to advisories.
  final List<String> mtPending;

  /// Parses the Firestore `mt_pending` value; see [AlertZone.mtPendingFrom].
  static List<String> mtPendingFrom(dynamic raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  double get avgPrice => (minPrice + maxPrice) / 2;

  /// The name in the reader's language, falling back to English when that
  /// language is blank or is a machine translation still pending review.
  String localizedName(String langCode) {
    final byLang = {
      'th': nameTh,
      'zh': nameZh,
      'ko': nameKo,
      'ru': nameRu,
      'ja': nameJa,
    };
    final own = byLang[langCode];
    if (own != null &&
        own.trim().isNotEmpty &&
        !mtPending.contains('name_$langCode')) {
      return own;
    }
    return nameEn;
  }

  factory PriceStandard.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PriceStandard(
      id:         doc.id,
      nameEn:     d['name_en'] ?? '',
      nameTh:     d['name_th'] ?? '',
      nameZh:     d['name_zh'] ?? '',
      nameKo:     d['name_ko'] ?? '',
      nameRu:     d['name_ru'] ?? '',
      nameJa:     d['name_ja'] ?? '',
      minPrice:   (d['min_price'] as num?)?.toDouble() ?? 0,
      maxPrice:   (d['max_price'] as num?)?.toDouble() ?? 0,
      category:   d['category'] ?? 'food',
      updatedAt:  (d['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl:   d['image_url'] ?? '',
      mtPending:  mtPendingFrom(d['mt_pending']),
    );
  }
}
