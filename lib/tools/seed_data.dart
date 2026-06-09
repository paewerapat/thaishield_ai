// One-time helper to populate Firestore with sample data for Phase 2 testing.
// Run with:  flutter run -t lib/tools/seed_data.dart -d <device-id>
// Safe to delete this file after running it once.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

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
        'risk_level': 'caution',
        'description_en':
            'Popular tourist area. Watch out for overpriced tuk-tuks and tours.',
        'description_th': 'พื้นที่ท่องเที่ยว ระวังตุ๊กตุ๊กและทัวร์ราคาแพง',
      },
      'zone_danger_01': {
        'name': 'High Risk Zone',
        'center_lat': 13.7500,
        'center_lng': 100.5200,
        'radius_km': 0.3,
        'risk_level': 'danger',
        'description_en': 'High crime rate reported. Avoid this area at night.',
        'description_th': 'มีรายงานอาชญากรรมสูง ควรหลีกเลี่ยงในเวลากลางคืน',
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
