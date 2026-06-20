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

  factory TravelAlert.fromGNewsJson(Map<String, dynamic> json) {
    return TravelAlert(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      imageUrl: json['image'] as String?,
      sourceName: (json['source'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  AlertCategory get category {
    final text = '$title $description'.toLowerCase();
    if (text.contains('flood')) return AlertCategory.flood;
    if (text.contains('fire') || text.contains('wildfire')) return AlertCategory.fire;
    if (text.contains('storm') || text.contains('typhoon') || text.contains('cyclone')) {
      return AlertCategory.storm;
    }
    if (text.contains('earthquake') || text.contains('quake') || text.contains('tsunami')) {
      return AlertCategory.earthquake;
    }
    if (text.contains('accident') || text.contains('crash') || text.contains('collision')) {
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
