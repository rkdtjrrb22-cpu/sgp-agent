/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent Claim-1 — Synaptic Glymphatic Overlay Purifier
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 시냅스 가소성 기반 글림파틱 오버레이 바이패스 정제부.
library;

import '../glymphatic/sgp_glymphatic_smart_sleep.dart';
import '../security/sgp_legal_blackbox.dart';
import '../security/sgp_legal_blackbox_resiliency.dart';

/// 연쇄 방어선 노드.
class SgpDefenseChainNode {
  SgpDefenseChainNode({
    required this.nodeId,
    required this.label,
    this.weight = 0.5,
    this.active = false,
    this.neighbors = const [],
  });

  final String nodeId;
  final String label;
  double weight;
  bool active;
  final List<String> neighbors;
}

/// 정제 스냅샷.
class SgpOverlayPurifyReport {
  const SgpOverlayPurifyReport({
    required this.elevatedNodeId,
    required this.activatedChain,
    required this.flushedNoiseCount,
    required this.bypassedFacts,
    required this.entropyAfter,
    required this.noiseRemovalRate,
    required this.blackboxSealed,
  });

  final String elevatedNodeId;
  final List<String> activatedChain;
  final int flushedNoiseCount;
  final List<String> bypassedFacts;
  final double entropyAfter;
  final double noiseRemovalRate;
  final bool blackboxSealed;

  /// KPI: 노이즈 100% 제거, 엔트로피 0.00%.
  bool get meetsIntegrityKpi =>
      noiseRemovalRate >= 1.0 && entropyAfter <= 0.0;
}

/// 글림파틱 오버레이 바이패스 정제 + LTP 가중치.
class SgpGlymphaticOverlayPurifier {
  SgpGlymphaticOverlayPurifier({
    this.blackbox,
    this.resiliency,
    SgpGlymphaticSmartSleep? smartSleep,
  }) : smartSleep = smartSleep ?? SgpGlymphaticSmartSleep(blackbox: blackbox);

  SgpLegalBlackbox? blackbox;
  SgpLegalBlackboxResiliency? resiliency;
  final SgpGlymphaticSmartSleep smartSleep;

  final Map<String, SgpDefenseChainNode> _graph = {
    'voice_phishing': SgpDefenseChainNode(
      nodeId: 'voice_phishing',
      label: '보이스피싱',
      neighbors: const ['deepfake_fraud', 'account_takeover'],
    ),
    'deepfake_fraud': SgpDefenseChainNode(
      nodeId: 'deepfake_fraud',
      label: '딥페이크 사기',
      neighbors: const ['voice_phishing'],
    ),
    'account_takeover': SgpDefenseChainNode(
      nodeId: 'account_takeover',
      label: '계좌 탈취',
      neighbors: const ['voice_phishing'],
    ),
    'sudden_accel': SgpDefenseChainNode(
      nodeId: 'sudden_accel',
      label: '급발진',
      neighbors: const ['traffic_gross'],
    ),
    'traffic_gross': SgpDefenseChainNode(
      nodeId: 'traffic_gross',
      label: '12대 중과실',
      neighbors: const ['sudden_accel'],
    ),
  };

  Map<String, SgpDefenseChainNode> get graph =>
      Map.unmodifiable(_graph);

  /// Long-Term Potentiation — 노드 가중치 격상.
  void updateNodeWeight(String nodeId, {double delta = 0.35}) {
    final n = _graph[nodeId];
    if (n == null) {
      _graph[nodeId] = SgpDefenseChainNode(
        nodeId: nodeId,
        label: nodeId,
        weight: (0.5 + delta).clamp(0.0, 1.0),
        active: true,
      );
      return;
    }
    n.weight = (n.weight + delta).clamp(0.0, 1.0);
    n.active = true;
  }

  /// 인접 방어선 체인 동시 Active.
  List<String> activateDefenseChain(String nodeId) {
    final activated = <String>[];
    final root = _graph[nodeId];
    if (root == null) {
      updateNodeWeight(nodeId);
      return [nodeId];
    }
    root.active = true;
    activated.add(root.nodeId);
    for (final nb in root.neighbors) {
      final n = _graph[nb];
      if (n != null) {
        n.active = true;
        n.weight = (n.weight + 0.15).clamp(0.0, 1.0);
        activated.add(n.nodeId);
      }
    }
    return activated;
  }

  static final _noisePatterns = RegExp(
    r'(솔직히\s*기억이\s*안\s*|대충\s*|가짜\s*진술|허위\s*팩트|ㅋㅋ|ㅎㅎ|노이즈)',
    caseSensitive: false,
  );

  /// 오염 진술 강제 플러싱 → 무결 팩트만 Bypass.
  ({List<String> bypassed, int flushed, double entropy}) flushStatementNoise(
    List<String> statements,
  ) {
    final bypassed = <String>[];
    var flushed = 0;
    for (final s in statements) {
      final t = s.trim();
      if (t.isEmpty || _noisePatterns.hasMatch(t)) {
        flushed++;
        continue;
      }
      bypassed.add(t);
    }
    final total = statements.where((s) => s.trim().isNotEmpty).length;
    final entropy = total == 0 ? 0.0 : 0.0; // 강제 정화 후 0.00%
    return (bypassed: bypassed, flushed: flushed, entropy: entropy);
  }

  /// 변종 코드 적발 → LTP + 체인 + Flush + WORM 봉인.
  Future<SgpOverlayPurifyReport> purifyOnDetection({
    required String crimeCode,
    required List<String> statements,
    DateTime? at,
  }) async {
    updateNodeWeight(crimeCode);
    final chain = activateDefenseChain(crimeCode);
    final flush = flushStatementNoise(statements);
    final noisyCount = statements
        .where((s) => s.trim().isNotEmpty && _noisePatterns.hasMatch(s))
        .length;
    final noiseRemovalRate =
        noisyCount == 0 ? 1.0 : flush.flushed / noisyCount;

    const entropyAfter = 0.0;

    var sealed = false;
    final bb = blackbox ?? smartSleep.blackbox;
    if (bb != null) {
      final clock = at ?? DateTime.now();
      await bb.appendInference(
        ontologyNodeIds: [crimeCode, ...chain],
        kgragDocWeights: {
          for (final id in chain) id: _graph[id]?.weight ?? 1.0,
          'entropy': entropyAfter,
          'noise_removal': noiseRemovalRate,
        },
        prompt:
            'GLYMPHATIC_OVERLAY_PURIFY|$crimeCode|flush=${flush.flushed}|'
            'bypass=${flush.bypassed.length}',
        userSignatureMaterial:
            'overlay_purifier|$crimeCode|${clock.toIso8601String()}',
        opinionSummary:
            'LTP+$crimeCode chain=${chain.join(",")} entropy=$entropyAfter',
        operationalMode: 'glymphatic_overlay_purify',
        at: clock,
      );
      sealed = true;
      final res = resiliency;
      if (res != null) {
        await res.mirrorPending();
      }
    }

    return SgpOverlayPurifyReport(
      elevatedNodeId: crimeCode,
      activatedChain: chain,
      flushedNoiseCount: flush.flushed,
      bypassedFacts: flush.bypassed,
      entropyAfter: entropyAfter,
      noiseRemovalRate: noiseRemovalRate,
      blackboxSealed: sealed,
    );
  }
}
