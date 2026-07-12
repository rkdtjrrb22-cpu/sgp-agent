/// S11 — 사법 무결성·감찰 내부 통제 (Anti-Corruption Shield).
///
/// 수사서류 작성·증거 등록 단계에서 신분범·직무범 저촉 위험을 실시간 파싱하여
/// 형법 제122·123·125·127·155·227조 및 경찰공무원법 제56·57조·징계령에 연계된
/// 네온 레드(#FF1744) 경고를 생성한다.
library;

/// 감찰 위험 심각도.
enum AntiCorruptionSeverity {
  /// 정보성 — 주의 환기.
  advisory,

  /// 경고 — 비위 정황.
  warning,

  /// 치명 — 형사처벌·파면/해임 대상.
  critical,
}

/// 개별 위험 플래그.
class AntiCorruptionFlag {
  const AntiCorruptionFlag({
    required this.id,
    required this.severity,
    required this.title,
    required this.legalBasis,
    required this.disciplineBasis,
    required this.message,
    required this.matchedKeywords,
    required this.ontologyNodes,
  });

  final String id;
  final AntiCorruptionSeverity severity;
  final String title;

  /// 형법 등 형사 근거 조문.
  final List<String> legalBasis;

  /// 경찰공무원법·징계령 근거.
  final List<String> disciplineBasis;

  final String message;
  final List<String> matchedKeywords;
  final List<String> ontologyNodes;

  bool get isCritical => severity == AntiCorruptionSeverity.critical;
}

/// 감찰 사전 리스크 평가 결과.
class AntiCorruptionAssessment {
  const AntiCorruptionAssessment({
    required this.flags,
    required this.terminalBanner,
  });

  final List<AntiCorruptionFlag> flags;

  /// 터미널·로그 출력용 배너 (null이면 위험 없음).
  final String? terminalBanner;

  bool get isClean => flags.isEmpty;

  bool get hasCritical => flags.any((f) => f.isCritical);

  AntiCorruptionSeverity get topSeverity {
    if (flags.any((f) => f.severity == AntiCorruptionSeverity.critical)) {
      return AntiCorruptionSeverity.critical;
    }
    if (flags.any((f) => f.severity == AntiCorruptionSeverity.warning)) {
      return AntiCorruptionSeverity.warning;
    }
    return AntiCorruptionSeverity.advisory;
  }

  /// UI 강조용 네온 레드 노출 여부.
  bool get showsNeonRed => hasCritical;

  /// 파면·해임 양정 경고 문구.
  String get disciplineWarning => hasCritical
      ? '수사기밀 유출 및 증거 훼손 시 파면·해임 등 형사처벌 대상임'
      : '감찰 조사의 대상이 될 수 있으므로 절차 준수 필요';
}

/// 압수·수색 영장 집행 정황 (절차 시한·서명 검증).
class SeizureExecutionContext {
  const SeizureExecutionContext({
    this.evidenceListAttached = true,
    this.participantSignaturePresent = true,
    this.warrantExecutionWithinDeadline = true,
    this.digitalEvidenceLogged = true,
  });

  final bool evidenceListAttached;
  final bool participantSignaturePresent;
  final bool warrantExecutionWithinDeadline;
  final bool digitalEvidenceLogged;
}

abstract final class SgpAntiCorruptionFilter {
  static const neonRedHex = 0xFFFF1744;

  static final _dereliction =
      RegExp(r'(직무유기|직무\s*방기|묵살|방치|미조치|신고\s*묵살)');
  static final _abuse =
      RegExp(r'(직권남용|강압|압박\s*수사|의무없는|권리행사\s*방해)');
  static final _coercion =
      RegExp(r'(욕설|폭언|폭행|가혹행위|진술\s*강요|자백\s*강요|협박\s*수사)');
  static final _secretLeak = RegExp(
      r'(수사기밀|비밀\s*누설|정보\s*유출|자취방\s*비밀번호|피의자\s*가족.*(인계|알려)|개인정보\s*유출)');
  static final _evidenceTamper = RegExp(
      r'(증거[를을]?\s*(인멸|은닉|조작|훼손|위조|변조)|컬러.*흑백|흑백\s*전환|CCTV.*(삭제|조작|변환)|증거물[을를]?\s*유출|영상[을를]?\s*삭제)');
  static final _falseDoc = RegExp(
      r'(허위\s*공문서|허위\s*작성|조서[를을]?\s*조작|허위\s*기재|압수목록\s*누락|서류[를을]?\s*조작|허위\s*보고)');

  /// 수사서류 텍스트 + 압수 정황 → 감찰 위험 평가.
  static AntiCorruptionAssessment assess({
    required String documentText,
    SeizureExecutionContext? seizure,
  }) {
    final text = documentText.trim();
    final flags = <AntiCorruptionFlag>[];

    void addTextFlag({
      required RegExp re,
      required String id,
      required AntiCorruptionSeverity severity,
      required String title,
      required List<String> legal,
      required List<String> discipline,
      required String message,
      required List<String> nodes,
    }) {
      final matches = re.allMatches(text).map((m) => m.group(0)!.trim()).toList();
      if (matches.isEmpty) return;
      flags.add(
        AntiCorruptionFlag(
          id: id,
          severity: severity,
          title: title,
          legalBasis: legal,
          disciplineBasis: discipline,
          message: message,
          matchedKeywords: matches,
          ontologyNodes: nodes,
        ),
      );
    }

    if (text.isNotEmpty) {
      addTextFlag(
        re: _evidenceTamper,
        id: 'AC-EVIDENCE-TAMPER',
        severity: AntiCorruptionSeverity.critical,
        title: '증거인멸·조작 저촉 위험',
        legal: const ['형법 제155조(증거인멸 등)', '형법 제227조(허위공문서작성)'],
        discipline: const ['경찰공무원법 제56조', '경찰공무원 징계령(파면·해임)'],
        message:
            'CCTV 컬러화면의 흑백 전환·증거물 유출 등 증거 훼손은 형법 제155조·제227조 저촉 위험이며 파면·해임 대상입니다.',
        nodes: const ['KR-CRIM-155-EVIDENCE', 'KR-CRIM-227-FALSEDOC', 'ORG-POLICE-DISCIPLINE'],
      );
      addTextFlag(
        re: _falseDoc,
        id: 'AC-FALSE-DOCUMENT',
        severity: AntiCorruptionSeverity.critical,
        title: '허위공문서작성 저촉 위험',
        legal: const ['형법 제227조(허위공문서작성)'],
        discipline: const ['경찰공무원법 제56조', '경찰공무원 징계령(파면·해임)'],
        message:
            '압수목록 누락·조서 허위 기재는 형법 제227조 허위공문서작성죄에 저촉되며 감찰 중징계 대상입니다.',
        nodes: const ['KR-CRIM-227-FALSEDOC', 'ORG-POLICE-DISCIPLINE'],
      );
      addTextFlag(
        re: _secretLeak,
        id: 'AC-SECRET-LEAK',
        severity: AntiCorruptionSeverity.critical,
        title: '공무상비밀누설·수사기밀 유출 위험',
        legal: const ['형법 제127조(공무상비밀누설)'],
        discipline: const ['경찰공무원법 제56조', '경찰공무원 징계령(파면)'],
        message:
            '피의자 가족에게 자취방 비밀번호 무단 인계 등 수사기밀 유출은 형법 제127조 저촉이며 최소 파면 양정에 해당합니다.',
        nodes: const ['KR-CRIM-127-SECRET', 'ORG-POLICE-DISCIPLINE'],
      );
      addTextFlag(
        re: _coercion,
        id: 'AC-COERCION',
        severity: AntiCorruptionSeverity.critical,
        title: '독직폭행·강압수사 위험',
        legal: const ['형법 제125조(독직폭행)'],
        discipline: const ['경찰공무원법 제56조', '경찰공무원 징계령(해임)'],
        message:
            '욕설·폭언·진술 강요 등 강압 수사는 형법 제125조 독직폭행에 해당하고 위법수집증거로 배제되며 해임 양정 대상입니다.',
        nodes: const ['KR-CRIM-125-VIOLENCE', 'ORG-POLICE-DISCIPLINE'],
      );
      addTextFlag(
        re: _abuse,
        id: 'AC-ABUSE-OF-AUTHORITY',
        severity: AntiCorruptionSeverity.warning,
        title: '직권남용 정황',
        legal: const ['형법 제123조(직권남용)'],
        discipline: const ['경찰공무원법 제57조'],
        message: '직권 남용으로 의무 없는 일을 강요하거나 권리행사를 방해한 정황이 감지되었습니다.',
        nodes: const ['KR-CRIM-123-ABUSE', 'ORG-POLICE-DISCIPLINE'],
      );
      addTextFlag(
        re: _dereliction,
        id: 'AC-DERELICTION',
        severity: AntiCorruptionSeverity.warning,
        title: '직무유기 정황',
        legal: const ['형법 제122조(직무유기)'],
        discipline: const ['경찰공무원법 제56조(성실의무)'],
        message: '정당한 이유 없는 직무 유기·신고 묵살 정황이 감지되었습니다.',
        nodes: const ['KR-CRIM-122-DERELICTION', 'ORG-POLICE-DISCIPLINE'],
      );
    }

    if (seizure != null) {
      _assessSeizure(seizure, flags);
    }

    return AntiCorruptionAssessment(
      flags: flags,
      terminalBanner: flags.isEmpty ? null : _buildBanner(flags),
    );
  }

  static void _assessSeizure(
    SeizureExecutionContext seizure,
    List<AntiCorruptionFlag> flags,
  ) {
    if (!seizure.digitalEvidenceLogged || !seizure.evidenceListAttached) {
      flags.add(
        const AntiCorruptionFlag(
          id: 'AC-SEIZURE-LIST-OMISSION',
          severity: AntiCorruptionSeverity.critical,
          title: '압수물 목록 누락 — 증거인멸·허위공문서 위험',
          legalBasis: ['형법 제155조(증거인멸 등)', '형법 제227조(허위공문서작성)'],
          disciplineBasis: ['경찰공무원법 제56조', '경찰공무원 징계령'],
          message:
              '디지털 증거 압수물 목록이 누락되었습니다. 형법 제155조·제227조 저촉 위험이 있으니 압수조서에 전량 등재하세요.',
          matchedKeywords: ['압수물 목록 누락'],
          ontologyNodes: ['KR-CRIM-155-EVIDENCE', 'KR-CRIM-227-FALSEDOC', 'ORG-POLICE-DISCIPLINE'],
        ),
      );
    }
    if (!seizure.warrantExecutionWithinDeadline ||
        !seizure.participantSignaturePresent) {
      flags.add(
        const AntiCorruptionFlag(
          id: 'AC-WARRANT-PROCEDURE',
          severity: AntiCorruptionSeverity.warning,
          title: '영장 집행 시한·참여인 서명 하자',
          legalBasis: ['형사소송법 제129조', '형법 제227조(허위공문서작성)'],
          disciplineBasis: ['경찰공무원법 제56조(성실의무)'],
          message:
              '압수·수색 영장 집행 시각 또는 참여인 서명이 법적 시한을 벗어났습니다. 절차 하자·허위공문서작성 위험을 검토하세요.',
          matchedKeywords: ['영장 집행 절차 하자'],
          ontologyNodes: ['KR-CRIM-227-FALSEDOC', 'ORG-POLICE-DISCIPLINE'],
        ),
      );
    }
  }

  static String _buildBanner(List<AntiCorruptionFlag> flags) {
    final critical = flags.where((f) => f.isCritical).toList();
    final buf = StringBuffer()
      ..writeln('🚨🚨🚨 [SGP ANTI-CORRUPTION SHIELD] 🚨🚨🚨');
    for (final f in flags) {
      final tag = switch (f.severity) {
        AntiCorruptionSeverity.critical => 'CRITICAL',
        AntiCorruptionSeverity.warning => 'WARNING',
        AntiCorruptionSeverity.advisory => 'ADVISORY',
      };
      buf.writeln('[$tag] ${f.title} — ${f.legalBasis.join(", ")}');
    }
    if (critical.isNotEmpty) {
      buf.writeln('▶ 수사기밀 유출 및 증거 훼손 시 파면·해임 등 형사처벌 대상임 (경찰공무원 징계령)');
    }
    return buf.toString().trimRight();
  }
}
