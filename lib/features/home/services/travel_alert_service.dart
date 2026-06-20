import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/api_keys.dart';
import '../models/travel_alert.dart';

/// Fetches Thailand travel-disruption news (floods, storms, fires, road
/// closures, major accidents, etc.) from the GNews API and filters out
/// anything that doesn't look travel-relevant.
///
/// Results are cached to disk (not just in memory) so the refresh interval
/// is respected across app restarts too, keeping us within the free-tier
/// quota of 100 requests/day.
class TravelAlertService {
  TravelAlertService._();
  static final TravelAlertService instance = TravelAlertService._();

  static const _refreshInterval = Duration(hours: 8);
  static const _cachedAtKey = 'travel_alerts_cached_at';
  static const _cachedDataKey = 'travel_alerts_cached_data';

  static const _searchTerms = [
    'flood', 'storm', 'wildfire', 'fire', 'road closed', 'road closure',
    'accident', 'earthquake', 'tsunami', 'evacuation', 'landslide',
    'flight cancel', 'airport closed', 'protest',
  ];

  Future<List<TravelAlert>> fetchAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAtMs = prefs.getInt(_cachedAtKey);
    final cachedData = prefs.getString(_cachedDataKey);

    if (cachedAtMs != null && cachedData != null) {
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
      if (DateTime.now().difference(cachedAt) < _refreshInterval) {
        return _decode(cachedData);
      }
    }

    final keywords = _searchTerms.map((t) => t.contains(' ') ? '"$t"' : t).join(' OR ');
    final query = 'Thailand AND ($keywords)';
    final uri = Uri.parse('https://gnews.io/api/v4/search').replace(queryParameters: {
      'q': query,
      'lang': 'en',
      'max': '10',
      'sortby': 'publishedAt',
      'apikey': ApiKeys.gnews,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('GNews request failed: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawArticles = (body['articles'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final articles = rawArticles.map(TravelAlert.fromGNewsJson).where(_looksTravelRelevant).toList();

      await prefs.setInt(_cachedAtKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_cachedDataKey, jsonEncode(rawArticles));
      return articles;
    } catch (e) {
      if (cachedData != null) return _decode(cachedData);
      rethrow;
    }
  }

  List<TravelAlert> _decode(String cachedData) {
    final rawArticles = (jsonDecode(cachedData) as List<dynamic>).cast<Map<String, dynamic>>();
    return rawArticles.map(TravelAlert.fromGNewsJson).where(_looksTravelRelevant).toList();
  }

  bool _looksTravelRelevant(TravelAlert alert) {
    final text = '${alert.title} ${alert.description}'.toLowerCase();
    if (!text.contains('thailand') && !text.contains('bangkok')) return false;
    return _searchTerms.any((term) => text.contains(term.toLowerCase()));
  }
}
