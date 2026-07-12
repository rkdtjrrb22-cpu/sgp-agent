/// S13 — AI 사법 모의 디펜스 패널 (글래스모피즘 + 위험 배지).
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:sgp_agent/features/investigation/modules/sgp_mock_defense_engine.dart';

import '../sgp_glass_skin.dart';

abstract final class SgpMockDefenseColors {
  static const neonOrange = Color(0xFFFF6D00);
  static const crimsonRed = Color(0xFFD50000);
  static const solidGreen = Color(0xFF00C853);
}

class SgpMockDefensePanel extends StatelessWidget {
  const SgpMockDefensePanel({super.key, required this.result});

  final MockDefenseResult result;

  Color get _accent => switch (result.overallRisk) {
        MockDefenseRiskLevel.warning => SgpMockDefenseColors.neonOrange,
        MockDefenseRiskLevel.critical => SgpMockDefenseColors.crimsonRed,
        MockDefenseRiskLevel.clear => SgpMockDefenseColors.solidGreen,
      };

  @override
  Widget build(BuildContext context) {
    return SgpGlassSkinCard(
      accent: _accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.balance_outlined, color: _accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI 사법 모의 디펜스',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              _RiskBadge(level: result.overallRisk),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          if (result.tackles.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final t in result.tackles) _TackleTile(tackle: t),
          ],
        ],
      ),
    );
  }
}

class SgpMockDefenseFab extends StatelessWidget {
  const SgpMockDefenseFab({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.riskLevel,
  });

  final VoidCallback onPressed;
  final bool loading;
  final MockDefenseRiskLevel? riskLevel;

  @override
  Widget build(BuildContext context) {
    final accent = riskLevel == null
        ? SgpGlassSkinColors.neonBlue
        : Color(switch (riskLevel!) {
            MockDefenseRiskLevel.warning => MockDefenseRiskLevelColors.neonOrange,
            MockDefenseRiskLevel.critical => MockDefenseRiskLevelColors.crimsonRed,
            MockDefenseRiskLevel.clear => MockDefenseRiskLevelColors.solidGreen,
          });

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: accent.withValues(alpha: 0.22),
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                    )
                  else
                    Icon(Icons.sports_martial_arts_outlined, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI 사법 모의 디펜스',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  if (riskLevel != null) ...[
                    const SizedBox(width: 6),
                    _RiskBadge(level: riskLevel!, compact: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level, this.compact = false});

  final MockDefenseRiskLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(level.colorHex);
    final label = switch (level) {
      MockDefenseRiskLevel.warning => 'WARN',
      MockDefenseRiskLevel.critical => 'CRIT',
      MockDefenseRiskLevel.clear => 'OK',
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
        boxShadow: level == MockDefenseRiskLevel.critical
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _TackleTile extends StatelessWidget {
  const _TackleTile({required this.tackle});

  final MockDefenseTackle tackle;

  @override
  Widget build(BuildContext context) {
    final color = Color(tackle.riskLevel.colorHex);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tackle.vulnerability.label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text('검사: ${tackle.prosecutorLine}', style: const TextStyle(fontSize: 11)),
            Text('법원: ${tackle.courtLine}', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              '보정: ${tackle.remediation}',
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }
}
