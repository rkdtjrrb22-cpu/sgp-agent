/// S13 — 피의자 유치인 안전 관리·신병 계호 Shield.
///
/// 경찰관직무집행법·유치장 관리 지침에 따른 입감·신체검사·특별계호·
/// 48시간 구속 시한 체인 연동을 검증한다.
library;

/// 유치인 위험 등급.
enum CustodyRiskLevel {
  standard('일반'),
  selfHarmRisk('자해 위험'),
  suicideHighRisk('자살 고위험');

  const CustodyRiskLevel(this.label);
  final String label;
}

/// 신체검사 수준.
enum BodySearchLevel {
  none('미실시'),
  patDown('신체검사'),
  stripSearch('살촕검사(성기·항문)');

  const BodySearchLevel(this.label);
  final String label;
}

/// 특별계호 순찰 주기.
enum SpecialGuardInterval {
  standard('2시간 순찰'),
  hourly('1시간 순찰'),
  cctvFocus('CCTV 집중관찰 + 30분 순찰');

  const SpecialGuardInterval(this.label);
  final String label;
}

/// 무결성 결함 유형.
enum CustodyIntegrityIssue {
  missingRightsNotice,
  incompleteBodySearch,
  incompleteSeizureList,
  specialGuardNotAssigned,
  custody48hBreach,
}

class CustodyManagementResult {
  const CustodyManagementResult({
    required this.isCustodyContext,
    required this.riskLevel,
    required this.bodySearchLevel,
    required this.guardInterval,
    required this.issues,
    required this.custody48hCompliant,
    required this.hoursRemaining48h,
    required this.warnings,
    required this.rationale,
    required this.ontologyNodes,
  });

  final bool isCustodyContext;
  final CustodyRiskLevel riskLevel;
  final BodySearchLevel bodySearchLevel;
  final SpecialGuardInterval guardInterval;
  final List<CustodyIntegrityIssue> issues;
  final bool custody48hCompliant;
  final Duration? hoursRemaining48h;
  final List<String> warnings;
  final String rationale;
  final List<String> ontologyNodes;

  bool get hasCriticalIssue =>
      issues.contains(CustodyIntegrityIssue.custody48hBreach) ||
      issues.contains(CustodyIntegrityIssue.specialGuardNotAssigned);
}

abstract final class SgpCustodyManagement {
  static final _custodyKw =
      RegExp(r'(유치|유치장|입감|구속\s*신병|신병\s*확보|피의자\s*유치)');
  static final _selfHarmKw =
      RegExp(r'(자해|자살|목\s*매|손목\s*긋|극단\s*선택|자살\s*기도)');
  static final _harmOthersKw = RegExp(r'(타해|남\s*해치|폭력\s*행사)');
  static final _rightsKw = RegExp(r'(권리\s*고지|변호인|묵비권|유치\s*권리)');
  static final _bodySearchKw = RegExp(r'(신체검사|살촕|성기|항문|검사\s*실시)');
  static final _seizureListKw = RegExp(r'(소지품\s*압수|압수\s*목록|압수목록)');
  static final _medicalKw = RegExp(r'(의료\s*조치|응급\s*처치|병원|구급|부상)');

  /// 구속 T-0 기준 48h 잔여.
  static Duration compute48hRemaining({
    required DateTime custodyStart,
    required DateTime now,
  }) {
    final end = custodyStart.add(const Duration(hours: 48));
    final rem = end.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  static CustodyManagementResult assess(
    String text, {
    DateTime? custodyStart,
    DateTime? now,
    bool rightsNoticeGiven = false,
    bool bodySearchCompleted = false,
    bool seizureListComplete = false,
    bool specialGuardAssigned = false,
  }) {
    final t = text.trim();
    final isCustody = _custodyKw.hasMatch(t);
    final selfHarm = _selfHarmKw.hasMatch(t);
    final harmOthers = _harmOthersKw.hasMatch(t);
    final hasMedical = _medicalKw.hasMatch(t);

    CustodyRiskLevel risk;
    if (selfHarm && RegExp(r'(자살|극단|기도)').hasMatch(t)) {
      risk = CustodyRiskLevel.suicideHighRisk;
    } else if (selfHarm || harmOthers) {
      risk = CustodyRiskLevel.selfHarmRisk;
    } else {
      risk = CustodyRiskLevel.standard;
    }

    BodySearchLevel searchLevel;
    if (RegExp(r'살촕|성기|항문').hasMatch(t) || bodySearchCompleted) {
      searchLevel = bodySearchCompleted || _bodySearchKw.hasMatch(t)
          ? BodySearchLevel.stripSearch
          : BodySearchLevel.patDown;
    } else if (_bodySearchKw.hasMatch(t) || bodySearchCompleted) {
      searchLevel = BodySearchLevel.patDown;
    } else {
      searchLevel = BodySearchLevel.none;
    }

    SpecialGuardInterval interval;
    if (risk == CustodyRiskLevel.suicideHighRisk) {
      interval = specialGuardAssigned
          ? SpecialGuardInterval.cctvFocus
          : SpecialGuardInterval.hourly;
    } else if (risk == CustodyRiskLevel.selfHarmRisk) {
      interval = SpecialGuardInterval.hourly;
    } else {
      interval = SpecialGuardInterval.standard;
    }

    final issues = <CustodyIntegrityIssue>[];
    if (isCustody && !rightsNoticeGiven && !_rightsKw.hasMatch(t)) {
      issues.add(CustodyIntegrityIssue.missingRightsNotice);
    }
    if (isCustody && searchLevel == BodySearchLevel.none && !bodySearchCompleted) {
      issues.add(CustodyIntegrityIssue.incompleteBodySearch);
    }
    if (isCustody && !seizureListComplete && !_seizureListKw.hasMatch(t)) {
      issues.add(CustodyIntegrityIssue.incompleteSeizureList);
    }
    if (isCustody &&
        (risk == CustodyRiskLevel.suicideHighRisk ||
            risk == CustodyRiskLevel.selfHarmRisk) &&
        !specialGuardAssigned) {
      issues.add(CustodyIntegrityIssue.specialGuardNotAssigned);
    }

    Duration? rem48;
    var compliant48 = true;
    if (custodyStart != null) {
      final clock = now ?? DateTime.now();
      rem48 = compute48hRemaining(custodyStart: custodyStart, now: clock);
      if (rem48 == Duration.zero && isCustody) {
        issues.add(CustodyIntegrityIssue.custody48hBreach);
        compliant48 = false;
      } else if (hasMedical && rem48.inHours <= 6) {
        compliant48 = rem48.inHours > 0;
      }
    }

    final warnings = <String>[];
    for (final issue in issues) {
      warnings.add(switch (issue) {
        CustodyIntegrityIssue.missingRightsNotice =>
          '유치인 권리 고지(변호인·묵비권) 미이행 — 경찰관직무집행법 위반 리스크.',
        CustodyIntegrityIssue.incompleteBodySearch =>
          '입감 신체검사·살촕검사 미실시 — 유치장 관리 지침 위반.',
        CustodyIntegrityIssue.incompleteSeizureList =>
          '소지품 압수 목록 미작성 — 증거·인권 분쟁 리스크.',
        CustodyIntegrityIssue.specialGuardNotAssigned =>
          '자해·자살 고위험군 특별계호 미지정 — 1시간 순찰·CCTV 집중관찰 필수.',
        CustodyIntegrityIssue.custody48hBreach =>
          '48시간 구속 시한 초과 — 즉시 석방·영장 신청 또는 연장 절차.',
      });
    }
    if (hasMedical && isCustody) {
      warnings.add('유치장 내 의료 조치 — 48h 구속 시한·계호 상태 동시 점검.');
    }

    final nodes = <String>['KR-LAW-CUSTODY-MGMT'];
    if (isCustody) nodes.add('KR-CUSTODY-ADMISSION');
    if (risk != CustodyRiskLevel.standard) {
      nodes.add('KR-CUSTODY-SPECIAL-GUARD');
    }
    if (hasMedical) nodes.add('KR-CUSTODY-MEDICAL-CHAIN');

    return CustodyManagementResult(
      isCustodyContext: isCustody,
      riskLevel: risk,
      bodySearchLevel: searchLevel,
      guardInterval: interval,
      issues: issues,
      custody48hCompliant: compliant48,
      hoursRemaining48h: rem48,
      warnings: warnings,
      rationale: _rationale(isCustody, risk, interval, compliant48),
      ontologyNodes: nodes,
    );
  }

  static String _rationale(
    bool isCustody,
    CustodyRiskLevel risk,
    SpecialGuardInterval interval,
    bool compliant48,
  ) {
    if (!isCustody) return '유치 정황 미감지.';
    final chain = compliant48 ? '48h 시한 준수.' : '48h 시한 위반·즉시 조치.';
    return '유치인 ${risk.label} — ${interval.label}. $chain';
  }
}
