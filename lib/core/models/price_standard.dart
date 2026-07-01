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

  double get avgPrice => (minPrice + maxPrice) / 2;

  String localizedName(String langCode) {
    switch (langCode) {
      case 'th': return nameTh;
      case 'zh': return nameZh;
      case 'ko': return nameKo;
      case 'ru': return nameRu;
      case 'ja': return nameJa;
      default:   return nameEn;
    }
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
    );
  }
}
