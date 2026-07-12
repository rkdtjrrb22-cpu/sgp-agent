/// S13 — 변사자 초동조치·KCSI 연계 패널 (내근 수사 모드).
library;

import 'package:flutter/material.dart';

import '../../investigation/modules/sgp_forensic_assistant.dart';
import '../sgp_glass_skin.dart';

abstract final class SgpForensicPanelColors {
  static const forensicTeal = Color(0xFF00BCD4);
  static const judicialRed = Color(0xFFD50000);
  static const adminGreen = Color(0xFF00C853);
  static const warningAmber = Color(0xFFFFB300);
}

class SgpForensicPanel extends StatelessWidget {
  const SgpForensicPanel({super.key, required this.result});

  final ForensicAssistantResult result;

  Color get _accent => switch (result.integrityStatus) {
        SceneIntegrityStatus.evidenceTamperingRisk =>
          SgpForensicPanelColors.judicialRed,
        SceneIntegrityStatus.policeLineMissing =>
          SgpForensicPanelColors.warningAmber,
        SceneIntegrityStatus.intact => result.requiresJudicialPath
            ? SgpForensicPanelColors.judicialRed
            : SgpForensicPanelColors.forensicTeal,
      };

  String get _phaseLabel => switch (result.phase) {
        ForensicPhase.sceneControl => '현장 통제',
        ForensicPhase.kcsiNotification => 'KCSI 통보',
        ForensicPhase.examination => '검시·부검',
        ForensicPhase.bodyHandover => '시신 인도',
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
              Icon(Icons.biotech_outlined, color: _accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '변사자 초동조치 · KCSI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              _RouteBadge(route: result.route),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.rationale,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusChip(
                label: _phaseLabel,
                color: _accent,
              ),
              _StatusChip(
                label: result.policeLineInstalled ? '통제선 OK' : '통제선 미설치',
                color: result.policeLineInstalled
                    ? SgpForensicPanelColors.adminGreen
                    : SgpForensicPanelColors.warningAmber,
              ),
              _StatusChip(
                label: result.kcsiLinked ? 'KCSI 연계' : 'KCSI 미통보',
                color: result.kcsiLinked
                    ? SgpForensicPanelColors.adminGreen
                    : SgpForensicPanelColors.warningAmber,
              ),
              _StatusChip(
                label: result.propertyHandlingCompliant
                    ? '소지품 준수'
                    : '소지품 점검',
                color: result.propertyHandlingCompliant
                    ? SgpForensicPanelColors.adminGreen
                    : SgpForensicPanelColors.warningAmber,
              ),
            ],
          ),
          if (result.checklist.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '형소법 제222조 체크리스트',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
            const SizedBox(height: 4),
            for (final item in result.checklist)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_box_outline_blank, size: 14, color: _accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final w in result.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '⚠ $w',
                  style: TextStyle(
                    fontSize: 11,
                    color: _accent.withValues(alpha: 0.95),
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.route});

  final DeathCaseRoute route;

  @override
  Widget build(BuildContext context) {
    final color = route == DeathCaseRoute.judicialAutopsy
        ? SgpForensicPanelColors.judicialRed
        : SgpForensicPanelColors.adminGreen;
    final label =
        route == DeathCaseRoute.judicialAutopsy ? '사법' : '행정';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
