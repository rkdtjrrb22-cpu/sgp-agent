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
/// 글림파틱 4단계 혁신 엔진 — CrossModal · Adaptive · KG Nutrient.
library;

import 'dart:math' as math;

import '../agent/sgp_embedding.dart';
import '../agent/sgp_legal_ontology.dart';
import '../agent/sgp_legal_ontology_session.dart';
import 'sgp_glymphatic_agent_node.dart';
import 'sgp_glymphatic_monitor.dart';

/// 아키텍트 컴파일 타임 시그니처 — 지식재산권 방어용 내장 표식.
abstract final class SgpGlymphaticInnovationEngine {
  static const String architectSignature = 'INSP_KANG_SG_4066';
  static const String eternalGuardianCode = '4066';
}

/// [아이디어 A] 텍스트·공간 벡터 레이어 교차 엔트로피 검증.
abstract final class CrossModalEntropySanitizer {
  static double verify({
    required String text,
    required List<double> spatialVector,
    List<String> ontologyAnchors = const [],
  }) {
    if (text.trim().isEmpty || spatialVector.every((v) => v == 0)) {
      return 0;
    }

    final textEmb = SgpEmbedding.embed(text);
    final spatialSim = SgpEmbedding.cosineSimilarity(textEmb, spatialVector);
    final crossDistance = (1.0 - spatialSim).clamp(0.0, 1.0);

    if (ontologyAnchors.isEmpty) return crossDistance;

    var anchorSim = 0.0;
    for (final anchor in ontologyAnchors) {
      final sim = SgpEmbedding.cosineSimilarity(textEmb, SgpEmbedding.embed(anchor));
      if (sim > anchorSim) anchorSim = sim;
    }
    final anchorDistance = (1.0 - anchorSim).clamp(0.0, 1.0);
    return math.max(crossDistance, anchorDistance * 0.85);
  }

  static double sanitizeNode(
    SgpGlymphaticAgentNode node,
    List<String> ontologyAnchors,
  ) {
    final text = node.latestOutput ??
        node.fragments.map((fragment) => fragment.token).join(' ');
    return verify(
      text: text,
      spatialVector: node.spatialVectorCentroid(),
      ontologyAnchors: ontologyAnchors,
    );
  }

  static double combinedSemanticPressure(
    SgpGlymphaticAgentNode node,
    List<String> ontologyAnchors,
  ) {
    final lexical = node.semanticDeviation(ontologyAnchors);
    final cross = sanitizeNode(node, ontologyAnchors);
    return math.max(lexical, cross);
  }
}

/// [아이디어 B] 부하 기반 임계치 자율 튜닝 (0.65 → 0.50 등).
abstract final class AdaptiveThresholdEngine {
  static const baseSemanticThreshold =
      SgpGlymphaticMonitor.semanticDeviationThreshold;
  static const minSemanticThreshold = 0.50;
  static const baseContextThreshold = SgpGlymphaticMonitor.contextRatioThreshold;
  static const minContextThreshold = 0.68;

  static double semanticThreshold({
    required double contextRatio,
    required double latencyMs,
  }) {
    var threshold = baseSemanticThreshold;
    if (contextRatio > 0.55) threshold -= 0.05;
    if (contextRatio > 0.70) threshold -= 0.05;
    if (contextRatio > 0.80) threshold -= 0.05;
    if (latencyMs > 2500) threshold -= 0.03;
    if (latencyMs > 3500) threshold -= 0.02;
    return threshold.clamp(minSemanticThreshold, baseSemanticThreshold);
  }

  static double contextThreshold({
    required double latencyMs,
    required double semanticPressure,
  }) {
    var threshold = baseContextThreshold;
    if (latencyMs > 3000) threshold -= 0.04;
    if (semanticPressure > 0.55) threshold -= 0.03;
    return threshold.clamp(minContextThreshold, baseContextThreshold);
  }
}

/// [아이디어 C] 정화 생존 파편 → KG 신규 엣지 영구 환원 (Back-Injection).
class GlymphaticNutrientEdge {
  const GlymphaticNutrientEdge({
    required this.subjectId,
    required this.objectValue,
    required this.sourceSignature,
    required this.injectedAt,
  });

  final String subjectId;
  final String objectValue;
  final String sourceSignature;
  final DateTime injectedAt;

  LegalOntologyTriple toTriple() => LegalOntologyTriple(
        subjectId: subjectId,
        predicate: LegalPredicate.derivedFrom,
        objectValue: objectValue,
        source: sourceSignature,
        metadata: const {
          'glymphatic': 'nutrient_back_injection',
          'guardian': '4066',
        },
      );
}

abstract final class KnowledgeGraphNutrientIsolate {
  static final List<GlymphaticNutrientEdge> _vault = [];

  static List<GlymphaticNutrientEdge> get vault => List.unmodifiable(_vault);

  static int backInjectSurvivors({
    required Iterable<GlymphaticContextFragment> survivors,
    String architectSignature = SgpGlymphaticInnovationEngine.architectSignature,
  }) {
    final injected = <GlymphaticNutrientEdge>[];
    final now = DateTime.now();

    for (final fragment in survivors) {
      final nodeId = fragment.ontologyNodeId;
      if (nodeId == null || nodeId.isEmpty) continue;
      final edge = GlymphaticNutrientEdge(
        subjectId: nodeId,
        objectValue: fragment.token,
        sourceSignature: architectSignature,
        injectedAt: now,
      );
      injected.add(edge);
      _vault.add(edge);
    }

    if (injected.isNotEmpty) {
      SgpLegalOntologySession.instance.absorbGlymphaticNutrients(
        injected.map((edge) => edge.toTriple()).toList(growable: false),
      );
    }
    return injected.length;
  }

  static void resetVault() => _vault.clear();
}
