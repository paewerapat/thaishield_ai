import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_zone.dart';
import '../models/partner_location.dart';
import '../models/price_standard.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  Future<List<PriceStandard>> getPriceStandards({String? category}) async {
    Query query = _db.collection('price_standards');
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    final snap = await query.get();
    return snap.docs.map(PriceStandard.fromFirestore).toList();
  }

  Future<List<PartnerLocation>> getPartnerLocations() async {
    final snap = await _db.collection('partner_locations').get();
    return snap.docs.map(PartnerLocation.fromFirestore).toList();
  }

  Future<List<AlertZone>> getAlertZones() async {
    final snap = await _db.collection('alert_zones').get();
    return snap.docs.map(AlertZone.fromFirestore).toList();
  }

  // Phase 3: match scanned price against standard
  Future<PriceStandard?> findPriceStandard(String keyword) async {
    final snap = await _db
        .collection('price_standards')
        .where('name_en', isGreaterThanOrEqualTo: keyword)
        .where('name_en', isLessThan: '${keyword}z')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PriceStandard.fromFirestore(snap.docs.first);
  }
}
