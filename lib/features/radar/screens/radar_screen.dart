import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/services/location_service.dart';
import '../../map/screens/map_screen.dart';
import '../../premium/models/premium_feature.dart';
import '../../premium/providers/premium_provider.dart';
import '../../premium/screens/paywall_screen.dart';
import '../../premium/widgets/premium_gate.dart';
import '../../premium/widgets/premium_lock_card.dart';
import '../models/radar_filters.dart';
import '../models/radar_result.dart';
import '../services/radar_service.dart';
import '../widgets/filter_panel.dart';
import '../widgets/radar_cards.dart';

const _headerGreen = Color(0xFF0A1810);
const _pageGrey = Color(0xFFF3F5F7);
const _navy = Color(0xFF0D1B2A);
const _gold = Color(0xFFFFB300);
const _green = Color(0xFF2E7D32);

enum _RadarState { idle, locating, scanning, ready, failed }

/// "What's Around Me" — Phase 2A task 2.1.
///
/// Pushed as a full screen; pops a [MapFocusRequest] when the user taps
/// "Show on Map" on a card, which the host switches to the Map tab with.
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  _RadarState _state = _RadarState.idle;
  String _errorKey = 'radar_location_error';
  double _radiusKm = RadarService.defaultRadiusKm;
  RadarFilters _filters = RadarFilters.all();
  RadarResult? _result;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    // Opening the screen is the request — no extra tap needed. A denied
    // permission drops back to the idle state with a retry button.
    //
    // Opening counts as an activation, so aged data is refetched rather than
    // served from the cache: someone opening the Radar is asking what is
    // around them *now*.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scan(forceRefresh: RadarService.instance.isStaleForActivation),
    );
  }

  /// [reuseLocation] re-runs the search over the cached position when only the
  /// radius or the filters changed, so we don't ask for a new GPS fix.
  /// [forceRefresh] bypasses the shared cache. Radius and filter changes leave
  /// it false — those re-run the maths locally and should never cost a round
  /// trip — while opening the screen and the manual refresh button set it.
  Future<void> _scan({
    bool reuseLocation = false,
    bool forceRefresh = false,
  }) async {
    var center = _center;

    if (!reuseLocation || center == null) {
      setState(() => _state = _RadarState.locating);
      final location = await LocationService.instance.current();
      if (!mounted) return;
      if (!location.isOk) {
        setState(() {
          _state = _RadarState.failed;
          _errorKey = switch (location.status) {
            LocationStatus.denied => 'radar_location_denied',
            LocationStatus.serviceDisabled => 'radar_location_disabled',
            _ => 'radar_location_error',
          };
        });
        return;
      }
      center = location.position!;
      _center = center;
    }

    setState(() => _state = _RadarState.scanning);
    try {
      final result = await RadarService.instance.scan(
        center: center,
        radiusKm: _radiusKm,
        categories: _filters.categories,
        riskLevels: _filters.riskLevels,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _RadarState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _RadarState.failed;
        _errorKey = 'radar_load_error';
      });
    }
  }

  void _onRadiusChanged(double km) {
    if (km == _radiusKm) return;
    setState(() => _radiusKm = km);
    _scan(reuseLocation: true);
  }

  Future<void> _openFilters() async {
    if (!await ensurePremium(context, PremiumFeature.filterPanel)) return;
    if (!mounted) return;

    final updated = await showRadarFilterPanel(context, _filters);
    if (updated == null || !mounted) return;
    setState(() => _filters = updated);
    _scan(reuseLocation: true);
  }

  void _showOnMap(double lat, double lng) =>
      Navigator.of(context).pop(MapFocusRequest(lat, lng));

  Future<void> _openPaywall() async {
    await showPaywall(context, feature: PremiumFeature.radarResults);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageGrey,
      body: Column(
        children: [
          _RadarHeader(
            onBack: () => Navigator.of(context).pop(),
            onRefresh: () => _scan(reuseLocation: true, forceRefresh: true),
            refreshing: _state == _RadarState.scanning,
          ),
          _RadarToolbar(
            radiusKm: _radiusKm,
            onRadiusChanged: _onRadiusChanged,
            activeFilterCount: _filters.activeCount,
            onOpenFilters: _openFilters,
            filtersLocked: !context.watch<PremiumProvider>().isPremium,
            busy: _state == _RadarState.locating ||
                _state == _RadarState.scanning,
          ),
          Expanded(child: _buildBody()),
          const _RadarDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _RadarState.idle:
      case _RadarState.locating:
      case _RadarState.scanning:
        return _CenteredMessage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _green),
              const SizedBox(height: 16),
              Text(
                appText(context, 'radar_scanning'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13),
              ),
            ],
          ),
        );

      case _RadarState.failed:
        return _CenteredMessage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded, color: Color(0xFF90A4AE), size: 44),
              const SizedBox(height: 12),
              Text(
                appText(context, _errorKey),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => _scan(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(appText(context, 'radar_retry')),
              ),
            ],
          ),
        );

      case _RadarState.ready:
        final full = _result;
        // The free tier sees the nearest few results and a card saying how
        // many more the radius holds (Phase 2B task 2.5). The scan itself is
        // unchanged — this only trims what is drawn.
        final isPremium = context.watch<PremiumProvider>().isPremium;
        final result = full == null || isPremium
            ? full
            : full.take(PremiumProvider.freeRadarResultLimit);
        final hiddenCount =
            full == null ? 0 : full.count - (result?.count ?? 0);

        if (result == null || result.isEmpty) {
          return _CenteredMessage(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radar_rounded, color: Color(0xFF90A4AE), size: 44),
                const SizedBox(height: 12),
                Text(
                  appText(
                    context,
                    _filters.isAll ? 'radar_empty' : 'radar_empty_filtered',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          );
        }

        final groups = result.grouped.entries.toList();
        final showLockCard = hiddenCount > 0;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          itemCount: groups.length + (showLockCard ? 2 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                // The count is the full one on purpose: the header states
                // what is in the radius, and the lock card below explains why
                // fewer cards are drawn.
                appText(context, 'radar_results_found')
                    .replaceFirst('{count}', '${full!.count}'),
                style: const TextStyle(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              );
            }
            if (showLockCard && index == groups.length + 1) {
              return PremiumLockedResultsCard(
                hiddenCount: hiddenCount,
                onUnlock: _openPaywall,
              );
            }
            final group = groups[index - 1];
            return RadarGroupSection(
              group: group.key,
              entries: group.value,
              onShowOnMap: _showOnMap,
            );
          },
        );
    }
  }
}

class _RadarHeader extends StatelessWidget {
  const _RadarHeader({
    required this.onBack,
    required this.onRefresh,
    required this.refreshing,
  });

  final VoidCallback onBack;

  /// Refetches both collections, ignoring the cache. Opening the screen
  /// already refreshes aged data, but there is no way for a user standing
  /// somewhere to tell how old "aged" is — so give them the control.
  final VoidCallback onRefresh;
  final bool refreshing;

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
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ThaiShield AI',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appText(context, 'radar_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appText(context, 'radar_subtitle'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: IconButton(
                  onPressed: refreshing ? null : onRefresh,
                  tooltip: appText(context, 'radar_refresh'),
                  icon: refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: _gold, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarToolbar extends StatelessWidget {
  const _RadarToolbar({
    required this.radiusKm,
    required this.onRadiusChanged,
    required this.activeFilterCount,
    required this.onOpenFilters,
    required this.filtersLocked,
    required this.busy,
  });

  final double radiusKm;
  final ValueChanged<double> onRadiusChanged;
  final int activeFilterCount;
  final VoidCallback onOpenFilters;

  /// Draws the padlock instead of the filter count, so a free user knows the
  /// button leads to the paywall before tapping it.
  final bool filtersLocked;
  final bool busy;

  String _radiusLabel(double km, bool isTh) {
    if (km < 1) {
      final metres = (km * 1000).round();
      return isTh ? '$metres ม.' : '$metres m';
    }
    final value = km == km.roundToDouble()
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(1);
    return isTh ? '$value กม.' : '$value km';
  }

  @override
  Widget build(BuildContext context) {
    final isTh = Localizations.localeOf(context).languageCode == 'th';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'radar_radius'),
                  style: const TextStyle(
                    color: Color(0xFF90A4AE),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final km in RadarService.radiusOptionsKm)
                      _RadiusChip(
                        label: _radiusLabel(km, isTh),
                        selected: km == radiusKm,
                        onTap: busy ? null : () => onRadiusChanged(km),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            count: activeFilterCount,
            locked: filtersLocked,
            onTap: busy ? null : onOpenFilters,
          ),
        ],
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _green : const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _green : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF546E7A),
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.count,
    required this.locked,
    required this.onTap,
  });

  final int count;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = !locked && count > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _green.withValues(alpha: 0.1) : const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _green : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              locked ? Icons.lock_rounded : Icons.tune_rounded,
              size: 17,
              color: active ? _green : const Color(0xFF546E7A),
            ),
            const SizedBox(width: 6),
            Text(
              appText(context, 'filter_title'),
              style: TextStyle(
                color: active ? _green : const Color(0xFF546E7A),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: child,
      ),
    );
  }
}

class _RadarDisclaimer extends StatelessWidget {
  const _RadarDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: SafeArea(
        top: false,
        child: Text(
          appText(context, 'radar_disclaimer'),
          style: TextStyle(color: Colors.grey[500], fontSize: 10, height: 1.35),
        ),
      ),
    );
  }
}
