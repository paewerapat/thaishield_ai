import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/providers/locale_provider.dart';
import '../../onboarding/screens/language_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loadingLocation = false;
  String? _address;
  String? _locationError;

  Future<void> _updateLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _locationError = appText(context, 'profile_location_error'); _loadingLocation = false; });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() { _locationError = appText(context, 'profile_location_denied'); _loadingLocation = false; });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      var address = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [p.subLocality, p.locality, p.administrativeArea, p.country]
              .where((s) => s != null && s.isNotEmpty)
              .toList();
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {}

      if (mounted) setState(() { _address = address; _loadingLocation = false; });
    } catch (_) {
      if (mounted) setState(() { _locationError = appText(context, 'profile_location_error'); _loadingLocation = false; });
    }
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'dev@thaishieldapp.com',
      queryParameters: {
        'subject': 'ThaiShield AI – Feedback',
        'body': 'App version: 1.0.0\n\n[Please describe your feedback, issue, or suggestion here]',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  children: [
                    _buildLocationCard(context),
                    const SizedBox(height: 16),
                    _buildEmergencyCard(context),
                    const SizedBox(height: 16),
                    _buildLanguageTile(context, locale.languageCode),
                    const SizedBox(height: 12),
                    _buildFeedbackTile(context),
                    const SizedBox(height: 12),
                    _buildInfoTile(
                      context,
                      Icons.info_outline,
                      appText(context, 'profile_about_title'),
                      'Version 1.0.0',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1810),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/images/logo.jpg', width: 96, height: 96, fit: BoxFit.cover),
          ),
          const SizedBox(height: 14),
          const Text(
            'ThaiShield AI',
            style: TextStyle(color: Color(0xFFFFB300), fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            appText(context, 'home_tagline'),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 22),
          Text(
            appText(context, 'profile_title'),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            appText(context, 'profile_tagline'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.location_on, const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
              const SizedBox(width: 10),
              Text(
                appText(context, 'profile_current_location'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEEEEEE), height: 1),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 32),
                ),
                const SizedBox(height: 12),
                if (_loadingLocation)
                  const CircularProgressIndicator(color: Color(0xFF2E7D32))
                else if (_locationError != null)
                  Text(_locationError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12))
                else if (_address != null)
                  Text(_address!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.w600))
                else
                  Text(
                    appText(context, 'profile_location_placeholder'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _loadingLocation ? null : _updateLocation,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      appText(context, 'profile_update_location'),
                      style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF2E7D32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context) {
    final items = [
      (appText(context, 'profile_tourist_police'), '1155', const Color(0xFF1976D2), const Color(0xFFE3F2FD)),
      (appText(context, 'profile_police'), '191', const Color(0xFFD32F2F), const Color(0xFFFFEBEE)),
      (appText(context, 'profile_ambulance'), '1669', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.health_and_safety, const Color(0xFFFFA000), const Color(0xFFFFF3E0)),
              const SizedBox(width: 10),
              Text(
                appText(context, 'profile_emergency_help_center'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EmergencyRow(label: item.$1, number: item.$2, color: item.$3, background: item.$4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color, Color background) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildLanguageTile(BuildContext context, String langCode) {
    final flags = {
      'th': '🇹🇭',
      'en': '🇬🇧',
      'zh': '🇨🇳',
      'ko': '🇰🇷',
      'ru': '🇷🇺',
      'ja': '🇯🇵',
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Text(flags[langCode] ?? '🌐', style: const TextStyle(fontSize: 24)),
        title: Text(
          appText(context, 'profile_language'),
          style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          langCode.toUpperCase(),
          style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF0A1810),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => LanguageSelectionScreen(
              onLanguageSelected: () => Navigator.pop(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: const Icon(Icons.feedback_outlined, color: Color(0xFFFFB300)),
        title: Text(
          appText(context, 'profile_feedback'),
          style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          appText(context, 'profile_feedback_subtitle'),
          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
        onTap: _sendFeedback,
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, IconData icon, String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: const Color(0xFF4FC3F7)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0D1B2A),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
        ),
      ),
    );
  }
}

class _EmergencyRow extends StatelessWidget {
  const _EmergencyRow({required this.label, required this.number, required this.color, required this.background});

  final String label;
  final String number;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.local_phone, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.w600, fontSize: 13)),
                Text(number, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('tel:+66$number'),
              mode: Platform.isIOS
                  ? LaunchMode.externalApplication
                  : LaunchMode.externalNonBrowserApplication,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.call, size: 16),
            label: Text(appText(context, 'profile_call')),
          ),
        ],
      ),
    );
  }
}
