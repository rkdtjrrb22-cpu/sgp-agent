/// 헌법 제37조 제2항(과잉금지) · 비례의 원칙 기반 5단계 물리력 검증 엔진.
library;

import 'sgp_legal_ontology_session.dart';

/// 대상자 저항 단계 (경찰청 표준 5단계).
enum ResistanceStage {
  compliance(1, '순응·협조'),
  passiveResistance(2, '소극적 저항'),
  activeResistance(3, '적극적 저항'),
  violentResistance(4, '폭력적 저항'),
  lethalResistance(5, '치명적 저항');

  const ResistanceStage(this.stageNumber, this.label);

  final int stageNumber;
  final String label;
}

/// 경찰 대응 물리력 단계.
enum PoliceForceTier {
  verbalControl(1, '언어적 통제', '지시·통고'),
  contactControl(2, '접촉성 통제', '신체적 리드·잡아끌기'),
  lowRiskForce(3, '저위험 물리력', '관절꺾기·분사기'),
  mediumRiskForce(4, '중위험 물리력', '경찰봉·전자충격기'),
  highRiskForce(5, '고위험 물리력', '권총 등 치명적 물리력');

  const PoliceForceTier(this.stageNumber, this.label, this.summary);

  final int stageNumber;
  final String label;
  final String summary;
}

/// 헌법적 검증 원칙 유형.
enum ConstitutionalPrinciple {
  minimumHarm('최소침해성의 원칙', '헌법상 최소침해성 충족'),
  proportionality('적합성 및 상당성의 원칙', '공익·침해법익 균형 검토'),
  necessityLimit('헌법 제37조 제2항', '과잉금지·최후 수단성');

  const ConstitutionalPrinciple(this.title, this.badgeLabel);

  final String title;
  final String badgeLabel;
}

/// 비례성 평가 결과 — [isExcessive]가 과잉 물리력(IsExcessive) 플래그.
class ConstitutionalForceAssessment {
  const ConstitutionalForceAssessment({
    required this.resistanceStage,
    required this.forceTier,
    required this.isExcessive,
    required this.principle,
    required this.badgeLabel,
    required this.warningMessage,
    required this.constitutionalBasis,
    this.ontologyTripleCount = 0,
    this.ontologySource = 'uninitialized',
    this.requiresFullScreenAlert = false,
  });

  final ResistanceStage resistanceStage;
  final PoliceForceTier forceTier;
  final bool isExcessive;
  final ConstitutionalPrinciple principle;
  final String badgeLabel;
  final String warningMessage;
  final String constitutionalBasis;
  final int ontologyTripleCount;
  final String ontologySource;
  final bool requiresFullScreenAlert;

  /// 작업지시서 명시 필드.
  bool get isExcessiveFlag => isExcessive;

  double get proportionalityScore {
    if (isExcessive) return 0;
    final gap = forceTier.stageNumber - resistanceStage.stageNumber;
    if (gap <= 0) return 1.0;
    return (1.0 - gap * 0.25).clamp(0.0, 1.0);
  }
}

abstract final class SgpConstitutionalForceEngine {
  static const constitutionNodeId = 'KR-CONST-001';
  static const policeDutyNodeId = 'KR-LAW-POLICE-DUTY';
  static const forceMatrixRootId = 'MANUAL-SGP-FORCE-MATRIX';

  static ResistanceStage? detectResistanceFromText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    if (_lethalKw.hasMatch(text)) return ResistanceStage.lethalResistance;
    if (_violentKw.hasMatch(text)) return ResistanceStage.violentResistance;
    if (_activeKw.hasMatch(text)) return ResistanceStage.activeResistance;
    if (_passiveKw.hasMatch(text)) return ResistanceStage.passiveResistance;
    if (_complianceKw.hasMatch(text)) return ResistanceStage.compliance;
    return null;
  }

  static PoliceForceTier? detectForceTierFromText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    if (_firearmKw.hasMatch(text)) return PoliceForceTier.highRiskForce;
    if (_taserKw.hasMatch(text)) return PoliceForceTier.mediumRiskForce;
    if (_batonKw.hasMatch(text)) return PoliceForceTier.mediumRiskForce;
    if (_sprayKw.hasMatch(text) || _jointKw.hasMatch(text)) {
      return PoliceForceTier.lowRiskForce;
    }
    if (_contactKw.hasMatch(text)) return PoliceForceTier.contactControl;
    if (_verbalKw.hasMatch(text)) return PoliceForceTier.verbalControl;
    return null;
  }

  static ConstitutionalForceAssessment assess({
    required ResistanceStage resistanceStage,
    required PoliceForceTier forceTier,
  }) {
    final isExcessive = forceTier.stageNumber > resistanceStage.stageNumber;
    final principle = _principleFor(resistanceStage.stageNumber);
    final badge = _badgeFor(resistanceStage, forceTier, isExcessive, principle);
    final warning = _warningFor(resistanceStage, forceTier, isExcessive);
    final basis = _constitutionalBasis(resistanceStage, isExcessive);

    return ConstitutionalForceAssessment(
      resistanceStage: resistanceStage,
      forceTier: forceTier,
      isExcessive: isExcessive,
      principle: principle,
      badgeLabel: badge,
      warningMessage: warning,
      constitutionalBasis: basis,
      requiresFullScreenAlert:
          isExcessive || forceTier == PoliceForceTier.highRiskForce,
    );
  }

  /// SPO 온톨로지 세션 — 헌법(LV1) 우선 관계망과 연동.
  static ConstitutionalForceAssessment assessWithOntology({
    required ResistanceStage resistanceStage,
    required PoliceForceTier forceTier,
    SgpLegalOntologySession? ontologySession,
  }) {
    final base = assess(
      resistanceStage: resistanceStage,
      forceTier: forceTier,
    );
    final session = ontologySession ?? SgpLegalOntologySession.instance;
    if (!session.isLoaded) {
      return base;
    }

    final chainIds = [
      constitutionNodeId,
      policeDutyNodeId,
      forceMatrixRootId,
      'PF-STAGE-${resistanceStage.stageNumber}',
    ];
    final triples = session.graph?.triplesForChain(chainIds) ?? const [];
    var warning = base.warningMessage;
    if (base.isExcessive) {
      warning =
          '【헌법 우선】 LV8 매뉴얼보다 헌법(LV1) 과잉금지 원칙 발동 — '
          'IsExcessive=true. $warning';
    }

    return ConstitutionalForceAssessment(
      resistanceStage: base.resistanceStage,
      forceTier: base.forceTier,
      isExcessive: base.isExcessive,
      principle: base.principle,
      badgeLabel: base.badgeLabel,
      warningMessage: warning,
      constitutionalBasis: base.constitutionalBasis,
      ontologyTripleCount: triples.length,
      ontologySource: session.source,
      requiresFullScreenAlert: base.requiresFullScreenAlert,
    );
  }

  static ConstitutionalPrinciple _principleFor(int stage) {
    if (stage <= 2) return ConstitutionalPrinciple.minimumHarm;
    if (stage <= 4) return ConstitutionalPrinciple.proportionality;
    return ConstitutionalPrinciple.necessityLimit;
  }

  static String _badgeFor(
    ResistanceStage resistance,
    PoliceForceTier force,
    bool isExcessive,
    ConstitutionalPrinciple principle,
  ) {
    if (isExcessive) return '🚨 과잉 물리력 경고';
    if (force == PoliceForceTier.highRiskForce) return '🚨 헌법 최고 경고';
    if (resistance.stageNumber >= 3) return '⚠️ 비례성 경고';
    if (resistance.stageNumber == 2) return '적법 통제 배지';
    return principle.badgeLabel;
  }

  static String _warningFor(
    ResistanceStage resistance,
    PoliceForceTier force,
    bool isExcessive,
  ) {
    if (isExcessive) {
      return '${resistance.label}(${resistance.stageNumber}단계) 대상에 '
          '${force.label}(${force.stageNumber}단계) 적용 — '
          '과잉금지 원칙 위반 가능성';
    }
    return switch (force) {
      PoliceForceTier.highRiskForce =>
        '권총 사용은 최후의 수단. 헌법상 과잉금지 원칙·정당방위/긴급피난 요건 검증',
      PoliceForceTier.mediumRiskForce =>
        '물리력 장구 사용 시 과잉금지 원칙 주의',
      PoliceForceTier.lowRiskForce =>
        '적합성·상당성 원칙 — 저위험 수단 우선',
      PoliceForceTier.contactControl => '물리적 접촉 경계 안내',
      PoliceForceTier.verbalControl => '헌법상 최소침해성 충족',
    };
  }

  static String _constitutionalBasis(ResistanceStage resistance, bool isExcessive) {
    if (isExcessive) {
      return '헌법 제37조 제2항 (과잉금지의 원칙) · 비례의 원칙 — '
          '하위 매뉴얼(LV8) < 최상위 헌법(LV1) 우선';
    }
    return switch (resistance.stageNumber) {
      1 || 2 => '헌법 제37조 · 최소침해성의 원칙 / 경찰관 직무집행법 제8조',
      3 || 4 => '비례의 원칙 · 경찰관 직무집행법 제8조·제10조',
      _ => '헌법 제37조 제2항 · 형법 제21조·제22조 (정당방위·긴급피난)',
    };
  }

  static final _complianceKw = RegExp(r'(순응|협조|협력|따름|지시.*(따|준)|저항\s*없)');
  static final _passiveKw = RegExp(r'(소극.*저항|손.*뒤|몸.*돌|말로만\s*거부|잡아.?끌)');
  static final _activeKw = RegExp(r'(적극.*저항|밀침|발로\s*차|도주\s*시도|장애물\s*던)');
  static final _violentKw = RegExp(r'(폭력.*저항|폭행|위협|흉기|경찰.*공격|테이저\s*필요)');
  static final _lethalKw = RegExp(r'(치명.*저항|총기|권총|생명\s*위협|살해\s*위협)');

  static final _verbalKw = RegExp(r'(언어.*통제|지시|통고|구두\s*경고)');
  static final _contactKw = RegExp(r'(접촉.*통제|리드|잡아.?끌|유도)');
  static final _jointKw = RegExp(r'(관절|꺾|압박\s*점)');
  static final _sprayKw = RegExp(r'(분사|OC|스프레이|후추)');
  static final _batonKw = RegExp(r'(경찰봉|확장봉|봉\s*타격)');
  static final _taserKw = RegExp(r'(테이저|전자충격|Taser|충격기\s*발사)');
  static final _firearmKw = RegExp(r'(권총|총기\s*사용|발포|사격)');
}
