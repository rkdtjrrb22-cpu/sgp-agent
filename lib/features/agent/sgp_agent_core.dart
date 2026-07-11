/// SGP-Agent 코어 엔진 — 온디바이스 수사 조서 정형화 및 sLLM 오케스트레이션.
library;

import 'dart:async';

export 'sgp_agent_law_filters.dart';
export 'sgp_agent_prompts.dart';

import 'sgp_agent_law_filters.dart';
import 'sgp_agent_prompts.dart';
import 'sgp_precedent_dictionary.dart';

import 'package:sgp_agent/native/sgp_native_bridge.dart';

part 'sgp_agent_advanced.dart';

// ---------------------------------------------------------------------------
// 4대 법리 변수 구조체
// ---------------------------------------------------------------------------

/// 수사관 터치 입력 법리 변수 (4대 + 10월 개정 압수·강제수사 검토).
class LawCheckList {
  const LawCheckList({
    this.isWeaponUsed = false,
    this.isDomesticViolence = false,
    this.isIntoxicated = false,
    this.isFleeing = false,
    this.isSeizureConstraintReviewed = false,
  });

  /// 특수죄 구성요건(흉기 사용 등) · 반의사불벌죄 배제 가이드.
  final bool isWeaponUsed;

  /// 스토킹·가정폭력처벌법 관계성 필터.
  final bool isDomesticViolence;

  /// 자의에 의한 음주 → 형법 제10조 3항 자의행위 매핑.
  final bool isIntoxicated;

  /// 도주·신분 확인 거부 → 형소법 제211조 체포 필요성.
  final bool isFleeing;

  /// 10월 개정 형사법 — 압수·강제수사 제한 요건(보완지시 삭제 등) 검토.
  final bool isSeizureConstraintReviewed;

  LawCheckList copyWith({
    bool? isWeaponUsed,
    bool? isDomesticViolence,
    bool? isIntoxicated,
    bool? isFleeing,
    bool? isSeizureConstraintReviewed,
  }) {
    return LawCheckList(
      isWeaponUsed: isWeaponUsed ?? this.isWeaponUsed,
      isDomesticViolence: isDomesticViolence ?? this.isDomesticViolence,
      isIntoxicated: isIntoxicated ?? this.isIntoxicated,
      isFleeing: isFleeing ?? this.isFleeing,
      isSeizureConstraintReviewed:
          isSeizureConstraintReviewed ?? this.isSeizureConstraintReviewed,
    );
  }

  Map<String, bool> toJson() => {
        'isWeaponUsed': isWeaponUsed,
        'isDomesticViolence': isDomesticViolence,
        'isIntoxicated': isIntoxicated,
        'isFleeing': isFleeing,
        'isSeizureConstraintReviewed': isSeizureConstraintReviewed,
      };

  factory LawCheckList.fromJson(Map<String, dynamic> json) {
    return LawCheckList(
      isWeaponUsed: json['isWeaponUsed'] as bool? ?? false,
      isDomesticViolence: json['isDomesticViolence'] as bool? ?? false,
      isIntoxicated: json['isIntoxicated'] as bool? ?? false,
      isFleeing: json['isFleeing'] as bool? ?? false,
      isSeizureConstraintReviewed:
          json['isSeizureConstraintReviewed'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// 환각 차단 · 사실관계 검증
// ---------------------------------------------------------------------------

/// 입력문에 명시되지 않은 시간·장소·행위 패턴 (하드코딩 차단).
final RegExp _hallucinationTimePattern = RegExp(
  r'(\d{1,2}시\s*\d{0,2}분?|\d{1,2}:\d{2}|오전|오후|새벽|자정)',
);
final RegExp _hallucinationPlacePattern = RegExp(
  r'(에서|근처|앞|뒤|옆|층|호|동\s*\d)',
);
final RegExp _ambiguousFactPattern = RegExp(
  r'(아마|추정|것\s*같|불명|확인\s*불가|모름|모르)',
);

/// 환각 차단 룰셋 — 프롬프트에 강제 삽입.
const String kHallucinationGuardRules = '''
[환각 차단 지침 — 절대 준수]
1. 입력문(rawText)에 명시되지 않은 시간, 장소, 행위, 인물 관계를 절대 지어내지 말 것.
2. 사실 관계가 모호하거나 입력문에 근거가 없으면 해당 항목을 "[추후 보완]"으로만 출력할 것.
3. 법률 적용은 아래 체크리스트와 입력문에 근거한 사실만 서술할 것.
4. 추론·가정·일반론적 판단을 사실 진술처럼 기재하지 말 것.
''';

/// rawText에서 사실관계 모호 여부를 검사한다.
bool hasAmbiguousFacts(String rawText) {
  if (rawText.trim().isEmpty) return true;
  return _ambiguousFactPattern.hasMatch(rawText);
}

/// 생성 결과에 환각 의심 표현이 포함되었는지 검사한다.
bool containsHallucinationRisk(String output, String rawText) {
  if (output.isEmpty) return false;
  final rawHasTime = _hallucinationTimePattern.hasMatch(rawText);
  final outHasTime = _hallucinationTimePattern.hasMatch(output);
  if (outHasTime && !rawHasTime) return true;

  final rawHasPlace = _hallucinationPlacePattern.hasMatch(rawText);
  final outHasPlace = _hallucinationPlacePattern.hasMatch(output);
  if (outHasPlace && !rawHasPlace) return true;

  return false;
}

/// 모호한 항목을 [추후 보완]으로 강제 치환.
String enforceSupplementPlaceholder(String section, {required bool isAmbiguous}) {
  if (isAmbiguous || section.trim().isEmpty) {
    return '[추후 보완]';
  }
  return section.trim();
}

// ---------------------------------------------------------------------------
// 3단계 파이프라인 결과
// ---------------------------------------------------------------------------

/// Rule → CoT LLM → 출력 전체 파이프라인 결과.
class InferencePipelineResult {
  const InferencePipelineResult({
    required this.ruleResult,
    required this.mergedChecklist,
    required this.prompt,
    required this.output,
    required this.advancedAnalysis,
  });

  final RuleMatchResult ruleResult;
  final LawCheckList mergedChecklist;
  final String prompt;
  final String output;
  final SgpAdvancedAnalysis advancedAnalysis;
}

/// 1단계 규칙 매칭 → 2단계 CoT 프롬프트 → 3단계 출력.
InferencePipelineResult buildPipeline({
  required String rawText,
  required LawCheckList checklist,
}) {
  final ruleResult = matchLawFilters(rawText);
  final merged = mergeChecklists(checklist, ruleResult.suggestedChecklist);
  final prompt = buildPipelinePrompt(
    rawText: rawText,
    checklist: merged,
    ruleResult: ruleResult,
  );
  final advanced = runAdvancedAnalysis(
    rawText: rawText,
    checklist: merged,
    ruleResult: ruleResult,
  );
  final output = generateStructuredOutput(
    rawText: rawText,
    checklist: merged,
    ruleResult: ruleResult,
    advanced: advanced,
  );
  return InferencePipelineResult(
    ruleResult: ruleResult,
    mergedChecklist: merged,
    prompt: prompt,
    output: output,
    advancedAnalysis: advanced,
  );
}

/// sLLM 스텁·오프라인 폴백 — 3단계 Markdown 출력.
String generateStructuredOutput({
  required String rawText,
  required LawCheckList checklist,
  required RuleMatchResult ruleResult,
  SgpAdvancedAnalysis? advanced,
}) {
  final adv = advanced ??
      runAdvancedAnalysis(
        rawText: rawText,
        checklist: checklist,
        ruleResult: ruleResult,
      );
  final crimes = <String>[];
  if (checklist.isWeaponUsed) {
    crimes.add('폭처법 위반(특수폭행·상해) / 형법 특수죄');
  }
  if (checklist.isDomesticViolence) {
    crimes.add('가정폭력처벌법·스토킹처벌법 위반');
  }
  if (!checklist.isWeaponUsed && !checklist.isDomesticViolence) {
    crimes.add('형법 폭행·상해(일반)');
  }

  final legalNature = checklist.isWeaponUsed
      ? '반의사불벌죄 해당 없음 (합의 불문 처벌 가능)'
      : '피해자 의사·반의사불벌죄 해당 여부 확인 필요';

  final arrestGuide = checklist.isFleeing
      ? '범행 명백·도주 염려 인정 시 현행범 체포(형소법 제211조) 검토.'
      : '범행 명백성·도주·증거인멸 염려 여부 추가 확인.';

  final seizureGuide = checklist.isWeaponUsed
      ? '범행 현장(형소법 제216조3항) 흉기·위험물 긴급 압수 후 사후영장 청구.'
      : '현장 증거·CCTV 등 확보. 위수증 방지 채증.';

  final checklistItems = <String>[
    if (checklist.isDomesticViolence)
      '피해자·피의자 즉시 분리 (가정폭력 임시조치 통보)',
    if (checklist.isWeaponUsed)
      '범행 위험물 확보·사진 채증 (위수증 방지)',
    if (checklist.isIntoxicated)
      '피의자 주취 상태 기록 (형법 제10조3항 대비)',
    '현장 진술·CCTV·목격자 확보',
  ];

  final cotNote = ruleResult.triggeredFilters.isEmpty
      ? '키워드 트리거 없음 — 수사관 체크·입력문 기준 추론.'
      : ruleResult.triggeredFilters
          .map((t) => '${t.definition.displayName} 확인(${t.matchedKeywords.join(",")})')
          .join(' → ');

  final factSummary = rawText.trim().isEmpty
      ? '[추후 보완]'
      : (hasAmbiguousFacts(rawText) ? '[추후 보완]' : '입력 무전·진술 원문 근거');
  final assurance = buildReliabilityAssessment(
    rawText: rawText,
    checklist: checklist,
    ruleResult: ruleResult,
  );
  final documentDraft = buildCaseRecordDraft(
    rawText: rawText,
    checklist: checklist,
    ruleResult: ruleResult,
  );

  return '''
■ 1단계: 핵심 법리 매핑 결과
 - 적용 가능한 죄명: ${crimes.join(' / ')}
 - 법적 성격: $legalNature
 - CoT 추론: $cotNote

■ 2단계: 사법 절차 및 강제처분 가이드 (형소법 기반)
 - 현행범 체포 요건: $arrestGuide
 - 영장 없는 압수·수색: $seizureGuide

■ 3단계: 현장 초동조치 수사관 체크리스트
${checklistItems.asMap().entries.map((e) => ' ${e.key + 1}. [ ] ${e.value}').join('\n')}

[사실관계] $factSummary

■ 신뢰성 점검 (수사관 확인용)
$assurance

■ 4단계: 사건 기록 문서 초안 (행정 편의용)
$documentDraft

■ 5단계: SGP-Agent Pro 고도화 분석
 - [실질공격유발자] ${adv.primaryAggressor}
 - [피해·방어당사자] ${adv.primaryVictim}
 - [가·피해자종합] ${adv.suspectVictimStatus}
 - [선제공격] ${adv.preemptiveAttackDetected ? '감지' : '미감지'}
 - [방어행위] ${adv.defenseActDetected ? '감지' : '미감지'}
 - [흉기주도권] ${adv.weaponDominanceHolder}
 - [공소유지예상] ${adv.prosecutionSuccessRate.toStringAsFixed(0)}%
${adv.legalRisks.isEmpty ? ' - [법리리스크] 특이 리스크 없음' : adv.legalRisks.map((r) => ' - [법리리스크] $r').join('\n')}
${adv.evidentiaryActions.isEmpty ? ' - [증거보강] 추가 조치 없음' : adv.evidentiaryActions.map((a) => ' - [증거보강] $a').join('\n')}
${adv.proceduralAlerts.isEmpty ? '' : adv.proceduralAlerts.map((a) => ' - [절차가이드] $a').join('\n')}
''';
}

/// 현장 오판을 줄이기 위한 근거·한계·확인 필요 항목.
String buildReliabilityAssessment({
  required String rawText,
  required LawCheckList checklist,
  required RuleMatchResult ruleResult,
}) {
  final factsMissing = <String>[
    if (!RegExp(r'(피해자|신고자|상대방)').hasMatch(rawText)) '피해자/신고자 특정',
    if (!RegExp(r'(피의자|남편|아내|전남친|전여친|상대방)').hasMatch(rawText)) '피의자 특정',
    if (!RegExp(r'(폭행|상해|위협|따라오|대기|도주|거부)').hasMatch(rawText)) '구체 행위',
    if (!RegExp(r'(칼|낫|소주병|벽돌|가위|차량|둔기|흉기|위험물)').hasMatch(rawText) &&
        checklist.isWeaponUsed)
      '위험물 종류·소지/사용 방식',
    if (checklist.isIntoxicated &&
        !RegExp(r'(술|취해|주취|만취|소주|맥주|약물)').hasMatch(rawText))
      '주취·약물 상태 객관 기록',
  ];

  final basis = ruleResult.triggeredFilters.isEmpty
      ? '명시 키워드 없음. 수사관 수동 체크와 입력문 중심으로 보수 판단.'
      : ruleResult.triggeredFilters
          .map((t) => '${t.definition.displayName}(${t.matchedKeywords.join(", ")})')
          .join(', ');

  final riskLevel = factsMissing.length >= 3
      ? '주의'
      : factsMissing.isEmpty
          ? '양호'
          : '보완 필요';

  return '''
 - 판단 근거: $basis
 - 신뢰도 상태: $riskLevel
 - 추가 확인 필요: ${factsMissing.isEmpty ? '현재 입력 기준 필수 보완 항목 없음' : factsMissing.join(', ')}
 - 안전 장치: 입력문에 없는 시간·장소·인적사항은 자동 기재하지 않음
 - 책임 원칙: AI는 추천·초안만 제공하며 최종 법적 판단은 수사관이 확정
''';
}

/// 저장·보고에 바로 옮겨 적기 쉬운 사건 기록 문서 초안.
String buildCaseRecordDraft({
  required String rawText,
  required LawCheckList checklist,
  required RuleMatchResult ruleResult,
}) {
  final safeRawText = rawText.trim().isEmpty ? '[추후 보완]' : rawText.trim();
  final triggeredLabels = ruleResult.triggeredFilters.isEmpty
      ? '특이 법리 필터 자동 감지 없음'
      : ruleResult.triggeredFilters
          .map((t) => '${t.definition.displayName}: ${t.matchedKeywords.join(", ")}')
          .join('\n- ');

  final laws = <String>[
    if (checklist.isWeaponUsed)
      '폭력행위 등 처벌에 관한 법률 제3조, 형법 제261조/제258조의2 검토',
    if (checklist.isDomesticViolence)
      '가정폭력처벌법 임시조치 또는 스토킹처벌법 긴급응급조치/잠정조치 검토',
    if (checklist.isIntoxicated)
      '형법 제10조 제3항(원인에 있어서 자유로운 행위) 검토',
    if (checklist.isFleeing)
      '형사소송법 제211조 현행범 체포 요건 검토',
  ];

  return '''
1. 접수·인지 경위
 - 무전/진술 원문: $safeRawText

2. 주요 확인 사항
 - 자동 감지 법리:
 - $triggeredLabels
 - 흉기·위험물 사용: ${checklist.isWeaponUsed ? '확인 또는 의심' : '미확인'}
 - 관계성 폭력/스토킹: ${checklist.isDomesticViolence ? '확인 또는 의심' : '미확인'}
 - 주취·약물: ${checklist.isIntoxicated ? '확인 또는 의심' : '미확인'}
 - 도주·신분확인 거부: ${checklist.isFleeing ? '확인 또는 의심' : '미확인'}

3. 적용 법리 검토
 - ${laws.isEmpty ? '[추후 보완]' : laws.join('\n - ')}

4. 초동조치 및 보완 필요 사항
 - 피해자 안전 확보, 피의자 분리, 현장 증거 보전 여부 확인
 - 입력문에 없는 시간·장소·인적사항은 담당 수사관이 별도 확인 후 기재

5. 수사관 자기판단 확인
 - 본 문서는 AI 추천 초안이며, 최종 조치·서류 확정은 담당 수사관의 확인 및 자기판단에 따른다.
''';
}

// ---------------------------------------------------------------------------
// sLLM Lazy Loading 엔진 (7B~9B 4-bit 양자화 연동 지점)
// ---------------------------------------------------------------------------

/// 추론 벤치마크 결과.
class InferenceBenchmarkResult {
  const InferenceBenchmarkResult({
    required this.scenarioName,
    required this.promptTokens,
    required this.outputTokens,
    required this.elapsedMs,
    required this.tokensPerSec,
  });

  final String scenarioName;
  final int promptTokens;
  final int outputTokens;
  final int elapsedMs;
  final double tokensPerSec;

  @override
  String toString() =>
      '$scenarioName: ${tokensPerSec.toStringAsFixed(2)} tokens/sec '
      '(${outputTokens}tok / ${elapsedMs}ms)';
}

/// 온디바이스 sLLM 엔진 — 화면 진입 시 load, 이탈 시 dispose.
///
/// 실제 Mobile Whisper + 4-bit sLLM 바인딩은 [_loadWeights] / [_runInference]
/// 교체 지점에서 연동한다. 앱 초기 구동 시에는 가중치를 로드하지 않는다.
class SgpAgentEngine {
  List<int>? _modelWeights;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// 화면 진입 시 호출 — RAM에 모델 적재 (Lazy Loading).
  Future<void> loadModel() async {
    if (_isLoaded) return;
    await _loadWeights();
    _isLoaded = true;
  }

  /// 화면 이탈 시 호출 — RAM 점유 즉시 해제.
  void dispose() {
    _modelWeights = null;
    _isLoaded = false;
  }

  /// 정형 프롬프트 기반 추론 (3단계 파이프라인).
  Future<InferencePipelineResult> runPipeline({
    required String rawText,
    required LawCheckList checklist,
  }) async {
    if (!_isLoaded) {
      await loadModel();
    }
    final ruleResult = matchLawFilters(rawText);
    final merged = mergeChecklists(checklist, ruleResult.suggestedChecklist);
    final prompt = buildPipelinePrompt(
      rawText: rawText,
      checklist: merged,
      ruleResult: ruleResult,
    );
    final advanced = runAdvancedAnalysis(
      rawText: rawText,
      checklist: merged,
      ruleResult: ruleResult,
    );
    final output = await _runInference(
      prompt,
      rawText: rawText,
      checklist: merged,
      ruleResult: ruleResult,
      advanced: advanced,
    );
    return InferencePipelineResult(
      ruleResult: ruleResult,
      mergedChecklist: merged,
      prompt: prompt,
      output: output,
      advancedAnalysis: advanced,
    );
  }

  /// 정형 프롬프트 기반 추론 (오프라인 전용).
  Future<String> infer({
    required String rawText,
    required LawCheckList checklist,
  }) async {
    final result = await runPipeline(rawText: rawText, checklist: checklist);
    return result.output;
  }

  /// 주취폭행·스토킹 가상 시나리오 벤치마크.
  Future<InferenceBenchmarkResult> runBenchmark(String scenarioName) async {
    if (!_isLoaded) await loadModel();

    final scenario = _benchmarkScenarios[scenarioName];
    if (scenario == null) {
      throw ArgumentError('Unknown scenario: $scenarioName');
    }

    final rules = matchLawFilters(scenario.rawText);
    final merged = mergeChecklists(scenario.checklist, rules.suggestedChecklist);
    final prompt = buildPipelinePrompt(
      rawText: scenario.rawText,
      checklist: merged,
      ruleResult: rules,
    );

    final advanced = runAdvancedAnalysis(
      rawText: scenario.rawText,
      checklist: merged,
      ruleResult: rules,
    );

    final sw = Stopwatch()..start();
    final output = await _runInference(
      prompt,
      rawText: scenario.rawText,
      checklist: merged,
      ruleResult: rules,
      advanced: advanced,
    );
    sw.stop();

    final promptTokens = _estimateTokens(prompt);
    final outputTokens = _estimateTokens(output);
    final elapsedMs = sw.elapsedMilliseconds.clamp(1, 1 << 30);
    final tokensPerSec = outputTokens / (elapsedMs / 1000.0);

    return InferenceBenchmarkResult(
      scenarioName: scenarioName,
      promptTokens: promptTokens,
      outputTokens: outputTokens,
      elapsedMs: elapsedMs,
      tokensPerSec: tokensPerSec,
    );
  }

  Future<void> _loadWeights() async {
    final native = await SgpNativeBridge.loadSllmModel();
    if (native.loaded && !native.useFallback) {
      _modelWeights = const [1];
      return;
    }
    // 네이티브 sLLM 미연동 시 규칙·CoT 폴백 엔진 활성화 마커
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _modelWeights = List<int>.filled(512 * 1024, 0);
  }

  Future<String> _runInference(
    String prompt, {
    required String rawText,
    required LawCheckList checklist,
    required RuleMatchResult ruleResult,
    required SgpAdvancedAnalysis advanced,
  }) async {
    if (_modelWeights == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }

    final native = await SgpNativeBridge.runSllmInference(prompt);
    if (!native.useFallback && native.text != null && native.text!.trim().isNotEmpty) {
      return native.text!;
    }

    // Dart 온디바이스 폴백 (규칙 매핑 + 구조화 출력)
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return generateStructuredOutput(
      rawText: rawText,
      checklist: checklist,
      ruleResult: ruleResult,
      advanced: advanced,
    );
  }

  int _estimateTokens(String text) => (text.length / 2.5).ceil();
}

class _BenchmarkScenario {
  const _BenchmarkScenario({required this.rawText, required this.checklist});
  final String rawText;
  final LawCheckList checklist;
}

const Map<String, _BenchmarkScenario> _benchmarkScenarios = {
  '주취폭행': _BenchmarkScenario(
    rawText: '112 신고. 피해자 남편이 술 취한 상태에서 주먹으로 얼굴 폭행. '
        '피해자가 가정폭력 신고 의사 밝힘. 피의자 현장에서 도주 시도.',
    checklist: LawCheckList(
      isDomesticViolence: true,
      isIntoxicated: true,
      isFleeing: true,
    ),
  ),
  '스토킹': _BenchmarkScenario(
    rawText: '피해자 신고. 전 남친이 2주간 30회 이상 전화·문자. '
        '피해자 거주지 앞에서 대기 목격. 스토킹 신고 의사 확인.',
    checklist: LawCheckList(
      isDomesticViolence: true,
      isFleeing: false,
    ),
  ),
};

/// 로컬 저장용 조서 레코드.
class AgentRecord {
  const AgentRecord({
    required this.id,
    required this.createdAt,
    required this.rawText,
    required this.checklist,
    required this.prompt,
    required this.output,
    required this.selfJudgmentConfirmed,
    this.advancedAnalysis,
    this.procedureTimeline,
    this.quantumLegalAnalysis,
  });

  final String id;
  final DateTime createdAt;
  final String rawText;
  final LawCheckList checklist;
  final String prompt;
  final String output;
  final bool selfJudgmentConfirmed;

  /// SGP-Agent Pro 고도화 분석 (선택).
  final Map<String, dynamic>? advancedAnalysis;

  /// 사법 절차 타임테이블 (선택).
  final Map<String, dynamic>? procedureTimeline;

  /// 양자적 법률 비교 결과 (선택).
  final Map<String, dynamic>? quantumLegalAnalysis;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'rawText': rawText,
        'checklist': checklist.toJson(),
        'prompt': prompt,
        'output': output,
        'selfJudgmentConfirmed': selfJudgmentConfirmed,
        if (advancedAnalysis != null) 'advancedAnalysis': advancedAnalysis,
        if (procedureTimeline != null) 'procedureTimeline': procedureTimeline,
        if (quantumLegalAnalysis != null) 'quantumLegalAnalysis': quantumLegalAnalysis,
      };
}
