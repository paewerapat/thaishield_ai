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
      return 'High Risk';
    case 'caution':
      return 'Caution';
    default:
      return 'Safe';
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
            onTap: () => setState(() {
              _selectedPartner = partner;
              _selectedZone = null;
            }),
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
                              zoomControlsEnabled: false,
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
              _PartnerBottomPanel(partner: _selectedPartner),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _LegendChip(color: const Color(0xFF4CAF50), label: 'Safe Zone'),
          const SizedBox(width: 12),
          _LegendChip(color: const Color(0xFFFF9800), label: 'Caution'),
          const SizedBox(width: 12),
          _LegendChip(color: const Color(0xFFEF5350), label: 'Danger'),
          const SizedBox(width: 12),
          _LegendChip(
            color: const Color(0xFF1565C0),
            label: 'Partner',
            isPin: true,
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    this.isPin = false,
  });
  final Color color;
  final String label;
  final bool isPin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isPin
            ? Icon(Icons.location_on, color: color, size: 12)
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(_riskIcon(zone.riskLevel), color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _riskLabel(zone.riskLevel),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1B2A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('ดูรายละเอียด', style: TextStyle(fontSize: 13)),
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
  const _PartnerBottomPanel({required this.partner});
  final PartnerLocation? partner;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF2E7D32),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (partner == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'แตะหมุดบนแผนที่เพื่อดูข้อมูลพาร์ทเนอร์',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            _PartnerCard(partner: partner!),
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
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 80,
            height: 72,
            color: const Color(0xFFE8F5E9),
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFF4CAF50),
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                partner.name,
                style: const TextStyle(
                  color: Color(0xFF0D1B2A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 16),
                  const SizedBox(width: 3),
                  Text(
                    partner.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFF0D1B2A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _Tag(
                    label: partner.priceTier.toUpperCase(),
                    color: partner.priceTier == 'fair'
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFEF5350),
                  ),
                  const _Tag(label: 'SAFE', color: Color(0xFF4CAF50)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
