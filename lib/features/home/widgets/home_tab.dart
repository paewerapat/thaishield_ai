import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_text.dart';
import '../../../core/providers/locale_provider.dart';
import '../models/travel_alert.dart';
import '../screens/safety_tips_screen.dart';
import '../screens/travel_alerts_list_screen.dart';
import '../services/travel_alert_service.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, locale.languageCode.toUpperCase()),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ActiveAlertsAndNews(onNavigateToTab: onNavigateToTab),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildUsefulTools(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1810),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/images/logo.jpg', width: 44, height: 44, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ThaiShield',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                appText(context, 'home_tagline'),
                style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              lang,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsefulTools(BuildContext context) {
    final tools = [
      _Tool(
        icon: Icons.document_scanner_outlined,
        label: 'AI Price Scanner',
        color: const Color(0xFF4FC3F7),
        onTap: () => onNavigateToTab(1),
      ),
      _Tool(
        icon: Icons.map_outlined,
        label: 'Smart Map',
        color: const Color(0xFF2E7D32),
        onTap: () => onNavigateToTab(2),
      ),
      _Tool(
        icon: Icons.record_voice_over_outlined,
        label: 'AI Voice SOS',
        color: const Color(0xFFEF5350),
        onTap: () => onNavigateToTab(3),
      ),
      _Tool(
        icon: Icons.shield_outlined,
        label: appText(context, 'tool_safety_tips'),
        color: const Color(0xFFFFB300),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SafetyTipsScreen())),
      ),
    ];

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
          Text(
            appText(context, 'home_useful_tools'),
            style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: tools.map((t) => Expanded(child: _ToolItem(tool: t))).toList(),
          ),
        ],
      ),
    );
  }
}

class _Tool {
  const _Tool({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ToolItem extends StatelessWidget {
  const _ToolItem({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tool.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tool.icon, color: tool.color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              tool.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAlertsAndNews extends StatefulWidget {
  const _ActiveAlertsAndNews({required this.onNavigateToTab});
  final ValueChanged<int> onNavigateToTab;

  @override
  State<_ActiveAlertsAndNews> createState() => _ActiveAlertsAndNewsState();
}

class _ActiveAlertsAndNewsState extends State<_ActiveAlertsAndNews> {
  late final Future<List<TravelAlert>> _future = TravelAlertService.instance.fetchAlerts();

  String _alertsSummary(BuildContext context, List<TravelAlert> alerts) {
    final counts = <AlertCategory, int>{};
    for (final a in alerts) {
      if (a.category == AlertCategory.other) continue;
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) {
      return appText(context, 'home_alerts_summary_generic').replaceFirst('{count}', '${alerts.length}');
    }
    final unit = appText(context, 'home_alerts_unit');
    return sorted
        .take(2)
        .map((e) => '${appText(context, alertCategoryTextKey[e.key]!)}: ${e.value} $unit')
        .join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TravelAlert>>(
      future: _future,
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        final loaded = snapshot.connectionState == ConnectionState.done && !snapshot.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loaded && alerts.isNotEmpty) _AlertsBanner(summary: _alertsSummary(context, alerts), onViewMap: () => widget.onNavigateToTab(2)),
            if (loaded && alerts.isNotEmpty) const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appText(context, 'home_top_news'),
                  style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (loaded && alerts.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TravelAlertsListScreen())),
                    child: Text(
                      appText(context, 'home_see_all'),
                      style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!loaded)
              const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))))
            else if (snapshot.hasError)
              _MessageBox(text: appText(context, 'travel_alerts_error'))
            else if (alerts.isEmpty)
              _MessageBox(text: appText(context, 'travel_alerts_empty'))
            else
              _TopNewsGrid(alerts: alerts),
            const SizedBox(height: 10),
            Text(
              appText(context, 'travel_alerts_disclaimer'),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.summary, required this.onViewMap});
  final String summary;
  final VoidCallback onViewMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(context, 'home_active_alerts_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: onViewMap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(appText(context, 'home_active_alerts_view_map'), style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                const Icon(Icons.chevron_right, color: Colors.white, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
    );
  }
}

class _TopNewsGrid extends StatelessWidget {
  const _TopNewsGrid({required this.alerts});
  final List<TravelAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopNewsCard(alert: alerts[0], height: 200),
        if (alerts.length > 1) const SizedBox(height: 12),
        if (alerts.length > 1)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TopNewsCard(alert: alerts[1], height: 170)),
              if (alerts.length > 2) const SizedBox(width: 12),
              if (alerts.length > 2) Expanded(child: _TopNewsCard(alert: alerts[2], height: 170)),
            ],
          ),
      ],
    );
  }
}

class _TopNewsCard extends StatelessWidget {
  const _TopNewsCard({required this.alert, required this.height});
  final TravelAlert alert;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = alertCategoryColor[alert.category]!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            alert.imageUrl != null
                ? Image.network(
                    alert.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: color.withValues(alpha: 0.3)),
                  )
                : Container(color: color.withValues(alpha: 0.3)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                  stops: const [0.4, 1],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  appText(context, alertCategoryTextKey[alert.category]!),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          timeAgoLabel(alert.publishedAt),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(alert.url), mode: LaunchMode.externalApplication),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            appText(context, 'travel_alerts_view_details'),
                            style: const TextStyle(color: Colors.white, fontSize: 10.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
