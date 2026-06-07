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
      return const Color(0xFFFFCA28);
    default:
      return const Color(0xFF66BB6A);
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
  bool _loading = true;
  String? _error;

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
            onTap: () => _showPartnerSheet(partner),
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
            fillColor: color.withValues(alpha: 0.18),
            strokeColor: color,
            strokeWidth: 2,
            consumeTapEvents: true,
            onTap: () => _showZoneSheet(zone),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
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

  void _showPartnerSheet(PartnerLocation partner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF142233),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PartnerSheet(partner: partner),
    );
  }

  void _showZoneSheet(AlertZone zone) {
    final locale = Localizations.localeOf(context).languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF142233),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ZoneSheet(zone: zone, langCode: locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
              )
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _bangkok,
                      zoom: 12,
                    ),
                    markers: _markers,
                    circles: _circles,
                    myLocationButtonEnabled: false,
                  ),
      ),
    );
  }
}

class _PartnerSheet extends StatelessWidget {
  const _PartnerSheet({required this.partner});

  final PartnerLocation partner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  partner.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (partner.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4FC3F7)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Color(0xFF4FC3F7), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFCA28), size: 18),
              const SizedBox(width: 4),
              Text(
                partner.rating.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Icon(_typeIcon(partner.type), color: Colors.white38, size: 16),
              const SizedBox(width: 4),
              Text(
                partner.type,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'hotel':
        return Icons.hotel;
      case 'transport':
        return Icons.directions_car;
      default:
        return Icons.restaurant;
    }
  }
}

class _ZoneSheet extends StatelessWidget {
  const _ZoneSheet({required this.zone, required this.langCode});

  final AlertZone zone;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(zone.riskLevel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  zone.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            zone.localizedDescription(langCode),
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
