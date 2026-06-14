import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/alert_zone.dart';
import '../../../core/models/partner_location.dart';
import '../../../core/services/firestore_service.dart';

const _bangkok = LatLng(13.7563, 100.5018);

Color _riskColor(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return const Color(0xFFEF5350);
    case 'caution':
      return const Color(0xFFFF9800);
    default:
      return const Color(0xFF4CAF50);
  }
}

IconData _riskIcon(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return Icons.warning_rounded;
    case 'caution':
      return Icons.error_outline_rounded;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

String _riskLabel(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return 'Community Alert Zone';
    case 'caution':
      return 'Tourist Advisory Area';
    default:
      return 'Travel Information Area';
  }
}

String _riskLabelTh(String riskLevel) {
  switch (riskLevel) {
    case 'danger':
      return 'พื้นที่ที่ชุมชนแจ้งเตือน';
    case 'caution':
      return 'พื้นที่คำแนะนำสำหรับนักท่องเที่ยว';
    default:
      return 'พื้นที่ข้อมูลการท่องเที่ยว';
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'hotel':
      return Icons.hotel_rounded;
    case 'transport':
      return Icons.local_taxi_rounded;
    default:
      return Icons.restaurant_rounded;
  }
}

String _typeLabel(String type, bool isTh) {
  switch (type) {
    case 'hotel':
      return isTh ? 'โรงแรม' : 'Hotel';
    case 'transport':
      return isTh ? 'การเดินทาง' : 'Transport';
    default:
      return isTh ? 'ร้านอาหาร' : 'Restaurant';
  }
}

class _Review {
  const _Review({
    required this.name,
    required this.initials,
    required this.rating,
    required this.comment,
  });

  final String name;
  final String initials;
  final int rating;
  final String comment;
}

List<_Review> _sampleReviews(String type, bool isTh) {
  switch (type) {
    case 'hotel':
      return [
        _Review(
          name: isTh ? 'นักท่องเที่ยว A' : 'Traveler A',
          initials: 'A',
          rating: 5,
          comment: isTh
              ? 'ห้องพักสะอาด พนักงานเป็นมิตร และทำเลสะดวกสำหรับเดินทางไปแหล่งท่องเที่ยว'
              : 'Clean rooms, friendly staff, and a convenient location for getting around.',
        ),
        _Review(
          name: isTh ? 'นักท่องเที่ยว B' : 'Traveler B',
          initials: 'B',
          rating: 4,
          comment: isTh
              ? 'ราคาตรงตามที่แสดงในแอป คุ้มค่ากับสิ่งที่ได้รับ'
              : 'Price matched what was shown in the app — good value overall.',
        ),
        _Review(
          name: isTh ? 'นักท่องเที่ยว C' : 'Traveler C',
          initials: 'C',
          rating: 5,
          comment: isTh
              ? 'บริการรวดเร็วและให้ข้อมูลที่เป็นประโยชน์กับนักท่องเที่ยว'
              : 'Quick service and helpful information for first-time visitors.',
        ),
      ];
    case 'transport':
      return [
        _Review(
          name: isTh ? 'นักท่องเที่ยว A' : 'Traveler A',
          initials: 'A',
          rating: 5,
          comment: isTh
              ? 'คนขับใช้มิเตอร์ตามปกติ ค่าโดยสารตรงกับช่วงราคาที่แอปแสดง'
              : 'Driver used the meter as expected — fare matched the typical range shown in the app.',
        ),
        _Review(
          name: isTh ? 'นักท่องเที่ยว B' : 'Traveler B',
          initials: 'B',
          rating: 4,
          comment: isTh
              ? 'สะดวกและรวดเร็วในการเดินทางช่วงเวลาเร่งด่วน'
              : 'Convenient and quick, even during busy hours.',
        ),
        _Review(
          name: isTh ? 'นักท่องเที่ยว C' : 'Traveler C',
          initials: 'C',
          rating: 4,
          comment: isTh
              ? 'พนักงานพูดคุยเป็นมิตรและช่วยแนะนำเส้นทาง'
              : 'Friendly driver who helped with directions along the way.',
        ),
      ];
    default:
      return [
        _Review(
          name: isTh ? 'นักท่องเที่ยว A' : 'Traveler A',
          initials: 'A',
          rating: 5,
          comment: isTh
              ? 'อาหารอร่อยและราคาตรงกับข้อมูลที่แสดงในแอป'
              : 'Great food, and pricing matched the information shown in the app.',
        ),
        _Review(
          name: isTh ? 'นักท่องเที่ยว B' : 'Traveler B',
          initials: 'B',
          rating: 4,
          comment: isTh
              ? 'บรรยากาศดีและพนักงานเป็นมิตรกับนักท่องเที่ยว'
              : 'Nice atmosphere and staff were welcoming to tourists.',
        ),
        _Review(
          name: isTh ? 'นักท่องเที่ยว C' : 'Traveler C',
          initials: 'C',
          rating: 5,
          comment: isTh
              ? 'คุ้มค่ากับราคาที่จ่าย และมีเมนูให้เลือกหลากหลาย'
              : 'Good value for the price, with a varied menu to choose from.',
        ),
      ];
  }
}

String _typeDescription(String type, bool isTh) {
  switch (type) {
    case 'hotel':
      return isTh
          ? 'ที่พักที่เข้าร่วมโครงการพาร์ทเนอร์ ThaiShield พร้อมข้อมูลราคาที่โปร่งใสสำหรับนักท่องเที่ยว'
          : 'A participating ThaiShield partner offering transparent pricing information for travelers.';
    case 'transport':
      return isTh
          ? 'บริการเดินทางที่เข้าร่วมโครงการพาร์ทเนอร์ ThaiShield พร้อมข้อมูลค่าโดยสารโดยประมาณสำหรับนักท่องเที่ยว'
          : 'A participating ThaiShield transport partner offering estimated fare information for travelers.';
    default:
      return isTh
          ? 'ร้านอาหารที่เข้าร่วมโครงการพาร์ทเนอร์ ThaiShield พร้อมข้อมูลราคาที่โปร่งใสสำหรับนักท่องเที่ยว'
          : 'A participating ThaiShield restaurant partner offering transparent pricing information for travelers.';
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _markers = <Marker>{};
  final _circles = <Circle>{};
  final _polygons = <Polygon>{};
  final _partnersById = <String, PartnerLocation>{};
  final _zonesById = <String, AlertZone>{};
  PartnerLocation? _selectedPartner;
  AlertZone? _selectedZone;
  bool _loading = true;
  String? _error;
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _showPartnerPins = true;
  final Map<String, bool> _zoneVisibility = {
    'safe': true,
    'caution': true,
    'danger': true,
  };

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    try {
      final partners = await FirestoreService.instance.getPartnerLocations();
      final zones = await FirestoreService.instance.getAlertZones();

      final markers = <Marker>{};
      for (final partner in partners) {
        _partnersById[partner.id] = partner;
        markers.add(
          Marker(
            markerId: MarkerId(partner.id),
            position: LatLng(partner.lat, partner.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              partner.isVerified
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueOrange,
            ),
            onTap: () {
              setState(() {
                _selectedPartner = partner;
                _selectedZone = null;
              });
              _openPartnerDetail(partner);
            },
          ),
        );
      }

      final circles = <Circle>{};
      final polygons = <Polygon>{};
      for (final zone in zones) {
        _zonesById[zone.id] = zone;
        final color = _riskColor(zone.riskLevel);
        if (zone.polygon.length >= 3) {
          polygons.add(
            Polygon(
              polygonId: PolygonId(zone.id),
              points: zone.polygon,
              fillColor: color.withValues(alpha: 0.2),
              strokeColor: color,
              strokeWidth: 2,
              consumeTapEvents: true,
              onTap: () => setState(() {
                _selectedZone = zone;
                _selectedPartner = null;
              }),
            ),
          );
        } else {
          circles.add(
            Circle(
              circleId: CircleId(zone.id),
              center: LatLng(zone.centerLat, zone.centerLng),
              radius: zone.radiusKm * 1000,
              fillColor: color.withValues(alpha: 0.2),
              strokeColor: color,
              strokeWidth: 2,
              consumeTapEvents: true,
              onTap: () => setState(() {
                _selectedZone = zone;
                _selectedPartner = null;
              }),
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedPartner =
            partners.where((p) => p.isVerified).firstOrNull ?? partners.firstOrNull;
        _markers
          ..clear()
          ..addAll(markers);
        _circles
          ..clear()
          ..addAll(circles);
        _polygons
          ..clear()
          ..addAll(polygons);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลแผนที่ไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _openLayersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _LayersSheet(
        showPartnerPins: _showPartnerPins,
        zoneVisibility: _zoneVisibility,
        onPartnerPinsChanged: (value) =>
            setState(() => _showPartnerPins = value),
        onZoneVisibilityChanged: (riskLevel, value) =>
            setState(() => _zoneVisibility[riskLevel] = value),
      ),
    );
  }

  void _openMapSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _MapSettingsSheet(
        mapType: _mapType,
        onMapTypeChanged: (type) => setState(() => _mapType = type),
      ),
    );
  }

  void _openPartnerDetail(PartnerLocation partner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PartnerDetailSheet(
        partner: partner,
        onShowOnMap: () {
          Navigator.pop(sheetContext);
          setState(() => _selectedPartner = partner);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(partner.lat, partner.lng), 16),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _MapHeader(onSettingsTap: _openMapSettings),
            _LegendRow(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFF0D1B2A)),
                          ),
                        )
                      : Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: const CameraPosition(
                                target: _bangkok,
                                zoom: 12,
                              ),
                              mapType: _mapType,
                              markers: _showPartnerPins ? _markers : const {},
                              circles: _circles.where((c) {
                                final zone = _zonesById[c.circleId.value];
                                return zone == null ||
                                    (_zoneVisibility[zone.riskLevel] ?? true);
                              }).toSet(),
                              polygons: _polygons.where((p) {
                                final zone = _zonesById[p.polygonId.value];
                                return zone == null ||
                                    (_zoneVisibility[zone.riskLevel] ?? true);
                              }).toSet(),
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: true,
                              zoomGesturesEnabled: true,
                              scrollGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              tiltGesturesEnabled: true,
                              onMapCreated: (c) => _mapController = c,
                              onTap: (_) => setState(() => _selectedZone = null),
                            ),
                            if (_selectedZone != null)
                              Positioned(
                                top: 12,
                                left: 16,
                                right: 16,
                                child: _ZonePopup(
                                  zone: _selectedZone!,
                                  langCode: Localizations.localeOf(context)
                                      .languageCode,
                                  onClose: () =>
                                      setState(() => _selectedZone = null),
                                ),
                              ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: _FloatingButtons(
                                onCenter: () => _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(_bangkok),
                                ),
                                onLayers: _openLayersSheet,
                              ),
                            ),
                          ],
                        ),
            ),
            if (!_loading && _error == null)
              _PartnerBottomPanel(
                partner: _selectedPartner,
                onViewDetails: _selectedPartner != null
                    ? () => _openPartnerDetail(_selectedPartner!)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/Google_Maps_icon_(2020).svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            'Smart Map',
            style: TextStyle(
              color: Color(0xFF0D1B2A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onSettingsTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _LegendChip(
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF4CAF50),
            label: 'Travel Info',
          ),
          _LegendChip(
            icon: Icons.error_rounded,
            color: const Color(0xFFFF9800),
            label: 'Advisory',
          ),
          _LegendChip(
            icon: Icons.cancel_rounded,
            color: const Color(0xFFEF5350),
            label: 'Alert Zone',
          ),
          _LegendChip(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF1565C0),
            label: 'Partner',
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonePopup extends StatelessWidget {
  const _ZonePopup({
    required this.zone,
    required this.langCode,
    required this.onClose,
  });
  final AlertZone zone;
  final String langCode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(zone.riskLevel);
    final desc = zone.localizedDescription(langCode);
    final points = desc
        .split(RegExp(r'(?<=[.!])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_riskIcon(zone.riskLevel), color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _riskLabel(zone.riskLevel),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _riskLabelTh(zone.riskLevel),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_rounded, color: Colors.grey[500], size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          zone.name,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final point in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_riskIcon(zone.riskLevel), color: color, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              point,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1B2A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ดูรายละเอียด',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingButtons extends StatelessWidget {
  const _FloatingButtons({required this.onCenter, required this.onLayers});
  final VoidCallback onCenter;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FabButton(icon: Icons.my_location_rounded, onTap: onCenter),
        const SizedBox(height: 8),
        _FabButton(icon: Icons.layers_rounded, onTap: onLayers),
      ],
    );
  }
}

class _FabButton extends StatelessWidget {
  const _FabButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0D1B2A), size: 20),
        ),
      ),
    );
  }
}

class _PartnerBottomPanel extends StatelessWidget {
  const _PartnerBottomPanel({required this.partner, this.onViewDetails});
  final PartnerLocation? partner;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Verified Partner',
                style: TextStyle(
                  color: Color(0xFF0D1B2A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: onViewDetails,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (partner == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'แตะหมุดบนแผนที่เพื่อดูข้อมูลพาร์ทเนอร์',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else ...[
            _PartnerCard(partner: partner!),
            const SizedBox(height: 10),
            Text(
              Localizations.localeOf(context).languageCode == 'th'
                  ? 'ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น ราคาจริงอาจแตกต่างกันได้'
                  : 'This information is generated from statistical and community-based data and is intended for informational purposes only. Actual prices may vary.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner});
  final PartnerLocation partner;

  @override
  Widget build(BuildContext context) {
    // Review count isn't part of the Firestore schema yet — derive a stable
    // placeholder from the partner id so the UI matches the mockup layout.
    final reviewCount = 80 + (partner.id.hashCode.abs() % 600);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 88,
            height: 80,
            color: const Color(0xFFE8F5E9),
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFF4CAF50),
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partner.name,
                style: const TextStyle(
                  color: Color(0xFF0D1B2A),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 17),
                  const SizedBox(width: 3),
                  Text(
                    partner.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF0D1B2A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($reviewCount รีวิว)',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(
                    label: partner.priceTier == 'fair'
                        ? 'FAIR PRICE'
                        : 'ABOVE TYPICAL RANGE',
                    color: partner.priceTier == 'fair'
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                  ),
                  const _Tag(
                    label: 'PARTNER',
                    color: Color(0xFF1565C0),
                    icon: Icons.shield_rounded,
                  ),
                  if (partner.isVerified)
                    const _Tag(
                      label: 'VERIFIED',
                      color: Color(0xFF2E7D32),
                      icon: Icons.verified_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 11),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.type, required this.isTh});
  final String type;
  final bool isTh;

  @override
  Widget build(BuildContext context) {
    final reviews = _sampleReviews(type, isTh);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTh ? 'รีวิวจากนักท่องเที่ยว' : 'Traveler Reviews',
          style: const TextStyle(
            color: Color(0xFF0D1B2A),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isTh
              ? 'ตัวอย่างความคิดเห็นจากชุมชนนักท่องเที่ยว'
              : 'Sample feedback from the traveler community',
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        const SizedBox(height: 10),
        for (final review in reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReviewCard(review: review),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final _Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFE0E0E0),
                child: Text(
                  review.initials,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF616161),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1B2A),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFFB300),
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: TextStyle(color: Colors.grey[700], fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PartnerDetailSheet extends StatelessWidget {
  const _PartnerDetailSheet({required this.partner, required this.onShowOnMap});
  final PartnerLocation partner;
  final VoidCallback onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final isTh = Localizations.localeOf(context).languageCode == 'th';
    final reviewCount = 80 + (partner.id.hashCode.abs() % 600);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _typeIcon(partner.type),
                    color: const Color(0xFF4CAF50),
                    size: 56,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: const TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(_typeIcon(partner.type), color: Colors.grey[500], size: 15),
                        const SizedBox(width: 5),
                        Text(
                          _typeLabel(partner.type, isTh),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          partner.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isTh ? '($reviewCount รีวิว)' : '($reviewCount reviews)',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(
                          label: partner.priceTier == 'fair'
                              ? 'FAIR PRICE'
                              : 'ABOVE TYPICAL RANGE',
                          color: partner.priceTier == 'fair'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                        ),
                        const _Tag(
                          label: 'PARTNER',
                          color: Color(0xFF1565C0),
                          icon: Icons.shield_rounded,
                        ),
                        if (partner.isVerified)
                          const _Tag(
                            label: 'VERIFIED',
                            color: Color(0xFF2E7D32),
                            icon: Icons.verified_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    Text(
                      isTh ? 'เกี่ยวกับ' : 'About',
                      style: const TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _typeDescription(partner.type, isTh),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey[200]),
                    const SizedBox(height: 12),
                    _ReviewsSection(type: partner.type, isTh: isTh),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onShowOnMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1B2A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: Text(
                          isTh ? 'ดูบนแผนที่' : 'Show on Map',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isTh
                          ? 'ข้อมูลนี้เป็นการประเมินจากข้อมูลสถิติและข้อมูลจากชุมชนเพื่อประกอบการตัดสินใจเท่านั้น ราคาจริงอาจแตกต่างกันได้'
                          : 'This information is generated from statistical and community-based data and is intended for informational purposes only. Actual prices may vary.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LayersSheet extends StatefulWidget {
  const _LayersSheet({
    required this.showPartnerPins,
    required this.zoneVisibility,
    required this.onPartnerPinsChanged,
    required this.onZoneVisibilityChanged,
  });

  final bool showPartnerPins;
  final Map<String, bool> zoneVisibility;
  final ValueChanged<bool> onPartnerPinsChanged;
  final void Function(String riskLevel, bool value) onZoneVisibilityChanged;

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  late bool _showPartnerPins;
  late Map<String, bool> _zoneVisibility;

  @override
  void initState() {
    super.initState();
    _showPartnerPins = widget.showPartnerPins;
    _zoneVisibility = Map.of(widget.zoneVisibility);
  }

  @override
  Widget build(BuildContext context) {
    final isTh = Localizations.localeOf(context).languageCode == 'th';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isTh ? 'เลเยอร์บนแผนที่' : 'Map Layers',
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isTh
                  ? 'เลือกแสดงหมุดและพื้นที่บนแผนที่'
                  : 'Choose which pins and areas to show',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 12),
            _LayerToggleRow(
              icon: Icons.location_on_rounded,
              color: const Color(0xFF1565C0),
              label: isTh ? 'หมุดพาร์ทเนอร์' : 'Partner Pins',
              value: _showPartnerPins,
              onChanged: (value) {
                setState(() => _showPartnerPins = value);
                widget.onPartnerPinsChanged(value);
              },
            ),
            _LayerToggleRow(
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF4CAF50),
              label: isTh ? 'ข้อมูลการท่องเที่ยว' : 'Travel Info',
              value: _zoneVisibility['safe'] ?? true,
              onChanged: (value) {
                setState(() => _zoneVisibility['safe'] = value);
                widget.onZoneVisibilityChanged('safe', value);
              },
            ),
            _LayerToggleRow(
              icon: Icons.error_rounded,
              color: const Color(0xFFFF9800),
              label: isTh ? 'พื้นที่คำแนะนำ' : 'Advisory',
              value: _zoneVisibility['caution'] ?? true,
              onChanged: (value) {
                setState(() => _zoneVisibility['caution'] = value);
                widget.onZoneVisibilityChanged('caution', value);
              },
            ),
            _LayerToggleRow(
              icon: Icons.cancel_rounded,
              color: const Color(0xFFEF5350),
              label: isTh ? 'พื้นที่แจ้งเตือน' : 'Alert Zone',
              value: _zoneVisibility['danger'] ?? true,
              onChanged: (value) {
                setState(() => _zoneVisibility['danger'] = value);
                widget.onZoneVisibilityChanged('danger', value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerToggleRow extends StatelessWidget {
  const _LayerToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF2E7D32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MapSettingsSheet extends StatefulWidget {
  const _MapSettingsSheet({
    required this.mapType,
    required this.onMapTypeChanged,
  });

  final MapType mapType;
  final ValueChanged<MapType> onMapTypeChanged;

  @override
  State<_MapSettingsSheet> createState() => _MapSettingsSheetState();
}

class _MapSettingsSheetState extends State<_MapSettingsSheet> {
  late MapType _mapType;

  @override
  void initState() {
    super.initState();
    _mapType = widget.mapType;
  }

  @override
  Widget build(BuildContext context) {
    final isTh = Localizations.localeOf(context).languageCode == 'th';
    final options = <(MapType, IconData, String, String)>[
      (MapType.normal, Icons.map_rounded, 'Normal', 'ปกติ'),
      (MapType.satellite, Icons.satellite_alt_rounded, 'Satellite', 'ดาวเทียม'),
      (MapType.terrain, Icons.terrain_rounded, 'Terrain', 'ภูมิประเทศ'),
      (MapType.hybrid, Icons.layers_rounded, 'Hybrid', 'แบบผสม'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isTh ? 'รูปแบบแผนที่' : 'Map Type',
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            for (final option in options)
              _MapTypeOption(
                icon: option.$2,
                label: isTh ? option.$4 : option.$3,
                selected: _mapType == option.$1,
                onTap: () {
                  setState(() => _mapType = option.$1);
                  widget.onMapTypeChanged(option.$1);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MapTypeOption extends StatelessWidget {
  const _MapTypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF2E7D32) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF2E7D32) : const Color(0xFF0D1B2A),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 20),
          ],
        ),
      ),
    );
  }
}
