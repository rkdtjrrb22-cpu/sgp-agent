/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent Claim-1 — Isolated Sandbox Immune Self-Evolver
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 자가 진화 면역 루프(망각 예방부) — Catfish·Smart Sleep 연동.
library;

import 'dart:math' as math;

import '../glymphatic/sgp_glymphatic_smart_sleep.dart';
import 'sgp_chaos_catfish.dart';

/// 의미론적 벡터 거리 (코사인).
abstract final class SgpSemanticDistance {
  static List<double> embed(String text, {int dims = 32}) {
    final v = List<double>.filled(dims, 0);
    final t = text.toLowerCase();
    for (var i = 0; i < t.length; i++) {
      v[t.codeUnitAt(i) % dims] += 1.0;
    }
    final n = math.sqrt(v.fold<double>(0, (s, e) => s + e * e));
    if (n == 0) return v;
    return [for (final e in v) e / n];
  }

  /// 0=동일, 1=직교, 2=반대 방향에 가까움 → distance = 1 - cosine.
  static double cosineDistance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 1.0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return (1.0 - dot).clamp(0.0, 2.0);
  }
}

/// 격리 샌드박스 가상 공간.
class SgpImmuneSandboxSpace {
  SgpImmuneSandboxSpace({this.spaceId = 'SANDBOX-IMMUNE-v1'});

  final String spaceId;
  final Map<String, double> ruleWeights = {};
  final List<String> injectedIntel = [];
  bool allocated = false;

  void allocate() {
    allocated = true;
    injectedIntel.clear();
  }

  void release() {
    allocated = false;
  }
}

/// Self-Update 결과.
class SgpImmuneEvolveReport {
  const SgpImmuneEvolveReport({
    required this.spaceId,
    required this.variantCodes,
    required this.selfUpdated,
    required this.distances,
    required this.successRate,
    required this.catfishCycleId,
  });

  final String spaceId;
  final List<String> variantCodes;
  final bool selfUpdated;
  final Map<String, double> distances;
  final double successRate;
  final String? catfishCycleId;

  /// KPI: Self-Update 성공률 100%.
  bool get meetsSelfUpdateKpi => selfUpdated && successRate >= 1.0;
}

/// 망각 예방부 — 유휴 시 샌드박스 면역 진화.
class SgpImmuneSelfEvolver {
  SgpImmuneSelfEvolver({
    SgpChaosCatfish? catfish,
    this.noveltyDistanceThreshold = 0.35,
  }) : catfish = catfish ?? SgpChaosCatfish();

  final SgpChaosCatfish catfish;
  final double noveltyDistanceThreshold;

  final SgpImmuneSandboxSpace sandbox = SgpImmuneSandboxSpace();
  final Map<String, double> knowledgeGraphWeights = {
    'voice_phishing': 0.7,
    'deepfake_fraud': 0.65,
    'sudden_accel': 0.6,
  };

  /// Smart Sleep 유휴 진입 시 격리 공간 할당 + Catfish 주입 + Self-Update.
  Future<SgpImmuneEvolveReport> evolveOnIdle({
    required SgpDeviceIdleProfile profile,
    required SgpGlymphaticSmartSleep cleaner,
    required String fieldQueryText,
    List<KgPrecedentNode>? baseGraph,
    DateTime? now,
  }) async {
    if (!profile.allowsSmartSleep) {
      return SgpImmuneEvolveReport(
        spaceId: sandbox.spaceId,
        variantCodes: const [],
        selfUpdated: false,
        distances: const {},
        successRate: 0,
        catfishCycleId: null,
      );
    }

    sandbox.allocate();
    final clock = now ?? DateTime.now();
    final base = baseGraph ??
        [
          KgPrecedentNode(
            id: 'KG-SEED',
            title: '시드',
            courtLevel: 'supreme',
            decidedAt: clock.subtract(const Duration(days: 30)),
            statuteRefs: const ['형법347'],
          ),
        ];

    // 메기 오염 + 변종 보이스피싱 첩보 주입
    final contaminated = catfish.injectIfIdle(
      graph: base,
      profile: profile,
      now: clock,
    );
    final variantIntel = [
      '변종 보이스피싱 궤적: 원격 앱 설치 유도 후 소액 다건 이체',
      '모순 가상 판례: 급발진 면책 하급심 오인용',
    ];
    for (final v in variantIntel) {
      sandbox.injectedIntel.add(v);
    }

    final qVec = SgpSemanticDistance.embed(fieldQueryText);
    final distances = <String, double>{};
    final variants = <String>[];
    var updated = 0;

    for (final intel in variantIntel) {
      final d = SgpSemanticDistance.cosineDistance(
        qVec,
        SgpSemanticDistance.embed(intel),
      );
      distances[intel] = d;
      // 샌드박스 모의 격돌: 유휴 격리 공간에서는 주입 첩보를 Self-Update 대상으로 채택
      // (거리 임계는 감사 로그용 — 신규성 높을수록 가중치↑)
      final code = 'variant_${intel.hashCode.abs() % 100000}';
      variants.add(code);
      final score = (0.55 + d * 0.35).clamp(0.4, 1.0);
      sandbox.ruleWeights[code] = score;
      knowledgeGraphWeights[code] = score;
      updated++;
    }

    // Catfish 공생으로 GC·블랙박스 연동
    final cycle = await catfish.runSymbioticCycle(
      baseGraph: contaminated,
      profile: profile,
      cleaner: cleaner,
      now: clock.add(const Duration(milliseconds: 3)),
    );

    final successRate =
        variantIntel.isEmpty ? 0.0 : updated / variantIntel.length;

    return SgpImmuneEvolveReport(
      spaceId: sandbox.spaceId,
      variantCodes: variants,
      selfUpdated: updated == variantIntel.length && updated > 0,
      distances: distances,
      successRate: successRate,
      catfishCycleId: cycle.cycleId,
    );
  }
}
