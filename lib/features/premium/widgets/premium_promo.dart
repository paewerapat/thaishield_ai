import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_text.dart';
import '../providers/premium_provider.dart';
import '../screens/paywall_screen.dart';

/// The Premium card from the top right of the design poster.
///
/// ## What it is
///
/// A crown, the word Premium, one line about what a member gets, and a
/// full-width button into the plans. That is the whole poster treatment, and
/// on 2026-08-31 the client asked for exactly that and nothing more.
///
/// It replaced a dark horizontal strip of feature chips that shipped earlier
/// the same day. The strip was accurate and ugly, which on the first screen of
/// a travel app is the wrong trade: this card carries the same message in the
/// shape the designer drew.
///
/// ## Why the words are not the poster's words
///
/// 🚨 The poster's card reads "ข้อมูลเชิงลึกแบบเรียลไทม์และครบถ้วนยิ่งขึ้น" —
/// real-time in-depth data. That describes AI Local Insights, which was
/// cancelled, and "real-time updates, 24 hours", which describes news the app
/// already refreshes every ten minutes for everyone free. Printing it would be
/// taking a subscription for things the app does not do, from a tourist, in six
/// languages. The layout is the poster's; the sentence says what is actually
/// behind the paywall.
///
/// ## Why it never hides
///
/// A fresh install starts the 3-day trial, so "hide it when access is active"
/// hides it from every new user — which is exactly the bug that made the whole
/// paywall unreachable for three days (see `paywall_reachability_test.dart`).
/// It stays, and says something true for each state instead.
const _cream = Color(0xFFFDF6E3);
const _creamBorder = Color(0xFFF0E2BC);
const _crownGold = Color(0xFFC9A227);
const _deepGreen = Color(0xFF0A1810);
const _bodyGrey = Color(0xFF6B7A70);

class PremiumHomeCard extends StatelessWidget {
  const PremiumHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    final onTrial = premium.isOnTrial;
    final active = premium.isPremium;
    final days = premium.daysRemaining;

    final String subtitle;
    if (onTrial && days != null) {
      subtitle = appText(context, 'premium_status_trial')
          .replaceFirst('{days}', '$days');
    } else if (active) {
      subtitle = appText(context, 'premium_status_active_title');
    } else {
      subtitle = appText(context, 'premium_strip_title');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _creamBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: _crownGold,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: _deepGreen,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _deepGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      appText(context, 'premium_promo_body'),
                      style: const TextStyle(
                        color: _bodyGrey,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => showPaywall(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _deepGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                appText(context, active ? 'premium_upgrade_action' : 'premium_cta'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
