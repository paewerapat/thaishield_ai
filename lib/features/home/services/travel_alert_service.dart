import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/travel_alert.dart';

/// Reads Thailand travel-disruption alerts (floods, storms, fires, road
/// closures, major accidents, etc.) from the `travel_alerts_cache`
/// Firestore collection.
///
/// The collection is populated by the scheduled `syncTravelAlerts` Cloud
/// Function (see `functions/index.js`), which polls the GNews API every 15
/// minutes and writes the shared result once for every app install to
/// read — this keeps the whole user base within GNews' free-tier quota of
/// 100 requests/day, instead of each device calling GNews on its own.
class TravelAlertService {
  TravelAlertService._();
  static final TravelAlertService instance = TravelAlertService._();

  static const _collection = 'travel_alerts_cache';

  Future<List<TravelAlert>> fetchAlerts() async {
    final snap = await FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('published_at', descending: true)
        .get();
    return snap.docs.map(TravelAlert.fromFirestore).toList();
  }
}
