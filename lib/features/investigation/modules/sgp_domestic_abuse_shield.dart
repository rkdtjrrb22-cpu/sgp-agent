/// S12 — 가정폭력·아동학대처벌법 긴급임시조치 Shield.
///
/// 긴급임시조치(격리·100m 접근금지·전기통신 접근금지) 시한 제어 및
/// 위반 시 형사처벌/과태료 사법 분기를 추론한다.
library;

/// 긴급임시조치 유형 (가정폭력처벌법·아동학대 특례법 실무).
enum EmergencyTempMeasureType {
  isolation('피해자·가해자 격리'),
  approachBan100m('100m 이내 접근금지'),
  telecomBan('전기통신 이용 접근금지');

  const EmergencyTempMeasureType(this.label);
  final String label;
}

/// 조치 위반 처분 분기.
enum MeasureViolationDisposition {
  /// 형사처벌 (가정폭력처벌법 제49조 등).
  criminal,

  /// 과태료 (아동학대 특례법·가폭법 위반 과태료).
  fine,

  /// 형사·과태료 병과 가능.
  criminalAndFine,
}

/// 긴급임시조치 시한 상태.
enum TempMeasureDeadlineStatus {
  valid,
  expiringSoon,
  expired,
}

class DomesticAbuseShieldResult {
  const DomesticAbuseShieldResult({
    required this.isDomesticViolenceContext,
    required this.isChildAbuseContext,
    required this.recommendedMeasures,
    required this.deadlineStatus,
    required this.hoursRemaining,
    required this.violationDisposition,
    required this.rationale,
    required this.ontologyNodes,
  });

  final bool isDomesticViolenceContext;
  final bool isChildAbuseContext;
  final List<EmergencyTempMeasureType> recommendedMeasures;
  final TempMeasureDeadlineStatus deadlineStatus;
  final Duration? hoursRemaining;
  final MeasureViolationDisposition? violationDisposition;
  final String rationale;
  final List<String> ontologyNodes;

  bool get requiresEmergencyMeasure =>
      isDomesticViolenceContext || isChildAbuseContext;
}

abstract final class SgpDomesticAbuseShield {
  static final _dvKw = RegExp(
    r'(가정폭력|배우자\s*폭행|남편\s*폭행|아내\s*폭행|연인\s*폭행|가해자\s*분리|피해자\s*보호)',
  );
  static final _caKw = RegExp(
    r'(아동학대|아동\s*학대|방임|유기|신체\s*학대|정서\s*학대|성\s*학대|학대\s*정황)',
  );
  static final _isolationKw = RegExp(r'(격리|분리|별실|피해자\s*보호\s*시설)');
  static final _approachKw = RegExp(r'(100\s*m|100m|접근금지|접근\s*금지|100\s*미터)');
  static final _telecomKw =
      RegExp(r'(전화|문자|연락|전기통신|SNS|카톡|메신저).*?(금지|차단|접근금지)');
  static final _violationKw = RegExp(
    r'(위반|접근|연락|전화|문자|100\s*m|100m|접근금지\s*위반|조치\s*위반)',
  );
  static final _childViolationKw = RegExp(r'(아동|미성년).*?(학대|방임|유기)');

  /// 긴급임시조치 발령 후 시한(기본 14일·연장 가능) 상태 계산.
  static TempMeasureDeadlineStatus deadlineStatus({
    required DateTime issuedAt,
    required DateTime now,
    Duration validity = const Duration(days: 14),
    Duration warnBefore = const Duration(hours: 24),
  }) {
    final expires = issuedAt.add(validity);
    if (now.isAfter(expires)) return TempMeasureDeadlineStatus.expired;
    if (expires.difference(now) <= warnBefore) {
      return TempMeasureDeadlineStatus.expiringSoon;
    }
    return TempMeasureDeadlineStatus.valid;
  }

  static Duration? hoursRemaining({
    required DateTime issuedAt,
    required DateTime now,
    Duration validity = const Duration(days: 14),
  }) {
    final rem = issuedAt.add(validity).difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  /// 현장 텍스트·조치 발령 시각 기반 추론.
  static DomesticAbuseShieldResult analyze(
    String text, {
    DateTime? measureIssuedAt,
    DateTime? now,
  }) {
    final t = text.trim();
    final isDv = _dvKw.hasMatch(t);
    final isCa = _caKw.hasMatch(t);
    final measures = <EmergencyTempMeasureType>[];

    if (_isolationKw.hasMatch(t) || isDv || isCa) {
      measures.add(EmergencyTempMeasureType.isolation);
    }
    if (_approachKw.hasMatch(t) || isDv) {
      measures.add(EmergencyTempMeasureType.approachBan100m);
    }
    if (_telecomKw.hasMatch(t) || isDv) {
      measures.add(EmergencyTempMeasureType.telecomBan);
    }

    if (measures.isEmpty && (isDv || isCa)) {
      measures.addAll(EmergencyTempMeasureType.values);
    }

    MeasureViolationDisposition? violation;
    if (_violationKw.hasMatch(t) && measures.isNotEmpty) {
      violation = _childViolationKw.hasMatch(t) || isCa
          ? MeasureViolationDisposition.criminalAndFine
          : isDv
              ? MeasureViolationDisposition.criminal
              : MeasureViolationDisposition.fine;
    }

    final nodes = <String>['KR-LAW-DVPA'];
    if (isCa) nodes.add('KR-LAW-CHILD-ABUSE');
    if (measures.contains(EmergencyTempMeasureType.isolation)) {
      nodes.add('KR-DV-TEMP-ISOLATION');
    }
    if (measures.contains(EmergencyTempMeasureType.approachBan100m)) {
      nodes.add('KR-DV-TEMP-APPROACH-100M');
    }
    if (measures.contains(EmergencyTempMeasureType.telecomBan)) {
      nodes.add('KR-DV-TEMP-TELECOM-BAN');
    }

    TempMeasureDeadlineStatus status = TempMeasureDeadlineStatus.valid;
    Duration? rem;
    if (measureIssuedAt != null) {
      final clock = now ?? DateTime.now();
      status = deadlineStatus(issuedAt: measureIssuedAt, now: clock);
      rem = hoursRemaining(issuedAt: measureIssuedAt, now: clock);
    }

    final rationale = _buildRationale(
      isDv: isDv,
      isCa: isCa,
      measures: measures,
      status: status,
      violation: violation,
    );

    return DomesticAbuseShieldResult(
      isDomesticViolenceContext: isDv,
      isChildAbuseContext: isCa,
      recommendedMeasures: measures,
      deadlineStatus: status,
      hoursRemaining: rem,
      violationDisposition: violation,
      rationale: rationale,
      ontologyNodes: nodes,
    );
  }

  static String _buildRationale({
    required bool isDv,
    required bool isCa,
    required List<EmergencyTempMeasureType> measures,
    required TempMeasureDeadlineStatus status,
    required MeasureViolationDisposition? violation,
  }) {
    final buf = StringBuffer();
    if (isDv) {
      buf.write('가정폭력처벌법상 긴급임시조치(격리·접근금지·전기통신 금지) 검토. ');
    }
    if (isCa) {
      buf.write('아동학대범죄의 처벌 등에 관한 특례법상 아동 보호·신고 의무 연계. ');
    }
    if (measures.isNotEmpty) {
      buf.write('권고 조치: ${measures.map((m) => m.label).join(', ')}. ');
    }
    buf.write(switch (status) {
      TempMeasureDeadlineStatus.valid => '조치 시한 유효.',
      TempMeasureDeadlineStatus.expiringSoon => '조치 만료 24시간 이내 — 연장·법원 신청 검토.',
      TempMeasureDeadlineStatus.expired => '조치 시한 만료 — 재발령 또는 임시조치 신청 필요.',
    });
    if (violation != null) {
      buf.write(' 위반 정황: ${switch (violation) {
        MeasureViolationDisposition.criminal => '형사처벌(가정폭력처벌법 제49조 등).',
        MeasureViolationDisposition.fine => '과태료 부과 가능.',
        MeasureViolationDisposition.criminalAndFine => '형사처벌·과태료 병과 가능.',
      }}');
    }
    return buf.toString().trim();
  }
}
