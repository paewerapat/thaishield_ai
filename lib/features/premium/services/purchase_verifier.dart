import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What a store said about a purchase when asked by our own server.
///
/// [valid] is only meaningful when [hasOpinion] is true. A verifier that could
/// not reach the store, or that has not been given the console permissions it
/// needs, answers with [PurchaseVerification.noOpinion] — never with
/// `valid: false`. The difference matters: no opinion means "fall back to the
/// store SDK on the device", while invalid means "do not grant this".
@immutable
class PurchaseVerification {
  const PurchaseVerification({
    required this.hasOpinion,
    required this.valid,
    this.expiresAt,
    this.purchasedAt,
    this.reason,
  });

  const PurchaseVerification.noOpinion()
      : hasOpinion = false,
        valid = false,
        expiresAt = null,
        purchasedAt = null,
        reason = 'unavailable';

  final bool hasOpinion;
  final bool valid;

  /// When the store says access ends — a subscription's real renewal date, or
  /// the pass's purchase time plus its fortnight. Replaces the app's own
  /// estimate whenever it is present.
  final DateTime? expiresAt;

  final DateTime? purchasedAt;
  final String? reason;
}

/// Asks our `validatePurchase` Cloud Function whether a purchase is real.
///
/// ## Why the app cannot answer this itself
///
/// Everything the app knows about a purchase arrives from the store SDK on the
/// user's own device, and `EntitlementRepository` is explicit that its
/// Firestore copy is not a security boundary — the rules have to let an
/// unauthenticated client write there. Neither is proof that money moved. Play
/// and Apple will answer for a receipt, but only to a server: the credentials
/// that ask the question cannot ship inside an APK.
///
/// ## What it fixes beyond fraud
///
/// The honest bug it closes is not a thief, it is arithmetic. A client cannot
/// see a subscription's real renewal date, so `PremiumProvider` has to grant a
/// rolling horizon of one billing period and re-confirm on every launch — which
/// over-grants access to someone who cancels and then stays offline. And the
/// 14-day pass measured from a device clock is a pass that can be extended by
/// changing the date. The function answers both with the store's own dates.
///
/// ## Failure is silence, never denial
///
/// 🚨 Every failure path here returns [PurchaseVerification.noOpinion]. If this
/// class ever starts answering `valid: false` for a network timeout, a paying
/// user on a bad connection loses what they bought. The only thing that
/// produces `valid: false` is the store itself saying so.
abstract class PurchaseVerifier {
  Future<PurchaseVerification> verify({
    required String productId,
    required String token,
  });
}

class CloudFunctionVerifier implements PurchaseVerifier {
  CloudFunctionVerifier({http.Client? client, String? platform})
      : _client = client ?? http.Client(),
        _platform = platform ?? _detectPlatform();

  static final instance = CloudFunctionVerifier();

  /// Same host shape as `RouteService`: the `cloudfunctions.net` form is
  /// derivable from region and project id, so it can be written down before the
  /// first deploy.
  static const endpoint =
      'https://asia-southeast1-thaishield-ai-790eb.cloudfunctions.net/validatePurchase';

  static const _timeout = Duration(seconds: 12);

  final http.Client _client;

  /// Which store to ask. Sent rather than inferred server-side because the
  /// token formats are not distinguishable with any confidence — Play's is an
  /// opaque string and Apple's is base64.
  final String _platform;

  static String _detectPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  @override
  Future<PurchaseVerification> verify({
    required String productId,
    required String token,
  }) async {
    if (token.isEmpty || _platform == 'unknown') {
      return const PurchaseVerification.noOpinion();
    }

    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'platform': _platform,
              'productId': productId,
              'token': token,
            }),
          )
          .timeout(_timeout);

      // 4xx here is this app sending something the function refuses — an
      // unknown product id, a malformed token. That is a bug in the caller,
      // not evidence about the user, so it is still no opinion.
      if (response.statusCode != 200) {
        return const PurchaseVerification.noOpinion();
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return const PurchaseVerification.noOpinion();
      }

      final reason = body['reason'] as String?;
      if (reason == 'unavailable') {
        return const PurchaseVerification.noOpinion();
      }

      return PurchaseVerification(
        hasOpinion: true,
        valid: body['valid'] == true,
        expiresAt: _millis(body['expiresAtMillis']),
        purchasedAt: _millis(body['purchasedAtMillis']),
        reason: reason,
      );
    } catch (_) {
      // Timeout, DNS, offline, malformed JSON. All of it is silence.
      return const PurchaseVerification.noOpinion();
    }
  }

  static DateTime? _millis(Object? raw) {
    final millis = raw is int ? raw : int.tryParse('${raw ?? ''}');
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
