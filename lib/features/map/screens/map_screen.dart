import 'package:flutter/material.dart';
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
  final _partnersById = <String, PartnerLocation>{};
  PartnerLocation? _selectedPartner;
  AlertZone? _selectedZone;
  bool _loading = true;
  String? _error;
  GoogleMapController? _mapController;

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
      for (final zone in zones) {
        final color = _riskColor(zone.riskLevel);
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
            _MapHeader(),
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
                              markers: _markers,
                              circles: _circles,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Color(0xFF2E7D32), size: 22),
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
          Icon(Icons.tune_rounded, color: Colors.grey[600], size: 22),
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
  const _FloatingButtons({required this.onCenter});
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FabButton(icon: Icons.my_location_rounded, onTap: onCenter),
        const SizedBox(height: 8),
        _FabButton(icon: Icons.layers_rounded, onTap: () {}),
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
                    const SizedBox(height: 20),
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
