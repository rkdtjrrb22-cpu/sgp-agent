/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Dynamic Edge-Cloud Hybrid Scheduler (Amdahl/Gunter v2)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 무선 음영·간헐 네트워크 대응 Edge Hybrid Mode.
///
/// RTT > 1500ms 또는 단절 시 Cloud N→0 수렴으로 인한 Amdahl 저하를 차단하고
/// Local ON-Device LLM/임베딩 풀로 즉시 스위칭한다.
library;

import 'sgp_amdahl_gunter_controller.dart';

/// 추론 배치 위치.
enum SgpInferencePlacement {
  /// 수사 넷 Cloud 워커 활용 가능.
  cloudHybrid,

  /// 온디바이스 LLM·임베딩만 (음영지역).
  edgeLocal,
}

/// 네트워크 관측 샘플.
class SgpNetworkProbe {
  const SgpNetworkProbe({
    required this.rttMs,
    required this.packetLossRate,
    this.connected = true,
    this.retransmissionDelayMs = 0,
  });

  /// Round-trip time (ms). 단절 시 ≥ 99999.
  final double rttMs;

  /// 0.0~1.0 패킷 유실률.
  final double packetLossRate;

  final bool connected;

  /// 재전송 누적 지연(ms) — 건터 α/β 보정용.
  final double retransmissionDelayMs;

  static const offline = SgpNetworkProbe(
    rttMs: 99999,
    packetLossRate: 1.0,
    connected: false,
    retransmissionDelayMs: 5000,
  );

  /// KPI: 음영 판정 임계 RTT.
  static const rttThresholdMs = 1500.0;

  /// 패킷 유실 급증 임계.
  static const packetLossSpike = 0.18;

  bool get isDegraded =>
      !connected ||
      rttMs > rttThresholdMs ||
      packetLossRate >= packetLossSpike;

  /// 네트워크 재전송 지연 비용 → α 가산.
  double get alphaRetransmissionCost =>
      (retransmissionDelayMs / 10000.0 + packetLossRate * 0.35).clamp(0.0, 0.45);

  /// 동기화 유실 일관성 패널티 → β 가산.
  double get betaSyncLossCost =>
      (packetLossRate * 0.08 + (isDegraded ? 0.04 : 0.0)).clamp(0.0, 0.20);

  SgpResourceSample toResourceSample({
    double cpuAvailability = 0.85,
    double memoryAvailability = 0.75,
    double queryTrafficRate = 0,
  }) {
    return SgpResourceSample(
      cpuAvailability: cpuAvailability,
      memoryAvailability: memoryAvailability,
      queryTrafficRate: queryTrafficRate,
      betaConsistencyLoad: betaSyncLossCost * 4,
      networkRttMs: connected ? rttMs : 99999,
      packetLossRate: packetLossRate,
      retransmissionDelayMs: retransmissionDelayMs,
    );
  }
}

/// Edge Hybrid 스위칭 결과.
class SgpEdgeHybridSwitchResult {
  const SgpEdgeHybridSwitchResult({
    required this.placement,
    required this.switchLatencyMs,
    required this.warmStartReady,
    required this.cloudSlotsForcedZero,
    required this.localPoolSlots,
    required this.adjustedAlpha,
    required this.adjustedBeta,
  });

  final SgpInferencePlacement placement;
  final double switchLatencyMs;
  final bool warmStartReady;
  final bool cloudSlotsForcedZero;
  final int localPoolSlots;
  final double adjustedAlpha;
  final double adjustedBeta;

  /// KPI: 오프라인 스위칭 지연 < 200ms.
  bool get meetsSwitchLatencyKpi => switchLatencyMs < 200;
}

/// Dynamic Edge-Cloud 스케줄러.
class SgpEdgeHybridScheduler {
  SgpEdgeHybridScheduler(this.controller);

  final SgpAmdahlGunterController controller;

  static const localWarmPoolSlots = 2;

  SgpInferencePlacement _placement = SgpInferencePlacement.cloudHybrid;
  SgpEdgeHybridSwitchResult? _lastSwitch;

  SgpInferencePlacement get placement => _placement;
  SgpEdgeHybridSwitchResult? get lastSwitch => _lastSwitch;
  bool get isEdgeLocal => _placement == SgpInferencePlacement.edgeLocal;

  /// 네트워크 프로브 반영 → Edge Hybrid 스위칭 (웜스타트).
  SgpEdgeHybridSwitchResult applyNetworkProbe(
    SgpNetworkProbe probe, {
    double? queryTrafficRate,
  }) {
    final sw = Stopwatch()..start();

    final sample = probe.toResourceSample(
      queryTrafficRate: queryTrafficRate ?? controller.queryTrafficRate,
    );
    final decision = controller.observe(sample);
    sw.stop();

    final latencyMs = sw.elapsedMicroseconds / 1000.0;

    if (probe.isDegraded || decision.edgeHybrid) {
      controller.pool.resize(localWarmPoolSlots);
      _placement = SgpInferencePlacement.edgeLocal;
      _lastSwitch = SgpEdgeHybridSwitchResult(
        placement: SgpInferencePlacement.edgeLocal,
        switchLatencyMs: latencyMs,
        warmStartReady: true,
        cloudSlotsForcedZero: true,
        localPoolSlots: localWarmPoolSlots,
        adjustedAlpha: decision.alpha,
        adjustedBeta: decision.beta,
      );
      return _lastSwitch!;
    }

    _placement = SgpInferencePlacement.cloudHybrid;
    _lastSwitch = SgpEdgeHybridSwitchResult(
      placement: SgpInferencePlacement.cloudHybrid,
      switchLatencyMs: latencyMs,
      warmStartReady: true,
      cloudSlotsForcedZero: false,
      localPoolSlots: decision.activeAgents,
      adjustedAlpha: decision.alpha,
      adjustedBeta: decision.beta,
    );
    return _lastSwitch!;
  }
}
