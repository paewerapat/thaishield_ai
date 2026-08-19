/// The features Phase 2B task 2.5 puts behind the paywall.
///
/// Written down as an enum rather than scattered `if (isPremium)` checks so
/// there is one list to read when Phase 2C wires real purchases, and so a test
/// can assert the list has not quietly grown. Each value names the gate it
/// guards and the headline the paywall opens with.
enum PremiumFeature {
  /// The Safety Radar past the first few results — see
  /// `PremiumProvider.freeRadarResultLimit`.
  radarResults('premium_feature_radar'),

  /// The shared Filter panel, on both the Map and the Radar.
  filterPanel('premium_feature_filter'),

  /// The Route Suggestion preview (task 2.4).
  routeSuggestion('premium_feature_route');

  const PremiumFeature(this.headlineKey);

  /// Key into `app_text.dart` for the line the paywall leads with when this
  /// gate is what sent the user there.
  final String headlineKey;
}
