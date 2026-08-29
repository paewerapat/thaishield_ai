import 'package:flutter/material.dart';

/// The 11 values of `partner_locations.type` (CLAUDE.md §3).
///
/// The first three (`restaurant`, `hotel`, `transport`) are the original enum
/// and keep their exact Firestore strings, so existing documents and the
/// Smart Map keep working without a data migration. The remaining eight were
/// added in Phase 2A task 2.3.
///
/// This list is mirrored by `PARTNER_LOCATION_TYPES` in
/// `lib/schemas/partner-locations.ts` in the web-admin repo — the two must
/// always be changed together, or staff cannot enter the new types.
enum PartnerCategory {
  restaurant('restaurant'),
  hotel('hotel'),
  transport('transport'),
  hospital('hospital'),
  pharmacy('pharmacy'),
  police('police'),
  touristPolice('tourist_police'),
  atmBank('atm_bank'),
  shopping('shopping'),
  attraction('attraction'),
  touristInfo('tourist_info');

  const PartnerCategory(this.value);

  /// The string stored in Firestore.
  final String value;

  /// Unknown / legacy values fall back to `restaurant`, matching the default
  /// already used by `PartnerLocation.fromFirestore`.
  static PartnerCategory fromValue(String? raw) {
    for (final c in PartnerCategory.values) {
      if (c.value == raw) return c;
    }
    return PartnerCategory.restaurant;
  }

  /// Key into the shared `appText` table (`lib/core/localization/app_text.dart`).
  String get textKey => 'cat_$value';

  /// Which Radar group this category is reported under (§4 task 2.1).
  RadarGroup get radarGroup {
    switch (this) {
      case PartnerCategory.hospital:
      case PartnerCategory.pharmacy:
      case PartnerCategory.police:
      case PartnerCategory.touristPolice:
        return RadarGroup.emergencyServices;
      case PartnerCategory.transport:
        return RadarGroup.transport;
      default:
        return RadarGroup.partners;
    }
  }
}

/// The six card groups the Radar returns, in display order.
enum RadarGroup {
  zoneDanger,
  zoneCaution,
  zoneSafe,
  emergencyServices,
  partners,
  transport,
}

const Map<PartnerCategory, IconData> partnerCategoryIcon = {
  PartnerCategory.restaurant: Icons.restaurant_rounded,
  PartnerCategory.hotel: Icons.hotel_rounded,
  PartnerCategory.transport: Icons.local_taxi_rounded,
  PartnerCategory.hospital: Icons.local_hospital_rounded,
  PartnerCategory.pharmacy: Icons.medical_services_rounded,
  PartnerCategory.police: Icons.local_police_rounded,
  PartnerCategory.touristPolice: Icons.shield_rounded,
  PartnerCategory.atmBank: Icons.account_balance_rounded,
  PartnerCategory.shopping: Icons.storefront_rounded,
  PartnerCategory.attraction: Icons.temple_buddhist_rounded,
  PartnerCategory.touristInfo: Icons.info_rounded,
};

const Map<PartnerCategory, Color> partnerCategoryColor = {
  PartnerCategory.restaurant: Color(0xFFF57C00),
  PartnerCategory.hotel: Color(0xFF1565C0),
  PartnerCategory.transport: Color(0xFF00897B),
  PartnerCategory.hospital: Color(0xFFD32F2F),
  PartnerCategory.pharmacy: Color(0xFFEF5350),
  PartnerCategory.police: Color(0xFF303F9F),
  PartnerCategory.touristPolice: Color(0xFF3949AB),
  PartnerCategory.atmBank: Color(0xFF2E7D32),
  PartnerCategory.shopping: Color(0xFF8E24AA),
  PartnerCategory.attraction: Color(0xFFFFB300),
  PartnerCategory.touristInfo: Color(0xFF4FC3F7),
};

/// Marker hue used for this category's pin on the Smart Map. Google Maps only
/// accepts a fixed set of hues, so these approximate `partnerCategoryColor`.
/// Pin colour by category, grouped rather than one hue per type.
///
/// Changed 2026-08-29 at the client's request: every **partner business** is
/// now the same blue, so a tourist scanning the map reads "these are the places
/// in the programme" in one glance instead of decoding eleven colours. The two
/// groups that are not partner businesses keep their own colour because they
/// answer a different question — red for where you go when something is wrong,
/// cyan for how you get around.
///
/// The grouping is [PartnerCategory.radarGroup], not a second list, so a
/// category added later cannot end up grouped one way on the map and another
/// way in the Radar.
const double _partnerHue = 210; // azure — every partner business
const double _emergencyHue = 0; // red — hospital, pharmacy, both police
const double _transportHue = 180; // cyan — getting around

double partnerCategoryHueFor(PartnerCategory category) {
  switch (category.radarGroup) {
    case RadarGroup.emergencyServices:
      return _emergencyHue;
    case RadarGroup.transport:
      return _transportHue;
    default:
      return _partnerHue;
  }
}

const Map<PartnerCategory, double> partnerCategoryMarkerHue = {
  PartnerCategory.restaurant: _partnerHue,
  PartnerCategory.hotel: _partnerHue,
  PartnerCategory.atmBank: _partnerHue,
  PartnerCategory.shopping: _partnerHue,
  PartnerCategory.attraction: _partnerHue,
  PartnerCategory.touristInfo: _partnerHue,
  PartnerCategory.hospital: _emergencyHue,
  PartnerCategory.pharmacy: _emergencyHue,
  PartnerCategory.police: _emergencyHue,
  PartnerCategory.touristPolice: _emergencyHue,
  PartnerCategory.transport: _transportHue,
};
