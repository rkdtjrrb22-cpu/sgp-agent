/// S11 — 3대 민생법령 KG Shield 분기·절차 제어 엔진.
///
/// 교통사고처리특례법(12대 중과실·공소권), 스토킹처벌법(지속성·잠정조치 타임라인),
/// 소년법(연령별 판정·소년부 송치)을 온톨로지 노드에 연계해 절차를 제어한다.
library;

/// 대상 법령 도메인.
enum StatuteDomain {
  trafficAccident,
  stalking,
  juvenile,
  none,
}

// ---------------------------------------------------------------------------
// 교통사고처리특례법 — 12대 중과실·공소권 분기
// ---------------------------------------------------------------------------

/// 교특법 12대 중과실 항목.
enum GrossNegligenceType {
  signalViolation('신호위반'),
  centerLineInvasion('중앙선 침범'),
  speeding('제한속도 20km 초과'),
  overtakingViolation('앞지르기 방법 위반'),
  railCrossing('철길건널목 위반'),
  crosswalk('횡단보도 보행자 보호의무 위반'),
  unlicensed('무면허 운전'),
  drunkDriving('음주운전'),
  sidewalkInvasion('보도 침범'),
  doorOpen('승객 추락방지 위반'),
  schoolZone('어린이보호구역 위반'),
  cargoFall('화물 낙하방지 위반');

  const GrossNegligenceType(this.label);
  final String label;
}

/// 교특법 처리 분기.
enum TrafficDisposition {
  /// 공소권 없음 (종합보험 + 12대 중과실 아님).
  noProsecution,

  /// 형사 입건 (12대 중과실 또는 뺑소니·사망).
  criminalCharge,
}

class TrafficAccidentResult {
  const TrafficAccidentResult({
    required this.grossNegligence,
    required this.disposition,
    required this.hasComprehensiveInsurance,
    required this.rationale,
    required this.ontologyNodes,
  });

  final List<GrossNegligenceType> grossNegligence;
  final TrafficDisposition disposition;
  final bool hasComprehensiveInsurance;
  final String rationale;
  final List<String> ontologyNodes;

  bool get isGrossNegligence => grossNegligence.isNotEmpty;
  bool get isCriminal => disposition == TrafficDisposition.criminalCharge;
}

// ---------------------------------------------------------------------------
// 스토킹처벌법 — 지속성·반복성 + 조치 타임라인
// ---------------------------------------------------------------------------

/// 스토킹 조치 단계.
enum StalkingMeasureStage {
  emergency('응급조치'),
  urgentTemporary('긴급응급조치'),
  provisional('잠정조치'),
  provisionalDetention('잠정조치 제4호(유치장 유치)');

  const StalkingMeasureStage(this.label);
  final String label;
}

class StalkingResult {
  const StalkingResult({
    required this.persistenceMet,
    required this.repetitionCount,
    required this.recommendedStage,
    required this.rationale,
    required this.ontologyNodes,
  });

  /// 지속성·반복성 요건 충족.
  final bool persistenceMet;
  final int repetitionCount;
  final StalkingMeasureStage recommendedStage;
  final String rationale;
  final List<String> ontologyNodes;

  bool get isStalkingCrime => persistenceMet;
}

// ---------------------------------------------------------------------------
// 소년법 — 연령별 판정·소년부 송치
// ---------------------------------------------------------------------------

/// 소년 연령 구분.
enum JuvenileCategory {
  /// 10세 미만 — 형사·보호처분 대상 아님.
  beombeop('범법소년', 0, 9),

  /// 10세 이상 14세 미만 — 촉법소년.
  chokbeop('촉법소년', 10, 13),

  /// 14세 이상 19세 미만 — 범죄소년.
  crimeJuvenile('범죄소년', 14, 18),

  /// 19세 이상 — 성인.
  adult('성인', 19, 999);

  const JuvenileCategory(this.label, this.minAge, this.maxAge);
  final String label;
  final int minAge;
  final int maxAge;
}

class JuvenileResult {
  const JuvenileResult({
    required this.age,
    required this.category,
    required this.requiresFamilyCourtTransfer,
    required this.criminalPunishable,
    required this.rationale,
    required this.ontologyNodes,
  });

  final int age;
  final JuvenileCategory category;

  /// 소년부(가정법원) 송치 필요.
  final bool requiresFamilyCourtTransfer;

  /// 형사처벌 가능.
  final bool criminalPunishable;

  final String rationale;
  final List<String> ontologyNodes;
}

abstract final class SgpStatuteDomainEngine {
  static final _stalkingKw = RegExp(r'(스토킹|따라다|미행|감시|찾아와|기다리|접근|반복.*연락|반복.*전화|계속.*문자)');
  static final _trafficKw = RegExp(r'(교통사고|추돌|접촉사고|차량|운전|충돌|들이받)');
  static final _juvenileKw = RegExp(r'(소년|미성년|학생|촉법|청소년|중학생|고등학생|초등학생)');

  static final _grossNegligencePatterns = <GrossNegligenceType, RegExp>{
    GrossNegligenceType.signalViolation: RegExp(r'(신호위반|신호\s*무시|빨간불|적신호)'),
    GrossNegligenceType.centerLineInvasion: RegExp(r'(중앙선\s*침범|중앙선\s*넘)'),
    GrossNegligenceType.speeding: RegExp(r'(과속|제한속도\s*초과|20km\s*초과|속도위반)'),
    GrossNegligenceType.overtakingViolation: RegExp(r'(앞지르기|추월\s*위반)'),
    GrossNegligenceType.railCrossing: RegExp(r'(철길|건널목)'),
    GrossNegligenceType.crosswalk: RegExp(r'(횡단보도|보행자\s*보호)'),
    GrossNegligenceType.unlicensed: RegExp(r'(무면허|면허\s*없)'),
    GrossNegligenceType.drunkDriving: RegExp(r'(음주운전|음주\s*상태|주취\s*운전|만취\s*운전)'),
    GrossNegligenceType.sidewalkInvasion: RegExp(r'(보도\s*침범|인도\s*침범|인도로\s*돌진)'),
    GrossNegligenceType.doorOpen: RegExp(r'(승객\s*추락|문\s*열)'),
    GrossNegligenceType.schoolZone: RegExp(r'(어린이보호구역|스쿨존)'),
    GrossNegligenceType.cargoFall: RegExp(r'(화물\s*낙하|적재물\s*낙하)'),
  };

  /// 도메인 자동 감지.
  static StatuteDomain detectDomain(String text) {
    final t = text.trim();
    if (_trafficKw.hasMatch(t)) return StatuteDomain.trafficAccident;
    if (_stalkingKw.hasMatch(t)) return StatuteDomain.stalking;
    if (_juvenileKw.hasMatch(t)) return StatuteDomain.juvenile;
    return StatuteDomain.none;
  }

  /// 교특법 12대 중과실·공소권 분기 추론.
  static TrafficAccidentResult analyzeTraffic(
    String text, {
    bool? hasComprehensiveInsurance,
  }) {
    final t = text.trim();
    final gross = <GrossNegligenceType>[];
    for (final entry in _grossNegligencePatterns.entries) {
      if (entry.value.hasMatch(t)) gross.add(entry.key);
    }

    final hitRun = RegExp(r'(뺑소니|도주|도망|구호조치\s*없)').hasMatch(t);
    final fatal = RegExp(r'(사망|숨진|사망사고)').hasMatch(t);
    final insured = hasComprehensiveInsurance ??
        RegExp(r'(종합보험|보험\s*가입|합의)').hasMatch(t);

    final nodes = <String>['KR-LAW-TSA'];
    TrafficDisposition disposition;
    String rationale;

    if (gross.isNotEmpty || hitRun || fatal) {
      disposition = TrafficDisposition.criminalCharge;
      nodes.add('KR-TSA-12-GROSS');
      final reasons = <String>[
        if (gross.isNotEmpty) '12대 중과실(${gross.map((g) => g.label).join(", ")})',
        if (hitRun) '뺑소니(도주치상)',
        if (fatal) '사망사고',
      ];
      rationale =
          '${reasons.join(" · ")} — 교특법 제3조 제2항에 따라 종합보험 가입·합의와 무관하게 형사 입건.';
    } else if (insured) {
      disposition = TrafficDisposition.noProsecution;
      rationale =
          '종합보험 가입 + 12대 중과실 미해당 — 교특법 제4조 공소권 없음(불입건) 처리.';
    } else {
      disposition = TrafficDisposition.criminalCharge;
      rationale = '종합보험 미가입 — 피해자 합의 여부에 따라 공소권 판단, 미합의 시 형사 입건.';
    }

    return TrafficAccidentResult(
      grossNegligence: gross,
      disposition: disposition,
      hasComprehensiveInsurance: insured,
      rationale: rationale,
      ontologyNodes: nodes,
    );
  }

  /// 스토킹 지속성·반복성 + 조치 단계 추론.
  static StalkingResult analyzeStalking(
    String text, {
    int? explicitRepetitionCount,
  }) {
    final t = text.trim();
    var count = explicitRepetitionCount ?? 0;
    if (explicitRepetitionCount == null) {
      count = _stalkingKw.allMatches(t).length;
      if (RegExp(r'(계속|지속|반복|매일|여러\s*번|수십\s*번|자꾸)').hasMatch(t)) {
        count += 2;
      }
    }

    final persistenceMet = count >= 2;
    final danger = RegExp(r'(흉기|칼|폭행|협박|살해|해치|감금|주거\s*침입)').hasMatch(t);
    final escalating = RegExp(r'(재발|또\s*찾아|다시\s*접근|불응|무시하고)').hasMatch(t);

    final nodes = <String>['KR-LAW-STALKING'];
    StalkingMeasureStage stage;
    String rationale;

    if (!persistenceMet) {
      stage = StalkingMeasureStage.emergency;
      nodes.add('KR-STALK-EMERGENCY');
      rationale = '일회성 접촉으로 지속성·반복성 미충족 — 응급조치(접근금지)로 대응, 잠정조치 신청 시 기각 우려.';
    } else if (danger) {
      stage = StalkingMeasureStage.provisionalDetention;
      nodes.addAll(['KR-STALK-PERSISTENCE', 'KR-STALK-PROVISIONAL']);
      rationale =
          '지속·반복 + 흉기·폭력 등 위해 우려 — 잠정조치 제4호(유치장 유치) 신청 검토.';
    } else if (escalating) {
      stage = StalkingMeasureStage.provisional;
      nodes.addAll(['KR-STALK-PERSISTENCE', 'KR-STALK-PROVISIONAL']);
      rationale = '반복성 + 재발·불응 정황 — 잠정조치(접근금지·전기통신 이용 금지) 신청.';
    } else {
      stage = StalkingMeasureStage.urgentTemporary;
      nodes.addAll(['KR-STALK-PERSISTENCE', 'KR-STALK-EMERGENCY']);
      rationale = '지속성·반복성 충족 — 긴급응급조치(접근금지·통신금지) 후 잠정조치 신청 준비.';
    }

    return StalkingResult(
      persistenceMet: persistenceMet,
      repetitionCount: count,
      recommendedStage: stage,
      rationale: rationale,
      ontologyNodes: nodes,
    );
  }

  /// 소년 연령별 판정·소년부 송치 추론.
  static JuvenileResult analyzeJuvenile(int age) {
    final category = categorize(age);
    bool transfer;
    bool punishable;
    String rationale;
    final nodes = <String>['KR-LAW-JUVENILE'];

    switch (category) {
      case JuvenileCategory.beombeop:
        transfer = false;
        punishable = false;
        nodes.add('KR-JUV-BEOMBEOP');
        rationale = '만 $age세 범법소년(10세 미만) — 형사·보호처분 대상 아님. 보호자 인계·복지 연계.';
        break;
      case JuvenileCategory.chokbeop:
        transfer = true;
        punishable = false;
        nodes.addAll(['KR-JUV-CHOKBEOP', 'KR-JUV-PROTECTIVE-ORDER']);
        rationale =
            '만 $age세 촉법소년(10~13세) — 형사책임 없음. 경찰서장이 소년부(가정법원) 직접 송치, 보호처분(1~10호) 검토.';
        break;
      case JuvenileCategory.crimeJuvenile:
        transfer = true;
        punishable = true;
        nodes.addAll(['KR-JUV-CRIMINAL', 'KR-JUV-PROTECTIVE-ORDER']);
        rationale =
            '만 $age세 범죄소년(14~18세) — 검사 선의주의에 따라 형사처벌 또는 소년부 송치 결정.';
        break;
      case JuvenileCategory.adult:
        transfer = false;
        punishable = true;
        rationale = '만 $age세 성인 — 소년법 적용 대상 아님. 일반 형사절차 진행.';
        break;
    }

    return JuvenileResult(
      age: age,
      category: category,
      requiresFamilyCourtTransfer: transfer,
      criminalPunishable: punishable,
      rationale: rationale,
      ontologyNodes: nodes,
    );
  }

  static JuvenileCategory categorize(int age) {
    if (age < 10) return JuvenileCategory.beombeop;
    if (age < 14) return JuvenileCategory.chokbeop;
    if (age < 19) return JuvenileCategory.crimeJuvenile;
    return JuvenileCategory.adult;
  }

  /// 텍스트에서 연령 추출 (예: "14세", "만 13살").
  static int? extractAge(String text) {
    final m = RegExp(r'(?:만\s*)?(\d{1,2})\s*(?:세|살)').firstMatch(text);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }
}
