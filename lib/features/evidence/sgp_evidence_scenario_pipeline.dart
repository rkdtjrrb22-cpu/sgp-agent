/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Digital Evidence Scenario Pipeline (Autophagosome)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 음주거부·폭행·스마트폰/블랙박스 임의제출 → CoC 체크리스트 + 범죄사실 초안.
library;

import 'sgp_evidence_coc_engine.dart';

enum EvidenceScenarioKind {
  duiRefusal,
  assault,
  digitalSubmission,
  mixed,
  generic,
}

class EvidenceCrimeFactDraft {
  const EvidenceCrimeFactDraft({
    required this.title,
    required this.statutoryBasis,
    required this.narrative,
    required this.checkItems,
  });

  final String title;
  final String statutoryBasis;
  final String narrative;
  final List<String> checkItems;
}

class EvidenceScenarioPipelineResult {
  const EvidenceScenarioPipelineResult({
    required this.kind,
    required this.chainOfCustody,
    required this.crimeFacts,
    required this.integrityChecklist,
    required this.supplementaryWarning,
  });

  final EvidenceScenarioKind kind;
  final EvidenceCoCSession chainOfCustody;
  final List<EvidenceCrimeFactDraft> crimeFacts;
  final List<String> integrityChecklist;
  final String supplementaryWarning;
}

/// 현장 텍스트 → 오토파지(절차 캡슐) 파이프라인.
abstract final class SgpEvidenceScenarioPipeline {
  static EvidenceScenarioPipelineResult run(String rawText) {
    final kind = _classify(rawText);
    final coc = SgpEvidenceCoCEngine.createSession(
      rawText: rawText,
      mediaLabel: '현장 디지털 증거',
    );
    final facts = <EvidenceCrimeFactDraft>[];

    if (kind == EvidenceScenarioKind.duiRefusal ||
        kind == EvidenceScenarioKind.mixed) {
      facts.add(
        const EvidenceCrimeFactDraft(
          title: '도로교통법 위반(음주측정 거부) 초안',
          statutoryBasis: '도로교통법 제44조·제148조의2',
          narrative:
              '피의자는 운전 중 또는 운전 직후 경찰공무원의 음주측정 요구에 응하지 아니하고 '
              '정당한 사유 없이 측정을 거부한 사실이 인정된다.',
          checkItems: [
            '측정 요구 시각·장소·고지 내용 기록',
            '거부 의사표시·영상/무전 확보',
            '운전 사실 입증(블랙박스·목격·영상)',
          ],
        ),
      );
    }

    if (kind == EvidenceScenarioKind.assault ||
        kind == EvidenceScenarioKind.mixed) {
      facts.add(
        const EvidenceCrimeFactDraft(
          title: '폭행 혐의 범죄사실 초안',
          statutoryBasis: '형법 제260조 (폭행)',
          narrative:
              '피의자는 피해자 ○○에 대하여 주먹·손바닥 등으로 신체를 가격하는 등 '
              '폭행한 사실이 인정된다. (부위·정도·상해 유무는 추가 조사)',
          checkItems: [
            '가해·피해 분리·상해진단',
            '현장 채증·바디캠',
            '목격자·CCTV 보전',
          ],
        ),
      );
    }

    if (kind == EvidenceScenarioKind.digitalSubmission ||
        kind == EvidenceScenarioKind.mixed ||
        coc.deviceType != null) {
      facts.add(
        EvidenceCrimeFactDraft(
          title: '전자정보 임의제출·압수 절차 요약',
          statutoryBasis: '형사소송법 제106조·제219조 / 디지털 증거 압수 법리',
          narrative:
              '피의자(또는 소지자)로부터 ${coc.deviceType ?? "전자기기"}를 '
              '임의제출받아 선별 압수·해시 추출·참여권 고지 절차를 이행하여야 한다. '
              '일괄 복제·비연관 정보 압수 시 위법수집증거 배제 위험이 있다.',
          checkItems: [
            for (final s in EvidenceCoCStep.values) s.label,
            '압수목록 현장 교부',
            '봉인·연속성(evidenceCoC) 기록',
          ],
        ),
      );
    }

    if (facts.isEmpty) {
      facts.add(
        const EvidenceCrimeFactDraft(
          title: '현장 조치 요약 초안',
          statutoryBasis: '형사소송법 일반',
          narrative: '입력된 현장 진술을 바탕으로 구성요건·절차를 추가 매핑합니다.',
          checkItems: ['사실관계 재확인', '디지털 증거 유무 확인'],
        ),
      );
    }

    final integrity = <String>[
      '디지털 증거수집 무결성 체크리스트 (대법원·하급심 기준)',
      ...EvidenceCoCStep.values.map((s) {
        final done = coc.steps[s]?.completed ?? false;
        return '${done ? "☑" : "☐"} ${s.label}';
      }),
      if (coc.blindSpots.isNotEmpty) '--- 맹점 ---',
      ...coc.blindSpots.map((b) => '⚠ ${b.label}: ${b.actionGuide}'),
    ];

    return EvidenceScenarioPipelineResult(
      kind: kind,
      chainOfCustody: coc,
      crimeFacts: facts,
      integrityChecklist: integrity,
      supplementaryWarning:
          SgpEvidenceCoCEngine.supplementaryInvestigationWarning(coc),
    );
  }

  static EvidenceScenarioKind _classify(String text) {
    final dui = text.contains('음주') ||
        text.contains('측정 거부') ||
        text.contains('음주측정') ||
        text.contains('음주운전');
    final assault =
        text.contains('폭행') || text.contains('구타') || text.contains('가격');
    final digital = text.contains('스마트폰') ||
        text.contains('휴대폰') ||
        text.contains('블랙박스') ||
        text.contains('임의제출') ||
        text.contains('CCTV');

    final n = (dui ? 1 : 0) + (assault ? 1 : 0) + (digital ? 1 : 0);
    if (n >= 2) return EvidenceScenarioKind.mixed;
    if (dui) return EvidenceScenarioKind.duiRefusal;
    if (assault) return EvidenceScenarioKind.assault;
    if (digital) return EvidenceScenarioKind.digitalSubmission;
    return EvidenceScenarioKind.generic;
  }
}
