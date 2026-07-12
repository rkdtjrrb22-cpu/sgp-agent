/// S11 — 3대 민생법령 도메인 분석 패널 (내근 수사 모드).
library;

import 'package:flutter/material.dart';

import '../sgp_app_theme.dart';
import '../sgp_statute_domain_engine.dart';

class SgpStatuteDomainPanel extends StatelessWidget {
  const SgpStatuteDomainPanel({
    super.key,
    required this.domain,
    this.traffic,
    this.stalking,
    this.juvenile,
  });

  final StatuteDomain domain;
  final TrafficAccidentResult? traffic;
  final StalkingResult? stalking;
  final JuvenileResult? juvenile;

  @override
  Widget build(BuildContext context) {
    if (domain == StatuteDomain.none) return const SizedBox.shrink();

    final (title, body, color) = switch (domain) {
      StatuteDomain.trafficAccident => (
          '교통사고처리특례법',
          traffic?.rationale ?? '',
          SgpAppTheme.warning,
        ),
      StatuteDomain.stalking => (
          '스토킹처벌법',
          stalking?.rationale ?? '',
          SgpAppTheme.accent,
        ),
      StatuteDomain.juvenile => (
          '소년법',
          juvenile?.rationale ?? '',
          SgpAppTheme.primaryLight,
        ),
      StatuteDomain.none => ('', '', SgpAppTheme.textMuted),
    };

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SgpAppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
