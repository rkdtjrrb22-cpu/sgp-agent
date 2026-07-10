part of 'sgp_agent_core.dart';

// ---------------------------------------------------------------------------
// 온디바이스 고도화 분석 결과 — 3대 혁신 엔진
// ---------------------------------------------------------------------------

/// 가·피해자 역할 구분 (UI 색상 매핑용).
enum PartyRole {
  aggressor,
  victim,
  unclear,
  mutualCombat,
}

/// 온디바이스 3대 혁신 엔진 통합 분석 결과.
class SgpAdvancedAnalysis {
  const SgpAdvancedAnalysis({
    required this.suspectVictimStatus,
    required this.prosecutionSuccessRate,
    required this.legalRisks,
    required this.evidentiaryActions,
    required this.proceduralAlerts,
    required this.primaryAggressor,
    required this.primaryVictim,
    required this.aggressorRole,
    required this.victimRole,
    required this.mutualCombatSuspected,
    required this.selfDefenseLikelihood,
    required this.hasCriticalProceduralAlert,
    required this.preemptiveAttackDetected,
    required this.defenseActDetected,
    required this.weaponDominanceHolder,
    required this.appliedPrecedentIds,
  });

  /// 가·피해자 분석 결론 및 판단 근거 (한글 서술).
  final String suspectVictimStatus;

  /// 예상 공소유지 성공률 0.0 ~ 100.0.
  final double prosecutionSuccessRate;

  final List<String> legalRisks;
  final List<String> evidentiaryActions;
  final List<String> proceduralAlerts;

  /// UI Red — 실질적 공격 유발자 추정.
  final String primaryAggressor;

  /// UI Blue — 소극적 저항·피해자 추정.
  final String primaryVictim;

  final PartyRole aggressorRole;
  final PartyRole victimRole;
  final bool mutualCombatSuspected;

  /// 정당방위 성립 가능성 0.0 ~ 1.0.
  final double selfDefenseLikelihood;

  /// 위수증·절차 하자 등 즉시 대응 필요.
  final bool hasCriticalProceduralAlert;

  /// Dual-Aspect: 선제 공격 정황 감지.
  final bool preemptiveAttackDetected;

  /// Dual-Aspect: 방어 행위(정당방위 요건) 감지.
  final bool defenseActDetected;

  /// Dual-Aspect: 흉기 소지·사용 주도권 추정 당사자.
  final String weaponDominanceHolder;

  /// Predictive Jurisprudence: 적용된 판례 ID 목록.
  final List<String> appliedPrecedentIds;

  factory SgpAdvancedAnalysis.fromJson(Map<String, dynamic> json) {
    return SgpAdvancedAnalysis(
      suspectVictimStatus: json['suspectVictimStatus'] as String? ?? '',
      prosecutionSuccessRate: (json['prosecutionSuccessRate'] as num?)?.toDouble() ?? 0,
      legalRisks: (json['legalRisks'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      evidentiaryActions:
          (json['evidentiaryActions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      proceduralAlerts:
          (json['proceduralAlerts'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      primaryAggressor: json['primaryAggressor'] as String? ?? '',
      primaryVictim: json['primaryVictim'] as String? ?? '',
      aggressorRole: PartyRole.values.byName(json['aggressorRole'] as String? ?? 'unclear'),
      victimRole: PartyRole.values.byName(json['victimRole'] as String? ?? 'unclear'),
      mutualCombatSuspected: json['mutualCombatSuspected'] as bool? ?? false,
      selfDefenseLikelihood: (json['selfDefenseLikelihood'] as num?)?.toDouble() ?? 0,
      hasCriticalProceduralAlert: json['hasCriticalProceduralAlert'] as bool? ?? false,
      preemptiveAttackDetected: json['preemptiveAttackDetected'] as bool? ?? false,
      defenseActDetected: json['defenseActDetected'] as bool? ?? false,
      weaponDominanceHolder: json['weaponDominanceHolder'] as String? ?? '',
      appliedPrecedentIds:
          (json['appliedPrecedentIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'suspectVictimStatus': suspectVictimStatus,
        'prosecutionSuccessRate': prosecutionSuccessRate,
        'legalRisks': legalRisks,
        'evidentiaryActions': evidentiaryActions,
        'proceduralAlerts': proceduralAlerts,
        'primaryAggressor': primaryAggressor,
        'primaryVictim': primaryVictim,
        'aggressorRole': aggressorRole.name,
        'victimRole': victimRole.name,
        'mutualCombatSuspected': mutualCombatSuspected,
        'selfDefenseLikelihood': selfDefenseLikelihood,
        'hasCriticalProceduralAlert': hasCriticalProceduralAlert,
        'preemptiveAttackDetected': preemptiveAttackDetected,
        'defenseActDetected': defenseActDetected,
        'weaponDominanceHolder': weaponDominanceHolder,
        'appliedPrecedentIds': appliedPrecedentIds,
      };
}

final _aggressorKw = RegExp(
  r'(선제|먼저|시비|덮치|때리|폭행|상해|위협|들고|휘두르|꺼내|소지|주먹|발로|밀치)',
);
final _victimKw = RegExp(
  r'(피해자|신고|울|겁|무서|쫓기|맞|피하|방어|막으|저항|도망|신고 의사)',
);
final _mutualKw = RegExp(r'(쌍방|서로|맞붙|주고받|끌어당|잡아당)');
final _defenseKw = RegExp(r'(막으려|방어|정당|밀치는 것을 막|손을 잡|쫓겨|위협받|피하려)');
final _provokeKw = RegExp(r'(선제|먼저|시비|욕설|모욕|도발|덮치|밀치)');
final _weaponDomKw = RegExp(r'(들고|휘두르|꺼내|소지|칼|흉기|소주병|둔기)');

/// 3대 혁신 엔진 통합 분석.
SgpAdvancedAnalysis runAdvancedAnalysis({
  required String rawText,
  required LawCheckList checklist,
  required RuleMatchResult ruleResult,
}) {
  final text = rawText.trim();
  final precedents = matchPrecedents(
    text: text,
    isDomesticViolence: checklist.isDomesticViolence,
    isIntoxicated: checklist.isIntoxicated,
    isWeaponUsed: checklist.isWeaponUsed,
  );
  final dual = _analyzeDualAspect(text, checklist, precedents);
  final procedural = _analyzeProceduralSafeguards(text, checklist);
  final prosecution = _predictProsecutionSuccess(
    text: text,
    checklist: checklist,
    dual: dual,
    precedents: precedents,
    proceduralRiskCount: procedural.where(_isCriticalAlert).length,
  );

  final legalRisks = <String>[
    ...dual.risks,
    ...precedents.map((p) => '판례 ${p.id}: ${p.holding}'),
    ...procedural.where(_isCriticalAlert).map((a) => '절차 리스크: $a'),
    if (checklist.isIntoxicated)
      '심신미약·자의적 음주 주장 소지 (형법 제10조3항 대비 필요)',
    if (dual.mutualCombatSuspected)
      '쌍방 폭행 외견 — 실질 가해자 오분류 시 무혐의·공소기각 위험',
    if (prosecution.rate < 45) '영장기각·불기소 소지 — 증거·진술 보강 시급',
    if (dual.preemptiveAttackDetected && dual.defenseActDetected)
      '선제공격·방어행위 교차 — 정당방위 4요건 정밀 대조 필수',
  ];

  final evidentiary = <String>[
    if (dual.mutualCombatSuspected)
      '선제 공격 시점·흉기 주도권을 CCTV·목격자·상처 부위로 교차 확인',
    if (dual.preemptiveAttackDetected)
      '선제 시비·도발 시점을 목격자·CCTV 타임스탬프로 고정',
    if (dual.defenseActDetected)
      '방어 행위의 상당성·침해 현재성을 현장 거리·도구 위치로 입증',
    if (checklist.isWeaponUsed)
      '흉기 확보 즉시 사진·지문·DNA 채취 (위수증 방지 절차 동시 기록)',
    if (checklist.isDomesticViolence)
      '피해자 별도 진술·신고 의사·상처 사진·병원 기록 확보',
    if (checklist.isIntoxicated)
      '피의자 주취 상태 객관 기록(체취·CCTV·목격) 및 고의성 입증 자료',
    '가·피해자 진술 녹화/녹음 시각·장소 메타데이터 보존',
    '현장 평면도·거리·도구 위치 스케치 또는 사진',
  ];

  final status = _buildSuspectVictimNarrative(dual, checklist);

  return SgpAdvancedAnalysis(
    suspectVictimStatus: status,
    prosecutionSuccessRate: prosecution.rate,
    legalRisks: legalRisks.toSet().toList(),
    evidentiaryActions: evidentiary.toSet().toList(),
    proceduralAlerts: procedural,
    primaryAggressor: dual.aggressorLabel,
    primaryVictim: dual.victimLabel,
    aggressorRole: dual.aggressorRole,
    victimRole: dual.victimRole,
    mutualCombatSuspected: dual.mutualCombatSuspected,
    selfDefenseLikelihood: dual.selfDefenseScore,
    hasCriticalProceduralAlert: procedural.any(_isCriticalAlert),
    preemptiveAttackDetected: dual.preemptiveAttackDetected,
    defenseActDetected: dual.defenseActDetected,
    weaponDominanceHolder: dual.weaponDominanceHolder,
    appliedPrecedentIds: precedents.map((p) => p.id).toList(),
  );
}

class _DualAspectResult {
  const _DualAspectResult({
    required this.aggressorLabel,
    required this.victimLabel,
    required this.aggressorRole,
    required this.victimRole,
    required this.mutualCombatSuspected,
    required this.selfDefenseScore,
    required this.aggressorScore,
    required this.victimScore,
    required this.risks,
    required this.preemptiveAttackDetected,
    required this.defenseActDetected,
    required this.weaponDominanceHolder,
  });

  final String aggressorLabel;
  final String victimLabel;
  final PartyRole aggressorRole;
  final PartyRole victimRole;
  final bool mutualCombatSuspected;
  final double selfDefenseScore;
  final int aggressorScore;
  final int victimScore;
  final List<String> risks;
  final bool preemptiveAttackDetected;
  final bool defenseActDetected;
  final String weaponDominanceHolder;
}

/// [엔진 1] Dual-Aspect Discrimination — 선제공격·방어·흉기 주도권 교차 분석.
_DualAspectResult _analyzeDualAspect(
  String text,
  LawCheckList checklist,
  List<PrecedentRef> precedents,
) {
  if (text.isEmpty) {
    return const _DualAspectResult(
      aggressorLabel: '미확인',
      victimLabel: '미확인',
      aggressorRole: PartyRole.unclear,
      victimRole: PartyRole.unclear,
      mutualCombatSuspected: false,
      selfDefenseScore: 0,
      aggressorScore: 0,
      victimScore: 0,
      risks: ['진술·무전 입력 없음 — 가·피해자 분리 불가'],
      preemptiveAttackDetected: false,
      defenseActDetected: false,
      weaponDominanceHolder: '미확인',
    );
  }

  final preemptive = _provokeKw.hasMatch(text);
  final defenseAct = _defenseKw.hasMatch(text);
  final weaponDom = checklist.isWeaponUsed && _weaponDomKw.hasMatch(text);

  var aggScore = 0;
  var vicScore = 0;
  if (_aggressorKw.hasMatch(text)) aggScore += 3;
  if (preemptive) aggScore += 4;
  if (_victimKw.hasMatch(text)) vicScore += 3;
  if (defenseAct) vicScore += 3;
  if (weaponDom && RegExp(r'(들고|휘두르|꺼내)').hasMatch(text)) aggScore += 3;
  if (RegExp(r'(신고|112)').hasMatch(text)) vicScore += 2;
  if (checklist.isDomesticViolence && RegExp(r'(남편|아내|전남친|전여친)').hasMatch(text)) {
    if (RegExp(r'(폭행|때리|상해)').hasMatch(text)) aggScore += 1;
    if (RegExp(r'(피해자|신고)').hasMatch(text)) vicScore += 2;
  }

  final mutual = _mutualKw.hasMatch(text) || (aggScore >= 3 && vicScore >= 3);
  final selfDefense = defenseAct && preemptive
      ? 0.72
      : defenseAct
          ? 0.52
          : 0.12;

  String weaponHolder = '미확인';
  if (weaponDom) {
    weaponHolder = aggScore >= vicScore
        ? '공격 정황 당사자(흉기 주도권 추정)'
        : '피해·방어 당사자 측 흉기 접촉 — 주도권 재확인 필요';
  } else if (checklist.isWeaponUsed) {
    weaponHolder = '흉기 사용 체크됨 — 소지·사용 주체 미상';
  }

  String aggressor = '미확인';
  String victim = '미확인';
  PartyRole aggRole = PartyRole.unclear;
  PartyRole vicRole = PartyRole.unclear;

  if (mutual && (aggScore - vicScore).abs() <= 1) {
    aggressor = preemptive
        ? '선제 공격 정황 — 실질 공격 유발자 추가 확인'
        : '쌍방 폭행 의심 — 실질 공격 유발자 추가 확인';
    victim = defenseAct
        ? '방어·피해 주장 당사자 — 정당방위 요건 대조 필요'
        : '상대 당사자 — 피해·방어 정황 대조 필요';
    aggRole = PartyRole.mutualCombat;
    vicRole = PartyRole.mutualCombat;
  } else if (aggScore > vicScore) {
    aggressor = _inferPartyLabel(text, isAggressor: true, preemptive: preemptive);
    victim = _inferPartyLabel(text, isAggressor: false, preemptive: false);
    aggRole = PartyRole.aggressor;
    vicRole = PartyRole.victim;
  } else if (vicScore > aggScore) {
    victim = _inferPartyLabel(text, isAggressor: false, preemptive: false);
    aggressor = _inferPartyLabel(text, isAggressor: true, preemptive: preemptive);
    vicRole = PartyRole.victim;
    aggRole = aggScore > 0 ? PartyRole.aggressor : PartyRole.unclear;
  }

  final dict = getPrecedentDictionary();
  final risks = <String>[
    if (mutual) dict.firstWhere((p) => p.id == 'SC_mutual_combat').holding,
    if (selfDefense > 0.4) dict.firstWhere((p) => p.id == 'SC_self_defense').holding,
    if (preemptive) dict.firstWhere((p) => p.id == 'SC_preemptive_attack').holding,
    if (weaponDom) dict.firstWhere((p) => p.id == 'SC_weapon_dominance').holding,
    if (aggScore == vicScore) '공격·방어 정황 동점 — 단순 쌍방 종결 금지',
    for (final p in precedents.where((p) => p.id == 'SC_dv_victim')) p.holding,
  ];

  return _DualAspectResult(
    aggressorLabel: aggressor,
    victimLabel: victim,
    aggressorRole: aggRole,
    victimRole: vicRole,
    mutualCombatSuspected: mutual,
    selfDefenseScore: selfDefense.clamp(0.0, 1.0),
    aggressorScore: aggScore,
    victimScore: vicScore,
    risks: risks.toSet().toList(),
    preemptiveAttackDetected: preemptive,
    defenseActDetected: defenseAct,
    weaponDominanceHolder: weaponHolder,
  );
}

String _inferPartyLabel(String text, {required bool isAggressor, required bool preemptive}) {
  if (RegExp(r'피해자').hasMatch(text) && !isAggressor) return '피해자(신고자)';
  if (RegExp(r'(남편|아내)').hasMatch(text)) {
    if (isAggressor && RegExp(r'(폭행|때리|술 취)').hasMatch(text)) {
      return preemptive ? '배우자(선제 공격·폭행 정황)' : '배우자(공격 정황)';
    }
    if (!isAggressor && RegExp(r'(피해|신고)').hasMatch(text)) return '배우자(피해·방어 정황)';
  }
  if (RegExp(r'(전남친|전여친|전 남친|전 여친)').hasMatch(text)) {
    return isAggressor ? '전 연인(추적·공격 의심)' : '전 연인 관계 피해자';
  }
  if (isAggressor && preemptive) return '실질 공격 유발자(선제 공격 추정)';
  return isAggressor ? '실질 공격 유발자(추정)' : '소극적 저항·피해자(추정)';
}

String _buildSuspectVictimNarrative(_DualAspectResult dual, LawCheckList checklist) {
  final buf = StringBuffer();
  if (dual.mutualCombatSuspected) {
    buf.write('【쌍방 폭행 방어】 외견상 상호 폭행. ');
    buf.write('선제 공격·흉기 주도권·피해 규모로 실질 가해자 구분. ');
  } else {
    buf.write('【가·피해자 정밀 분리】 ');
  }
  if (dual.preemptiveAttackDetected) buf.write('선제 공격 정황 감지. ');
  if (dual.defenseActDetected) buf.write('방어 행위(정당방위 검토) 감지. ');
  buf.write('공격 유발: ${dual.aggressorLabel}. ');
  buf.write('피해·방어: ${dual.victimLabel}. ');
  buf.write('흉기 주도권: ${dual.weaponDominanceHolder}. ');
  if (dual.selfDefenseScore >= 0.4) {
    buf.write('정당방위 검토 ${(dual.selfDefenseScore * 100).round()}% — ');
    buf.write('침해 현재성·부당성·방어의사·상당성 대법원 기준 대조. ');
  }
  if (checklist.isWeaponUsed) {
    buf.write('흉기 소지 주도권이 공격자 판단 핵심.');
  }
  return buf.toString().trim();
}

class _ProsecutionPrediction {
  const _ProsecutionPrediction(this.rate);
  final double rate;
}

/// [엔진 2] Predictive Jurisprudence — 판례 딕셔너리 기반 공소유지율.
_ProsecutionPrediction _predictProsecutionSuccess({
  required String text,
  required LawCheckList checklist,
  required _DualAspectResult dual,
  required List<PrecedentRef> precedents,
  required int proceduralRiskCount,
}) {
  var rate = 52.0;

  if (text.isNotEmpty) rate += 8;
  if (dual.aggressorScore > dual.victimScore + 1) rate += 12;
  if (dual.preemptiveAttackDetected && !dual.defenseActDetected) rate += 8;
  if (dual.defenseActDetected && dual.preemptiveAttackDetected) rate -= 10;
  if (dual.mutualCombatSuspected) rate -= 15;
  if (checklist.isWeaponUsed) rate += 8;
  if (checklist.isDomesticViolence && RegExp(r'신고').hasMatch(text)) rate += 10;
  if (checklist.isIntoxicated) rate -= 6;
  if (checklist.isFleeing) rate += 4;
  if (hasAmbiguousFacts(text)) rate -= 18;
  rate -= proceduralRiskCount * 12;
  rate -= dual.risks.length * 2;

  for (final p in precedents) {
    if (dual.selfDefenseScore > 0.5 && p.id == 'SC_self_defense') {
      rate -= p.factorPenalty;
    } else if (p.id == 'SC_dv_victim' || p.id == 'SC_preemptive_attack') {
      rate += p.factorBoost * 0.5;
    } else if (p.id == 'SC_illegal_evidence' || p.id == 'SC_warrantless_seizure') {
      rate -= p.factorPenalty * 0.4;
    }
  }

  return _ProsecutionPrediction(rate.clamp(5.0, 92.0));
}

/// [엔진 3] Procedural Safeguard — 위수증 실시간 방어망.
List<String> _analyzeProceduralSafeguards(String text, LawCheckList checklist) {
  final alerts = <String>[];

  if (checklist.isFleeing) {
    alerts.add(
      '【현행범 체포】 형소법 제211조 — 범행 명백성·도주 염려 문언화 후 체포',
    );
    alerts.add('【미란다】 체포 직후 지체 없이 고지 — 미고지 시 진술 증거능력 리스크');
  }

  if (RegExp(r'(임의동행|동행 요청|경찰서)').hasMatch(text)) {
    alerts.add('【임의동행】 강제가 아님을 명시·거부권 고지 — 위법 동행 전환 금지');
  }

  if (checklist.isWeaponUsed) {
    alerts.add(
      '【긴급압수】 형소법 제216조3항 — 범행 현장·현행범 흉기 압수 후 사후 영장 청구',
    );
    alerts.add('지금 즉시 압수 목록·담당자·시각을 기록하고 사진 채증하십시오');
  }

  if (checklist.isDomesticViolence) {
    alerts.add('【피해자 분리】 가정폭력 임시조치·긴급응급조치 통보 검토');
    alerts.add('피해자·가해자 동시 조사 시 교차 진술 오염 방지 — 별실 분리');
  }

  if (RegExp(r'(휴대폰|문자|카톡|녹음|영상|핸드폰)').hasMatch(text)) {
    alerts.add('【임의제출】 지금 즉시 임의제출 동의서를 받으십시오 — 위수증 방지');
    alerts.add('형소법 제216조 — 영장 없는 디지털 증거 압수 시 예외 요건 엄격 적용');
  }

  if (checklist.isIntoxicated) {
    alerts.add('【진술】 주취 상태 진술은 체조력·고지 시점 기록 후 확보');
  }

  final illegal = getPrecedentDictionary().firstWhere((p) => p.id == 'SC_illegal_evidence');
  alerts.add('【위수증 방어】 ${illegal.holding}');

  return alerts;
}

bool _isCriticalAlert(String alert) =>
    alert.contains('임의제출') ||
    alert.contains('미란다') ||
    alert.contains('긴급압수') ||
    alert.contains('위수증') ||
    alert.contains('영장');
