import 'package:flutter/material.dart';

import '../../../core/localization/app_text.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  static const _tipKeys = [
    'safety_tip_1', 'safety_tip_2', 'safety_tip_3', 'safety_tip_4',
    'safety_tip_5', 'safety_tip_6', 'safety_tip_7', 'safety_tip_8',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0D1B2A)),
        title: Text(
          appText(context, 'tool_safety_tips'),
          style: const TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _tipKeys.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _TipCard(index: i + 1, text: appText(context, _tipKeys[i])),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.index, required this.text});
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF0D1B2A), fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
