import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../models/scan_result.dart';
import '../services/gemini_vision_service.dart';
import '../services/price_scan_service.dart';

enum _ScanState { idle, processing, identifying, noMatch, error, results }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.onViewOnMap});

  /// Called when the user taps "View on Map" on a scan result, with the
  /// latitude/longitude where the photo was taken.
  final void Function(double latitude, double longitude)? onViewOnMap;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  _ScanState _state = _ScanState.idle;
  List<ScanResult> _results = const [];
  File? _capturedImage;

  Future<void> _captureAndScan() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final imageFile = File(picked.path);
    setState(() {
      _state = _ScanState.processing;
      _capturedImage = imageFile;
    });

    try {
      final positionFuture = _currentPositionOrNull();
      final standards = await FirestoreService.instance.getPriceStandards();
      final text = await PriceScanService.instance.recognizeText(imageFile);
      final position = await positionFuture;

      if (text.trim().isNotEmpty) {
        final results = PriceScanService.instance.matchPrices(
          text,
          standards,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
        if (results.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _state = _ScanState.results;
            _results = results;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() => _state = _ScanState.identifying);

      final dishName = await GeminiVisionService.instance.identifyDish(
        imageFile,
        knownDishNames: standards.map((s) => s.nameEn).toList(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (dishName == null) {
        if (!mounted) return;
        setState(() => _state = _ScanState.noMatch);
        return;
      }

      final standard =
          PriceScanService.instance.findStandardByName(dishName, standards);
      if (!mounted) return;
      if (standard == null) {
        setState(() => _state = _ScanState.noMatch);
      } else {
        setState(() {
          _state = _ScanState.results;
          _results = [
            ScanResult.referenceOnly(
              standard,
              latitude: position?.latitude,
              longitude: position?.longitude,
            ),
          ];
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _ScanState.error);
    }
  }

  Future<Position?> _currentPositionOrNull() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  void _reset() => setState(() {
        _state = _ScanState.idle;
        _capturedImage = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Column(
          children: [
            const _ScannerHeader(),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _ScanState.processing:
        return _capturedImage != null
            ? _PhotoScanningView(
                imageFile: _capturedImage!,
                message: appText(context, 'scanner_processing'),
              )
            : _StatusView(
                loading: true,
                message: appText(context, 'scanner_processing'),
              );
      case _ScanState.identifying:
        return _capturedImage != null
            ? _PhotoScanningView(
                imageFile: _capturedImage!,
                message: appText(context, 'scanner_identifying'),
              )
            : _StatusView(
                loading: true,
                message: appText(context, 'scanner_identifying'),
              );
      case _ScanState.noMatch:
        return _StatusView(
          icon: Icons.search_off_rounded,
          message: appText(context, 'scanner_no_match_found'),
          onRetry: _reset,
        );
      case _ScanState.error:
        return _StatusView(
          icon: Icons.error_outline_rounded,
          message: appText(context, 'scanner_error_generic'),
          onRetry: _reset,
        );
      case _ScanState.results:
        return _ResultsView(
          results: _results,
          capturedImage: _capturedImage,
          onScanAgain: _reset,
          onViewOnMap: widget.onViewOnMap,
        );
      case _ScanState.idle:
        return _IdleView(onCapture: _captureAndScan);
    }
  }
}

// ═══════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1810),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded,
              color: Color(0xFFFFB300), size: 24),
          const SizedBox(width: 10),
          const Text(
            'AI Price Scanner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(Icons.help_outline_rounded,
              color: Colors.white.withValues(alpha: 0.7), size: 22),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Idle
// ═══════════════════════════════════════════════════

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onCapture});
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F7FD),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: Color(0xFF4FC3F7),
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              appText(context, 'scanner_instructions_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF0D1B2A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              appText(context, 'scanner_instructions_subtitle'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(
                  appText(context, 'scanner_capture_button'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Status (loading / no-match / error)
// ═══════════════════════════════════════════════════

class _StatusView extends StatelessWidget {
  const _StatusView({
    this.icon,
    this.loading = false,
    required this.message,
    this.onRetry,
  });
  final IconData? icon;
  final bool loading;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const CircularProgressIndicator(color: Color(0xFF4FC3F7))
            else
              Icon(icon, color: const Color(0xFF90A4AE), size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Color(0xFF0D1B2A), fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4FC3F7),
                  side: const BorderSide(color: Color(0xFF4FC3F7)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(appText(context, 'scanner_scan_again')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Results — full-screen hero layout
// ═══════════════════════════════════════════════════

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.results,
    required this.onScanAgain,
    this.capturedImage,
    this.onViewOnMap,
  });

  final List<ScanResult> results;
  final File? capturedImage;
  final VoidCallback onScanAgain;
  final void Function(double, double)? onViewOnMap;

  @override
  Widget build(BuildContext context) {
    final langCode =
        context.watch<LocaleProvider>().locale.languageCode;
    final primary = results.first;

    return Column(
      children: [
        _HeroSection(
          result: primary,
          langCode: langCode,
          capturedImage: capturedImage,
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryChip(category: primary.standard.category),
                  const SizedBox(height: 16),
                  _PriceDisplay(result: primary),
                  if (!primary.isReferenceOnly) ...[
                    const SizedBox(height: 20),
                    _VarianceSection(result: primary),
                  ],
                  if (results.length > 1) ...[
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 14),
                    Text(
                      appText(context, 'scanner_other_matches'),
                      style: const TextStyle(
                        color: Color(0xFF90A4AE),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...results.skip(1).map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _CompactResultRow(
                                result: r, langCode: langCode),
                          ),
                        ),
                  ],
                  if (primary.hasLocation) ...[
                    const SizedBox(height: 20),
                    _LocationCard(
                        result: primary, onViewOnMap: onViewOnMap),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    appText(context, 'scanner_disclaimer'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onScanAgain,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4FC3F7),
                        side: const BorderSide(color: Color(0xFF4FC3F7)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                      icon:
                          const Icon(Icons.camera_alt_outlined, size: 18),
                      label: Text(
                        appText(context, 'scanner_scan_again'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// Hero section — food photo + dish name
// ═══════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.result,
    required this.langCode,
    this.capturedImage,
  });

  final ScanResult result;
  final String langCode;
  final File? capturedImage;

  @override
  Widget build(BuildContext context) {
    final imageUrl = result.standard.imageUrl;
    final hasRefImage = imageUrl.isNotEmpty;

    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background: reference dish photo or captured fallback ──
          if (hasRefImage)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => _capturedOrPlaceholder(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _capturedOrPlaceholder(),
            )
          else
            _capturedOrPlaceholder(),

          // ── Gradient overlay ──
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.3, 1.0],
                colors: [Colors.transparent, Color(0xE6000000)],
              ),
            ),
          ),

          // ── Captured photo thumbnail (when ref image is the hero) ──
          if (capturedImage != null && hasRefImage)
            Positioned(
              right: 16,
              bottom: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.file(capturedImage!, fit: BoxFit.cover),
                ),
              ),
            ),

          // ── Dish name + AI badge ──
          Positioned(
            left: 20,
            right: (capturedImage != null && hasRefImage) ? 84 : 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (result.isReferenceOnly) ...[
                  const _AiBadge(),
                  const SizedBox(height: 6),
                ],
                Text(
                  result.standard.localizedName(langCode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black87)
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capturedOrPlaceholder() {
    if (capturedImage != null) {
      return Image.file(capturedImage!, fit: BoxFit.cover);
    }
    return _CategoryBackground(category: result.standard.category);
  }
}

class _CategoryBackground extends StatelessWidget {
  const _CategoryBackground({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final (icon, c1, c2) = switch (category) {
      'transport' => (
          Icons.directions_car_rounded,
          const Color(0xFF0D3352),
          const Color(0xFF1565C0),
        ),
      'attraction' => (
          Icons.account_balance_rounded,
          const Color(0xFF1A3A20),
          const Color(0xFF2E7D32),
        ),
      _ => (
          Icons.restaurant_rounded,
          const Color(0xFF3A1428),
          const Color(0xFF880E4F),
        ),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon,
            color: Colors.white.withValues(alpha: 0.15), size: 100),
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            appText(context, 'scanner_ai_identified'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Category chip
// ═══════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final (icon, color, labelKey) = switch (category) {
      'transport' => (
          Icons.directions_car_rounded,
          const Color(0xFF4FC3F7),
          'scanner_category_transport',
        ),
      'attraction' => (
          Icons.account_balance_rounded,
          const Color(0xFF2E7D32),
          'scanner_category_attraction',
        ),
      _ => (
          Icons.restaurant_rounded,
          const Color(0xFFFFB300),
          'scanner_category_food',
        ),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            appText(context, labelKey),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Price display
// ═══════════════════════════════════════════════════

class _PriceDisplay extends StatelessWidget {
  const _PriceDisplay({required this.result});
  final ScanResult result;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (result.isReferenceOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, 'scanner_reference_range'),
            style: const TextStyle(
                color: Color(0xFF90A4AE), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '฿${_fmt(result.standard.minPrice)} – ฿${_fmt(result.standard.maxPrice)}',
            style: const TextStyle(
              color: Color(0xFF0D1B2A),
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      );
    }

    final color = varianceColors[result.level]!;
    final pct = result.variancePercent!;
    final pctLabel =
        '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText(context, 'scanner_detected_price'),
          style: const TextStyle(
              color: Color(0xFF90A4AE), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '฿${_fmt(result.detectedPrice!)}',
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pctLabel,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${appText(context, 'scanner_typical_range')}: ฿${_fmt(result.standard.minPrice)} – ฿${_fmt(result.standard.maxPrice)}',
          style: const TextStyle(
              color: Color(0xFF90A4AE), fontSize: 13),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// Variance bar + status label
// ═══════════════════════════════════════════════════

class _VarianceSection extends StatelessWidget {
  const _VarianceSection({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final color = varianceColors[result.level]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VarianceBar(result: result, color: color),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              appText(context, varianceTextKey[result.level]!),
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class _VarianceBar extends StatelessWidget {
  const _VarianceBar({required this.result, required this.color});
  final ScanResult result;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final standard = result.standard;
    final detectedPrice = result.detectedPrice!;
    final scaleMax =
        [standard.maxPrice * 1.5, detectedPrice * 1.1, 1.0]
            .reduce((a, b) => a > b ? a : b);

    final minFraction =
        (standard.minPrice / scaleMax).clamp(0.0, 1.0);
    final maxFraction =
        (standard.maxPrice / scaleMax).clamp(0.0, 1.0);
    final markerFraction =
        (detectedPrice / scaleMax).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 20,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                width: width,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: width * minFraction,
                child: Container(
                  height: 6,
                  width: width * (maxFraction - minFraction),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32)
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: (width * markerFraction - 7)
                    .clamp(0.0, width - 14),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// Photo scanning animation
// ═══════════════════════════════════════════════════

class _PhotoScanningView extends StatefulWidget {
  const _PhotoScanningView({
    required this.imageFile,
    required this.message,
  });
  final File imageFile;
  final String message;

  @override
  State<_PhotoScanningView> createState() => _PhotoScanningViewState();
}

class _PhotoScanningViewState extends State<_PhotoScanningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(widget.imageFile, fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.5)),
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (context, _) => CustomPaint(
            painter: _ScanOverlayPainter(scanProgress: _scanAnim.value),
          ),
        ),
        Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFF4FC3F7),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({required this.scanProgress});
  final double scanProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const accent = Color(0xFF4FC3F7);

    final frameRect = Rect.fromLTRB(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.92,
      size.height * 0.68,
    );
    const cornerLen = 28.0;

    final cornerPaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Corner brackets
    canvas.drawLine(frameRect.topLeft,
        frameRect.topLeft.translate(cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.topLeft,
        frameRect.topLeft.translate(0, cornerLen), cornerPaint);
    canvas.drawLine(frameRect.topRight,
        frameRect.topRight.translate(-cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.topRight,
        frameRect.topRight.translate(0, cornerLen), cornerPaint);
    canvas.drawLine(frameRect.bottomLeft,
        frameRect.bottomLeft.translate(cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.bottomLeft,
        frameRect.bottomLeft.translate(0, -cornerLen), cornerPaint);
    canvas.drawLine(frameRect.bottomRight,
        frameRect.bottomRight.translate(-cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.bottomRight,
        frameRect.bottomRight.translate(0, -cornerLen), cornerPaint);

    final scanY = frameRect.top + scanProgress * frameRect.height;

    // Glow
    canvas.drawRect(
      Rect.fromLTRB(
          frameRect.left, scanY - 8, frameRect.right, scanY + 8),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            accent.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(
            frameRect.left, scanY - 8, frameRect.right, scanY + 8)),
    );

    // Scan line
    canvas.drawRect(
      Rect.fromLTRB(
          frameRect.left, scanY - 1, frameRect.right, scanY + 1),
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, accent, Colors.transparent],
        ).createShader(Rect.fromLTRB(
            frameRect.left, scanY - 1, frameRect.right, scanY + 1)),
    );
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanProgress != scanProgress;
}

// ═══════════════════════════════════════════════════
// Location card
// ═══════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.result, this.onViewOnMap});
  final ScanResult result;
  final void Function(double, double)? onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Color(0xFF4FC3F7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'scanner_scan_location'),
                  style: const TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.latitude!.toStringAsFixed(4)}, '
                  '${result.longitude!.toStringAsFixed(4)}',
                  style: const TextStyle(
                      color: Color(0xFF90A4AE), fontSize: 11),
                ),
              ],
            ),
          ),
          if (onViewOnMap != null)
            TextButton(
              onPressed: () =>
                  onViewOnMap!(result.latitude!, result.longitude!),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appText(context, 'scanner_view_location'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Compact row for secondary OCR matches
// ═══════════════════════════════════════════════════

class _CompactResultRow extends StatelessWidget {
  const _CompactResultRow(
      {required this.result, required this.langCode});
  final ScanResult result;
  final String langCode;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final color = result.isReferenceOnly
        ? const Color(0xFFFFB300)
        : varianceColors[result.level]!;
    final label = result.isReferenceOnly
        ? '฿${_fmt(result.standard.minPrice)}–฿${_fmt(result.standard.maxPrice)}'
        : '${result.variancePercent! >= 0 ? '+' : ''}'
            '${result.variancePercent!.toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result.standard.localizedName(langCode),
              style: const TextStyle(
                color: Color(0xFF0D1B2A),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
