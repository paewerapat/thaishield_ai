import 'package:cloud_firestore/cloud_firestore.dart';

import 'partner_category.dart';

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
    this.nameTh = '',
    this.nameZh = '',
    this.nameKo = '',
    this.nameRu = '',
    this.nameJa = '',
  });

  final String id;
  final String name;

  /// Optional official names. Empty is the normal case — see [localizedName].
  final String nameTh;
  final String nameZh;
  final String nameKo;
  final String nameRu;
  final String nameJa;

  /// The business's name in the reader's language, falling back to [name].
  ///
  /// Optional in the CMS on purpose: a business name usually has no
  /// translation, and requiring six would produce either the English copied
  /// five times or an invented name for a real business — which is precisely
  /// the kind of statement about an identified business the wording rules
  /// exist to prevent. Filled only where an official name exists.
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
  final double lat;
  final double lng;
  final String type;
  final double rating;
  final bool isVerified;

  /// `fair` | `caution` | `high`, or `''` when the document has none — which
  /// is how the CMS stores a place with no prices (since 2026-09-13). Read
  /// [showsPriceTier] rather than comparing this directly.
  final String priceTier;
  final String imageUrl;

  /// `type` resolved to one of the 11 documented categories (CLAUDE.md §3).
  /// Unrecognised strings fall back to `restaurant`.
  PartnerCategory get category => PartnerCategory.fromValue(type);

  /// Whether any price badge belongs on this place.
  bool get showsPriceTier =>
      category.hasPriceTier && _knownTiers.contains(priceTier);

  /// Only a stored `caution` or `high` is "above typical range". A blank or
  /// unknown value used to fall into this branch and put an orange price
  /// warning on places that have no prices.
  bool get isAboveTypicalRange => showsPriceTier && priceTier != 'fair';

  static const _knownTiers = {'fair', 'caution', 'high'};

  factory PartnerLocation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PartnerLocation(
      id:          doc.id,
      name:        d['name'] ?? '',
      nameTh:      d['name_th'] ?? '',
      nameZh:      d['name_zh'] ?? '',
      nameKo:      d['name_ko'] ?? '',
      nameRu:      d['name_ru'] ?? '',
      nameJa:      d['name_ja'] ?? '',
      lat:         (d['lat'] as num?)?.toDouble() ?? 0,
      lng:         (d['lng'] as num?)?.toDouble() ?? 0,
      type:        d['type'] ?? 'restaurant',
      rating:      (d['rating'] as num?)?.toDouble() ?? 0,
      isVerified:  d['is_verified'] ?? false,
      priceTier:   d['price_tier'] ?? '',
      imageUrl:    d['image_url'] ?? '',
    );
  }
}
