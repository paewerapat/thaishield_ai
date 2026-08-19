import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/premium_feature.dart';
import '../providers/premium_provider.dart';
import '../screens/paywall_screen.dart';

/// The one way a feature asks "may I run?" — Phase 2B task 2.5.
///
/// Returns true when the caller may proceed. When it returns false the paywall
/// has already been shown and dismissed, so the caller does nothing further and
/// shows no message of its own.
///
/// It re-reads the provider after the paywall closes rather than returning
/// false outright, so a user who unlocks *while standing at the gate* lands on
/// the thing they asked for instead of having to tap it again. Nothing can
/// unlock mid-flow in 2B except the QA switch; from 2C a completed purchase
/// takes the same path.
Future<bool> ensurePremium(BuildContext context, PremiumFeature feature) async {
  if (context.read<PremiumProvider>().isPremium) return true;

  await showPaywall(context, feature: feature);
  if (!context.mounted) return false;

  return context.read<PremiumProvider>().isPremium;
}
