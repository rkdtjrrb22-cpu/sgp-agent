/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Self-Healing Context Purification Engine
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 *              : [20-Year Veteran Public Order & Security Operations Commander]
 * PATENT NO    : KR 10-2026-0128052 (Asynchronous Context Flush Mechanism)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 글림파틱 핑퐁 핸드셰이킹 결과.
library;

/// 노드 간 컨텍스트·온톨로지 세션 무손실 이관 결과.
class GlymphaticHandshakeResult {
  const GlymphaticHandshakeResult({
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.transferredFragments,
    required this.transferredOntologyNodes,
    required this.pendingPacketsRelayed,
    required this.confirmed,
  });

  final String sourceNodeId;
  final String targetNodeId;
  final int transferredFragments;
  final List<String> transferredOntologyNodes;
  final int pendingPacketsRelayed;
  final bool confirmed;

  bool get isLossless => confirmed && transferredFragments >= 0;
}

/// Flush 완료 후 Ready 상태 리포트.
class GlymphaticReadyStateReport {
  const GlymphaticReadyStateReport({
    required this.nodeId,
    required this.isClean,
    required this.readyForSwap,
    required this.retainedFragments,
    required this.prunedNoiseFragments,
  });

  final String nodeId;
  final bool isClean;
  final bool readyForSwap;
  final int retainedFragments;
  final int prunedNoiseFragments;
}
