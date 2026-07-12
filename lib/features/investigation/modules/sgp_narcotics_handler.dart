/// S12 — 마약류관리법 간이시약 거부 시 강제처분 Handler.
///
/// 피의자의 간이시약 검사 거부 시 감정처분허가장·압수수색영장 신청
/// 절차 타임라인 및 필수 소명 요건을 검증한다.
library;

/// 간이시약(현장) 검사 단계.
enum NarcoticsScreeningStage {
  /// 현장 간이시약 검사 제안.
  fieldRapidTest,

  /// 피의자 거부.
  refusal,

  /// 감정처분허가장 신청.
  forensicWarrantApplication,

  /// 압수수색·채취 영장 신청.
  searchSeizureWarrant,
}

/// 강제처분 타임라인 노드 상태.
enum NarcoticsTimelineStatus {
  onTrack,
  urgent,
  overdue,
}

class NarcoticsMandatoryResult {
  const NarcoticsMandatoryResult({
    required this.narcoticsContext,
    required this.refusedRapidTest,
    required this.stage,
    required this.timelineStatus,
    required this.justificationComplete,
    required this.missingJustifications,
    required this.rationale,
    required this.ontologyNodes,
  });

  final bool narcoticsContext;
  final bool refusedRapidTest;
  final NarcoticsScreeningStage stage;
  final NarcoticsTimelineStatus timelineStatus;
  final bool justificationComplete;
  final List<String> missingJustifications;
  final String rationale;
  final List<String> ontologyNodes;

  bool get requiresForcedMeasure => narcoticsContext && refusedRapidTest;
}

/// 강제처분 소명 필수 요건.
abstract final class NarcoticsJustificationFields {
  static const suspicionBasis = '마약류 혐의 reasonable suspicion (현장 정황·전과·행동)';
  static const refusalRecord = '간이시약 거부 경위·고지·녹화 기록';
  static const sampleChain = '채취·봉인·인도 chain of custody';
  static const warrantBasis = '감정처분허가장·압수수색영장 신청서 법리';
}

abstract final class SgpNarcoticsHandler {
  static final _narcKw =
      RegExp(r'(마약|대마|필로폰|코카인|향정|마약류|약물\s*투약|투약\s*정황|마약\s*소지)');
  static final _refusalKw =
      RegExp(r'(거부|거절|검사\s*안\s*함|검사\s*거부|채취\s*거부|간이\s*시약\s*거부|시약\s*거부)');
  static final _warrantKw =
      RegExp(r'(영장|감정처분|허가장|압수수색|채취\s*영장|감정\s*처분)');
  static final _suspicionKw =
      RegExp(r'(혐의|정황|전과|투약\s*흔적|눈동자|축\s*처|현장\s*발견|마약\s*도구)');

  /// 거부 시점 기준 영장 신청 권고 시한(실무 24h).
  static NarcoticsTimelineStatus timelineStatus({
    required DateTime refusalAt,
    required DateTime now,
    Duration deadline = const Duration(hours: 24),
  }) {
    final elapsed = now.difference(refusalAt);
    if (elapsed > deadline) return NarcoticsTimelineStatus.overdue;
    final remaining = deadline - elapsed;
    if (remaining <= const Duration(hours: 4)) {
      return NarcoticsTimelineStatus.urgent;
    }
    return NarcoticsTimelineStatus.onTrack;
  }

  static NarcoticsMandatoryResult analyze(
    String text, {
    DateTime? refusalAt,
    DateTime? now,
    bool hasRefusalRecord = false,
    bool hasSuspicionBasis = false,
    bool hasSampleChain = false,
    bool hasWarrantDraft = false,
  }) {
    final t = text.trim();
    final narc = _narcKw.hasMatch(t);
    final refused = _refusalKw.hasMatch(t) || (narc && text.contains('거부'));
    final hasWarrant = _warrantKw.hasMatch(t) || hasWarrantDraft;
    final hasSuspicion = _suspicionKw.hasMatch(t) || hasSuspicionBasis;

    NarcoticsScreeningStage stage;
    if (!narc) {
      stage = NarcoticsScreeningStage.fieldRapidTest;
    } else if (refused && hasWarrant) {
      stage = NarcoticsScreeningStage.searchSeizureWarrant;
    } else if (refused) {
      stage = NarcoticsScreeningStage.forensicWarrantApplication;
    } else {
      stage = NarcoticsScreeningStage.fieldRapidTest;
    }

    final missing = <String>[];
    if (refused && !hasRefusalRecord && !_refusalKw.hasMatch(t)) {
      missing.add(NarcoticsJustificationFields.refusalRecord);
    }
    if (refused && !hasSuspicion) {
      missing.add(NarcoticsJustificationFields.suspicionBasis);
    }
    if (refused && hasWarrant && !hasSampleChain) {
      missing.add(NarcoticsJustificationFields.sampleChain);
    }
    if (refused && !hasWarrant) {
      missing.add(NarcoticsJustificationFields.warrantBasis);
    }

    NarcoticsTimelineStatus tlStatus = NarcoticsTimelineStatus.onTrack;
    if (refused && refusalAt != null) {
      tlStatus = timelineStatus(
        refusalAt: refusalAt,
        now: now ?? DateTime.now(),
      );
    }

    final nodes = <String>['KR-LAW-NARCOTICS'];
    if (narc) nodes.add('KR-NARC-RAPID-TEST');
    if (refused) nodes.add('KR-NARC-FORCED-MEASURE');
    if (hasWarrant) nodes.add('KR-NARC-WARRANT');

    return NarcoticsMandatoryResult(
      narcoticsContext: narc,
      refusedRapidTest: refused,
      stage: stage,
      timelineStatus: tlStatus,
      justificationComplete: missing.isEmpty,
      missingJustifications: missing,
      rationale: _buildRationale(
        narc: narc,
        refused: refused,
        stage: stage,
        tlStatus: tlStatus,
        missing: missing,
      ),
      ontologyNodes: nodes,
    );
  }

  static String _buildRationale({
    required bool narc,
    required bool refused,
    required NarcoticsScreeningStage stage,
    required NarcoticsTimelineStatus tlStatus,
    required List<String> missing,
  }) {
    if (!narc) return '마약류 정황 미감지 — 일반 절차.';
    if (!refused) {
      return '마약류관리법 — 현장 간이시약 검사 제안·동의 확보 권고.';
    }
    final tl = switch (tlStatus) {
      NarcoticsTimelineStatus.onTrack => '영장 신청 시한 내.',
      NarcoticsTimelineStatus.urgent => '영장 신청 시한 4h 이내 — 긴급.',
      NarcoticsTimelineStatus.overdue => '영장 신청 시한 초과 — 즉시 소명·신청.',
    };
    final stageLabel = switch (stage) {
      NarcoticsScreeningStage.forensicWarrantApplication =>
        '감정처분허가장·압수수색영장 신청 단계.',
      NarcoticsScreeningStage.searchSeizureWarrant =>
        '압수수색·채취 영장 집행 준비.',
      _ => '강제처분 절차.',
    };
    if (missing.isNotEmpty) {
      return '간이시약 거부 — $stageLabel $tl 소명 누락: ${missing.join(', ')}.';
    }
    return '간이시약 거부 — $stageLabel $tl 소명 요건 충족.';
  }
}
