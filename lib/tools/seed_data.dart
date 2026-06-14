// One-time helper to populate Firestore with sample data for Phase 2 testing.
// Run with:  flutter run -t lib/tools/seed_data.dart -d <device-id>
// Safe to delete this file after running it once.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

// Builds an irregular hexagon of GeoPoints around a center point, used to
// render alert zones as area shapes on the map instead of plain circles.
List<GeoPoint> _polygonAround(double lat, double lng, double radiusKm) {
  final latOffset = radiusKm / 111;
  final lngOffset = radiusKm / (111 * cos(lat * pi / 180));
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

    final partners = {
      'landmark_bangkok': {
        'name': 'The Landmark Bangkok',
        'lat': 13.7401,
        'lng': 100.5601,
        'type': 'hotel',
        'rating': 4.8,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': 'https://example.com/landmark.jpg',
      },
      'chatuchak_restaurant_01': {
        'name': 'Chatuchak Local Kitchen',
        'lat': 13.7999,
        'lng': 100.5500,
        'type': 'restaurant',
        'rating': 4.2,
        'is_verified': true,
        'price_tier': 'fair',
        'image_url': 'https://example.com/chatuchak.jpg',
      },
      'siam_tuk_tuk_stand': {
        'name': 'Siam Tuk Tuk Stand',
        'lat': 13.7466,
        'lng': 100.5347,
        'type': 'transport',
        'rating': 3.6,
        'is_verified': false,
        'price_tier': 'caution',
        'image_url': 'https://example.com/tuktuk.jpg',
      },
    };

    final zones = {
      'zone_silom_safe': {
        'name': 'Silom Business District',
        'center_lat': 13.7244,
        'center_lng': 100.5278,
        'radius_km': 1.0,
        'polygon': _polygonAround(13.7244, 100.5278, 1.0),
        'risk_level': 'safe',
        'description_en':
            'Business and tourist-friendly area with verified partners.',
        'description_th': 'ย่านธุรกิจและท่องเที่ยว มีพาร์ทเนอร์ที่ผ่านการรับรอง',
      },
      'zone_khaosan_caution': {
        'name': 'Khaosan Road Area',
        'center_lat': 13.7590,
        'center_lng': 100.4972,
        'radius_km': 0.5,
        'polygon': _polygonAround(13.7590, 100.4972, 0.5),
        'risk_level': 'caution',
        'description_en':
            'Popular tourist area. Tuk-tuk and tour pricing here may vary significantly from typical rates — compare before booking.',
        'description_th':
            'พื้นที่ท่องเที่ยวที่ได้รับความนิยม ราคาตุ๊กตุ๊กและทัวร์ในบริเวณนี้อาจแตกต่างจากราคาทั่วไป ควรเปรียบเทียบราคาก่อนตัดสินใจ',
      },
      'zone_danger_01': {
        'name': 'Community Alert Zone',
        'center_lat': 13.7500,
        'center_lng': 100.5200,
        'radius_km': 0.3,
        'polygon': _polygonAround(13.7500, 100.5200, 0.3),
        'risk_level': 'danger',
        'description_en':
            'Increased community reports in this area. Extra caution is recommended, especially at night.',
        'description_th':
            'มีรายงานจากชุมชนในพื้นที่นี้เพิ่มขึ้น แนะนำให้เพิ่มความระมัดระวังเป็นพิเศษ โดยเฉพาะช่วงเวลากลางคืน',
      },
    };

    partners.forEach((id, data) {
      batch.set(db.collection('partner_locations').doc(id), data);
    });
    zones.forEach((id, data) {
      batch.set(db.collection('alert_zones').doc(id), data);
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
