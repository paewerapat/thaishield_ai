import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../models/scan_result.dart';
import '../services/price_scan_service.dart';

enum _ScanState { idle, processing, noText, noMatch, error, results }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  _ScanState _state = _ScanState.idle;
  List<ScanResult> _results = const [];

  Future<void> _captureAndScan() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _state = _ScanState.processing);

    try {
      final text = await PriceScanService.instance.recognizeText(File(picked.path));
      if (text.trim().isEmpty) {
        if (!mounted) return;
        setState(() => _state = _ScanState.noText);
        return;
      }

      final standards = await FirestoreService.instance.getPriceStandards();
      final results = PriceScanService.instance.matchPrices(text, standards);
      if (!mounted) return;
      setState(() {
        if (results.isEmpty) {
          _state = _ScanState.noMatch;
        } else {
          _state = _ScanState.results;
          _results = results;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _ScanState.error);
    }
  }

  void _reset() => setState(() => _state = _ScanState.idle);

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
        return _StatusView(
          icon: null,
          loading: true,
          message: appText(context, 'scanner_processing'),
        );
      case _ScanState.noText:
        return _StatusView(
          icon: Icons.text_fields_rounded,
          message: appText(context, 'scanner_no_text_found'),
          onRetry: _reset,
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
        return _ResultsView(results: _results, onScanAgain: _reset);
      case _ScanState.idle:
        return _IdleView(onCapture: _captureAndScan);
    }
  }
}

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded, color: Color(0xFF4FC3F7), size: 22),
          const SizedBox(width: 8),
          const Text(
            'AI Price Scanner',
            style: TextStyle(
              color: Color(0xFF0D1B2A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(Icons.help_outline_rounded, color: Colors.grey[400], size: 22),
        ],
      ),
    );
  }
}

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
            const _PlaceholderIcon(),
            const SizedBox(height: 20),
            Text(
              appText(context, 'scanner_instructions_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              appText(context, 'scanner_instructions_subtitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(
                  appText(context, 'scanner_capture_button'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({this.icon, this.loading = false, required this.message, this.onRetry});
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
              style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4FC3F7),
                  side: const BorderSide(color: Color(0xFF4FC3F7)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.results, required this.onScanAgain});
  final List<ScanResult> results;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: results.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ResultCard(result: results[index], langCode: locale.languageCode),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            appText(context, 'scanner_disclaimer'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onScanAgain,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                side: const BorderSide(color: Color(0xFF4FC3F7)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(appText(context, 'scanner_scan_again')),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.langCode});
  final ScanResult result;
  final String langCode;

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final color = varianceColors[result.level]!;
    final pct = result.variancePercent;
    final pctLabel = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%';

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
              Expanded(
                child: Text(
                  result.standard.localizedName(langCode),
                  style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pctLabel,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PriceLabel(
                  label: appText(context, 'scanner_detected_price'),
                  value: '฿${_fmt(result.detectedPrice)}',
                  valueColor: const Color(0xFF0D1B2A),
                ),
              ),
              Expanded(
                child: _PriceLabel(
                  label: appText(context, 'scanner_typical_range'),
                  value: '฿${_fmt(result.standard.minPrice)} - ฿${_fmt(result.standard.maxPrice)}',
                  valueColor: const Color(0xFF90A4AE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _VarianceBar(result: result, color: color),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: color),
              const SizedBox(width: 6),
              Text(
                appText(context, varianceTextKey[result.level]!),
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  const _PriceLabel({required this.label, required this.value, required this.valueColor});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
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
    final scaleMax = [standard.maxPrice * 1.5, result.detectedPrice * 1.1, 1.0].reduce((a, b) => a > b ? a : b);

    final minFraction = (standard.minPrice / scaleMax).clamp(0.0, 1.0);
    final maxFraction = (standard.maxPrice / scaleMax).clamp(0.0, 1.0);
    final markerFraction = (result.detectedPrice / scaleMax).clamp(0.0, 1.0);

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
                decoration: BoxDecoration(color: const Color(0xFFEFF2F4), borderRadius: BorderRadius.circular(3)),
              ),
              Positioned(
                left: width * minFraction,
                child: Container(
                  height: 6,
                  width: width * (maxFraction - minFraction),
                  decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.35), borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Positioned(
                left: (width * markerFraction - 7).clamp(0.0, width - 14),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
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
