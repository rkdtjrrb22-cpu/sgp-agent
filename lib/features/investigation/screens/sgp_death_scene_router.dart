/// S14 — 변사 처리 외근·내근 하이브리드 화면 라우터.
library;

import 'package:flutter/material.dart';

import '../../agent/sgp_glass_skin.dart';
import '../../agent/sgp_operational_mode.dart';
import '../modules/sgp_death_logic_hub.dart';

class SgpDeathSceneRouter extends StatelessWidget {
  const SgpDeathSceneRouter({
    super.key,
    required this.currentMode,
    required this.caseId,
    required this.decision,
    this.onReportToInvestigation,
  });

  final SgpOperationalMode currentMode;
  final String caseId;
  final SgpDeathCaseDecision decision;
  final VoidCallback? onReportToInvestigation;

  @override
  Widget build(BuildContext context) {
    if (currentMode == SgpOperationalMode.field) {
      return SgpFieldDeathPanel(
        caseId: caseId,
        checklist: decision.fieldChecklist,
        offlineHandoffReady: decision.offlineHandoffReady,
        onReportToInvestigation: onReportToInvestigation,
      );
    }

    return SgpInvestigationDeathPanel(
      caseId: caseId,
      legalGuides: decision.investigationGuides,
      routeLabel: decision.route.code,
      actionRequired: decision.actionRequired,
      applicableLaw: decision.applicableLaw,
      documentTemplate: decision.documentTemplate,
      precedentMatches: decision.precedentMatches,
      actionButtonLabel: decision.requiresAutopsyWarrant
          ? '부검 지휘 신청 및 사체인도서 서류 빌드'
          : '사체 인도서 및 검시 보고서 빌드',
    );
  }
}

class SgpFieldDeathPanel extends StatelessWidget {
  const SgpFieldDeathPanel({
    super.key,
    required this.caseId,
    required this.checklist,
    required this.offlineHandoffReady,
    this.onReportToInvestigation,
  });

  final String caseId;
  final List<String> checklist;
  final bool offlineHandoffReady;
  final VoidCallback? onReportToInvestigation;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00B0FF);
    return SgpGlassSkinCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DeathPanelHeader(
            icon: Icons.local_police_outlined,
            title: '외근 모드 · 변사 현장 대응',
            accent: accent,
            badge: 'FIELD',
          ),
          const SizedBox(height: 8),
          Text(
            '사건번호 $caseId · 112 변사 신고 초동 데이터',
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < checklist.length; i++)
            _NumberedLine(number: i + 1, text: checklist[i], accent: accent),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onReportToInvestigation,
            icon: Icon(
              offlineHandoffReady
                  ? Icons.sync_alt_outlined
                  : Icons.offline_bolt_outlined,
              size: 18,
            ),
            label: Text(
              offlineHandoffReady
                  ? '내근 형사과 대시보드로 오프라인 인계'
                  : '초동 체크 후 오프라인 인계 대기',
            ),
          ),
        ],
      ),
    );
  }
}

class SgpInvestigationDeathPanel extends StatelessWidget {
  const SgpInvestigationDeathPanel({
    super.key,
    required this.caseId,
    required this.legalGuides,
    required this.routeLabel,
    required this.actionRequired,
    required this.applicableLaw,
    required this.documentTemplate,
    required this.precedentMatches,
    required this.actionButtonLabel,
  });

  final String caseId;
  final List<String> legalGuides;
  final String routeLabel;
  final String actionRequired;
  final String applicableLaw;
  final String documentTemplate;
  final List<String> precedentMatches;
  final String actionButtonLabel;

  @override
  Widget build(BuildContext context) {
    final criminal = routeLabel == SgpDeathCaseRoute.investigationCriminal.code;
    final accent = criminal ? const Color(0xFFD50000) : const Color(0xFF00C853);
    return SgpGlassSkinCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeathPanelHeader(
            icon: Icons.gavel_outlined,
            title: '내근 모드 · 변사 수사/과수',
            accent: accent,
            badge: criminal ? '사법 변사' : '행정 변사',
          ),
          const SizedBox(height: 8),
          Text(
            '사건번호 $caseId · $actionRequired',
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 8),
          _GuideChip(label: applicableLaw, color: accent),
          const SizedBox(height: 10),
          for (var i = 0; i < legalGuides.length; i++)
            _NumberedLine(number: i + 1, text: legalGuides[i], accent: accent),
          const SizedBox(height: 8),
          Text(
            '서식: $documentTemplate',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          if (precedentMatches.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in precedentMatches.take(3))
                  _GuideChip(label: id, color: accent),
              ],
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(actionButtonLabel),
          ),
        ],
      ),
    );
  }
}

class _DeathPanelHeader extends StatelessWidget {
  const _DeathPanelHeader({
    required this.icon,
    required this.title,
    required this.accent,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: accent),
          ),
        ),
        _GuideChip(label: badge, color: accent),
      ],
    );
  }
}

class _NumberedLine extends StatelessWidget {
  const _NumberedLine({
    required this.number,
    required this.text,
    required this.accent,
  });

  final int number;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.75)),
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
