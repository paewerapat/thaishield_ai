import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_text.dart';
import '../models/travel_alert.dart';
import '../services/travel_alert_service.dart';

class TravelAlertsListScreen extends StatefulWidget {
  const TravelAlertsListScreen({super.key});

  @override
  State<TravelAlertsListScreen> createState() => _TravelAlertsListScreenState();
}

class _TravelAlertsListScreenState extends State<TravelAlertsListScreen> {
  late final Future<List<TravelAlert>> _future = TravelAlertService.instance.fetchAlerts();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D1B2A)),
        title: Text(
          appText(context, 'home_top_news'),
          style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<TravelAlert>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
          }
          if (snapshot.hasError) {
            return Center(child: Text(appText(context, 'travel_alerts_error')));
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return Center(child: Text(appText(context, 'travel_alerts_empty')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _AlertListCard(alert: alerts[i], timeAgo: timeAgoLabel(alerts[i].publishedAt)),
          );
        },
      ),
    );
  }
}

class _AlertListCard extends StatelessWidget {
  const _AlertListCard({required this.alert, required this.timeAgo});
  final TravelAlert alert;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    final color = alertCategoryColor[alert.category]!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: alert.imageUrl != null
                ? Image.network(
                    alert.imageUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(width: 100, height: 100, color: color.withValues(alpha: 0.12)),
                  )
                : Container(width: 100, height: 100, color: color.withValues(alpha: 0.12)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      appText(context, alertCategoryTextKey[alert.category]!),
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${alert.sourceName} · $timeAgo',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(alert.url), mode: LaunchMode.externalApplication),
                        child: Text(
                          appText(context, 'travel_alerts_view_details'),
                          style: const TextStyle(color: Color(0xFF1976D2), fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
