/// S11-UI — 사법 무결성·감찰 경고 패널 (네온 레드 #FF1744).
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../control/sgp_anti_corruption_filter.dart';

abstract final class SgpAntiCorruptionColors {
  static const neonRed = Color(0xFFFF1744);
  static const neonRedGlow = Color(0xFFFF5252);
  static const criticalBg = Color(0xFF2A0A0F);
  static const warningAmber = Color(0xFFFFB300);
  static const realBlack = Color(0xFF000000);
  static const pureWhite = Color(0xFFFFFFFF);
}

/// 감찰 위험 경고 카드.
class SgpAntiCorruptionPanel extends StatelessWidget {
  const SgpAntiCorruptionPanel({super.key, required this.assessment});

  final AntiCorruptionAssessment assessment;

  @override
  Widget build(BuildContext context) {
    if (assessment.isClean) return const SizedBox.shrink();
    final critical = assessment.hasCritical;
    final accent = critical
        ? SgpAntiCorruptionColors.neonRed
        : SgpAntiCorruptionColors.warningAmber;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: SgpAntiCorruptionColors.criticalBg.withValues(alpha: 0.82),
            border: Border.all(color: accent, width: 2),
            boxShadow: critical
                ? [
                    BoxShadow(
                      color: SgpAntiCorruptionColors.neonRed.withValues(alpha: 0.6),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    critical ? Icons.gpp_bad : Icons.warning_amber_rounded,
                    color: accent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      critical ? '🚨 사법 무결성 경고 (감찰 대상)' : '감찰 사전 리스크 주의',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final flag in assessment.flags) _buildFlag(flag),
              if (critical) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SgpAntiCorruptionColors.neonRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    assessment.disciplineWarning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: SgpAntiCorruptionColors.pureWhite,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlag(AntiCorruptionFlag flag) {
    final accent = flag.isCritical
        ? SgpAntiCorruptionColors.neonRedGlow
        : SgpAntiCorruptionColors.warningAmber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  flag.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            flag.message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: SgpAntiCorruptionColors.pureWhite,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final basis in [...flag.legalBasis, ...flag.disciplineBasis])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    basis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
