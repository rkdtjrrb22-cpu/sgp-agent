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
/// 글림파틱 모니터링 데몬 — 4대 트리거 센싱.
library;

import 'sgp_glymphatic_agent_node.dart';
import 'sgp_glymphatic_innovation_engine.dart';

/// 트리거 유형.
enum GlymphaticTrigger {
  semanticPollution,
  contextSaturation,
  systemLatency,
  contextualIdle,
}

class GlymphaticMonitorSnapshot {
  const GlymphaticMonitorSnapshot({
    required this.semanticDeviation,
    required this.contextRatio,
    required this.averageLatencyMs,
    required this.idleDuration,
    required this.triggers,
    required this.shouldHeal,
    this.adaptiveSemanticThreshold,
    this.adaptiveContextThreshold,
    this.crossModalEntropy,
  });

  final double semanticDeviation;
  final double contextRatio;
  final double averageLatencyMs;
  final Duration idleDuration;
  final List<GlymphaticTrigger> triggers;
  final bool shouldHeal;
  final double? adaptiveSemanticThreshold;
  final double? adaptiveContextThreshold;
  final double? crossModalEntropy;
}

abstract final class SgpGlymphaticMonitor {
  static const semanticDeviationThreshold = 0.65;
  static const contextRatioThreshold = 0.75;
  static const latencyThresholdMs = 3500.0;
  static const idleTriggerDuration = Duration(minutes: 10);
  static const monitorInterval = Duration(seconds: 1);

  static GlymphaticMonitorSnapshot evaluate({
    required SgpGlymphaticAgentNode node,
    required List<String> ontologyAnchors,
    required Duration idleDuration,
    int queueIngressCount = 0,
    bool useAdaptiveThresholds = true,
    bool useCrossModalSanitizer = true,
  }) {
    final crossModal = useCrossModalSanitizer
        ? CrossModalEntropySanitizer.sanitizeNode(node, ontologyAnchors)
        : 0.0;
    final semantic = useCrossModalSanitizer
        ? CrossModalEntropySanitizer.combinedSemanticPressure(
            node,
            ontologyAnchors,
          )
        : node.semanticDeviation(ontologyAnchors);
    final ratio = node.tokenRatio;
    final latency = node.getCurrentLatencyMs();

    final semanticCutoff = useAdaptiveThresholds
        ? AdaptiveThresholdEngine.semanticThreshold(
            contextRatio: ratio,
            latencyMs: latency,
          )
        : semanticDeviationThreshold;
    final contextCutoff = useAdaptiveThresholds
        ? AdaptiveThresholdEngine.contextThreshold(
            latencyMs: latency,
            semanticPressure: semantic,
          )
        : contextRatioThreshold;

    final triggers = <GlymphaticTrigger>[];

    if (semantic > semanticCutoff) {
      triggers.add(GlymphaticTrigger.semanticPollution);
    }
    if (ratio > contextCutoff) {
      triggers.add(GlymphaticTrigger.contextSaturation);
    }
    if (latency > latencyThresholdMs) {
      triggers.add(GlymphaticTrigger.systemLatency);
    }
    if (queueIngressCount == 0 && idleDuration >= idleTriggerDuration) {
      triggers.add(GlymphaticTrigger.contextualIdle);
    }

    return GlymphaticMonitorSnapshot(
      semanticDeviation: semantic,
      contextRatio: ratio,
      averageLatencyMs: latency,
      idleDuration: idleDuration,
      triggers: triggers,
      shouldHeal: triggers.isNotEmpty,
      adaptiveSemanticThreshold: semanticCutoff,
      adaptiveContextThreshold: contextCutoff,
      crossModalEntropy: crossModal,
    );
  }
}
