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
/// 특허 실증·발명챌린지용 글림파틱 자가치유 QA 시뮬레이터.
///
/// 특허 출원번호: [SgpGlymphaticController.patentApplicationNo]
library;

import 'dart:async';

import 'sgp_glymphatic_agent_node.dart';
import 'sgp_glymphatic_controller.dart';
import 'sgp_glymphatic_handshake.dart';
import 'sgp_glymphatic_monitor.dart';

/// 가상 노이즈 주입 — 엔트로피·토큰 포화 과부하 재현.
abstract final class GlymphaticNoiseInjector {
  static const defaultOntologyAnchors = [
    '형사소송법',
    '정당방위',
    '현장 수사',
    '증거 보전',
    '체포 절차',
  ];

  static const _semanticPollutionCorpus = [
    '비트코인 채굴 수익률 예측 마이닝 풀 해시레이트 분석',
    '우주여행 로켓 연료 소비량 예측 모델 시뮬레이션',
    '메타버스 NFT 거래량 주가 상관관계 딥러닝',
  ];

  /// 시맨틱 엔트로피를 [targetMin] 이상으로 강제 상승 (기본 0.70).
  static double injectSemanticPollution(
    SgpGlymphaticAgentNode node, {
    List<String> ontologyAnchors = defaultOntologyAnchors,
    double targetMin = 0.70,
  }) {
    for (final text in _semanticPollutionCorpus) {
      node.recordOutput(text);
      final entropy = node.semanticDeviation(ontologyAnchors);
      if (entropy >= targetMin) return entropy;
      node.appendContext(text);
    }
    node.recordOutput(_semanticPollutionCorpus.last);
    return node.semanticDeviation(ontologyAnchors);
  }

  /// 컨텍스트 윈도우를 [targetRatio] 이상으로 과부하 (기본 80%).
  static double injectContextOverload(
    SgpGlymphaticAgentNode node, {
    double targetRatio = 0.80,
    String? ontologyNodeId,
  }) {
    var guard = 0;
    while (node.tokenRatio < targetRatio && guard < 512) {
      node.appendContext(
        'GLYMPHATIC-QA-NOISE-${guard}x' * 8,
        ontologyNodeId: ontologyNodeId,
      );
      guard++;
    }
    return node.tokenRatio;
  }

  /// 현장 지령 컨텍스트(온톨로지 연결) + 노이즈 혼합 주입.
  static void injectMixedFieldNoise(
    SgpGlymphaticAgentNode node, {
    List<String> ontologyAnchors = defaultOntologyAnchors,
    double entropyTarget = 0.70,
    double saturationTarget = 0.80,
  }) {
    node.appendContext(
      '112 변사 현장 출동 형사소송법 체포 절차',
      ontologyNodeId: 'KR-LAW-FIELD-001',
    );
    injectContextOverload(
      node,
      targetRatio: saturationTarget,
      ontologyNodeId: null,
    );
    injectSemanticPollution(
      node,
      ontologyAnchors: ontologyAnchors,
      targetMin: entropyTarget,
    );
  }
}

/// 대시보드 동기화 검증용 메트릭 스냅샷 (Flutter 비의존).
class GlymphaticQaDashboardMetrics {
  const GlymphaticQaDashboardMetrics({
    required this.semanticEntropy,
    required this.contextSaturationRatio,
    required this.contextSaturationPercent,
    required this.activeNodeId,
    required this.mainState,
    required this.shadowState,
    required this.isFlushInFlight,
    required this.semanticDanger,
    required this.contextDanger,
    this.readyReport,
  });

  final double semanticEntropy;
  final double contextSaturationRatio;
  final double contextSaturationPercent;
  final String activeNodeId;
  final GlymphaticAgentState mainState;
  final GlymphaticAgentState shadowState;
  final bool isFlushInFlight;
  final bool semanticDanger;
  final bool contextDanger;
  final GlymphaticReadyStateReport? readyReport;

  bool get isHealthy =>
      !semanticDanger && !contextDanger && !isFlushInFlight;

  static GlymphaticQaDashboardMetrics capture({
    required SgpGlymphaticController controller,
    List<String> ontologyAnchors = GlymphaticNoiseInjector.defaultOntologyAnchors,
    bool monitorRunning = false,
  }) {
    final active = controller.activeNode;
    final entropy = active.semanticDeviation(ontologyAnchors);
    final ratio = active.tokenRatio;
    GlymphaticReadyStateReport? ready;
    if (controller.healLog.isNotEmpty) {
      ready = controller.healLog.last.flushReport.readyState;
    }

    return GlymphaticQaDashboardMetrics(
      semanticEntropy: entropy,
      contextSaturationRatio: ratio,
      contextSaturationPercent: ratio * 100,
      activeNodeId: active.nodeId,
      mainState: controller.mainNode.state,
      shadowState: controller.shadowNode.state,
      isFlushInFlight: controller.isFlushing,
      semanticDanger: entropy > SgpGlymphaticMonitor.semanticDeviationThreshold,
      contextDanger: ratio > SgpGlymphaticMonitor.contextRatioThreshold,
      readyReport: ready,
    );
  }

  static GlymphaticQaDashboardMetrics captureStandby({
    required SgpGlymphaticController controller,
    List<String> ontologyAnchors = GlymphaticNoiseInjector.defaultOntologyAnchors,
  }) {
    final standby = controller.standbyNode;
    final entropy = standby.semanticDeviation(ontologyAnchors);
    final ratio = standby.tokenRatio;
    return GlymphaticQaDashboardMetrics(
      semanticEntropy: entropy,
      contextSaturationRatio: ratio,
      contextSaturationPercent: ratio * 100,
      activeNodeId: controller.activeNode.nodeId,
      mainState: controller.mainNode.state,
      shadowState: controller.shadowNode.state,
      isFlushInFlight: controller.isFlushing,
      semanticDanger: entropy > SgpGlymphaticMonitor.semanticDeviationThreshold,
      contextDanger: ratio > SgpGlymphaticMonitor.contextRatioThreshold,
      readyReport: controller.healLog.isEmpty
          ? null
          : controller.healLog.last.flushReport.readyState,
    );
  }
}

/// 자가치유 시나리오 실행 결과.
class GlymphaticPatentQaRunResult {
  const GlymphaticPatentQaRunResult({
    required this.beforeDashboard,
    required this.afterHealDashboard,
    required this.afterFlushStandby,
    required this.afterRecoveryDashboard,
    required this.healEvent,
    required this.handshake,
    required this.monitorDetected,
  });

  final GlymphaticQaDashboardMetrics beforeDashboard;
  final GlymphaticQaDashboardMetrics afterHealDashboard;
  final GlymphaticQaDashboardMetrics afterFlushStandby;
  final GlymphaticQaDashboardMetrics afterRecoveryDashboard;
  final GlymphaticHealEvent healEvent;
  final GlymphaticHandshakeResult handshake;
  final GlymphaticMonitorSnapshot monitorDetected;
}

/// E2E 자가치유 시나리오 오케스트레이터.
class GlymphaticPatentQaSimulator {
  GlymphaticPatentQaSimulator({
    SgpGlymphaticController? controller,
    this.ontologyAnchors = GlymphaticNoiseInjector.defaultOntologyAnchors,
    this.monitorInterval = SgpGlymphaticMonitor.monitorInterval,
  }) : controller = controller ?? SgpGlymphaticController();

  final SgpGlymphaticController controller;
  final List<String> ontologyAnchors;
  final Duration monitorInterval;

  /// 노이즈 주입 → 모니터 포착 검증 → 핑퐁 핸드셰이킹 → 백그라운드 정화 → 대시보드 복구.
  ///
  /// [useMonitorDaemon]가 true이면 1초(또는 [daemonWaitOverride]) 감시 루프로 치유를 트리거한다.
  Future<GlymphaticPatentQaRunResult> runSelfHealScenario({
    double entropyTarget = 0.70,
    double saturationTarget = 0.80,
    Duration? daemonWaitOverride,
    bool useMonitorDaemon = false,
  }) async {
    final active = controller.activeNode;
    final fieldPacket = '112 변사 현장 지령 증거보전 KR-LAW-FIELD-001';
    controller.routeTraffic(fieldPacket);

    GlymphaticNoiseInjector.injectSemanticPollution(
      active,
      ontologyAnchors: ontologyAnchors,
      targetMin: entropyTarget,
    );
    GlymphaticNoiseInjector.injectContextOverload(
      active,
      targetRatio: saturationTarget,
    );

    final before = GlymphaticQaDashboardMetrics.capture(
      controller: controller,
      ontologyAnchors: ontologyAnchors,
    );

    final monitorSnap = SgpGlymphaticMonitor.evaluate(
      node: active,
      ontologyAnchors: ontologyAnchors,
      idleDuration: Duration.zero,
    );
    if (!monitorSnap.shouldHeal) {
      throw StateError(
        'QA precondition failed: monitor did not detect heal triggers '
        '(entropy=${before.semanticEntropy}, ratio=${before.contextSaturationRatio})',
      );
    }

    final healEvent = useMonitorDaemon
        ? await _triggerViaMonitorDaemon(daemonWaitOverride)
        : await controller.triggerSelfHealing(triggers: monitorSnap.triggers);
    if (healEvent == null) {
      throw StateError('Self-heal did not complete.');
    }

    final handshake = healEvent.handshake;
    final afterHeal = GlymphaticQaDashboardMetrics.capture(
      controller: controller,
      ontologyAnchors: ontologyAnchors,
    );

    final afterFlushStandby = GlymphaticQaDashboardMetrics.captureStandby(
      controller: controller,
      ontologyAnchors: ontologyAnchors,
    );

    // 현장 복구: 새 Active 노드의 노이즈를 제거하고 온톨로지 정렬 출력으로 대시보드 정상화.
    final recoveredActive = controller.activeNode;
    recoveredActive.clearContext();
    controller.recordInference(
      nodeId: recoveredActive.nodeId,
      output: '형사소송법 현장 수사 체포 절차 증거 보전 완료',
      latencyMs: 420,
    );
    recoveredActive.appendContext(
      '형사소송법 현장 수사 체포 절차 증거 보전',
      ontologyNodeId: 'KR-LAW-FIELD-001',
    );

    final afterRecovery = GlymphaticQaDashboardMetrics.capture(
      controller: controller,
      ontologyAnchors: ontologyAnchors,
    );

    return GlymphaticPatentQaRunResult(
      beforeDashboard: before,
      afterHealDashboard: afterHeal,
      afterFlushStandby: afterFlushStandby,
      afterRecoveryDashboard: afterRecovery,
      healEvent: healEvent,
      handshake: handshake,
      monitorDetected: monitorSnap,
    );
  }

  void dispose() => controller.dispose();

  Future<GlymphaticHealEvent?> _triggerViaMonitorDaemon(
    Duration? daemonWaitOverride,
  ) async {
    GlymphaticHealEvent? healEvent;
    await controller.startMonitorLoop(
      interval: daemonWaitOverride ?? monitorInterval,
    );
    final waitLoops = daemonWaitOverride != null ? 5 : 3;
    for (var i = 0; i < waitLoops; i++) {
      await Future<void>.delayed(daemonWaitOverride ?? monitorInterval);
      if (controller.healLog.isNotEmpty) {
        healEvent = controller.healLog.last;
        break;
      }
    }
    controller.stopMonitorLoop();
    return healEvent;
  }
}
