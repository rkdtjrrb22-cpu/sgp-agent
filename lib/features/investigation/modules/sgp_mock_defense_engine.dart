/// S13 — AI 가상 모의 디펜스 코어 (검사·판사 선제 태클).
library;

import '../../agent/sgp_kgrag_router.dart';

/// 모의 디펜스 체크리스트 (LawCheckList 핵심 필드만).
class MockDefenseChecklist {
  const MockDefenseChecklist({
    this.isWeaponUsed = false,
    this.isFleeing = false,
    this.isSeizureConstraintReviewed = false,
  });

  final bool isWeaponUsed;
  final bool isFleeing;
  final bool isSeizureConstraintReviewed;
}

/// 모의 디펜스 분석 입력 (SgpReportInput 필드와 1:1 대응).
class MockDefenseAnalyzeInput {
  const MockDefenseAnalyzeInput({
    required this.rawText,
    this.checklist = const MockDefenseChecklist(),
    this.evidenceNoticeComplete = false,
    this.kgragReasoning,
  });

  final String rawText;
  final MockDefenseChecklist checklist;
  final bool evidenceNoticeComplete;
  final KgragReasoningResult? kgragReasoning;
}

/// 모의 디펜스 3대 취약점 축.
enum MockDefenseVulnerability {
  fleeingAndResidence('도주 우려·주거 부정 검증'),
  chainOfCustody('위수증·증거능력'),
  forceProportionality('물리력 비례의 원칙');

  const MockDefenseVulnerability(this.label);
  final String label;
}

/// 위험 수준 — UI 배지 색상과 연동.
enum MockDefenseRiskLevel {
  /// 네온 오렌지 #FF6D00
  warning,

  /// 크림슨 레드 #D50000
  critical,

  /// 솔리드 그린 #00C853
  clear,
}

extension MockDefenseRiskLevelColors on MockDefenseRiskLevel {
  static const neonOrange = 0xFFFF6D00;
  static const crimsonRed = 0xFFD50000;
  static const solidGreen = 0xFF00C853;

  int get colorHex => switch (this) {
        MockDefenseRiskLevel.warning => neonOrange,
        MockDefenseRiskLevel.critical => crimsonRed,
        MockDefenseRiskLevel.clear => solidGreen,
      };
}

/// 개별 태클(보완수사·기각 사유).
class MockDefenseTackle {
  const MockDefenseTackle({
    required this.id,
    required this.vulnerability,
    required this.riskLevel,
    required this.prosecutorLine,
    required this.courtLine,
    required this.remediation,
    required this.matchedSignals,
  });

  final String id;
  final MockDefenseVulnerability vulnerability;
  final MockDefenseRiskLevel riskLevel;
  final String prosecutorLine;
  final String courtLine;
  final String remediation;
  final List<String> matchedSignals;
}

class MockDefenseResult {
  const MockDefenseResult({
    required this.tackles,
    required this.overallRisk,
    required this.defenseReady,
    required this.summary,
  });

  final List<MockDefenseTackle> tackles;
  final MockDefenseRiskLevel overallRisk;
  final bool defenseReady;
  final String summary;

  int get criticalCount =>
      tackles.where((t) => t.riskLevel == MockDefenseRiskLevel.critical).length;

  int get warningCount =>
      tackles.where((t) => t.riskLevel == MockDefenseRiskLevel.warning).length;
}

abstract final class SgpMockDefenseEngine {
  static final _fleeKw =
      RegExp(r'(도주|도망|신원\s*불명|주소\s*불명|주거\s*미확인|거짓\s*주소|허위\s*주소|신분\s*확인\s*거부)');
  static final _residenceKw =
      RegExp(r'(주거\s*확인|실거주|등본|주소\s*확인|거주\s*검증)');
  static final _chainKw = RegExp(
    r'(위수증|압수\s*목록|증거\s*목록|chain|봉인|인도\s*기록|채증\s*고지|녹화\s*개시)',
  );
  static final _forceExcessKw = RegExp(
    r'(과잉\s*물리력|과도\s*force|비례\s*위반|정당방위\s*초과|과잉\s*방어|불필요\s*force|과격)',
  );
  static final _weaponKw = RegExp(r'(흉기|봉|전기\s*충격|테이저|삼단\s*봉)');

  /// SgpReportInput + KG-RAG 결과를 가상 검사·판사 컨텍스트에 투입.
  static MockDefenseResult analyze({
    required MockDefenseAnalyzeInput input,
    KgragReasoningResult? kgrag,
  }) {
    final text = input.rawText.trim();
    final checklist = input.checklist;
    final kgragResult = kgrag ?? input.kgragReasoning;
    final tackles = <MockDefenseTackle>[];

    // 1) 도주 우려 / 주거 검증
    final fleeText = _fleeKw.hasMatch(text);
    final fleeCheck = checklist.isFleeing;
    final residenceOk = _residenceKw.hasMatch(text);
    MockDefenseRiskLevel fleeRisk;
    if ((fleeText || fleeCheck) && !residenceOk) {
      fleeRisk = MockDefenseRiskLevel.critical;
    } else if (fleeText || fleeCheck) {
      fleeRisk = MockDefenseRiskLevel.warning;
    } else if (!residenceOk && text.isNotEmpty) {
      fleeRisk = MockDefenseRiskLevel.warning;
    } else {
      fleeRisk = MockDefenseRiskLevel.clear;
    }
    if (fleeRisk != MockDefenseRiskLevel.clear) {
      tackles.add(
        MockDefenseTackle(
          id: 'MD-FLEE-RESIDENCE',
          vulnerability: MockDefenseVulnerability.fleeingAndResidence,
          riskLevel: fleeRisk,
          prosecutorLine: '도주 우려·주거지 확인 소홀 — 보완수사 요구 가능',
          courtLine: '영장(구속·수색) 기각 — 주거·신원 확인 미흡',
          remediation:
              '체포·검거 직후 주소·실거주·등본·신원 확인을 조서·녹화로 남기고 도주 경위를 구체화하세요.',
          matchedSignals: [
            if (fleeText) '도주/신원·주소 정황',
            if (fleeCheck) '체크리스트 도주',
            if (!residenceOk) '주거 검증 미기재',
          ],
        ),
      );
    }

    // 2) 위수증·증거능력
    final chainMention = _chainKw.hasMatch(text);
    final seizureReviewed = checklist.isSeizureConstraintReviewed;
    final timelineEvidence = input.evidenceNoticeComplete;
    MockDefenseRiskLevel chainRisk;
    if (!chainMention && !seizureReviewed && !timelineEvidence) {
      chainRisk = MockDefenseRiskLevel.critical;
    } else if (!chainMention || !seizureReviewed) {
      chainRisk = MockDefenseRiskLevel.warning;
    } else {
      chainRisk = MockDefenseRiskLevel.clear;
    }
    if (chainRisk != MockDefenseRiskLevel.clear) {
      tackles.add(
        MockDefenseTackle(
          id: 'MD-CHAIN-CUSTODY',
          vulnerability: MockDefenseVulnerability.chainOfCustody,
          riskLevel: chainRisk,
          prosecutorLine: '압수·위수증·채증 고지 누락 — 증거능력 다툼 예상',
          courtLine: '위법수집증거·증거능력 부정 — 기각·무죄 가능성',
          remediation:
              '압수목록·위수증·채증 법적 고지·녹화 개시 시각을 타임라인과 조서에 일치시키세요.',
          matchedSignals: [
            if (!chainMention) '위수증/목록 미언급',
            if (!seizureReviewed) '압수·강제수사 검토 미체크',
            if (!timelineEvidence) '채증 고지 미완료',
          ],
        ),
      );
    }

    // 3) 물리력 비례의 원칙
    final forceExcess = _forceExcessKw.hasMatch(text);
    final weapon = checklist.isWeaponUsed || _weaponKw.hasMatch(text);
    final lowConfidence = kgragResult != null && !kgragResult.hallucinationGuardPass;
    final lowSelfDefense =
        kgragResult != null && kgragResult.selfDefenseProbability < 0.35;
    MockDefenseRiskLevel forceRisk;
    if (forceExcess || (weapon && lowSelfDefense)) {
      forceRisk = MockDefenseRiskLevel.critical;
    } else if (weapon || lowConfidence) {
      forceRisk = MockDefenseRiskLevel.warning;
    } else {
      forceRisk = MockDefenseRiskLevel.clear;
    }
    if (forceRisk != MockDefenseRiskLevel.clear) {
      tackles.add(
        MockDefenseTackle(
          id: 'MD-FORCE-PROP',
          vulnerability: MockDefenseVulnerability.forceProportionality,
          riskLevel: forceRisk,
          prosecutorLine: '물리력 행사 비례성·정당방위 상당성 재검토 요구',
          courtLine: '과잉 방위·위법성 — 무죄·감형 주장 여지',
          remediation:
              '침해의 현재성·상당성·최소 침해 원칙을 CoT·판례(KG-RAG)와 함께 조서에 명시하세요.',
          matchedSignals: [
            if (forceExcess) '과잉 물리력 정황',
            if (weapon) '흉기·무기',
            if (lowSelfDefense) '정당방위 확률 낮음',
            if (lowConfidence) 'KG-RAG 환각 가드 미통과',
          ],
        ),
      );
    }

    if (tackles.isEmpty) {
      return const MockDefenseResult(
        tackles: [],
        overallRisk: MockDefenseRiskLevel.clear,
        defenseReady: true,
        summary: '가상 검사·판사 모의 디펜스 — 3대 취약점 미감지, 사법 방어 준비 양호.',
      );
    }

    final overall = tackles.any((t) => t.riskLevel == MockDefenseRiskLevel.critical)
        ? MockDefenseRiskLevel.critical
        : MockDefenseRiskLevel.warning;

    return MockDefenseResult(
      tackles: tackles,
      overallRisk: overall,
      defenseReady: overall == MockDefenseRiskLevel.clear,
      summary:
          '모의 디펜스 ${tackles.length}건 태클 — '
          '${overall == MockDefenseRiskLevel.critical ? "즉시 보정 필요" : "선제 보정 권고"}.',
    );
  }
}
