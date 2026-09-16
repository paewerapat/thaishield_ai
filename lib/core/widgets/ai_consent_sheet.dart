import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/legal_urls.dart';
import '../localization/app_text.dart';
import '../services/ai_consent.dart';

/// Which feature is asking, so the sheet can say exactly what leaves the
/// device and where it goes.
enum AiConsentPurpose { scanner, sos }

/// Returns true when the user has agreed — now or earlier — to this feature
/// sending their photo or voice to Google's AI services.
///
/// Shows the consent sheet only when no agreement is on record, so a user who
/// said yes once is never asked again unless they withdraw it in Profile. A
/// declined sheet returns false and records nothing: "not now" is not "never",
/// and the next press asks again.
///
/// See [AiConsentStore] for why this exists (App Review, 2026-09-16).
Future<bool> ensureAiConsent(
  BuildContext context,
  AiConsentPurpose purpose, {
  AiConsentStore? store,
}) async {
  final consent = store ?? AiConsentStore.instance;
  if (!consent.isLoaded) await consent.load();
  if (consent.isGranted) return true;
  if (!context.mounted) return false;

  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AiConsentSheet(purpose: purpose),
  );

  if (agreed == true) {
    await consent.grant();
    return true;
  }
  return false;
}

/// The sheet itself. Pops with `true` on agree, `false` on decline, and null
/// when dismissed by dragging or tapping outside — which the caller treats
/// the same as a decline.
class AiConsentSheet extends StatelessWidget {
  const AiConsentSheet({super.key, required this.purpose});

  final AiConsentPurpose purpose;

  static const _navy = Color(0xFF0D1B2A);
  static const _green = Color(0xFF2E7D32);
  static const _muted = Color(0xFF546E7A);

  String get _bodyKey => switch (purpose) {
        AiConsentPurpose.scanner => 'ai_consent_body_scanner',
        AiConsentPurpose.sos => 'ai_consent_body_sos',
      };

  IconData get _icon => switch (purpose) {
        AiConsentPurpose.scanner => Icons.document_scanner_outlined,
        AiConsentPurpose.sos => Icons.mic_none_rounded,
      };

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse(LegalUrls.privacy),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, color: _green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appText(context, 'ai_consent_title'),
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              appText(context, _bodyKey),
              style: const TextStyle(color: _navy, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              appText(context, 'ai_consent_common'),
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openPrivacyPolicy,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: _green,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new, size: 15),
                label: Text(
                  appText(context, 'ai_consent_privacy_link'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  appText(context, 'ai_consent_agree'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: _muted),
                child: Text(appText(context, 'ai_consent_decline')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
