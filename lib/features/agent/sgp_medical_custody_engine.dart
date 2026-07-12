/// S8-MED — 응급환자 이송·신병 확보·형소법 시한 통제 (Flutter 비의존).
library;

/// 병원 이송 사법 분기.
enum MedTransferBranch {
  /// A. 현행범 / 긴급체포 후 이송 — 48h 시한 흐름.
  arrestAfter('arrest_after'),

  /// B. 임의동행 / 병원 선 이송 — 체포 시한 정지·행정관리.
  voluntaryFirst('voluntary_first');

  const MedTransferBranch(this.code);

  final String code;

  static MedTransferBranch? fromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final b in MedTransferBranch.values) {
      if (b.code == code) return b;
    }
    return null;
  }

  String get displayLabel => switch (this) {
        MedTransferBranch.arrestAfter => 'A. 현행범·긴급체포 후 이송',
        MedTransferBranch.voluntaryFirst => 'B. 임의동행·병원 선 이송',
      };
}

/// 이송 진행 상태 코드 (교차 검증용).
enum MedTransferStatus {
  notStarted('NOT_STARTED'),
  inTransit('IN_TRANSIT'),
  erAdmission('ER_ADMISSION'),
  inpatientGuard('INPATIENT_GUARD'),
  treatmentComplete('TREATMENT_COMPLETE');

  const MedTransferStatus(this.code);

  final String code;

  static MedTransferStatus? fromCode(String? code) {
    if (code == null) return null;
    for (final s in MedTransferStatus.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// 도주 우려 등급 (B 분기).
enum MedFlightRiskLevel {
  normal,
  elevated,
  critical,
}

/// 현장 응급 이송 세션.
class SgpMedicalTransferSession {
  const SgpMedicalTransferSession({
    required this.branch,
    required this.arrestAt,
    this.status = MedTransferStatus.inTransit,
    this.subjectName = '피의자',
    this.hospitalName = '응급의료기관',
    this.injuryDescription = '외상',
    this.guardCount = 2,
    this.expectedDischargeAt,
    this.evaluatedAt,
  });

  final MedTransferBranch branch;
  final DateTime arrestAt;
  final MedTransferStatus status;
  final String subjectName;
  final String hospitalName;
  final String injuryDescription;
  final int guardCount;
  final DateTime? expectedDischargeAt;
  final DateTime? evaluatedAt;

  bool get requiresGuardImplicit =>
      status == MedTransferStatus.erAdmission ||
      status == MedTransferStatus.inpatientGuard ||
      status == MedTransferStatus.inTransit;

  SgpMedicalTransferSession copyWith({
    MedTransferBranch? branch,
    DateTime? arrestAt,
    MedTransferStatus? status,
    String? subjectName,
    String? hospitalName,
    String? injuryDescription,
    int? guardCount,
    DateTime? expectedDischargeAt,
    DateTime? evaluatedAt,
  }) {
    return SgpMedicalTransferSession(
      branch: branch ?? this.branch,
      arrestAt: arrestAt ?? this.arrestAt,
      status: status ?? this.status,
      subjectName: subjectName ?? this.subjectName,
      hospitalName: hospitalName ?? this.hospitalName,
      injuryDescription: injuryDescription ?? this.injuryDescription,
      guardCount: guardCount ?? this.guardCount,
      expectedDischargeAt: expectedDischargeAt ?? this.expectedDischargeAt,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
    );
  }
}

/// 체포·구속 시한 잔여 시간 계산 결과.
class MedicalCustodyDeadline {
  const MedicalCustodyDeadline({
    required this.branch,
    required this.arrestAt,
    required this.evaluatedAt,
    required this.prosecutorFilingDeadline,
    required this.timelineFrozen,
    required this.requiresGuard,
    required this.remainingMinutes,
    required this.isCritical,
    required this.isExpired,
    required this.flightRisk,
    required this.validationWarnings,
    required this.lv8DisplayHint,
  });

  final MedTransferBranch branch;
  final DateTime arrestAt;
  final DateTime evaluatedAt;
  final DateTime prosecutorFilingDeadline;
  final bool timelineFrozen;
  final bool requiresGuard;
  final int? remainingMinutes;
  final bool isCritical;
  final bool isExpired;
  final MedFlightRiskLevel flightRisk;
  final List<String> validationWarnings;
  final String lv8DisplayHint;

  double? get remainingHours =>
      remainingMinutes == null ? null : remainingMinutes! / 60.0;
}

/// 형소법 체포·구속 시한 — 분 단위 잔여 계산 및 교차 검증.
abstract final class SgpMedicalCustodyTimeline {
  static const arrestDeadlineHours = 48;
  static const criticalRemainingMinutes = 360;

  static MedicalCustodyDeadline compute({
    required SgpMedicalTransferSession session,
    DateTime? now,
    bool requiresGuard = true,
  }) {
    final evaluatedAt = now ?? session.evaluatedAt ?? DateTime.now();
    final branch = session.branch;
    final timelineFrozen = branch == MedTransferBranch.voluntaryFirst;
    final filingDeadline =
        session.arrestAt.add(const Duration(hours: arrestDeadlineHours));
    final warnings = validateCross(session, evaluatedAt: evaluatedAt);

    int? remainingMinutes;
    var isCritical = false;
    var isExpired = false;
    String lv8Hint;

    if (timelineFrozen) {
      remainingMinutes = null;
      lv8Hint =
          '⏱️ 행정관리 모드 — 체포 48h 시한은 흐르지 않음. '
          '치료 완료 예정 시각을 수기 입력하고 퇴원 시 지정 체포·임의동행 재요구 절차를 준비하세요.';
    } else {
      remainingMinutes = filingDeadline.difference(evaluatedAt).inMinutes;
      isExpired = remainingMinutes <= 0;
      isCritical = !isExpired && remainingMinutes <= criticalRemainingMinutes;
      lv8Hint = isExpired
          ? '🚨 사법 시한 초과 — 즉시 검사 지휘·영장 신청 분기 확보 요망.'
          : isCritical
              ? '🚨 사법 시한 카운트다운 — 이송 중에도 체포 48h 시한이 흐릅니다. '
                  '신속한 치료 후 검사 지휘 분기 확보 요망.'
              : '체포 48h 시한 진행 중 — 병원 치료와 영장 신청 일정을 병행 관리하세요.';
    }

    final flightRisk = _flightRisk(session, warnings);

    return MedicalCustodyDeadline(
      branch: branch,
      arrestAt: session.arrestAt,
      evaluatedAt: evaluatedAt,
      prosecutorFilingDeadline: filingDeadline,
      timelineFrozen: timelineFrozen,
      requiresGuard: requiresGuard,
      remainingMinutes: remainingMinutes,
      isCritical: isCritical,
      isExpired: isExpired,
      flightRisk: flightRisk,
      validationWarnings: warnings,
      lv8DisplayHint: lv8Hint,
    );
  }

  /// 체포 시각·이송 상태 코드 교차 검증.
  static List<String> validateCross(
    SgpMedicalTransferSession session, {
    DateTime? evaluatedAt,
  }) {
    final warnings = <String>[];
    final now = evaluatedAt ?? DateTime.now();

    if (session.branch == MedTransferBranch.arrestAfter &&
        session.arrestAt.isAfter(now)) {
      warnings.add('체포 시각이 현재 시각보다 미래입니다.');
    }

    if (session.branch == MedTransferBranch.arrestAfter &&
        session.status == MedTransferStatus.notStarted) {
      warnings.add('현행범·긴급체포 분기인데 이송 상태가 미시작입니다.');
    }

    if (session.branch == MedTransferBranch.voluntaryFirst &&
        session.status == MedTransferStatus.inpatientGuard) {
      warnings.add('임의동행 분기에서 입원 계호 상태는 강제력 행사 불가 — 절차 재확인.');
    }

    if (session.requiresGuardImplicit &&
        session.guardCount < 2 &&
        (session.status == MedTransferStatus.erAdmission ||
            session.status == MedTransferStatus.inpatientGuard)) {
      warnings.add('응급실·입원 계호는 2인 1조 교대 배치 지침을 준수하세요.');
    }

    if (session.branch == MedTransferBranch.voluntaryFirst &&
        session.expectedDischargeAt == null &&
        session.status != MedTransferStatus.notStarted) {
      warnings.add('치료 완료 예정 시각 미입력 — 퇴원 시 체포·동행 재요구 일정을 수기 기록하세요.');
    }

    return warnings;
  }

  static MedFlightRiskLevel _flightRisk(
    SgpMedicalTransferSession session,
    List<String> warnings,
  ) {
    if (session.branch == MedTransferBranch.arrestAfter) {
      return MedFlightRiskLevel.normal;
    }
    if (warnings.length >= 2) return MedFlightRiskLevel.critical;
    if (session.expectedDischargeAt == null) return MedFlightRiskLevel.elevated;
    return MedFlightRiskLevel.normal;
  }

  /// 상황 보고서 단락 자동 생성.
  static String buildSituationReportParagraph({
    required SgpMedicalTransferSession session,
    required MedicalCustodyDeadline deadline,
  }) {
    final arrestClock = _fmtClock(session.arrestAt);
    final branchLabel = session.branch.displayLabel;
    final guardPhrase = session.guardCount >= 2
        ? '수사관 ${session.guardCount}명 동행 2인 1조 교대 계호'
        : '수사관 동행 계호';

    if (deadline.timelineFrozen) {
      return '피의자 ${session.subjectName}은 ${session.injuryDescription}로 '
          '${session.hospitalName} 이송($branchLabel). '
          '강제력 행사 불가 상태로 의사 식별·치료 기간 소견 확보 중이며, '
          '퇴원 시점 지정 체포 또는 임의동행 재요구 절차를 준비함. '
          '도주 우려 등급: ${_flightRiskLabel(deadline.flightRisk)}.';
    }

    final remain = deadline.remainingMinutes ?? 0;
    return '피의자 ${session.subjectName}은 ${session.injuryDescription}로 '
        '${session.hospitalName} 이송, 현행범·긴급체포($arrestClock) 상태로 '
        '$guardPhrase 중이며, '
        '치료 완료 예상 시점에 따라 영장 신청 기한(T-0 + 48h, 잔여 ${remain}분)을 관리함.';
  }

  static String _fmtClock(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static String _flightRiskLabel(MedFlightRiskLevel level) => switch (level) {
        MedFlightRiskLevel.normal => '보통',
        MedFlightRiskLevel.elevated => '상향',
        MedFlightRiskLevel.critical => '긴급',
      };
}
