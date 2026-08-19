import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';

const _navy = Color(0xFF0D1B2A);
const _gold = Color(0xFFFFB300);

/// Closes the free tier's Radar list: says how many results were withheld and
/// offers the paywall.
///
/// Showing the count rather than hiding it is deliberate — a list that simply
/// stops looks like the search failed, and "there are 7 more" is both honest
/// and the actual argument for upgrading.
class PremiumLockedResultsCard extends StatelessWidget {
  const PremiumLockedResultsCard({
    super.key,
    required this.hiddenCount,
    required this.onUnlock,
  });

  final int hiddenCount;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFFB07800),
                  size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  appText(context, 'premium_locked_results')
                      .replaceFirst('{count}', '$hiddenCount'),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUnlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const Icon(Icons.workspace_premium_rounded, size: 17),
              label: Text(
                appText(context, 'premium_locked_action'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
