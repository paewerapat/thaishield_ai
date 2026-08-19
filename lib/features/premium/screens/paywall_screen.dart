import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_text.dart';
import '../models/premium_feature.dart';
import '../models/premium_plan.dart';
import '../providers/premium_provider.dart';

const _headerGreen = Color(0xFF0A1810);
const _pageGrey = Color(0xFFF3F5F7);
const _navy = Color(0xFF0D1B2A);
const _gold = Color(0xFFFFB300);
const _green = Color(0xFF2E7D32);
const _muted = Color(0xFF546E7A);

/// Opens the plan-comparison screen.
///
/// [feature] is the gate the user came from, which decides the line the screen
/// leads with — someone who tapped "Directions" is asked about routes, not
/// about the radar. Null when they opened it from Profile of their own accord.
Future<void> showPaywall(
  BuildContext context, {
  PremiumFeature? feature,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(feature: feature),
    ),
  );
}

/// Plan comparison and purchase entry point — Phase 2B task 2.5.
///
/// 🚨 **Nothing here can take money yet.** Billing is Phase 2C task 2.8; both
/// buttons currently land on [StoreOutcome.notAvailableYet] and say so. The
/// screen is built against `PremiumProvider.purchase` / `.restore` so 2C
/// replaces those two method bodies and this file does not change.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.feature});

  final PremiumFeature? feature;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PremiumPlan _selected = PremiumPlan.recommended;
  bool _busy = false;

  Future<void> _run(Future<StoreOutcome> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);

    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case StoreOutcome.success:
        Navigator.of(context).pop();
      case StoreOutcome.cancelled:
        break;
      case StoreOutcome.notAvailableYet:
      case StoreOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context, 'premium_store_unavailable'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PremiumProvider>();

    return Scaffold(
      backgroundColor: _pageGrey,
      body: Column(
        children: [
          _PaywallHeader(onClose: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                if (widget.feature != null) ...[
                  _GateBanner(feature: widget.feature!),
                  const SizedBox(height: 18),
                ],
                Text(
                  appText(context, 'premium_benefits_title'),
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                for (final feature in PremiumFeature.values)
                  _BenefitRow(text: appText(context, feature.headlineKey)),
                const SizedBox(height: 20),
                for (final plan in PremiumPlan.values) ...[
                  _PlanCard(
                    plan: plan,
                    selected: plan == _selected,
                    onTap: () => setState(() => _selected = plan),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 2),
                _FootNote(text: appText(context, 'premium_price_note')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _busy ? null : () => _run(() => provider.purchase(_selected)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB0BEC5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            appText(context, 'premium_cta'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    // Apple rejects an app that sells a non-consumable without
                    // a restore path, so this ships from 2B even though it
                    // cannot do anything until 2C.
                    onPressed: _busy ? null : () => _run(provider.restore),
                    child: Text(
                      appText(context, 'premium_restore'),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _FootNote(text: appText(context, 'premium_platform_note')),
                const SizedBox(height: 8),
                _FootNote(text: appText(context, 'premium_legal_note')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaywallHeader extends StatelessWidget {
  const _PaywallHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _headerGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'ThaiShield AI',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: _gold,
                          size: 22,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            appText(context, 'premium_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appText(context, 'premium_subtitle'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The line the screen leads with when a gate sent the user here.
class _GateBanner extends StatelessWidget {
  const _GateBanner({required this.feature});

  final PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, color: Color(0xFFB07800), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appText(context, feature.headlineKey),
              style: const TextStyle(
                color: _navy,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF37474F),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;

  /// Groups thousands without pulling in locale-specific number formatting for
  /// six languages — Phase 2C replaces this with the store's own localised
  /// price string anyway.
  static String _price(int thb) {
    final digits = thb.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '฿$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final isRecommended = plan == PremiumPlan.recommended;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _green : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _green : const Color(0xFFB0BEC5),
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          appText(context, plan.titleKey),
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appText(context, 'premium_badge_recommended'),
                            style: const TextStyle(
                              color: Color(0xFF3E2B00),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    appText(context, plan.periodKey),
                    style: const TextStyle(
                      color: Color(0xFF90A4AE),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _price(plan.priceThb),
              style: const TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  const _FootNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey[600], fontSize: 10.5, height: 1.4),
    );
  }
}
