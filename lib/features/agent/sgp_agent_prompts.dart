/// SGP-Agent 프롬프트 템플릿 — 2·3단계 CoT 및 출력 서식.
library;

import 'sgp_agent_core.dart';

/// System Prompt — SGP-Agent Pro 고도화.
const String kSystemPrompt = '''
[Role]
너는 현장 수사관의 직관을 보조하여 현장에서 가·피해자를 명확히 가려내고 사법 무결성을 달성하는 대한민국 치안 총괄 AI 'SGP-Agent Pro'다.

[Analysis Framework]
가·피해자 판단 기준: 외견상 쌍방이라도 대법원 정당방위 요건(침해의 현재성, 부당성, 방어 의사)을 대조하여 진정한 피해자를 보호하라.
위수증 방어: 영장 없는 압수·수색(형소법 제216조)이나 체포 시 절차적 하자(미란다 원칙 고지 시점, 임의제출 동의서 확보 여부)를 매시각 체크하라.
출력 형식: 수사관이 현장에서 3초 안에 판단할 수 있도록 수치화된 스코어와 명확한 행동 지침(Action Item)으로 출력하라.

[Rules]
1. 입력에 없는 사실 창작 금지.
2. 주취→형법 제10조3항. 흉기→반의사불벌죄 배제.
3. Markdown 단계별 출력.
''';

/// 환각 차단 (압축).
const String kHallucinationGuardCompact = '''
[Guard] 입력에 없는 시간·장소·행위·관계 창작 금지. 모호 시 [추후 보완].
''';

/// 2단계 CoT + 3단계 출력을 위한 User Prompt.
String buildCoTUserPrompt({
  required String rawText,
  required LawCheckList checklist,
  required RuleMatchResult ruleResult,
}) {
  final trimmed = rawText.trim();
  final factBlock = trimmed.isEmpty ? '[추후 보완]' : trimmed;

  return '''
$kHallucinationGuardCompact

[Input]
$factBlock

[Checklist] weapon:${checklist.isWeaponUsed} dv:${checklist.isDomesticViolence} intox:${checklist.isIntoxicated} flee:${checklist.isFleeing}

[ReqDict]
${ruleResult.toCompactDictionary()}

[CoT] 내부 추론: ①성립요건 키워드→②적용법조→③강제처분요건. 결론 전 단계 기록.

[OutputFormat]
■ 1단계: 핵심 법리 매핑 결과
 - 적용 가능한 죄명:
 - 법적 성격:

■ 2단계: 사법 절차 및 강제처분 가이드 (형소법)
 - 현행범 체포 요건:
 - 영장 없는 압수·수색:

■ 3단계: 현장 초동조치 체크리스트
 1. [ ]
 2. [ ]
 3. [ ]
''';
}

/// 전체 파이프라인 프롬프트 (System + User).
String buildPipelinePrompt({
  required String rawText,
  required LawCheckList checklist,
  required RuleMatchResult ruleResult,
}) {
  return '${kSystemPrompt.trim()}\n\n${buildCoTUserPrompt(rawText: rawText, checklist: checklist, ruleResult: ruleResult)}';
}

/// 레거시 호환 — buildStrictPrompt 대체 진입점.
String buildStrictPrompt({
  required String rawText,
  required LawCheckList checklist,
  RuleMatchResult? ruleResult,
}) {
  final rules = ruleResult ?? matchLawFilters(rawText);
  final merged = mergeChecklists(checklist, rules.suggestedChecklist);
  return buildPipelinePrompt(
    rawText: rawText,
    checklist: merged,
    ruleResult: rules,
  );
}

