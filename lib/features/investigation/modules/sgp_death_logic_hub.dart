/// S14 — 변사 처리 외근·내근 하이브리드 분기 허브.
library;

import '../../agent/sgp_vector_store.dart';
import 'sgp_forensic_assistant.dart';

/// 변사 사건 최종 라우팅.
enum SgpDeathCaseRoute {
  investigationCriminal('INVESTIGATION_CRIMINAL'),
  administrativeClose('ADMINISTRATIVE_CLOSE');

  const SgpDeathCaseRoute(this.code);
  final String code;
}

/// 외근 초동 데이터 정규화 모델.
class SgpDeathFieldData {
  const SgpDeathFieldData({
    required this.caseId,
    required this.narrative,
    this.hasFoulPlay = false,
    this.policeLineInstalled = false,
    this.evidencePreserved = false,
    this.witnessStatementCaptured = false,
    this.offlineHandoffRequested = false,
  });

  final String caseId;
  final String narrative;
  final bool hasFoulPlay;
  final bool policeLineInstalled;
  final bool evidencePreserved;
  final bool witnessStatementCaptured;
  final bool offlineHandoffRequested;

  factory SgpDeathFieldData.fromMap(Map<String, dynamic> data) {
    final text = (data['narrative'] ?? data['raw_text'] ?? data['text'] ?? '')
        .toString();
    return SgpDeathFieldData(
      caseId: (data['case_id'] ?? data['caseId'] ?? 'DEATH-OFFLINE').toString(),
      narrative: text,
      hasFoulPlay: data['has_foul_play'] as bool? ??
          data['hasFoulPlay'] as bool? ??
          RegExp(r'(타살|살해|피살|흉기|목\s*조름|방화|혈흔|피\s*흔적|폭행)')
              .hasMatch(text),
      policeLineInstalled: data['police_line_installed'] as bool? ??
          data['policeLineInstalled'] as bool? ??
          RegExp(r'(통제선|폴리스\s*라인|police\s*line|출입\s*통제)',
                  caseSensitive: false)
              .hasMatch(text),
      evidencePreserved: data['evidence_preserved'] as bool? ??
          data['evidencePreserved'] as bool? ??
          RegExp(r'(현장\s*보존|증거\s*보존|유류품\s*봉인|사진\s*촬영)')
              .hasMatch(text),
      witnessStatementCaptured: data['witness_statement_captured'] as bool? ??
          data['witnessStatementCaptured'] as bool? ??
          RegExp(r'(목격자|최초\s*발견자|유족\s*진술|진술\s*녹음)').hasMatch(text),
      offlineHandoffRequested: data['offline_handoff_requested'] as bool? ??
          data['offlineHandoffRequested'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toMap() => {
        'case_id': caseId,
        'narrative': narrative,
        'has_foul_play': hasFoulPlay,
        'police_line_installed': policeLineInstalled,
        'evidence_preserved': evidencePreserved,
        'witness_statement_captured': witnessStatementCaptured,
        'offline_handoff_requested': offlineHandoffRequested,
      };
}

class SgpDeathCaseDecision {
  const SgpDeathCaseDecision({
    required this.caseId,
    required this.route,
    required this.actionRequired,
    required this.applicableLaw,
    required this.documentTemplate,
    required this.fieldChecklist,
    required this.investigationGuides,
    required this.forensicResult,
    required this.precedentMatches,
    required this.offlineHandoffReady,
  });

  final String caseId;
  final SgpDeathCaseRoute route;
  final String actionRequired;
  final String applicableLaw;
  final String documentTemplate;
  final List<String> fieldChecklist;
  final List<String> investigationGuides;
  final ForensicAssistantResult forensicResult;
  final List<String> precedentMatches;
  final bool offlineHandoffReady;

  bool get requiresAutopsyWarrant =>
      route == SgpDeathCaseRoute.investigationCriminal;

  bool get isAdministrativeClose =>
      route == SgpDeathCaseRoute.administrativeClose;

  Map<String, dynamic> toMap() => {
        'case_id': caseId,
        'route': route.code,
        'action_required': actionRequired,
        'applicable_law': applicableLaw,
        'document_template': documentTemplate,
        'field_checklist': fieldChecklist,
        'investigation_guides': investigationGuides,
        'precedent_matches': precedentMatches,
        'offline_handoff_ready': offlineHandoffReady,
      };
}

class SgpDeathLogicHub {
  SgpDeathLogicHub(this._vectorStore);

  final SgpVectorStore _vectorStore;

  /// 외근의 초동 데이터와 내근의 사법 판례 데이터셋을 교차 검증한다.
  SgpDeathCaseDecision processDeathCase(Map<String, dynamic> fieldData) {
    final normalized = SgpDeathFieldData.fromMap(fieldData);
    final hasExplicitFoulPlay = fieldData.containsKey('has_foul_play') ||
        fieldData.containsKey('hasFoulPlay');
    final forensic = SgpForensicAssistant.analyze(
      normalized.narrative,
      policeLineDeclared: normalized.policeLineInstalled,
      propertyListDeclared: normalized.evidencePreserved,
      kcsiNotified: RegExp(r'(KCSI|과학수사|감식)', caseSensitive: false)
          .hasMatch(normalized.narrative),
    );
    final hasFoulPlay = hasExplicitFoulPlay
        ? normalized.hasFoulPlay
        : normalized.hasFoulPlay ||
            forensic.route == DeathCaseRoute.judicialAutopsy;
    final route = hasFoulPlay
        ? SgpDeathCaseRoute.investigationCriminal
        : SgpDeathCaseRoute.administrativeClose;
    final matches = _vectorStore
        .search(
          '${normalized.narrative} 변사 검시 현장보존 부검 사체인도',
          topK: 5,
          minScore: 0.05,
        )
        .map((h) => h.record.id)
        .toList();

    return SgpDeathCaseDecision(
      caseId: normalized.caseId,
      route: route,
      actionRequired: route == SgpDeathCaseRoute.investigationCriminal
          ? '강력계 즉시 출동 및 사법 변사 절차 가동'
          : '변사자 인적사항 확인 및 유족 인도 절차 조율',
      applicableLaw: route == SgpDeathCaseRoute.investigationCriminal
          ? '형사소송법 제222조 제2항 (타살 혐의 수사)'
          : '변사자 처리 규칙 제6조 (단순 병사/변사 인도)',
      documentTemplate: route == SgpDeathCaseRoute.investigationCriminal
          ? '사체 부검 영장 신청서 초안'
          : '사체 인도서 및 검시 보고서',
      fieldChecklist: fieldChecklistFor(normalized),
      investigationGuides: investigationGuidesFor(route),
      forensicResult: forensic,
      precedentMatches: matches,
      offlineHandoffReady: normalized.offlineHandoffRequested ||
          (normalized.policeLineInstalled &&
              normalized.evidencePreserved &&
              normalized.witnessStatementCaptured),
    );
  }

  static List<String> fieldChecklistFor(SgpDeathFieldData data) => [
        '형소법 제222조 기반 폴리스라인(Police Line) 즉시 설치 여부',
        '과학수사팀(KCSI) 도착 전 사체 및 유류품 임의 이동 금지 알림',
        '최초 발견자 및 유족 비정형 진술 무전/음성 즉시 녹음창',
        if (!data.policeLineInstalled) '통제선 미설치 — 현장 접근 차단 우선',
        if (!data.evidencePreserved) '증거/현장 보존 조치 미완료 — 사진·봉인 필요',
        if (!data.witnessStatementCaptured) '유족·목격자 최초 진술 확보 필요',
      ];

  static List<String> investigationGuidesFor(SgpDeathCaseRoute route) => [
        '범죄 혐의점 유무에 따른 행정 변사(인도) vs 사법 변사(부검영장) 분기 추론',
        '관할 검찰청 검사 검시 지휘 서식 자동 매핑',
        '허위 검시서 작성 방지를 위한 감찰 방패(Anti-Corruption) 가이드라인 노출',
        if (route == SgpDeathCaseRoute.investigationCriminal)
          '부검 지휘 신청 및 사체인도서 서류 빌드'
        else
          '사체 인도서 및 검시 보고서 빌드',
      ];
}
