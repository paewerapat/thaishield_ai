// One-time helper to populate Firestore with sample data for Phase 2 testing.
// Run with:  flutter run -t lib/tools/seed_data.dart -d <device-id>
// Safe to delete this file after running it once.

import 'dart:math';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/utils/geo_utils.dart';
import '../firebase_options.dart';

// Builds an irregular hexagon of GeoPoints around a center point, used to
// render alert zones as area shapes on the map instead of plain circles.
//
// The multipliers reach 1.15, so `sizeKm` is the NOMINAL size of the shape,
// not its bounding radius — never store it as `radius_km`. Use [_zone] below,
// which derives the stored fields from the polygon it just drew.
List<GeoPoint> _polygonAround(double lat, double lng, double sizeKm) {
  final latOffset = sizeKm / 111;
  final lngOffset = sizeKm / (111 * cos(lat * pi / 180));
  const angles = [90.0, 150.0, 220.0, 270.0, 330.0, 30.0];
  const mults = [1.0, 0.75, 1.1, 0.85, 1.15, 0.9];
  return List.generate(angles.length, (i) {
    final rad = angles[i] * pi / 180;
    return GeoPoint(
      lat + latOffset * mults[i] * sin(rad),
      lng + lngOffset * mults[i] * cos(rad),
    );
  });
}

/// Area-weighted centroid (shoelace), planar — mirrors the CMS's
/// `computePolygonCentroid` in `lib/geo/polygon.ts`.
LatLng _centroidOf(List<GeoPoint> points) {
  var area = 0.0, cx = 0.0, cy = 0.0;
  for (var i = 0; i < points.length; i++) {
    final p0 = points[i];
    final p1 = points[(i + 1) % points.length];
    final cross = p0.longitude * p1.latitude - p1.longitude * p0.latitude;
    area += cross;
    cx += (p0.longitude + p1.longitude) * cross;
    cy += (p0.latitude + p1.latitude) * cross;
  }
  area /= 2;
  if (area.abs() < 1e-12) {
    final n = points.length;
    return LatLng(
      points.fold(0.0, (s, p) => s + p.latitude) / n,
      points.fold(0.0, (s, p) => s + p.longitude) / n,
    );
  }
  return LatLng(cy / (6 * area), cx / (6 * area));
}

/// Builds one `alert_zones` document, deriving `center_lat`/`center_lng`/
/// `radius_km` FROM the polygon exactly as the CMS does on every save.
///
/// These three used to be hard-coded beside the polygon, which left all seeded
/// zones ~13% short: the stored radius was the nominal size, but the polygon's
/// farthest vertex sits at 1.15× that. Since [isInsideZone] rejects on the
/// centre+radius circle BEFORE running the precise polygon test, a tourist
/// standing near a corner was discarded at the first gate — no Radar hit and
/// no proximity card. See INTEGRATION_TEST.md §F2.
Map<String, dynamic> _zone({
  required String name,
  required double lat,
  required double lng,
  required double sizeKm,
  required String riskLevel,
  required String descriptionEn,
  required String descriptionTh,
}) {
  final polygon = _polygonAround(lat, lng, sizeKm);
  final centre = _centroidOf(polygon);
  final radiusKm = polygon.fold<double>(
    0,
    (max, p) => math.max(max, distanceKm(centre, LatLng(p.latitude, p.longitude))),
  );
  return {
    'name': name,
    'polygon': polygon,
    'center_lat': centre.latitude,
    'center_lng': centre.longitude,
    'radius_km': radiusKm,
    'risk_level': riskLevel,
    'description_en': descriptionEn,
    'description_th': descriptionTh,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = FirebaseFirestore.instance;
  final result = await _seed(db);

  runApp(_SeedResultApp(message: result));
}

Future<String> _seed(FirebaseFirestore db) async {
  try {
    final batch = db.batch();

    // Free-to-use stock photos (Pexels License — free for commercial use, no
    // attribution required) used as placeholder imagery per partner type
    // until a real photo pipeline (see CLAUDE.md "Phase 5: Web CMS") exists.
    const hotelImage =
        'https://images.pexels.com/photos/14580368/pexels-photo-14580368.jpeg?auto=compress&cs=tinysrgb&w=800';
    const restaurantImage =
        'https://images.pexels.com/photos/776538/pexels-photo-776538.jpeg?auto=compress&cs=tinysrgb&w=800';
    const transportImage =
        'https://images.pexels.com/photos/29817094/pexels-photo-29817094.jpeg?auto=compress&cs=tinysrgb&w=800';

    final partners = {
      'landmark_bangkok': {
        'name': 'The Landmark Bangkok',
        'lat': 13.7401,
        'lng': 100.5601,
        'type': 'hotel',
        'rating': 4.8,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': hotelImage,
      },
      'chatuchak_restaurant_01': {
        'name': 'Chatuchak Local Kitchen',
        'lat': 13.7999,
        'lng': 100.5500,
        'type': 'restaurant',
        'rating': 4.2,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': restaurantImage,
      },
      'siam_tuk_tuk_stand': {
        'name': 'Siam Tuk Tuk Stand',
        'lat': 13.7466,
        'lng': 100.5347,
        'type': 'transport',
        'rating': 3.6,
        'is_verified': false,
        'price_tier': 'caution',
        'image_url': transportImage,
      },

      // Categories added by the 3 -> 11 `type` expansion (Phase 2A task 2.3).
      // One sample per new value so every Safety Radar group renders; these
      // carry no photo, which the app already handles (`image_url` may be "").
      'silom_community_hospital': {
        'name': 'Silom Community Hospital',
        'lat': 13.7261,
        'lng': 100.5340,
        'type': 'hospital',
        'rating': 4.4,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
      'sukhumvit_pharmacy_01': {
        'name': 'Sukhumvit Pharmacy',
        'lat': 13.7321,
        'lng': 100.5665,
        'type': 'pharmacy',
        'rating': 4.0,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
      'bangrak_police_station': {
        'name': 'Bang Rak Police Station',
        'lat': 13.7286,
        'lng': 100.5241,
        'type': 'police',
        'rating': 4.0,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
      'khaosan_tourist_police': {
        'name': 'Khaosan Tourist Police Point',
        'lat': 13.7585,
        'lng': 100.4980,
        'type': 'tourist_police',
        'rating': 4.3,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
      'siam_atm_point': {
        'name': 'Siam Square Bank & ATM Point',
        'lat': 13.7455,
        'lng': 100.5340,
        'type': 'atm_bank',
        'rating': 4.1,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
      'chatuchak_market_shops': {
        'name': 'Chatuchak Weekend Market Shops',
        'lat': 13.7996,
        'lng': 100.5502,
        'type': 'shopping',
        'rating': 4.3,
        'is_verified': false,
        'price_tier': 'caution',
        'image_url': '',
      },
      'wat_pho_attraction': {
        'name': 'Wat Pho Temple Area',
        'lat': 13.7465,
        'lng': 100.4933,
        'type': 'attraction',
        'rating': 4.7,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
      'silom_tourist_info': {
        'name': 'Silom Tourist Information Centre',
        'lat': 13.7250,
        'lng': 100.5300,
        'type': 'tourist_info',
        'rating': 4.2,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': '',
      },
    };

    final zones = {
      'zone_silom_safe': _zone(
        name: 'Silom Business District',
        lat: 13.7244,
        lng: 100.5278,
        sizeKm: 1.0,
        riskLevel: 'safe',
        descriptionEn:
            'Business and tourist-friendly area with verified partners.',
        descriptionTh: 'ย่านธุรกิจและท่องเที่ยว มีพาร์ทเนอร์ที่ผ่านการรับรอง',
      ),
      'zone_khaosan_caution': _zone(
        name: 'Khaosan Road Area',
        lat: 13.7590,
        lng: 100.4972,
        sizeKm: 0.5,
        riskLevel: 'caution',
        descriptionEn:
            'Popular tourist area. Tuk-tuk and tour pricing here may vary significantly from typical rates — compare before booking.',
        descriptionTh:
            'พื้นที่ท่องเที่ยวที่ได้รับความนิยม ราคาตุ๊กตุ๊กและทัวร์ในบริเวณนี้อาจแตกต่างจากราคาทั่วไป ควรเปรียบเทียบราคาก่อนตัดสินใจ',
      ),
      'zone_danger_01': _zone(
        name: 'Community Alert Zone',
        lat: 13.7500,
        lng: 100.5200,
        sizeKm: 0.3,
        riskLevel: 'danger',
        descriptionEn:
            'Increased community reports in this area. Extra caution is recommended, especially at night.',
        descriptionTh:
            'มีรายงานจากชุมชนในพื้นที่นี้เพิ่มขึ้น แนะนำให้เพิ่มความระมัดระวังเป็นพิเศษ โดยเฉพาะช่วงเวลากลางคืน',
      ),
    };

    // `id` goes in as a FIELD as well as the document ID — omitting it is what
    // made seeded documents invisible in the CMS list and uneditable in its
    // form (INTEGRATION_TEST.md §F1/§F3).
    partners.forEach((id, data) {
      batch.set(db.collection('partner_locations').doc(id), {'id': id, ...data});
    });
    zones.forEach((id, data) {
      batch.set(db.collection('alert_zones').doc(id), {'id': id, ...data});
    });

    await batch.commit();
    return 'Seed completed!\n${partners.length} partner_locations\n${zones.length} alert_zones';
  } catch (e) {
    return 'Seed failed:\n$e';
  }
}

class _SeedResultApp extends StatelessWidget {
  const _SeedResultApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
