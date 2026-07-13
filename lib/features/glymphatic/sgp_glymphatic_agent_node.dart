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
/// 글림파틱 듀얼 에이전트 노드 — Main / Shadow 세션 상태.
library;

import 'dart:math' as math;

import '../agent/sgp_embedding.dart';
import '../agent/sgp_legal_ontology.dart';
import 'sgp_glymphatic_handshake.dart';

/// 에이전트 노드 운용 상태.
enum GlymphaticAgentState {
  active,
  throttled,
  sleeping,
  flushing,
  clean,
  ready,
}

/// 콘텍스트 토큰 파편.
class GlymphaticContextFragment {
  const GlymphaticContextFragment({
    required this.token,
    this.ontologyNodeId,
    this.createdAt,
    this.causalScore = 1.0,
  });

  final String token;
  final String? ontologyNodeId;
  final DateTime? createdAt;
  final double causalScore;

  bool get isOntologyLinked =>
      ontologyNodeId != null && ontologyNodeId!.isNotEmpty;

  GlymphaticContextFragment copyWith({
    String? ontologyNodeId,
    double? causalScore,
  }) =>
      GlymphaticContextFragment(
        token: token,
        ontologyNodeId: ontologyNodeId ?? this.ontologyNodeId,
        createdAt: createdAt,
        causalScore: causalScore ?? this.causalScore,
      );
}

/// 듀얼 에이전트 중 하나의 세션·메트릭 버퍼.
class SgpGlymphaticAgentNode {
  SgpGlymphaticAgentNode({
    required this.nodeId,
    this.maxWindowTokens = 8192,
  });

  final String nodeId;
  final int maxWindowTokens;

  GlymphaticAgentState state = GlymphaticAgentState.ready;
  bool throttleInput = false;
  bool readyForSwap = true;
  String? latestOutput;
  final List<GlymphaticContextFragment> _fragments = [];
  final Map<String, List<double>> _embeddingCache = {};
  final List<double> _latencyMsSamples = [];
  final Set<String> _ontologySessionNodeIds = {};

  int get contextTokenCount =>
      _fragments.fold<int>(0, (sum, f) => sum + f.token.length);

  double get tokenRatio => contextTokenCount / maxWindowTokens;

  bool get isThrottled =>
      throttleInput ||
      state == GlymphaticAgentState.throttled ||
      state == GlymphaticAgentState.sleeping ||
      state == GlymphaticAgentState.flushing;

  Set<String> get ontologySessionNodeIds =>
      Set<String>.unmodifiable(_ontologySessionNodeIds);

  void activate() {
    throttleInput = false;
    readyForSwap = false;
    state = GlymphaticAgentState.active;
  }

  void throttle() {
    throttleInput = true;
    readyForSwap = false;
    state = GlymphaticAgentState.throttled;
  }

  void enterSleepMode() {
    state = GlymphaticAgentState.sleeping;
    throttleInput = true;
  }

  void enterFlushing() {
    state = GlymphaticAgentState.flushing;
  }

  void markClean() {
    throttleInput = false;
    state = GlymphaticAgentState.clean;
  }

  /// 다음 스위칭 주기를 위한 예비(Standby) 노드 복귀.
  void markReadyForSwap() {
    throttleInput = false;
    readyForSwap = true;
    state = GlymphaticAgentState.ready;
  }

  void bindOntologySession(Iterable<String> nodeIds) {
    _ontologySessionNodeIds
      ..clear()
      ..addAll(nodeIds);
  }

  void appendContext(String token, {String? ontologyNodeId}) {
    if (token.trim().isEmpty) return;
    _fragments.add(
      GlymphaticContextFragment(
        token: token.trim(),
        ontologyNodeId: ontologyNodeId,
        createdAt: DateTime.now(),
      ),
    );
    _embeddingCache[token] = SgpEmbedding.embed(token);
    if (ontologyNodeId != null) {
      _ontologySessionNodeIds.add(ontologyNodeId);
    }
  }

  void recordOutput(String output) {
    latestOutput = output;
    appendContext(output);
  }

  void recordLatency(double milliseconds) {
    _latencyMsSamples.add(milliseconds);
    if (_latencyMsSamples.length > 32) {
      _latencyMsSamples.removeAt(0);
    }
  }

  /// 활성 노드 → 예비 노드 핸드셰이킹 (현장 지령·온톨로지 세션 무손실 이관).
  GlymphaticHandshakeResult handoverFrom(
    SgpGlymphaticAgentNode source, {
    List<String> pendingPackets = const [],
  }) {
    final transferredNodes = <String>{...source._ontologySessionNodeIds};
    var transferredCount = 0;

    for (final fragment in source._fragments) {
      appendContext(
        fragment.token,
        ontologyNodeId: fragment.ontologyNodeId,
      );
      transferredCount++;
      if (fragment.ontologyNodeId != null) {
        transferredNodes.add(fragment.ontologyNodeId!);
      }
    }

    for (final packet in pendingPackets) {
      appendContext(packet);
      transferredCount++;
    }

    if (source.latestOutput != null && source.latestOutput!.isNotEmpty) {
      latestOutput = source.latestOutput;
    }

    for (final sample in source._latencyMsSamples) {
      recordLatency(sample);
    }

    bindOntologySession(transferredNodes);
    activate();

    return GlymphaticHandshakeResult(
      sourceNodeId: source.nodeId,
      targetNodeId: nodeId,
      transferredFragments: transferredCount,
      transferredOntologyNodes: transferredNodes.toList(growable: false),
      pendingPacketsRelayed: pendingPackets.length,
      confirmed: state == GlymphaticAgentState.active,
    );
  }

  /// 온톨로지 그래프 기준 노드 ID 자동 매핑.
  int inferOntologyLinks(LegalOntologyGraph? ontology) {
    if (ontology == null) return 0;
    var linked = 0;
    for (var i = 0; i < _fragments.length; i++) {
      final f = _fragments[i];
      if (f.isOntologyLinked) continue;
      final match = _matchOntologyNode(f.token, ontology);
      if (match != null) {
        _fragments[i] = f.copyWith(ontologyNodeId: match);
        _ontologySessionNodeIds.add(match);
        linked++;
      }
    }
    return linked;
  }

  static String? _matchOntologyNode(String text, LegalOntologyGraph ontology) {
    final lower = text.toLowerCase();
    for (final node in ontology.nodes) {
      if (lower.contains(node.id.toLowerCase()) ||
          lower.contains(node.title.toLowerCase())) {
        return node.id;
      }
    }
    return null;
  }

  /// 온톨로지 이탈도(시맨틱 엔트로피).
  double semanticDeviation(List<String> ontologyAnchors) {
    final output = latestOutput;
    if (output == null || output.trim().isEmpty || ontologyAnchors.isEmpty) {
      return 0;
    }

    final outEmb = SgpEmbedding.embed(output);
    var bestSim = 0.0;
    for (final anchor in ontologyAnchors) {
      final sim = SgpEmbedding.cosineSimilarity(outEmb, SgpEmbedding.embed(anchor));
      if (sim > bestSim) bestSim = sim;
    }
    final embeddingDistance = 1.0 - bestSim;

    final anchorBlob = ontologyAnchors.join(' ').toLowerCase();
    final tokens = output
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) return embeddingDistance.clamp(0.0, 1.0);

    var overlap = 0;
    for (final token in tokens) {
      if (anchorBlob.contains(token)) overlap++;
    }
    final lexicalDistance = 1.0 - (overlap / tokens.length);

    return math.max(embeddingDistance, lexicalDistance).clamp(0.0, 1.0);
  }

  double getCurrentLatencyMs() {
    if (_latencyMsSamples.isEmpty) return 0;
    return _latencyMsSamples.reduce((a, b) => a + b) / _latencyMsSamples.length;
  }

  /// 온톨로지 노드 ID가 없는 파편만 제거.
  int pruneUnlinkedFragments() {
    final before = _fragments.length;
    _fragments.removeWhere((fragment) => !fragment.isOntologyLinked);
    final keptTokens = _fragments.map((f) => f.token).toSet();
    _embeddingCache.removeWhere((key, _) => !keptTokens.contains(key));
    return before - _fragments.length;
  }

  /// 시맨틱 노이즈·미연결 파편 제거 (온톨로지 매핑 파편만 유지).
  int pruneSemanticNoise({
    required LegalOntologyGraph? ontology,
    required List<String> ontologyAnchors,
    double noiseDeviationThreshold = 0.65,
  }) {
    if (ontology != null) {
      inferOntologyLinks(ontology);
    }
    final before = _fragments.length;
    _fragments.removeWhere((fragment) {
      if (fragment.isOntologyLinked) return false;
      if (ontology != null &&
          _matchOntologyNode(fragment.token, ontology) != null) {
        return false;
      }
      if (ontologyAnchors.isEmpty) return true;
      final deviation = semanticDeviation(ontologyAnchors);
      return deviation > noiseDeviationThreshold || fragment.causalScore < 0.35;
    });

    final keptTokens = _fragments.map((f) => f.token).toSet();
    _embeddingCache.removeWhere((key, _) => !keptTokens.contains(key));
    return before - _fragments.length;
  }

  /// 지정 토큰 파편·캐시 벡터 강제 소거.
  int removeTokens(Iterable<String> tokens) {
    final removeSet = tokens.toSet();
    final before = _fragments.length;
    _fragments.removeWhere((f) => removeSet.contains(f.token));
    for (final key in removeSet) {
      _embeddingCache.remove(key);
    }
    return before - _fragments.length;
  }

  /// 파편에 온톨로지 노드 ID를 사후 매핑.
  void relinkFragments(Map<String, String> tokenToNodeId) {
    for (var i = 0; i < _fragments.length; i++) {
      final link = tokenToNodeId[_fragments[i].token];
      if (link != null) {
        _fragments[i] = _fragments[i].copyWith(ontologyNodeId: link);
        _ontologySessionNodeIds.add(link);
      }
    }
  }

  void clearContext() {
    _fragments.clear();
    _embeddingCache.clear();
    _ontologySessionNodeIds.clear();
    latestOutput = null;
    _latencyMsSamples.clear();
  }

  /// 핵심 가중치(온톨로지 연결) 캐시만 Pruning.
  void optimizeMemoryCache({double minRetentionScore = 0.12}) {
    if (_embeddingCache.length <= 8) return;
    final scored = <MapEntry<String, double>>[];
    for (final entry in _embeddingCache.entries) {
      final linked = _fragments.any(
        (f) => f.token == entry.key && f.isOntologyLinked,
      );
      scored.add(MapEntry(entry.key, linked ? 1.0 : minRetentionScore));
    }
    scored.sort((a, b) => a.value.compareTo(b.value));
    final removeCount = (_embeddingCache.length * 0.35).ceil();
    for (var i = 0; i < removeCount && i < scored.length; i++) {
      _embeddingCache.remove(scored[i].key);
    }
  }

  List<GlymphaticContextFragment> get fragments => List.unmodifiable(_fragments);

  /// 공간 벡터 레이어(임베딩 캐시) 중심 — CrossModal 검증용.
  List<double> spatialVectorCentroid() {
    if (_embeddingCache.isEmpty) {
      return List<double>.filled(SgpEmbedding.dimension, 0);
    }
    final dim = SgpEmbedding.dimension;
    final acc = List<double>.filled(dim, 0);
    for (final vec in _embeddingCache.values) {
      for (var i = 0; i < dim && i < vec.length; i++) {
        acc[i] += vec[i];
      }
    }
    final count = _embeddingCache.length.toDouble();
    for (var i = 0; i < dim; i++) {
      acc[i] /= count;
    }
    var sumSq = 0.0;
    for (final x in acc) {
      sumSq += x * x;
    }
    if (sumSq == 0) return acc;
    final inv = 1.0 / math.sqrt(sumSq);
    return acc.map((x) => x * inv).toList();
  }
}
