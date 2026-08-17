import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AlertCategory { flood, fire, storm, earthquake, accident, other }

class TravelAlert {
  const TravelAlert({
    required this.title,
    required this.description,
    required this.url,
    required this.imageUrl,
    required this.sourceName,
    required this.publishedAt,
  });

  final String title;
  final String description;
  final String url;
  final String? imageUrl;
  final String sourceName;
  final DateTime publishedAt;

  /// Built from a `travel_alerts_cache` document, which the scheduled
  /// `syncTravelAlerts` Cloud Function refreshes from GNews every 15
  /// minutes — the app never calls GNews directly.
  factory TravelAlert.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TravelAlert(
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      url: data['url'] as String? ?? '',
      imageUrl: data['image'] as String?,
      sourceName: data['source_name'] as String? ?? '',
      publishedAt: (data['published_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Idioms that contain a disaster word but describe no disaster. Matched
  /// before the category words, so "Blackpink's Lisa under fire for…" stops
  /// being labelled ไฟไหม้ / Fire on the Home tab (INTEGRATION_TEST.md §F7).
  ///
  /// Keep in sync with `NON_EVENT_PHRASES` in `functions/index.js`, which
  /// keeps these stories out of `travel_alerts_cache` in the first place.
  static const _nonEventPhrases = [
    'under fire',
    'fire back',
    'fires back',
    'fired back',
    'firing back',
    'come under fire',
    'draws fire',
    'drew fire',
    'fired up',
    'fire up',
    // Shootings. "a gunman opened fire" put three of them on the Home tab
    // badged as fires, and they are not the travel disruption this feature
    // reports (CLAUDE.md §2.1).
    'opened fire',
    'open fire',
    'opens fire',
    'ready to fire',
    'crash course',
    'storm of criticism',
    'social media storm',
    'takes the internet by storm',
    'flood of comments',
    'flood of criticism',
    'flooded with',
  ];

  /// Matches [word] only as a whole word, so "fire" no longer fires on
  /// "firearm" or "misfire" and "quake" no longer fires on "quaker".
  static bool _hasWord(String text, String word) =>
      RegExp('(?<![a-z])${RegExp.escape(word)}(?![a-z])').hasMatch(text);

  static bool _hasAny(String text, List<String> words) =>
      words.any((w) => _hasWord(text, w));

  AlertCategory get category {
    final text = '$title $description'.toLowerCase();

    // A headline using a disaster word figuratively is not a travel event.
    // Falling through to `other` keeps it in the list but strips the red
    // hazard badge and the count on the Home banner.
    if (_nonEventPhrases.any(text.contains)) return AlertCategory.other;

    if (_hasWord(text, 'flood') ||
        _hasWord(text, 'flooding') ||
        _hasWord(text, 'floods')) {
      return AlertCategory.flood;
    }
    // Never the bare word: "fire" reaches the Home tab far more often inside
    // "opened fire", "under fire" and "ready to fire" than as a fire. Matching
    // the shapes an actual fire is described in costs nothing and does not
    // need a new blacklist entry every time a sports desk reaches for the
    // metaphor.
    if (_hasAny(text, [
      'wildfire',
      'wildfires',
      'bushfire',
      'blaze',
      'arson',
      'fire broke out',
      'caught fire',
      'set on fire',
      'house fire',
      'forest fire',
      'building fire',
      'factory fire',
      'market fire',
      'fire destroyed',
      'fire damaged',
      'fire swept',
      'fire engulfed',
      'firefighters',
    ])) {
      return AlertCategory.fire;
    }
    if (_hasAny(text, ['storm', 'storms', 'typhoon', 'cyclone', 'monsoon'])) {
      return AlertCategory.storm;
    }
    if (_hasAny(text, ['earthquake', 'quake', 'tsunami', 'aftershock'])) {
      return AlertCategory.earthquake;
    }
    if (_hasAny(text, ['accident', 'crash', 'collision', 'derailment'])) {
      return AlertCategory.accident;
    }
    return AlertCategory.other;
  }
}

const Map<AlertCategory, String> alertCategoryTextKey = {
  AlertCategory.flood: 'alert_category_flood',
  AlertCategory.fire: 'alert_category_fire',
  AlertCategory.storm: 'alert_category_storm',
  AlertCategory.earthquake: 'alert_category_earthquake',
  AlertCategory.accident: 'alert_category_accident',
  AlertCategory.other: 'alert_category_other',
};

const Map<AlertCategory, Color> alertCategoryColor = {
  AlertCategory.flood: Color(0xFF1976D2),
  AlertCategory.fire: Color(0xFFD32F2F),
  AlertCategory.storm: Color(0xFF7B1FA2),
  AlertCategory.earthquake: Color(0xFF6D4C41),
  AlertCategory.accident: Color(0xFFF57C00),
  AlertCategory.other: Color(0xFF607D8B),
};

String timeAgoLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
