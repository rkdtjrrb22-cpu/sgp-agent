/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Electronic Information Seizure Result Report
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// [전자정보 압수·수색 결과보고서] 마크다운 자동 조립 (온디바이스).
library;

import 'sgp_evidence_coc_engine.dart';
import 'sgp_evidence_scenario_pipeline.dart';

abstract final class SgpElectronicSeizureReport {
  static String buildMarkdown({
    required EvidenceCoCSession chainOfCustody,
    required String rawText,
    EvidenceScenarioPipelineResult? pipeline,
    DateTime? generatedAt,
    List<String> supervisorFeedbackLog = const [],
  }) {
    final at = generatedAt ?? DateTime.now();
    final stamp =
        '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('**문서 분류**  보안 · 수사 내부용');
    buf.writeln('**문서 성격**  전자정보 압수·수색 결과보고서 초안');
    buf.writeln('**생성 시각**  $stamp');
    buf.writeln('**시그니처**  INSP_KANG_SG_4066');
    buf.writeln('---');
    buf.writeln();
    buf.writeln('# 전자정보 압수·수색 결과보고서');
    buf.writeln();
    buf.writeln('## 1. 사건·매체 개요');
    buf.writeln();
    buf.writeln('- **매체**: ${chainOfCustody.deviceType ?? "미상"}');
    buf.writeln('- **evidenceCoC 신호등**: ${chainOfCustody.trafficLabel}');
    buf.writeln('- **준거**: 형사소송법 제106조·제219조, 대법원 디지털 증거 압수 법리');
    buf.writeln('- **진행**: ${chainOfCustody.completedCount}/4 단계');
    buf.writeln();
    buf.writeln('## 2. 현장 요지');
    buf.writeln();
    buf.writeln(rawText.trim().isEmpty ? '(입력 없음)' : rawText.trim());
    buf.writeln();
    buf.writeln('## 3. Chain of Custody (evidenceCoC) 4단계');
    buf.writeln();
    for (final step in EvidenceCoCStep.values) {
      final rec = chainOfCustody.steps[step];
      final mark = rec?.completed == true ? '✓' : '☐';
      buf.writeln('- **$mark ${step.label}**');
      if (rec?.completedAt != null) {
        buf.writeln('  - 완료시각: ${rec!.completedAt!.toIso8601String()}');
      }
      if (rec?.hashValue != null) {
        buf.writeln('  - SHA-256: `${rec!.hashValue}`');
      }
      if (rec?.note != null && rec!.note!.trim().isNotEmpty) {
        buf.writeln('  - 비고: ${rec.note}');
      }
    }
    buf.writeln();
    buf.writeln('## 4. 디지털 맹점·보완수사 예방');
    buf.writeln();
    buf.writeln(
      SgpEvidenceCoCEngine.supplementaryInvestigationWarning(chainOfCustody),
    );
    if (chainOfCustody.blindSpots.isNotEmpty) {
      buf.writeln();
      for (final b in chainOfCustody.blindSpots) {
        buf.writeln('### ${b.label}');
        buf.writeln();
        buf.writeln(b.actionGuide);
        buf.writeln();
      }
    }
    if (pipeline != null && pipeline.crimeFacts.isNotEmpty) {
      buf.writeln('## 5. 범죄사실·구성요건 초안');
      buf.writeln();
      for (var i = 0; i < pipeline.crimeFacts.length; i++) {
        final fact = pipeline.crimeFacts[i];
        buf.writeln('### ${i + 1}. ${fact.title}');
        buf.writeln();
        buf.writeln('- **근거**: ${fact.statutoryBasis}');
        buf.writeln();
        buf.writeln(fact.narrative);
        buf.writeln();
      }
    }
    buf.writeln('## 6. 내부 심사(팀장/과장) 보정 로그');
    buf.writeln();
    if (supervisorFeedbackLog.isEmpty) {
      buf.writeln('- (없음 — 로컬 암호화 환류 대기)');
    } else {
      for (final line in supervisorFeedbackLog) {
        buf.writeln('- $line');
      }
    }
    buf.writeln();
    buf.writeln('## 7. 확인·서명');
    buf.writeln();
    buf.writeln('| 구분 | 기재 |');
    buf.writeln('| --- | --- |');
    buf.writeln('| 작성 수사관 | ____________________ |');
    buf.writeln('| 참여권 고지 확인 | ____________________ |');
    buf.writeln('| 해시 대조 | ____________________ |');
    buf.writeln('| 결재 | ____________________ |');
    buf.writeln();
    buf.writeln('---');
    buf.writeln('*온디바이스·폐쇄망 전제. 유치인 custody와 evidenceCoC를 혼동하지 말 것. 외부 유출 금지.*');
    return buf.toString();
  }
}
