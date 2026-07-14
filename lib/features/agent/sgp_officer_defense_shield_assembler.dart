/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Officer Dokjik (Abuse-of-Authority Assault) Defense Shield
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 독직폭행 피소 대비 — 맞대응 법리 · 디지털 공무집행 무결성(CoC) · 법률비용보험 원클릭 조립.
library;

import 'sgp_constitutional_force_engine.dart';
import 'sgp_physical_force_matrix.dart';
import 'sgp_physical_threat_level.dart';

/// 타임라인 저항 단계 로그 한 줄.
class ResistanceTimelineEntry {
  const ResistanceTimelineEntry({
    required this.timeLabel,
    required this.stageLabel,
    required this.stageNumber,
  });

  final String timeLabel;
  final String stageLabel;
  final int stageNumber;

  String get arrowLine => '$timeLabel $stageLabel';
}

/// 엔진·UI 공유 — 외근에서 누적한 물리력 보호막 원천 데이터.
class ForceDefensePackageSnapshot {
  const ForceDefensePackageSnapshot({
    required this.rawText,
    required this.threatLevel,
    required this.forceTier,
    required this.forceExecutionLogged,
    required this.isExcessive,
    required this.capturedAt,
    this.forceExecutionNote,
  });

  final String rawText;
  final PhysicalThreatLevel threatLevel;
  final PoliceForceTier forceTier;
  final bool forceExecutionLogged;
  final String? forceExecutionNote;
  final bool isExcessive;
  final DateTime capturedAt;

  /// 무전·타임라인·집행 기록으로부터 스냅샷 구성 (SgpAgentEngine 백엔드 진입점).
  factory ForceDefensePackageSnapshot.capture({
    required String rawText,
    PhysicalThreatLevel? threatLevel,
    PoliceForceTier? forceTier,
    bool forceExecutionLogged = false,
    String? forceExecutionNote,
    bool isExcessive = false,
    DateTime? capturedAt,
  }) {
    final resolvedThreat = threatLevel ??
        PhysicalThreatLevelBridge.fromResistanceStage(
          SgpConstitutionalForceEngine.detectResistanceFromText(rawText) ??
              ResistanceStage.compliance,
        ) ??
        PhysicalThreatLevel.compliance;
    final resolvedForce = forceTier ??
        SgpConstitutionalForceEngine.detectForceTierFromText(rawText) ??
        resolvedThreat.resistanceStage.defaultForceTier;

    return ForceDefensePackageSnapshot(
      rawText: rawText,
      threatLevel: resolvedThreat,
      forceTier: resolvedForce,
      forceExecutionLogged: forceExecutionLogged,
      forceExecutionNote: forceExecutionNote,
      isExcessive: isExcessive,
      capturedAt: capturedAt ?? DateTime.now(),
    );
  }

  bool get hasUsableDefenseData =>
      threatLevel.stageNumber >= 2 ||
      forceExecutionLogged ||
      forceTier.stageNumber >= 2 ||
      SgpOfficerDefenseShieldAssembler.parseResistanceTimeline(rawText)
          .isNotEmpty;

  OfficerDefenseShieldPack toPack({
    String officerIdHint = '현장 수사관',
    DateTime? generatedAt,
  }) {
    return SgpOfficerDefenseShieldAssembler.assemble(
      threatLevel: threatLevel,
      forceTier: forceTier,
      rawText: rawText,
      isExcessive: isExcessive,
      officerIdHint: officerIdHint,
      generatedAt: generatedAt ?? capturedAt,
    );
  }
}

/// 조립된 방어 문서 묶음.
class OfficerDefenseShieldPack {
  const OfficerDefenseShieldPack({
    required this.legalDefenseMarkdown,
    required this.integrityReportMarkdown,
    required this.insuranceApplicationMarkdown,
    required this.dutyLiabilityInsuranceMarkdown,
    required this.activeAdminExemptionMarkdown,
    required this.timelineTableMarkdown,
    required this.timelineEntries,
    required this.combinedMarkdown,
  });

  /// 경직법 제11조의5 · 형법 제20조 · 판례 매핑 (맞대응 변론서).
  final String legalDefenseMarkdown;

  /// 디지털 공무집행 무결성 보고서(CoC).
  final String integrityReportMarkdown;

  /// 경찰관 법률비용보험 지원 신청서 (레거시 호환).
  final String insuranceApplicationMarkdown;

  /// 공무 수행 책임보험 · 지방청 청문감사과 연계 가이드.
  final String dutyLiabilityInsuranceMarkdown;

  /// 적극행정 면책신청서.
  final String activeAdminExemptionMarkdown;

  /// 사법기관 증빙용 타임라인 표(마크다운).
  final String timelineTableMarkdown;

  final List<ResistanceTimelineEntry> timelineEntries;

  /// 복사·공유용 통합 본문.
  final String combinedMarkdown;

  String get plainCombined => stripMarkdown(combinedMarkdown);

  static String stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'^- ', multiLine: true), '• ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

abstract final class SgpOfficerDefenseShieldAssembler {
  /// 적극적 저항(3단계) 이상이면 법률 조력 보호막(Blue) 활성.
  static bool isLegalAidShieldActive(ResistanceStage stage) =>
      stage.stageNumber >= 3;

  static bool isLegalAidShieldActiveFromThreat(PhysicalThreatLevel? level) =>
      level != null && level.stageNumber >= 3;

  /// 물리력 집행 기록이 있다고 볼 수 있는지 (방어막 탭 노출 조건).
  static bool shouldExposeDefenseTab({
    PhysicalThreatLevel? threatLevel,
    PoliceForceTier? forceTier,
    bool forceExecutionLogged = false,
  }) {
    if (forceExecutionLogged) return true;
    if (forceTier != null && forceTier.stageNumber >= 2) return true;
    if (threatLevel != null && threatLevel.stageNumber >= 2) return true;
    return false;
  }

  /// 무전·현장 텍스트에서 `HH:MM + 저항단계` 패턴 추출.
  static List<ResistanceTimelineEntry> parseResistanceTimeline(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return const [];

    final re = RegExp(
      r'(\d{1,2}:\d{2})\s*[^\n]{0,40}?'
      r'(치명적\s*저항|폭력적\s*저항|적극적\s*저항|소극적\s*저항|순응|협조)',
      caseSensitive: false,
    );
    final out = <ResistanceTimelineEntry>[];
    for (final m in re.allMatches(text)) {
      final time = m.group(1)!;
      final labelRaw = m.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      final stage = _labelToStage(labelRaw);
      out.add(
        ResistanceTimelineEntry(
          timeLabel: time,
          stageLabel: stage.label,
          stageNumber: stage.stageNumber,
        ),
      );
    }
    return out;
  }

  static ResistanceStage _labelToStage(String label) {
    if (label.contains('치명')) return ResistanceStage.lethalResistance;
    if (label.contains('폭력')) return ResistanceStage.violentResistance;
    if (label.contains('적극')) return ResistanceStage.activeResistance;
    if (label.contains('소극')) return ResistanceStage.passiveResistance;
    return ResistanceStage.compliance;
  }

  static OfficerDefenseShieldPack assemble({
    required PhysicalThreatLevel threatLevel,
    required PoliceForceTier forceTier,
    String rawText = '',
    bool isExcessive = false,
    String officerIdHint = '현장 수사관',
    DateTime? generatedAt,
  }) {
    final at = generatedAt ?? DateTime.now();
    final stamp =
        '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    var timeline = parseResistanceTimeline(rawText);
    if (timeline.isEmpty) {
      timeline = [
        ResistanceTimelineEntry(
          timeLabel: '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')}',
          stageLabel: threatLevel.resistanceStage.label,
          stageNumber: threatLevel.stageNumber,
        ),
      ];
    }

    final response = SgpPhysicalForceMatrix.responseFor(threatLevel);
    final legal = _buildLegalDefense(
      threatLevel: threatLevel,
      forceTier: forceTier,
      response: response,
      isExcessive: isExcessive,
    );
    final table = _buildTimelineTable(timeline);
    final coc = _buildIntegrityReport(
      stamp: stamp,
      threatLevel: threatLevel,
      forceTier: forceTier,
      response: response,
      timeline: timeline,
      timelineTable: table,
      rawText: rawText,
      isExcessive: isExcessive,
    );
    final insurance = _buildInsuranceApplication(
      stamp: stamp,
      threatLevel: threatLevel,
      forceTier: forceTier,
      officerIdHint: officerIdHint,
      timeline: timeline,
    );
    final dutyLiability = _buildDutyLiabilityInsurance(
      stamp: stamp,
      threatLevel: threatLevel,
      forceTier: forceTier,
      officerIdHint: officerIdHint,
      timeline: timeline,
    );
    final activeAdmin = _buildActiveAdminExemption(
      stamp: stamp,
      threatLevel: threatLevel,
      forceTier: forceTier,
      officerIdHint: officerIdHint,
      timeline: timeline,
      isExcessive: isExcessive,
    );

    final combined = StringBuffer()
      ..writeln(legal)
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln(coc)
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln(dutyLiability)
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln(activeAdmin);

    return OfficerDefenseShieldPack(
      legalDefenseMarkdown: legal.trim(),
      integrityReportMarkdown: coc.trim(),
      insuranceApplicationMarkdown: insurance.trim(),
      dutyLiabilityInsuranceMarkdown: dutyLiability.trim(),
      activeAdminExemptionMarkdown: activeAdmin.trim(),
      timelineTableMarkdown: table.trim(),
      timelineEntries: timeline,
      combinedMarkdown: combined.toString().trim(),
    );
  }

  static String _buildTimelineTable(List<ResistanceTimelineEntry> timeline) {
    final buf = StringBuffer()
      ..writeln('| 시각 | 단계 | 저항 수준 |')
      ..writeln('|------|------|-----------|');
    for (final e in timeline) {
      buf.writeln('| ${e.timeLabel} | ${e.stageNumber}단계 | ${e.stageLabel} |');
    }
    if (timeline.length >= 2) {
      buf
        ..writeln()
        ..writeln(
          '연속성: `${timeline.map((e) => e.stageLabel).join(' ➔ ')}`',
        );
    }
    return buf.toString().trim();
  }

  static String _buildLegalDefense({
    required PhysicalThreatLevel threatLevel,
    required PoliceForceTier forceTier,
    required PhysicalForceResponse response,
    required bool isExcessive,
  }) {
    final buf = StringBuffer()
      ..writeln('# 맞대응 변론서 초안 — 독직폭행 피소 대비')
      ..writeln()
      ..writeln(
        '> 피의자가 독직폭행(형법 제125조)으로 고소·협박하는 경우, '
        '**정당한 직무집행** 프레임으로 즉시 맞대응하기 위한 온디바이스 초안입니다.',
      )
      ..writeln()
      ..writeln('## 1. 경찰관직무집행법 제11조의5 (형사책임 감면)')
      ..writeln()
      ..writeln(
        '정당한 직무 집행 과정에서 **고의 또는 중대한 과실이 없는 경우** '
        '형의 감경 또는 면제 요건을 검토한다.',
      )
      ..writeln()
      ..writeln('### 자동 서식(현장 체크)')
      ..writeln()
      ..writeln('- [ ] 직무 목적: 체포·현행범·위험 방지 등 **법령상 권한 범위** 내')
      ..writeln(
        '- [ ] 저항 단계: **${threatLevel.displayName}** '
        '(${threatLevel.resistanceStage.label})',
      )
      ..writeln(
        '- [ ] 대응 물리력: **${forceTier.label}** (${forceTier.summary})',
      )
      ..writeln('- [ ] 법적 근거(매트릭스): ${response.legalBasis}')
      ..writeln(
        '- [ ] 고의·중과실 부인: 저항 단계에 비례한 최소·상당 물리력, '
        '${isExcessive ? "**⚠ IsExcessive=true — 과잉 소명 필요**" : "비례성 충족(초기 평가)"}',
      )
      ..writeln(
        '- [ ] 중단 원칙: 저항 중단·제압 완료 시 물리력 **즉시 중단** 기록 확보',
      )
      ..writeln()
      ..writeln('## 2. 형법 제20조 (정당행위)')
      ..writeln()
      ..writeln(
        '법령에 의한 행위 또는 업무로 인한 정당행위로서, '
        '**비례성의 원칙**(적합성·필요성·상당성)에 따른 물리력 집행은 위법성이 조각된다.',
      )
      ..writeln()
      ..writeln('### 정당성 변론 요약')
      ..writeln()
      ..writeln('- 목적: ${response.summary}')
      ..writeln('- 수단: ${response.allowedEquipment.isEmpty ? "언어·유도 중심" : response.allowedEquipment.join(" · ")}')
      ..writeln(
        '- 상당성: 피의자 저항 ${threatLevel.stageNumber}단계 대비 '
        '경찰 대응 ${forceTier.stageNumber}단계'
        '${forceTier.stageNumber <= threatLevel.stageNumber ? " (단계 이내)" : " (상회 — 소명·기록 보강)"}',
      )
      ..writeln('- 헌법 연계: 헌법 제37조 제2항 과잉금지 · 최소침해')
      ..writeln()
      ..writeln('## 3. 대법원 판례 매핑 · 역고소(공무집행방해)')
      ..writeln()
      ..writeln(
        '경찰관의 **정당한 물리력 집행**에 대하여 폭행·협박·유형력으로 저항하는 행위는 '
        '**공무집행방해죄(형법 제136조)**에 해당할 수 있으며, '
        '독직폭행 고소에 대한 **역고소·병행 입건**이 가능하다.',
      )
      ..writeln()
      ..writeln('- 요지: 정당한 직무집행 방해 ≠ 독직폭행 성립 사유')
      ..writeln('- 현장 조치: 저항·폭행 시각·부위·영상·목격자·의무기록 보전')
      ..writeln('- 대응 문구(예시): 「정당한 체포·제압에 대한 저항은 공무집행방해로 수사할 수 있습니다.」')
      ..writeln()
      ..writeln('---')
      ..writeln('*SGP-Agent · INSP_KANG_SG_4066 · 온디바이스 · 수사관 최종 판단*');
    return buf.toString().trim();
  }

  static String _buildIntegrityReport({
    required String stamp,
    required PhysicalThreatLevel threatLevel,
    required PoliceForceTier forceTier,
    required PhysicalForceResponse response,
    required List<ResistanceTimelineEntry> timeline,
    required String timelineTable,
    required String rawText,
    required bool isExcessive,
  }) {
    final arrow = timeline.map((e) => e.arrowLine).join(' ➔ ');
    final buf = StringBuffer()
      ..writeln('# 디지털 공무집행 무결성 보고서 (CoC)')
      ..writeln()
      ..writeln('- 생성 시각: $stamp')
      ..writeln('- 문서 유형: Chain-of-Custody / Duty Integrity Pack')
      ..writeln('- 물리력 평가: ${threatLevel.displayName}')
      ..writeln('- 집행 단계: ${forceTier.label} (${forceTier.summary})')
      ..writeln('- 매트릭스 근거: ${response.legalBasis}')
      ..writeln(
        '- 비례성 플래그: ${isExcessive ? "IsExcessive=true" : "IsExcessive=false"}',
      )
      ..writeln()
      ..writeln('## 타임라인 연속성 입증 (사법기관 증빙용)')
      ..writeln()
      ..writeln('`$arrow`')
      ..writeln()
      ..writeln(timelineTable)
      ..writeln()
      ..writeln('## 공무집행 무결성 체크리스트')
      ..writeln()
      ..writeln('- [ ] 저항 단계 평가 시각·수사관 ID 기록')
      ..writeln('- [ ] 사용 장구·기술·사유기재 (테이저 등 별도 시각)')
      ..writeln('- [ ] 바디캠·CCTV·무전 로그 해시·보존')
      ..writeln('- [ ] 부상 유무·응급조치·인계 시각')
      ..writeln('- [ ] 미란다·채증 고지 여부')
      ..writeln();
    if (rawText.trim().isNotEmpty) {
      buf
        ..writeln('## 현장·무전 원문(발췌)')
        ..writeln()
        ..writeln('```')
        ..writeln(rawText.trim())
        ..writeln('```')
        ..writeln();
    }
    buf
      ..writeln('## 해시·보관 (현장 수기)')
      ..writeln()
      ..writeln('- 보고서 출력/복사 시각: $stamp')
      ..writeln('- 보관 매체: (□ 관서 NAS □ 수사용 PC □ 출력 편철)')
      ..writeln('- 인수자/인계자: ________ / ________')
      ..writeln()
      ..writeln('---')
      ..writeln('*SGP-Agent Digital Duty CoC · 외부 유출 주의*');
    return buf.toString().trim();
  }

  static String _buildDutyLiabilityInsurance({
    required String stamp,
    required PhysicalThreatLevel threatLevel,
    required PoliceForceTier forceTier,
    required String officerIdHint,
    required List<ResistanceTimelineEntry> timeline,
  }) {
    final buf = StringBuffer()
      ..writeln('# 공무 수행 책임보험 신청 가이드 (지방청 청문감사과 연계)')
      ..writeln()
      ..writeln('- 작성 일시: $stamp')
      ..writeln('- 신청인: $officerIdHint')
      ..writeln('- 연계 부서: **지방청 청문감사과** (관서 경무·감사 협조)')
      ..writeln('- 사안: 독직폭행 고소·인권위 진정 등 사후 법적 분쟁')
      ..writeln('- 관련 저항: ${threatLevel.displayName} / 대응 ${forceTier.label}')
      ..writeln()
      ..writeln('## 제출 전 체크')
      ..writeln()
      ..writeln('- [ ] 디지털 공무집행 무결성 보고서(CoC) 첨부')
      ..writeln('- [ ] 저항 단계 타임라인 표 첨부')
      ..writeln('- [ ] 바디캠·무전·의료기록 목록')
      ..writeln('- [ ] 관서장·팀장 경유 확인')
      ..writeln()
      ..writeln('## 신청 요지(자동 완성)')
      ..writeln()
      ..writeln(
        '본인은 법령에 따른 정당한 직무 집행 과정에서 물리력을 행사하였으며, '
        '이후 상대방의 독직폭행 고소·진정 등에 대비하여 '
        '**공무 수행 책임보험** 지원을 요청합니다. '
        '저항 경과: ${timeline.map((e) => e.arrowLine).join(" ➔ ")}.',
      )
      ..writeln()
      ..writeln('제출처: 지방청 청문감사과 / 관서 보험 담당')
      ..writeln()
      ..writeln('---')
      ..writeln('*온디바이스 초안 — 청문감사과 양식에 맞춰 편집 후 제출*');
    return buf.toString().trim();
  }

  static String _buildActiveAdminExemption({
    required String stamp,
    required PhysicalThreatLevel threatLevel,
    required PoliceForceTier forceTier,
    required String officerIdHint,
    required List<ResistanceTimelineEntry> timeline,
    required bool isExcessive,
  }) {
    final buf = StringBuffer()
      ..writeln('# 적극행정 면책신청서 (초안)')
      ..writeln()
      ..writeln('- 신청 일시: $stamp')
      ..writeln('- 신청인: $officerIdHint')
      ..writeln('- 직무: 현행범·체포·위험방지 등 현장 공권력 집행')
      ..writeln('- 저항 평가: ${threatLevel.displayName}')
      ..writeln('- 물리력: ${forceTier.label} (${forceTier.summary})')
      ..writeln(
        '- 비례성 자기점검: ${isExcessive ? "IsExcessive 플래그 존재 — 소명 보강" : "초기 평가상 단계 이내"}',
      )
      ..writeln()
      ..writeln('## 신청 취지')
      ..writeln()
      ..writeln(
        '공공의 안전과 법질서 유지를 위한 **적극행정**으로서 '
        '비례·필요성의 범위 내에서 물리력을 집행하였음을 소명하며, '
        '고의·중과실 없는 정당한 직무에 대한 **면책**을 신청합니다. '
        '(관련: 경찰관직무집행법 제11조의5, 형법 제20조)',
      )
      ..writeln()
      ..writeln('## 사실관계 요약')
      ..writeln();
    for (final e in timeline) {
      buf.writeln('- ${e.timeLabel}: ${e.stageNumber}단계 ${e.stageLabel}');
    }
    buf
      ..writeln()
      ..writeln('## 첨부')
      ..writeln()
      ..writeln('- [ ] CoC 무결성 보고서')
      ..writeln('- [ ] 타임라인 표')
      ..writeln('- [ ] 맞대응 변론서 요지')
      ..writeln()
      ..writeln('신청인: ____________    확인 간부: ____________')
      ..writeln()
      ..writeln('---')
      ..writeln('*적극행정 면책 — 관서·청 감사 절차에 따라 제출*');
    return buf.toString().trim();
  }

  static String _buildInsuranceApplication({
    required String stamp,
    required PhysicalThreatLevel threatLevel,
    required PoliceForceTier forceTier,
    required String officerIdHint,
    required List<ResistanceTimelineEntry> timeline,
  }) {
    final buf = StringBuffer()
      ..writeln('# 경찰관 법률비용보험 지원 신청서 (초안)')
      ..writeln()
      ..writeln('- 신청 일시: $stamp')
      ..writeln('- 신청인(수사관): $officerIdHint')
      ..writeln('- 사건 개요: 현장 물리력 집행 후 독직폭행 고소·협박 / 피소 대비')
      ..writeln('- 관련 저항 단계: ${threatLevel.displayName}')
      ..writeln('- 집행 물리력: ${forceTier.label}')
      ..writeln()
      ..writeln('## 신청 사유')
      ..writeln()
      ..writeln(
        '정당한 직무집행 과정에서 피의자 측의 독직폭행 고소·협박에 따른 '
        '법률 조력·소송비용 지원을 요청합니다. '
        '첨부: 디지털 공무집행 무결성 보고서(CoC), 저항 단계 타임라인, 현장 로그.',
      )
      ..writeln()
      ..writeln('## 첨부 타임라인')
      ..writeln();
    for (final e in timeline) {
      buf.writeln('- ${e.timeLabel} ${e.stageLabel}');
    }
    buf
      ..writeln()
      ..writeln('## 지원 요청 항목')
      ..writeln()
      ..writeln('- [ ] 변호사 자문·선임 비용')
      ..writeln('- [ ] 민사·형사 대응 서류 작성 지원')
      ..writeln('- [ ] 관서 감사·징계 조사 대응 조력')
      ..writeln()
      ..writeln('## 서약')
      ..writeln()
      ..writeln(
        '본 신청 내용은 허위가 없으며, SGP-Agent가 생성한 초안을 '
        '수사관이 검토·보완한 후 제출합니다.',
      )
      ..writeln()
      ..writeln('신청인 서명: ____________    확인 간부: ____________')
      ..writeln()
      ..writeln('---')
      ..writeln('*양식 초안 — 관서 보험 담당·경무과 제출용으로 편집*');
    return buf.toString().trim();
  }
}

/// UI 표시명용 확장 — 가이드 위젯과 동일 라벨.
extension _ThreatDisplay on PhysicalThreatLevel {
  String get displayName => switch (this) {
        PhysicalThreatLevel.compliance => '1단계: 순응·협조',
        PhysicalThreatLevel.passiveResistance => '2단계: 소극적 저항',
        PhysicalThreatLevel.activeResistance => '3단계: 적극적 저항',
        PhysicalThreatLevel.violentAttack => '4단계: 폭력적 저항',
        PhysicalThreatLevel.lethalAttack => '5단계: 치명적 저항',
      };
}
