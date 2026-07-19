/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent Claim-1 — Amdahl Serial/Parallel Switching Controller
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 암달 기반 직렬/병렬 분산 연산 스위칭 제어부 (Edge-Hybrid 연동).
library;

import '../control/sgp_amdahl_gunter_controller.dart';
import '../control/sgp_edge_hybrid_scheduler.dart';
import '../glymphatic/sgp_glymphatic_flush_policy.dart';
import '../glymphatic/sgp_glymphatic_scheduler.dart';
import 'sgp_gesture_urgency_math.dart';

/// 직렬 코어에 고정되는 법률 표준 요건.
enum SequentialLegalCore {
  criminalProcedureMandatory,
  constitutionArt37Para2Proportionality,
}

/// 병렬 풀에 할당되는 가변 연산.
enum ParallelWorkloadKind {
  precedentRagEmbedding,
  situationalIntelAnalysis,
}

/// 스위칭 결정 스냅샷.
class SgpAmdahlSwitchDecision {
  const SgpAmdahlSwitchDecision({
    required this.forcedByUrgency,
    required this.sequentialCores,
    required this.parallelKinds,
    required this.glymphaticMode,
    required this.switchLatencyMs,
    required this.amdahlSpeedup,
    required this.nMax,
    required this.activeAgents,
    required this.compressionDepth,
  });

  final bool forcedByUrgency;
  final List<SequentialLegalCore> sequentialCores;
  final List<ParallelWorkloadKind> parallelKinds;
  final GlymphaticFlushMode glymphaticMode;
  final double switchLatencyMs;
  final double amdahlSpeedup;
  final int nMax;
  final int activeAgents;
  final double compressionDepth;

  bool get meetsLatencyKpi => switchLatencyMs <= 200;
}

/// 암달 스위칭 제어부 — [SgpEdgeHybridScheduler] 연동.
class SgpAmdahlSwitchingController {
  SgpAmdahlSwitchingController._({
    required this.amdahlGunter,
    required this.edgeHybrid,
    this.glymphaticScheduler,
  });

  factory SgpAmdahlSwitchingController.linked({
    SgpAmdahlGunterController? controller,
    SgpGlymphaticScheduler? glymphaticScheduler,
  }) {
    final c = controller ?? SgpAmdahlGunterController();
    return SgpAmdahlSwitchingController._(
      amdahlGunter: c,
      edgeHybrid: SgpEdgeHybridScheduler(c),
      glymphaticScheduler: glymphaticScheduler,
    );
  }

  final SgpAmdahlGunterController amdahlGunter;
  final SgpEdgeHybridScheduler edgeHybrid;
  final SgpGlymphaticScheduler? glymphaticScheduler;

  SgpGestureUrgencySnapshot? _lastUrgency;
  SgpAmdahlSwitchDecision? _lastDecision;

  SgpGestureUrgencySnapshot? get lastUrgency => _lastUrgency;
  SgpAmdahlSwitchDecision? get lastDecision => _lastDecision;

  static const sequentialCorePinned = <SequentialLegalCore>[
    SequentialLegalCore.criminalProcedureMandatory,
    SequentialLegalCore.constitutionArt37Para2Proportionality,
  ];

  /// 다급성 스냅샷 반영 → 암달 스위칭 강제 발동.
  SgpAmdahlSwitchDecision applyUrgency(
    SgpGestureUrgencySnapshot urgency, {
    SgpNetworkProbe? network,
  }) {
    final sw = Stopwatch()..start();
    _lastUrgency = urgency;

    if (network != null) {
      edgeHybrid.applyNetworkProbe(network);
    }

    final forced = urgency.isPeakUrgency || urgency.isHighUrgency;
    if (forced) {
      amdahlGunter.recordSequentialGate();
      final sample = SgpResourceSample(
        cpuAvailability: urgency.isPeakUrgency ? 0.35 : 0.55,
        memoryAvailability: 0.5,
        queryTrafficRate:
            amdahlGunter.queryTrafficRate + urgency.trajectoryDensity * 4,
        networkRttMs: amdahlGunter.lastDecision?.networkRttMs ?? 0,
        packetLossRate: amdahlGunter.lastDecision?.packetLossRate ?? 0,
      );
      final decision = amdahlGunter.observe(sample);
      glymphaticScheduler?.markUserQueryStarted();

      final parallel = <ParallelWorkloadKind>[
        ParallelWorkloadKind.precedentRagEmbedding,
        if (!urgency.isPeakUrgency)
          ParallelWorkloadKind.situationalIntelAnalysis,
      ];
      for (final _ in parallel) {
        amdahlGunter.recordParallelWork();
      }

      sw.stop();
      final out = SgpAmdahlSwitchDecision(
        forcedByUrgency: true,
        sequentialCores: sequentialCorePinned,
        parallelKinds: parallel,
        glymphaticMode: GlymphaticFlushMode.minor,
        switchLatencyMs: sw.elapsedMicroseconds / 1000.0,
        amdahlSpeedup: decision.amdahlSpeedup,
        nMax: decision.nMax,
        activeAgents: decision.activeAgents,
        compressionDepth: urgency.compressionDepth,
      );
      _lastDecision = out;
      return out;
    }

    amdahlGunter.recordParallelWork();
    amdahlGunter.recordParallelWork();
    final decision = amdahlGunter.observe(
      SgpResourceSample(
        cpuAvailability: 0.8,
        memoryAvailability: 0.75,
        queryTrafficRate: amdahlGunter.queryTrafficRate,
      ),
    );
    glymphaticScheduler?.markUserQueryFinished();
    sw.stop();
    final out = SgpAmdahlSwitchDecision(
      forcedByUrgency: false,
      sequentialCores: sequentialCorePinned,
      parallelKinds: const [
        ParallelWorkloadKind.precedentRagEmbedding,
        ParallelWorkloadKind.situationalIntelAnalysis,
      ],
      glymphaticMode: GlymphaticFlushMode.major,
      switchLatencyMs: sw.elapsedMicroseconds / 1000.0,
      amdahlSpeedup: decision.amdahlSpeedup,
      nMax: decision.nMax,
      activeAgents: decision.activeAgents,
      compressionDepth: urgency.compressionDepth,
    );
    _lastDecision = out;
    return out;
  }

  Future<T> runParallel<T>(Future<T> Function() work) {
    return amdahlGunter.pool.run(work);
  }

  T runSequentialCore<T>(T Function() work) {
    amdahlGunter.recordSequentialGate();
    return work();
  }
}
