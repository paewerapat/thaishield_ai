import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_text.dart';
import '../models/premium_feature.dart';
import '../providers/premium_provider.dart';
import '../screens/paywall_screen.dart';

/// The design poster's premium band, and the Home card that leads to it.
///
/// ## What these may say
///
/// 🚨 **Only features that exist and are actually gated.** The poster's band
/// advertises six things; three of them — AI Local Insights, Offline Map and
/// Smart Alerts — were cancelled, and a fourth, "real-time updates, 24 hours",
/// describes news that already refreshes every ten minutes for everyone free.
/// Reproducing that band would be selling a subscription on four things the app
/// does not do, to a tourist, in six languages. The strip therefore lists the
/// three gates that are real: the Radar past its free limit, the Filter panel,
/// and Route Suggestion — the same list as [PremiumFeature], so it cannot drift
/// from what is actually locked.
///
/// ## Why the card changes with entitlement rather than hiding
///
/// A fresh install starts the 3-day trial, so "hide it when access is active"
/// hides it from every new user — which is exactly the bug that made the whole
/// paywall invisible for three days (see `paywall_reachability_test.dart`).
/// It stays, and says something true for each state instead.
const _headerGreen = Color(0xFF0A1810);
const _gold = Color(0xFFFFB300);
const _mutedOnDark = Color(0xFF8FAF94);

/// The three real gates, in the order the paywall lists them.
const _stripFeatures = <(IconData, PremiumFeature)>[
  (Icons.travel_explore_rounded, PremiumFeature.radarResults),
  (Icons.tune_rounded, PremiumFeature.filterPanel),
  (Icons.alt_route_rounded, PremiumFeature.routeSuggestion),
];

/// The poster's dark band: a crown, a title, and what a member gets.
///
/// Horizontally scrollable on purpose. Four chips in a fixed [Row] overflowed
/// by 5.7px in Thai once, while analyze and 166 tests stayed green — six
/// languages and three labels go through here.
class PremiumFeaturesStrip extends StatelessWidget {
  const PremiumFeaturesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _headerGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: _gold, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    appText(context, 'premium_strip_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final (icon, feature) in _stripFeatures) ...[
                  _StripItem(icon: icon, labelKey: feature.headlineKey),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.icon, required this.labelKey});

  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 20),
          const SizedBox(height: 8),
          Text(
            appText(context, labelKey),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _mutedOnDark,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Home tab's way in — the thing that was missing entirely.
///
/// Three states, all of which say something true:
///
/// - **free** — what a member gets, and a button to the plans;
/// - **on trial** — that the member features are open now and for how long,
///   without implying a charge is coming (the in-app trial does not convert);
/// - **subscribed** — a quiet confirmation, and still a way into the plans, so
///   someone can read what they pay for and find the cancel instructions.
class PremiumHomeCard extends StatelessWidget {
  const PremiumHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    final onTrial = premium.isOnTrial;
    final active = premium.isPremium;
    final days = premium.daysRemaining;

    final String headline;
    final String body;
    if (onTrial) {
      headline = appText(context, 'premium_promo_trial_headline');
      body = days == null
          ? appText(context, 'premium_promo_body')
          : appText(context, 'premium_status_trial')
              .replaceFirst('{days}', '$days');
    } else if (active) {
      headline = appText(context, 'premium_status_active_title');
      body = appText(context, 'premium_promo_body');
    } else {
      headline = appText(context, 'premium_promo_headline');
      body = appText(context, 'premium_promo_body');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFB8860B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Color(0xFF0D1B2A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Color(0xFF607D8B),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => showPaywall(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                appText(
                  context,
                  active ? 'premium_upgrade_action' : 'premium_cta',
                ),
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
