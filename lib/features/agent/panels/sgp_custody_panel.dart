/// S13 — 피의자 유치인 안전 관리 패널 (내근 수사 모드).
library;

import 'package:flutter/material.dart';

import '../../control/sgp_custody_management.dart';
import '../sgp_glass_skin.dart';

abstract final class SgpCustodyPanelColors {
  static const custodyBlue = Color(0xFF2979FF);
  static const warningAmber = Color(0xFFFFB300);
  static const criticalRed = Color(0xFFD50000);
  static const safeGreen = Color(0xFF00C853);
}

class SgpCustodyPanel extends StatelessWidget {
  const SgpCustodyPanel({super.key, required this.result});

  final CustodyManagementResult result;

  Color get _accent => switch (result.riskLevel) {
        CustodyRiskLevel.suicideHighRisk => SgpCustodyPanelColors.criticalRed,
        CustodyRiskLevel.selfHarmRisk => SgpCustodyPanelColors.warningAmber,
        CustodyRiskLevel.standard => result.hasCriticalIssue
            ? SgpCustodyPanelColors.criticalRed
            : SgpCustodyPanelColors.custodyBlue,
      };

  String _fmt48h(Duration? d) {
    if (d == null) return 'T-0 미설정';
    if (d == Duration.zero) return '48h 초과';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m 잔여';
  }

  @override
  Widget build(BuildContext context) {
    return SgpGlassSkinCard(
      accent: _accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: _accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '유치인 안전 관리',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              _RiskBadge(level: result.riskLevel),
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
                label: result.bodySearchLevel.label,
                color: result.bodySearchLevel == BodySearchLevel.none
                    ? SgpCustodyPanelColors.warningAmber
                    : SgpCustodyPanelColors.safeGreen,
              ),
              _StatusChip(
                label: result.guardInterval.label,
                color: _accent,
              ),
              _StatusChip(
                label: _fmt48h(result.hoursRemaining48h),
                color: result.custody48hCompliant
                    ? SgpCustodyPanelColors.safeGreen
                    : SgpCustodyPanelColors.criticalRed,
              ),
            ],
          ),
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '무결성 결함',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
            const SizedBox(height: 4),
            for (final issue in result.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ${_issueLabel(issue)}',
                  style: const TextStyle(fontSize: 11),
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

  static String _issueLabel(CustodyIntegrityIssue issue) => switch (issue) {
        CustodyIntegrityIssue.missingRightsNotice => '권리 고지 미이행',
        CustodyIntegrityIssue.incompleteBodySearch => '신체검사 미실시',
        CustodyIntegrityIssue.incompleteSeizureList => '압수 목록 미작성',
        CustodyIntegrityIssue.specialGuardNotAssigned => '특별계호 미지정',
        CustodyIntegrityIssue.custody48hBreach => '48h 구속 시한 초과',
      };
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level});

  final CustodyRiskLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      CustodyRiskLevel.suicideHighRisk => SgpCustodyPanelColors.criticalRed,
      CustodyRiskLevel.selfHarmRisk => SgpCustodyPanelColors.warningAmber,
      CustodyRiskLevel.standard => SgpCustodyPanelColors.custodyBlue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        level.label,
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
