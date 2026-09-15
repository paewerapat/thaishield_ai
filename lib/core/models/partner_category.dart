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

  /// Whether a place of this kind can carry a `price_tier` at all. A hospital,
  /// a police station or a bus stop has no price to rate, so the app never
  /// shows a price badge for one — even a legacy document still storing
  /// `fair`. Mirrors `TYPES_WITHOUT_PRICE_TIER` in the web-admin repo's
  /// `lib/schemas/partner-locations.ts`; change both together.
  bool get hasPriceTier {
    switch (this) {
      case PartnerCategory.transport:
      case PartnerCategory.hospital:
      case PartnerCategory.police:
      case PartnerCategory.touristPolice:
      case PartnerCategory.atmBank:
      case PartnerCategory.touristInfo:
        return false;
      default:
        return true;
    }
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

/// Which colour a category's pin takes on the Smart Map. Four groups, not
/// eleven colours: the client asked on 2026-08-29 for every partner business
/// to share one colour so a tourist reads "these are the places in the
/// programme" in one glance, and on 2026-09-15 for the police to stop sharing
/// the hospitals' red — a police station and an emergency room answer
/// different questions, and a blue badge next to a red cross is read faster
/// than two red pins.
///
/// Colours as of 2026-09-15 (final design pass, client's words):
/// - **partner** — green, the same green as the status tags on the partner
///   card, so the pin and the card read as one design;
/// - **police** — blue, for both police and tourist police;
/// - **emergency** — red, hospital and pharmacy;
/// - **transport** — teal, how you get around.
///
/// The grouping stays derived from [PartnerCategory.radarGroup] except for the
/// police split, so a category added later cannot end up grouped one way on
/// the map and another way in the Radar without somebody choosing that.
enum MarkerGroup { partner, police, emergency, transport }

extension PartnerCategoryMarkerGroup on PartnerCategory {
  MarkerGroup get markerGroup {
    switch (this) {
      case PartnerCategory.police:
      case PartnerCategory.touristPolice:
        return MarkerGroup.police;
      default:
        switch (radarGroup) {
          case RadarGroup.emergencyServices:
            return MarkerGroup.emergency;
          case RadarGroup.transport:
            return MarkerGroup.transport;
          default:
            return MarkerGroup.partner;
        }
    }
  }
}

/// Google Maps' fixed hue for each [MarkerGroup]. Only the stock-teardrop
/// fallback in `MarkerIcons.forCategory` draws with these; the real pins use
/// [markerGroupColor]. Kept in step with it so a pin that fails to rasterise
/// is still roughly the right colour.
const double _partnerHue = 120; // green — every partner business
const double _policeHue = 210; // azure — police, tourist police
const double _emergencyHue = 0; // red — hospital, pharmacy
const double _transportHue = 180; // cyan — getting around

double partnerCategoryHueFor(PartnerCategory category) {
  switch (category.markerGroup) {
    case MarkerGroup.partner:
      return _partnerHue;
    case MarkerGroup.police:
      return _policeHue;
    case MarkerGroup.emergency:
      return _emergencyHue;
    case MarkerGroup.transport:
      return _transportHue;
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
  PartnerCategory.police: _policeHue,
  PartnerCategory.touristPolice: _policeHue,
  PartnerCategory.transport: _transportHue,
};

/// The exact fill each [MarkerGroup]'s pin is drawn with, and the colour the
/// map legend's "Partner" chip uses for the same reason. The partner green is
/// the app's primary green (`0xFF2E7D32`) — the "Certified Fair Price" tag and
/// the Directions button — rather than the lighter `0xFF4CAF50` of the
/// "within typical range" tag, because the lighter one sinks into the pale
/// green Google paints parks and countryside with.
const Map<MarkerGroup, Color> markerGroupColor = {
  MarkerGroup.partner: Color(0xFF2E7D32),
  MarkerGroup.police: Color(0xFF1565C0),
  MarkerGroup.emergency: Color(0xFFD32F2F),
  MarkerGroup.transport: Color(0xFF00838F),
};
