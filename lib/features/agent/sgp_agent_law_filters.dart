/// 성립 요건 딕셔너리 — 규칙 기반 법리 매핑 (1단계).
library;

import 'sgp_agent_core.dart';

/// 단일 법리 필터 정의.
class LawFilterDefinition {
  const LawFilterDefinition({
    required this.filterName,
    required this.displayName,
    required this.triggerKeywords,
    required this.mappingLaw,
    required this.checklistField,
  });

  final String filterName;
  final String displayName;
  final List<String> triggerKeywords;
  final Map<String, String> mappingLaw;
  final LawChecklistField checklistField;
}

enum LawChecklistField {
  weapon,
  relational,
  intoxication,
  fleeing,
  seizureConstraint,
}

/// 트리거된 필터 1건.
class TriggeredFilter {
  const TriggeredFilter({
    required this.definition,
    required this.matchedKeywords,
  });

  final LawFilterDefinition definition;
  final List<String> matchedKeywords;
}

/// 1단계 규칙 매칭 결과.
class RuleMatchResult {
  const RuleMatchResult({
    required this.triggeredFilters,
    required this.suggestedChecklist,
  });

  final List<TriggeredFilter> triggeredFilters;
  final LawCheckList suggestedChecklist;

  bool get isEmpty => triggeredFilters.isEmpty;

  bool isTriggered(String filterName) =>
      triggeredFilters.any((t) => t.definition.filterName == filterName);

  /// LLM 프롬프트용 — 트리거된 요건만 압축 직렬화.
  String toCompactDictionary() {
    if (triggeredFilters.isEmpty) {
      return '(트리거된 성립요건 없음 — 입력·체크리스트 기준 추론)';
    }
    final buf = StringBuffer();
    for (final t in triggeredFilters) {
      buf.writeln('[${t.definition.displayName}] kw:${t.matchedKeywords.join(",")}');
      for (final e in t.definition.mappingLaw.entries) {
        buf.writeln(' ${e.key}:${e.value}');
      }
    }
    return buf.toString().trim();
  }
}

/// 성립 요건 딕셔너리 (법률 전문 대신 참조).
const List<LawFilterDefinition> kLawFilterDictionary = [
  LawFilterDefinition(
    filterName: 'weapon_and_danger',
    displayName: '흉기·위험물 사용 필터',
    triggerKeywords: [
      '칼', '낫', '소주병', '벽돌', '가위', '차량', '둔기', '들고', '휘두르',
      '흉기', '위험물', '주먹', '폭행', '상해',
    ],
    mappingLaw: {
      'primary': '폭력행위 등 처벌에 관한 법률 제3조 (특수폭행·상해)',
      'secondary': '형법 제261조 (특수폭행) / 제258조의2 (특수상해)',
      'procedure_note':
          '반의사불벌죄 배제. 피해자 합의 무관 형사 입건·현행범 체포 적극 검토.',
    },
    checklistField: LawChecklistField.weapon,
  ),
  LawFilterDefinition(
    filterName: 'relational_violence',
    displayName: '관계성 폭력 필터',
    triggerKeywords: [
      '남편', '아내', '와이프', '전남친', '전여친', '동거인',
      '따라오', '집 앞에', '지속적', '가정', '스토킹', '전 남친', '전 여친',
    ],
    mappingLaw: {
      'domestic': '가정폭력범죄의 처벌 등에 관한 특례법 (임시조치 제29조)',
      'stalking': '스토킹범죄의 처벌 등에 관한 법률 (긴급응급조치/잠정조치)',
      'procedure_note':
          '피해자 분리·주거지 100m 접근금지·전기통신 접근금지 선제 집행 검토.',
    },
    checklistField: LawChecklistField.relational,
  ),
  LawFilterDefinition(
    filterName: 'voluntary_intoxication',
    displayName: '자의적 주취·약물 필터',
    triggerKeywords: [
      '술', '취해', '소주', '맥주', '약물', '기억 안 나', '비틀거', '주취', '만취',
    ],
    mappingLaw: {
      'primary': '형법 제10조 제3항 (원인에 있어서 자유로운 행위)',
      'procedure_note':
          '자의적 음주 심신미약 감경 주장 선제 차단. 범행 당시 고의성 입증 주력.',
    },
    checklistField: LawChecklistField.intoxication,
  ),
  LawFilterDefinition(
    filterName: 'fleeing_identity_refusal',
    displayName: '도주·신분확인 거부 필터',
    triggerKeywords: [
      '도주', '도망', '달아', '신분', '확인 거부', '경찰관', '체포', '도망치',
    ],
    mappingLaw: {
      'primary': '형사소송법 제211조 (현행범인 체포)',
      'procedure_note': '도망·증거인멸 염려 시 현행범 체포 요건 충족 여부 검토.',
    },
    checklistField: LawChecklistField.fleeing,
  ),
  LawFilterDefinition(
    filterName: 'seizure_coercion_constraint',
    displayName: '압수·강제수사 제한 요건 필터 (10월 개정)',
    triggerKeywords: [
      '압수', '수색', '영장', '강제수사', '보완지시', '디지털', '휴대폰', '압수수색',
      '임의제출', '동의', '증거', '체포', '구속',
    ],
    mappingLaw: {
      'primary': '형사소송법 제106조·제216조 (압수·수색) + 2025.10 개정 강제수사 요건',
      'procedure_note':
          '보완지시 삭제·강제수사 완결성 — 영장 요건·디지털 포렌식·동의서 확보 여부 재검토.',
    },
    checklistField: LawChecklistField.seizureConstraint,
  ),
];

/// 텍스트 전처리 후 키워드 매칭 — 1단계 파이프라인.
RuleMatchResult matchLawFilters(String rawText) {
  final normalized = rawText.trim().toLowerCase();
  if (normalized.isEmpty) {
    return const RuleMatchResult(
      triggeredFilters: [],
      suggestedChecklist: LawCheckList(),
    );
  }

  final triggered = <TriggeredFilter>[];
  var weapon = false;
  var relational = false;
  var intoxication = false;
  var fleeing = false;
  var seizureConstraint = false;

  for (final def in kLawFilterDictionary) {
    final hits = <String>[];
    for (final kw in def.triggerKeywords) {
      if (normalized.contains(kw.toLowerCase())) {
        hits.add(kw);
      }
    }
    if (hits.isEmpty) continue;

    triggered.add(TriggeredFilter(definition: def, matchedKeywords: hits));
    switch (def.checklistField) {
      case LawChecklistField.weapon:
        weapon = true;
      case LawChecklistField.relational:
        relational = true;
      case LawChecklistField.intoxication:
        intoxication = true;
      case LawChecklistField.fleeing:
        fleeing = true;
      case LawChecklistField.seizureConstraint:
        seizureConstraint = true;
    }
  }

  return RuleMatchResult(
    triggeredFilters: triggered,
    suggestedChecklist: LawCheckList(
      isWeaponUsed: weapon,
      isDomesticViolence: relational,
      isIntoxicated: intoxication,
      isFleeing: fleeing,
      isSeizureConstraintReviewed: seizureConstraint,
    ),
  );
}

/// 수사관 수동 체크 + 규칙 추천 병합 (OR).
LawCheckList mergeChecklists(LawCheckList manual, LawCheckList suggested) {
  return LawCheckList(
    isWeaponUsed: manual.isWeaponUsed || suggested.isWeaponUsed,
    isDomesticViolence: manual.isDomesticViolence || suggested.isDomesticViolence,
    isIntoxicated: manual.isIntoxicated || suggested.isIntoxicated,
    isFleeing: manual.isFleeing || suggested.isFleeing,
    isSeizureConstraintReviewed:
        manual.isSeizureConstraintReviewed || suggested.isSeizureConstraintReviewed,
  );
}

/// 필드별 규칙 자동 추천 여부.
bool isFieldSuggestedByRule(
  RuleMatchResult rules,
  LawChecklistField field,
) {
  for (final t in rules.triggeredFilters) {
    if (t.definition.checklistField == field) return true;
  }
  return false;
}
