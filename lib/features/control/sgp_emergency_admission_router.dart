/// S12 — 정신건강복지법 제50조 응급입원 절차 라우터.
///
/// 자·타해 위험 고위험 정신질환자 발견 시 의사·경찰관 동의 하 72시간
/// 응급입원 절차 무결성 및 이송·인치 과정 계호 한계 리스크를 경고한다.
library;

/// 응급입원 동의 주체.
enum EmergencyAdmissionConsent {
  /// 의사 + 경찰관(또는 소방·군인) 동의.
  doctorAndPolice,

  /// 의사 단독(제50조 제1항 — 입원 의사·간호사 등).
  doctorOnly,

  /// 동의 미충족 — 위법 입원 위험.
  insufficient,
}

/// 이송·계호 리스크.
enum CustodyGuardRisk {
  none,
  /// 이송 중 자·타해 재발.
  transitSelfHarm,
  /// 병원 도착 전 구속·인치 한계.
  preHospitalCustodyLimit,
  /// 72시간 초과 연장 미신청.
  seventyTwoHourBreach,
}

class EmergencyAdmissionResult {
  const EmergencyAdmissionResult({
    required this.selfHarmRisk,
    required this.harmToOthersRisk,
    required this.consentStatus,
    required this.hoursRemaining72h,
    required this.guardRisk,
    required this.rationale,
    required this.warnings,
    required this.ontologyNodes,
  });

  final bool selfHarmRisk;
  final bool harmToOthersRisk;
  final EmergencyAdmissionConsent consentStatus;
  final Duration? hoursRemaining72h;
  final CustodyGuardRisk guardRisk;
  final String rationale;
  final List<String> warnings;
  final List<String> ontologyNodes;

  bool get isHighRisk => selfHarmRisk || harmToOthersRisk;
  bool get isLawfulAdmission => consentStatus == EmergencyAdmissionConsent.doctorAndPolice;
}

abstract final class SgpEmergencyAdmissionRouter {
  static final _selfHarmKw =
      RegExp(r'(자해|자살|목\s*매|투신|손목\s*긋|약\s*과다|극단\s*선택)');
  static final _harmOthersKw =
      RegExp(r'(타해|남\s*해치|흉기\s*휘두|폭력\s*행사|주변\s*위협|주변\s*인\s*해칠)');
  static final _mentalKw =
      RegExp(r'(정신질환|조현|우울|망상|환각|정신\s*병|정신\s*과|조증|정신\s*이상)');
  static final _doctorKw = RegExp(r'(의사|정신과\s*의사|응급\s*의료|의료진|전문의)');
  static final _policeKw = RegExp(r'(경찰|경찰관|112|112\s*신고|112\s*출동)');
  static final _transferKw = RegExp(r'(이송|구급차|병원\s*이송|응급실|119)');
  static final _custodyKw = RegExp(r'(인치|구속|신병|계호|도주\s*우려)');

  /// T-0(입원 개시) 기준 72시간 잔여.
  static Duration compute72hRemaining({
    required DateTime admissionAt,
    required DateTime now,
  }) {
    final end = admissionAt.add(const Duration(hours: 72));
    final rem = end.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  static EmergencyAdmissionResult route(
    String text, {
    DateTime? admissionAt,
    DateTime? now,
    bool doctorConsentDeclared = false,
    bool policeConsentDeclared = false,
  }) {
    final t = text.trim();
    final selfHarm = _selfHarmKw.hasMatch(t);
    final harmOthers = _harmOthersKw.hasMatch(t);
    final mental = _mentalKw.hasMatch(t);
    final hasDoctor = doctorConsentDeclared || _doctorKw.hasMatch(t);
    final hasPolice = policeConsentDeclared || _policeKw.hasMatch(t);

    EmergencyAdmissionConsent consent;
    if (hasDoctor && hasPolice) {
      consent = EmergencyAdmissionConsent.doctorAndPolice;
    } else if (hasDoctor && !hasPolice) {
      consent = EmergencyAdmissionConsent.doctorOnly;
    } else {
      consent = EmergencyAdmissionConsent.insufficient;
    }

    CustodyGuardRisk guardRisk = CustodyGuardRisk.none;
    final warnings = <String>[];

    if (_transferKw.hasMatch(t) && (selfHarm || harmOthers)) {
      guardRisk = CustodyGuardRisk.transitSelfHarm;
      warnings.add('이송 중 자·타해 재발 위험 — 2인 1조 계호·구급대 연계 필수.');
    }
    if (_custodyKw.hasMatch(t) && mental) {
      guardRisk = CustodyGuardRisk.preHospitalCustodyLimit;
      warnings.add('병원 도착 전 경찰 인치·계호 한계 — 정신건강복지법 제50조 응급입원 절차 우선.');
    }

    Duration? rem72;
    if (admissionAt != null) {
      final clock = now ?? DateTime.now();
      rem72 = compute72hRemaining(admissionAt: admissionAt, now: clock);
      if (rem72 == Duration.zero) {
        guardRisk = CustodyGuardRisk.seventyTwoHourBreach;
        warnings.add('72시간 응급입원 시한 초과 — 정신건강의학과 전문의 재평가·연장 입원 신청 필요.');
      } else if (rem72.inHours <= 6) {
        warnings.add('72시간 시한 ${rem72.inHours}h 잔여 — 연장 입원 또는 퇴원 결정 준비.');
      }
    }

    if (consent == EmergencyAdmissionConsent.insufficient && (selfHarm || harmOthers)) {
      warnings.add('의사·경찰관 동의 미충족 — 위법 응급입원·불법 구금 리스크.');
    }
    if (consent == EmergencyAdmissionConsent.doctorOnly && hasPolice == false) {
      warnings.add('경찰관 동의 누락 — 제50조 제2항 경찰관 동의 요건 확인.');
    }

    final nodes = <String>['KR-LAW-MHW-50'];
    if (mental) nodes.add('KR-MHW-EMERGENCY-ADMISSION');
    if (selfHarm) nodes.add('KR-MHW-SELF-HARM');
    if (harmOthers) nodes.add('KR-MHW-HARM-OTHERS');

    final rationale = _buildRationale(
      mental: mental,
      selfHarm: selfHarm,
      harmOthers: harmOthers,
      consent: consent,
    );

    return EmergencyAdmissionResult(
      selfHarmRisk: selfHarm,
      harmToOthersRisk: harmOthers,
      consentStatus: consent,
      hoursRemaining72h: rem72,
      guardRisk: guardRisk,
      rationale: rationale,
      warnings: warnings,
      ontologyNodes: nodes,
    );
  }

  static String _buildRationale({
    required bool mental,
    required bool selfHarm,
    required bool harmOthers,
    required EmergencyAdmissionConsent consent,
  }) {
    if (!mental && !selfHarm && !harmOthers) {
      return '정신건강 응급입원 정황 미감지 — 일반 수사·보호 절차 적용.';
    }
    final risk = [
      if (selfHarm) '자해',
      if (harmOthers) '타해',
    ].join('·');
    final consentLabel = switch (consent) {
      EmergencyAdmissionConsent.doctorAndPolice =>
        '의사·경찰관 동의 충족 — 72시간 응급입원 가능.',
      EmergencyAdmissionConsent.doctorOnly =>
        '의사 동의만 확인 — 경찰관 동의 추가 필요(제50조).',
      EmergencyAdmissionConsent.insufficient =>
        '동의 요건 미충족 — 응급입원·구금 위법성 리스크.',
    };
    return '정신건강복지법 제50조 — $risk 위험. $consentLabel';
  }
}
