import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/travel_alert.dart';

/// Reads Thailand travel-disruption alerts (floods, storms, fires, road
/// closures, major accidents, etc.) from the `travel_alerts_cache`
/// Firestore collection.
///
/// The collection is populated by the scheduled `syncTravelAlerts` Cloud
/// Function (see `functions/index.js`), which polls newsdata.io every 15
/// minutes and writes the shared result once for every app install to
/// read — this keeps the whole user base within newsdata.io's free-tier
/// allowance of 200 credits/day, instead of each device calling the news API
/// on its own.
///
/// The function filters for Thai places and disruption words before writing,
/// but the client filters again in `TravelAlert.category`: the cache holds up
/// to a week of stories, so a rule tightened today still has yesterday's
/// documents to contend with.
class TravelAlertService {
  TravelAlertService._();
  static final TravelAlertService instance = TravelAlertService._();

  static const _collection = 'travel_alerts_cache';

  Future<List<TravelAlert>> fetchAlerts() async {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    final snap = await FirebaseFirestore.instance
        .collection(_collection)
        .where('published_at', isGreaterThan: cutoff)
        .orderBy('published_at', descending: true)
        .get();
    return snap.docs.map(TravelAlert.fromFirestore).toList();
  }
}
