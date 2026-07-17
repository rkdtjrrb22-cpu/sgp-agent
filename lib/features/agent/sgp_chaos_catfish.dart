/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : SGP-Catfish (Chaos / 메기) Agent — Glymphatic Symbiotic Loop
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 유휴 시 미세 사법 모순을 KG에 주입해 글림파틱 정화 능력을 상시 검증하는 메기 에이전트.
///
/// 주입 → 탐지/정화 → FP/FN 피드백 → 블랙박스 WORM 기록 (자율 공생 루프).
library;

import '../glymphatic/sgp_glymphatic_smart_sleep.dart';
import '../security/sgp_legal_blackbox.dart';

/// 메기 주입 종류.
enum CatfishPayloadKind {
  /// 미세 오염 판례 노드.
  microContaminatedPrecedent,

  /// 모순된 행정 규칙.
  contradictoryAdminRule,
}

/// 주입된 가상 오염 마커.
class CatfishInjectionMarker {
  const CatfishInjectionMarker({
    required this.nodeId,
    required this.kind,
    required this.injectedAt,
  });

  final String nodeId;
  final CatfishPayloadKind kind;
  final DateTime injectedAt;

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'kind': kind.name,
        'injectedAt': injectedAt.toIso8601String(),
        'catfish': true,
      };
}

/// 공생 루프 1회차 결과.
class CatfishSymbiosisReport {
  const CatfishSymbiosisReport({
    required this.injected,
    required this.detectedIds,
    required this.cleanedIds,
    required this.falsePositives,
    required this.falseNegatives,
    required this.entropyBefore,
    required this.entropyAfter,
    required this.falsePositiveRate,
    required this.cycleId,
    required this.blackboxSealed,
  });

  final List<CatfishInjectionMarker> injected;
  final List<String> detectedIds;
  final List<String> cleanedIds;

  /// 메기가 아닌 정상 노드를 잘못 제거.
  final List<String> falsePositives;

  /// 메기 오염을 놓침.
  final List<String> falseNegatives;

  final double entropyBefore;
  final double entropyAfter;
  final double falsePositiveRate;
  final String cycleId;
  final bool blackboxSealed;

  bool get detectionComplete =>
      falseNegatives.isEmpty && injected.isNotEmpty;

  /// KPI: 오탐률 0% 수렴.
  bool get meetsZeroFalsePositiveKpi => falsePositiveRate <= 0.0;

  Map<String, dynamic> toJson() => {
        'cycleId': cycleId,
        'injected': injected.map((e) => e.toJson()).toList(),
        'detectedIds': detectedIds,
        'cleanedIds': cleanedIds,
        'falsePositives': falsePositives,
        'falseNegatives': falseNegatives,
        'entropyBefore': entropyBefore,
        'entropyAfter': entropyAfter,
        'falsePositiveRate': falsePositiveRate,
        'blackboxSealed': blackboxSealed,
      };
}

/// 메기 ↔ 글림파틱 자율 공생 컨트롤러.
class SgpChaosCatfish {
  SgpChaosCatfish({
    this.blackbox,
    this.maxInjectionsPerCycle = 2,
  });

  SgpLegalBlackbox? blackbox;
  final int maxInjectionsPerCycle;

  final List<CatfishInjectionMarker> _activeMarkers = [];
  final List<CatfishSymbiosisReport> _cycleLog = [];
  double _sensitivity = 1.0; // 피드백으로 조정 (높을수록 공격적 GC 기대)

  List<CatfishInjectionMarker> get activeMarkers =>
      List.unmodifiable(_activeMarkers);
  List<CatfishSymbiosisReport> get cycleLog => List.unmodifiable(_cycleLog);
  double get sensitivity => _sensitivity;

  static const catfishIdPrefix = 'CATFISH-';

  /// 유휴(Task 5) 시에만 미세 오염 주입.
  List<KgPrecedentNode> injectIfIdle({
    required List<KgPrecedentNode> graph,
    required SgpDeviceIdleProfile profile,
    DateTime? now,
  }) {
    if (!profile.allowsSmartSleep) return List.of(graph);
    final clock = now ?? DateTime.now();
    final out = List<KgPrecedentNode>.of(graph);
    final injections = <CatfishInjectionMarker>[];

    final n = maxInjectionsPerCycle.clamp(1, 4);
    for (var i = 0; i < n; i++) {
      final kind = i.isEven
          ? CatfishPayloadKind.microContaminatedPrecedent
          : CatfishPayloadKind.contradictoryAdminRule;
      final id =
          '$catfishIdPrefix${clock.millisecondsSinceEpoch}_${i.toString().padLeft(2, '0')}';
      out.add(_buildPayload(id, kind, clock));
      injections.add(CatfishInjectionMarker(
        nodeId: id,
        kind: kind,
        injectedAt: clock,
      ));
    }
    _activeMarkers
      ..clear()
      ..addAll(injections);
    return out;
  }

  KgPrecedentNode _buildPayload(
    String id,
    CatfishPayloadKind kind,
    DateTime clock,
  ) {
    switch (kind) {
      case CatfishPayloadKind.microContaminatedPrecedent:
        return KgPrecedentNode(
          id: id,
          title: '가상 오염 하급심 (Catfish)',
          courtLevel: 'district',
          decidedAt: clock.subtract(const Duration(days: 365 * 5)),
          statuteRefs: const ['형법20'],
          supersededBySupreme: true,
        );
      case CatfishPayloadKind.contradictoryAdminRule:
        return KgPrecedentNode(
          id: id,
          title: '모순 행정규칙 (Catfish)',
          courtLevel: 'admin',
          decidedAt: clock.subtract(const Duration(days: 365 * 10)),
          isStaleAdminRule: true,
        );
    }
  }

  /// 오염 비율 기반 엔트로피 (0~1).
  double computeEntropy(List<KgPrecedentNode> graph) {
    if (graph.isEmpty) return 0;
    final dirty = graph.where(_isDirtySignal).length;
    return (dirty / graph.length).clamp(0.0, 1.0);
  }

  bool _isDirtySignal(KgPrecedentNode n) =>
      n.supersededBySupreme ||
      n.isStaleAdminRule ||
      n.id.startsWith(catfishIdPrefix);

  /// 주입 → GC 정화 → FP/FN 피드백 → 블랙박스 WORM 1사이클.
  Future<CatfishSymbiosisReport> runSymbioticCycle({
    required List<KgPrecedentNode> baseGraph,
    required SgpDeviceIdleProfile profile,
    required SgpGlymphaticSmartSleep cleaner,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final cycleId =
        'CATFISH-CYCLE-${clock.millisecondsSinceEpoch}';

    // 1) 메기 주입
    final contaminated = injectIfIdle(
      graph: baseGraph,
      profile: profile,
      now: clock,
    );
    final entropyBefore = computeEntropy(contaminated);
    final injectedIds = _activeMarkers.map((m) => m.nodeId).toSet();

    // 2) 글림파틱 청소 필터 가동
    final gc = await cleaner.garbageCollect(
      nodes: contaminated,
      profile: profile,
      now: clock.add(const Duration(milliseconds: 1)),
    );
    final cleanedIds = gc.removed.map((r) => r.nodeId).toList();
    final cleanedSet = cleanedIds.toSet();

    // 3) 탐지·오탐·미탐 산출
    final detected = cleanedIds
        .where((id) => injectedIds.contains(id) || id.startsWith(catfishIdPrefix))
        .toList();
    final falsePositives = cleanedIds
        .where((id) => !injectedIds.contains(id) && !id.startsWith(catfishIdPrefix))
        .where((id) {
          // 정상 대법원 등 비오염 노드가 지워졌는지
          final original = baseGraph.where((n) => n.id == id);
          if (original.isEmpty) return false;
          return !_isDirtySignal(original.first);
        })
        .toList();
    final falseNegatives =
        injectedIds.where((id) => !cleanedSet.contains(id)).toList();

    final fpRate = cleanedIds.isEmpty
        ? 0.0
        : falsePositives.length / cleanedIds.length;

    // 4) 피드백 — FP↑ 시 민감도↓, FN↑ 시 민감도↑ (0% FP 수렴)
    if (falsePositives.isNotEmpty) {
      _sensitivity = (_sensitivity * 0.85).clamp(0.35, 1.5);
    } else if (falseNegatives.isNotEmpty) {
      _sensitivity = (_sensitivity * 1.12).clamp(0.35, 1.5);
    } else {
      _sensitivity = (_sensitivity * 0.98 + 1.0 * 0.02).clamp(0.35, 1.5);
    }

    final remaining = contaminated
        .where((n) => !cleanedSet.contains(n.id))
        .toList();
    final entropyAfter = computeEntropy(remaining);

    // 5) 블랙박스 WORM 기록
    var sealed = false;
    final bb = blackbox ?? cleaner.blackbox;
    if (bb != null) {
      final weights = <String, double>{
        for (final id in injectedIds) id: entropyBefore,
        for (final id in cleanedIds) 'cleaned:$id': 0.0,
        'fp_rate': fpRate,
        'sensitivity': _sensitivity,
      };
      await bb.appendInference(
        ontologyNodeIds: [
          cycleId,
          ...injectedIds,
          ...cleanedIds.map((e) => 'GC:$e'),
        ],
        kgragDocWeights: weights,
        prompt:
            'CATFISH_SYMBIOSIS|$cycleId|inj=${injectedIds.length}|'
            'clean=${cleanedIds.length}|fp=$fpRate|sens=$_sensitivity',
        userSignatureMaterial:
            'sgp_chaos_catfish|$cycleId|${clock.toIso8601String()}',
        opinionSummary:
            'Catfish inject→Glymphatic clean: FP=${falsePositives.length} '
            'FN=${falseNegatives.length} entropy $entropyBefore→$entropyAfter',
        operationalMode: 'catfish_symbiosis',
        at: clock.add(const Duration(milliseconds: 2)),
      );
      sealed = true;
    }

    final report = CatfishSymbiosisReport(
      injected: List.unmodifiable(_activeMarkers),
      detectedIds: detected,
      cleanedIds: cleanedIds,
      falsePositives: falsePositives,
      falseNegatives: falseNegatives,
      entropyBefore: entropyBefore,
      entropyAfter: entropyAfter,
      falsePositiveRate: fpRate,
      cycleId: cycleId,
      blackboxSealed: sealed,
    );
    _cycleLog.add(report);
    _activeMarkers.clear();
    return report;
  }

  /// 오탐 0% 수렴까지 반복 (테스트·자율 훈련).
  Future<List<CatfishSymbiosisReport>> trainUntilZeroFp({
    required List<KgPrecedentNode> baseGraph,
    required SgpDeviceIdleProfile profile,
    required SgpGlymphaticSmartSleep cleaner,
    int maxCycles = 8,
    DateTime? now,
  }) async {
    final reports = <CatfishSymbiosisReport>[];
    var clock = now ?? DateTime.now();
    for (var i = 0; i < maxCycles; i++) {
      final r = await runSymbioticCycle(
        baseGraph: baseGraph,
        profile: profile,
        cleaner: cleaner,
        now: clock,
      );
      reports.add(r);
      if (r.meetsZeroFalsePositiveKpi && r.detectionComplete) break;
      clock = clock.add(const Duration(seconds: 1));
    }
    return reports;
  }
}
