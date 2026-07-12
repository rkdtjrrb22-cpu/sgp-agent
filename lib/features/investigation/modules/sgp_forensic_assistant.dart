/// S13 — 변사자 발생 초동조치·KCSI 연계 과학수사 Assistant.
///
/// 형사소송법 제222조(변사자의 검시)에 따른 현장 통제·행정/사법 변사 분기·
/// KCSI 감식 전 현장 무결성 통제를 수행한다.
library;

/// 변사 처리 경로.
enum DeathCaseRoute {
  /// 범죄 혐의 없음 — 행정 변사(유족·장례 인도).
  administrativeHandover('행정 변사(인도)'),

  /// 범죄 혐의점 — 사법 변사(부검 영장·검사 지휘).
  judicialAutopsy('사법 변사(부검·검사 지휘)');

  const DeathCaseRoute(this.label);
  final String label;
}

/// 현장 무결성 상태.
enum SceneIntegrityStatus {
  intact,
  policeLineMissing,
  evidenceTamperingRisk,
}

/// 검시 진행 단계.
enum ForensicPhase {
  sceneControl,
  kcsiNotification,
  examination,
  bodyHandover,
}

class ForensicAssistantResult {
  const ForensicAssistantResult({
    required this.isDeathScene,
    required this.route,
    required this.integrityStatus,
    required this.phase,
    required this.policeLineInstalled,
    required this.propertyHandlingCompliant,
    required this.kcsiLinked,
    required this.checklist,
    required this.warnings,
    required this.rationale,
    required this.ontologyNodes,
  });

  final bool isDeathScene;
  final DeathCaseRoute route;
  final SceneIntegrityStatus integrityStatus;
  final ForensicPhase phase;
  final bool policeLineInstalled;
  final bool propertyHandlingCompliant;
  final bool kcsiLinked;
  final List<String> checklist;
  final List<String> warnings;
  final String rationale;
  final List<String> ontologyNodes;

  bool get requiresJudicialPath => route == DeathCaseRoute.judicialAutopsy;
}

abstract final class SgpForensicAssistant {
  static const art222 = '형사소송법 제222조(변사자의 검시)';

  static final _deathKw =
      RegExp(r'(변사|사망|시신|사체|112\s*변사|익사|추락\s*사망|교통\s*사망|자살\s*의심)');
  static final _crimeSuspicionKw = RegExp(
    r'(범죄\s*혐의|타살|살해|피살|둔기|흉기|목\s*조름|감전|중독\s*의심|방화|피해\s*흔적|타박상|출혈\s*정황|피\s*흔적)',
  );
  static final _adminKw =
      RegExp(r'(질병\s*사|자연\s*사|노환|병사|유족\s*인도|장례|행정\s*변사)');
  static final _policeLineKw = RegExp(r'(통제선|폴리스\s*라인|police\s*line|현장\s*통제|출입\s*통제)');
  static final _propertyKw = RegExp(r'(소지품|유류품|임의\s*처분|압수|목록|봉인)');
  static final _kcsiKw = RegExp(r'(KCSI|과학수사|감식|현장\s*감식|감식\s*팀|검시)');
  static final _tamperKw =
      RegExp(r'(현장\s*훼손|증거\s*오염|사진\s*미촬영|유류품\s*이동|현장\s*변경)');

  static ForensicAssistantResult analyze(
    String text, {
    bool policeLineDeclared = false,
    bool propertyListDeclared = false,
    bool kcsiNotified = false,
  }) {
    final t = text.trim();
    final isDeath = _deathKw.hasMatch(t);
    final crimeSuspicion = _crimeSuspicionKw.hasMatch(t);
    final adminOnly = _adminKw.hasMatch(t) && !crimeSuspicion;

    DeathCaseRoute route;
    if (!isDeath) {
      route = DeathCaseRoute.administrativeHandover;
    } else if (crimeSuspicion) {
      route = DeathCaseRoute.judicialAutopsy;
    } else if (adminOnly) {
      route = DeathCaseRoute.administrativeHandover;
    } else {
      route = DeathCaseRoute.judicialAutopsy;
    }

    final policeLine =
        policeLineDeclared || _policeLineKw.hasMatch(t);
    final propertyOk = propertyListDeclared ||
        (_propertyKw.hasMatch(t) && !RegExp(r'임의\s*처분').hasMatch(t));
    final kcsi = kcsiNotified || _kcsiKw.hasMatch(t);

    SceneIntegrityStatus integrity;
    if (_tamperKw.hasMatch(t)) {
      integrity = SceneIntegrityStatus.evidenceTamperingRisk;
    } else if (isDeath && !policeLine) {
      integrity = SceneIntegrityStatus.policeLineMissing;
    } else {
      integrity = SceneIntegrityStatus.intact;
    }

    ForensicPhase phase;
    if (!isDeath) {
      phase = ForensicPhase.sceneControl;
    } else if (!kcsi) {
      phase = ForensicPhase.kcsiNotification;
    } else if (route == DeathCaseRoute.judicialAutopsy) {
      phase = ForensicPhase.examination;
    } else {
      phase = ForensicPhase.bodyHandover;
    }

    final checklist = <String>[
      if (isDeath) art222,
      if (isDeath) '현장 통제선(Police Line) 설치',
      if (isDeath) '변사자 소지품·유류품 임의 처분 금지',
      if (route == DeathCaseRoute.judicialAutopsy) '부검 영장 신청·검사 지휘',
      if (route == DeathCaseRoute.administrativeHandover) '유족 인도·행정 변사 처리',
      if (kcsi) 'KCSI 감식·현장 사진 연계',
    ];

    final warnings = <String>[];
    if (isDeath && !policeLine) {
      warnings.add('과학수사팀 감식 전 통제선 미설치 — 현장 훼손·증거 오염 위험.');
    }
    if (isDeath && RegExp(r'임의\s*처분').hasMatch(t)) {
      warnings.add('변사자 소지품·유류품 임의 처분 금지 — 압수·목록·봉인 절차 준수.');
    }
    if (integrity == SceneIntegrityStatus.evidenceTamperingRisk) {
      warnings.add('현장 훼손 정황 — 검시·부검 결과 신뢰성 훼손 및 국가배상 리스크.');
    }
    if (route == DeathCaseRoute.judicialAutopsy && !kcsi) {
      warnings.add('사법 변사 — KCSI 감식·검사 지휘 전 현장 보존 필수.');
    }

    final nodes = <String>['KR-LAW-CRIM-PROC-222'];
    if (isDeath) nodes.add('KR-FORENSIC-DEATH-SCENE');
    if (route == DeathCaseRoute.judicialAutopsy) {
      nodes.add('KR-FORENSIC-JUDICIAL-AUTOPSY');
    } else if (isDeath) {
      nodes.add('KR-FORENSIC-ADMIN-HANDOVER');
    }
    if (kcsi) nodes.add('KR-FORENSIC-KCSI-LINK');

    return ForensicAssistantResult(
      isDeathScene: isDeath,
      route: route,
      integrityStatus: integrity,
      phase: phase,
      policeLineInstalled: policeLine,
      propertyHandlingCompliant: propertyOk,
      kcsiLinked: kcsi,
      checklist: checklist,
      warnings: warnings,
      rationale: _rationale(isDeath, route, integrity),
      ontologyNodes: nodes,
    );
  }

  static String _rationale(
    bool isDeath,
    DeathCaseRoute route,
    SceneIntegrityStatus integrity,
  ) {
    if (!isDeath) return '변사 정황 미감지.';
    final path = route.label;
    final integ = switch (integrity) {
      SceneIntegrityStatus.intact => '현장 무결성 양호.',
      SceneIntegrityStatus.policeLineMissing => '통제선 미설치 — 즉시 보완.',
      SceneIntegrityStatus.evidenceTamperingRisk => '현장 훼손 위험 — 긴급 통제.',
    };
    return '$art222 — $path 분기. $integ';
  }
}
