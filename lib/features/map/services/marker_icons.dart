import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/partner_category.dart';

/// Map pins drawn as the design poster draws them: a rounded badge carrying the
/// category's own glyph, with a pointed tail, rather than Google's plain
/// teardrop.
///
/// ## Why this exists
///
/// `BitmapDescriptor.defaultMarkerWithHue` can only tint the stock teardrop, so
/// every pin on the map looked identical apart from its colour. The poster
/// shows a shop, a hospital cross, a train, a park and a police badge, and that
/// difference is most of what makes its map readable at a glance. The client
/// asked for the pins to match it on 2026-08-31.
///
/// ## The colour rule this must not break
///
/// 🚨 **Every partner business is blue.** The client asked for that explicitly
/// on 2026-08-29 — restaurants, hotels, shops, banks and attractions read as
/// one programme rather than eleven colours to decode. So the *fill* comes from
/// [partnerCategoryMarkerHue]'s three groups (blue partners, red emergency,
/// cyan transport) and only the *glyph* varies by category. Do not switch the
/// fill to [partnerCategoryColor], which is the per-category palette used by
/// list rows and would undo that request.
///
/// ## Cost
///
/// Each icon is rasterised once per (category, pixel ratio) and cached for the
/// life of the process. There are eleven categories, so this is a handful of
/// small bitmaps — but it is real work on the raster thread, which is why
/// [warmUp] exists and why `map_screen` awaits it before building markers
/// rather than rasterising inside the marker loop.
class MarkerIcons {
  MarkerIcons._();

  static final MarkerIcons instance = MarkerIcons._();

  final Map<String, BitmapDescriptor> _cache = {};

  /// Logical size of the badge. Kept modest: a pin large enough to read is also
  /// large enough to hide the thing it is pointing at when several cluster on
  /// one street.
  static const double _badge = 34;
  static const double _tail = 9;
  static const double _glyph = 19;

  String _key(PartnerCategory category, double ratio) =>
      '${category.name}@${ratio.toStringAsFixed(2)}';

  /// Draws every category once so the first map frame does not stutter.
  ///
  /// Failure here is not worth breaking the map over — a category that cannot
  /// be drawn simply falls back to the stock marker in [forCategory].
  Future<void> warmUp(double devicePixelRatio) async {
    for (final category in PartnerCategory.values) {
      try {
        await forCategory(category, devicePixelRatio);
      } catch (_) {
        // Leave it uncached; forCategory will fall back each time.
      }
    }
  }

  Future<BitmapDescriptor> forCategory(
    PartnerCategory category,
    double devicePixelRatio,
  ) async {
    final key = _key(category, devicePixelRatio);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final descriptor = await _draw(category, devicePixelRatio);
      _cache[key] = descriptor;
      return descriptor;
    } catch (_) {
      // A pin that renders is worth more than a pin that matches the poster.
      return BitmapDescriptor.defaultMarkerWithHue(
        partnerCategoryMarkerHue[category] ?? BitmapDescriptor.hueAzure,
      );
    }
  }

  Future<BitmapDescriptor> _draw(
    PartnerCategory category,
    double ratio,
  ) async {
    final fill = _fillFor(category);
    final icon = partnerCategoryIcon[category] ?? Icons.place_rounded;

    final width = _badge * ratio;
    final height = (_badge + _tail) * ratio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, _badge * ratio),
      Radius.circular(11 * ratio),
    );

    // Shadow first, so the pin lifts off the map rather than sitting flat on a
    // busy satellite tile.
    canvas.drawRRect(
      badgeRect.shift(Offset(0, 1.5 * ratio)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * ratio),
    );

    // The tail, drawn before the badge so the badge's border covers its join.
    final tailPath = Path()
      ..moveTo(width / 2 - 6 * ratio, (_badge - 1) * ratio)
      ..lineTo(width / 2, height)
      ..lineTo(width / 2 + 6 * ratio, (_badge - 1) * ratio)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = fill);

    canvas.drawRRect(badgeRect, Paint()..color = fill);
    canvas.drawRRect(
      badgeRect.deflate(1 * ratio),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * ratio
        ..color = Colors.white,
    );

    // The glyph comes out of the icon font — the same IconData the list rows
    // use, so a category can never show one symbol on the map and another in a
    // card.
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: _glyph * ratio,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      Offset(
        (width - painter.width) / 2,
        (_badge * ratio - painter.height) / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(
          width.ceil(),
          height.ceil(),
        );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('marker did not rasterise');

    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: _badge,
      height: _badge + _tail,
    );
  }

  /// 🚨 Group colour, not per-category colour — see the class comment.
  Color _fillFor(PartnerCategory category) {
    final hue = partnerCategoryMarkerHue[category] ?? BitmapDescriptor.hueAzure;
    if (hue == 0) return const Color(0xFFD32F2F); // emergency services
    if (hue == 180) return const Color(0xFF00838F); // getting around
    return const Color(0xFF1565C0); // every partner business
  }

  @visibleForTesting
  void clearCache() => _cache.clear();

  @visibleForTesting
  int get cachedCount => _cache.length;

  @visibleForTesting
  Future<Uint8List?> rawBytesFor(
    PartnerCategory category,
    double ratio,
  ) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder);
    final descriptor = await _draw(category, ratio);
    return descriptor is BytesMapBitmap ? descriptor.byteData : null;
  }
}
