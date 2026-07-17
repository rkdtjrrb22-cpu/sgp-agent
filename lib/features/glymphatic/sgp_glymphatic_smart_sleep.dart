/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Smart Sleep Mode + Ontology GC
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 심야·충전·유휴 감지 Smart Sleep + 오염 판례/낡은 조문 GC.
library;

import '../security/sgp_legal_blackbox.dart';
import 'sgp_glymphatic_flush_policy.dart';
import 'sgp_glymphatic_scheduler.dart';

/// 디바이스 유휴/충전/심야 프로파일.
class SgpDeviceIdleProfile {
  const SgpDeviceIdleProfile({
    required this.isCharging,
    required this.idleMinutes,
    required this.hourOfDay,
    this.backgroundCpuShare = 0.0,
    this.userQueryActive = false,
  });

  final bool isCharging;
  final double idleMinutes;
  final int hourOfDay; // 0~23
  final double backgroundCpuShare;
  final bool userQueryActive;

  /// 심야 창: 00:00–05:59
  bool get isDeepNight => hourOfDay >= 0 && hourOfDay < 6;

  /// Smart Sleep 진입 조건.
  bool get allowsSmartSleep =>
      !userQueryActive &&
      (isDeepNight || isCharging || idleMinutes >= 25) &&
      backgroundCpuShare < 0.35;

  SgpDeviceIdleProfile copyWith({
    bool? isCharging,
    double? idleMinutes,
    int? hourOfDay,
    double? backgroundCpuShare,
    bool? userQueryActive,
  }) {
    return SgpDeviceIdleProfile(
      isCharging: isCharging ?? this.isCharging,
      idleMinutes: idleMinutes ?? this.idleMinutes,
      hourOfDay: hourOfDay ?? this.hourOfDay,
      backgroundCpuShare: backgroundCpuShare ?? this.backgroundCpuShare,
      userQueryActive: userQueryActive ?? this.userQueryActive,
    );
  }
}

/// GC로 제거된 오염/충돌 노드 기록.
class GlymphaticGcRemoval {
  const GlymphaticGcRemoval({
    required this.nodeId,
    required this.reason,
    required this.removedAt,
  });

  final String nodeId;
  final String reason;
  final DateTime removedAt;

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'reason': reason,
        'removedAt': removedAt.toIso8601String(),
      };
}

/// 온톨로지/판례 정합성 GC 결과.
class GlymphaticGcReport {
  const GlymphaticGcReport({
    required this.removed,
    required this.keptCount,
    required this.smartSleepActive,
  });

  final List<GlymphaticGcRemoval> removed;
  final int keptCount;
  final bool smartSleepActive;

  int get removedCount => removed.length;
}

/// 판례/조문 노드 (GC 입력용 경량 DTO).
class KgPrecedentNode {
  const KgPrecedentNode({
    required this.id,
    required this.title,
    required this.courtLevel,
    required this.decidedAt,
    this.statuteRefs = const [],
    this.supersededBySupreme = false,
    this.isStaleAdminRule = false,
  });

  final String id;
  final String title;

  /// supreme | appellate | district | admin
  final String courtLevel;
  final DateTime decidedAt;
  final List<String> statuteRefs;
  final bool supersededBySupreme;
  final bool isStaleAdminRule;
}

/// 스마트 슬립 + 가중치 정밀 정화 엔진.
class SgpGlymphaticSmartSleep {
  SgpGlymphaticSmartSleep({
    this.blackbox,
    this.nightMajorBoost = 1.0,
  });

  SgpLegalBlackbox? blackbox;
  final double nightMajorBoost;

  final List<GlymphaticGcRemoval> _lastRemovals = [];
  GlymphaticGcReport? _lastReport;

  GlymphaticGcReport? get lastReport => _lastReport;
  List<GlymphaticGcRemoval> get lastRemovals =>
      List.unmodifiable(_lastRemovals);

  /// Smart Sleep 시 Major I/O 예산 부스트.
  GlymphaticIoBudget boostBudgetIfSmartSleep({
    required GlymphaticIoBudget base,
    required SgpDeviceIdleProfile profile,
  }) {
    if (!profile.allowsSmartSleep) return base;
    if (!base.allowClean && base.ioLimit <= 0) {
      return GlymphaticIoBudget(
        ioLimit: 0.85 * nightMajorBoost,
        allowClean: true,
        preferredMode: GlymphaticFlushMode.major,
        fragmentBatchSize: 64,
        smartSleepActive: true,
      );
    }
    return GlymphaticIoBudget(
      ioLimit: (base.ioLimit * 1.35 * nightMajorBoost).clamp(0.0, 1.0),
      allowClean: true,
      preferredMode: GlymphaticFlushMode.major,
      fragmentBatchSize: mathMax(base.fragmentBatchSize, 48),
      smartSleepActive: true,
    );
  }

  /// 사용자 쿼리 동시 유입 시 Major→Minor 강제 (응답 딜레이 KPI).
  GlymphaticIoBudget throttleForConcurrentQuery(GlymphaticIoBudget budget) {
    if (!budget.allowClean) return budget;
    return GlymphaticIoBudget(
      ioLimit: budget.ioLimit * 0.2,
      allowClean: budget.ioLimit * 0.2 > 0.05,
      preferredMode: GlymphaticFlushMode.minor,
      fragmentBatchSize: mathMax(1, (budget.fragmentBatchSize * 0.25).round()),
      smartSleepActive: budget.smartSleepActive,
    );
  }

  /// 대법원 개정과 충돌하는 하급심·낡은 행정조문 GC.
  Future<GlymphaticGcReport> garbageCollect({
    required List<KgPrecedentNode> nodes,
    required SgpDeviceIdleProfile profile,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final supremeRefs = <String>{};
    for (final n in nodes) {
      if (n.courtLevel == 'supreme') {
        supremeRefs.addAll(n.statuteRefs);
      }
    }

    final kept = <KgPrecedentNode>[];
    final removed = <GlymphaticGcRemoval>[];

    for (final n in nodes) {
      String? reason;
      if (n.supersededBySupreme) {
        reason = '대법원 개정 판례에 의해 폐기된 하급심 노드';
      } else if (n.courtLevel != 'supreme' &&
          n.statuteRefs.any(supremeRefs.contains) &&
          n.decidedAt.isBefore(clock.subtract(const Duration(days: 365 * 3)))) {
        reason = '최근 대법원 조문 해석과 충돌하는 노후 하급심';
      } else if (n.isStaleAdminRule) {
        reason = '낡은 행정 조문 (stale admin rule)';
      }

      if (reason != null && profile.allowsSmartSleep) {
        removed.add(GlymphaticGcRemoval(
          nodeId: n.id,
          reason: reason,
          removedAt: clock,
        ));
      } else if (reason != null && !profile.allowsSmartSleep) {
        // 비-슬립: 영구 삭제 보류, 유지
        kept.add(n);
      } else {
        kept.add(n);
      }
    }

    _lastRemovals
      ..clear()
      ..addAll(removed);
    final report = GlymphaticGcReport(
      removed: List.unmodifiable(removed),
      keptCount: kept.length,
      smartSleepActive: profile.allowsSmartSleep,
    );
    _lastReport = report;

    // Task 6 블랙박스로 삭제 이력 즉시 전송
    final bb = blackbox;
    if (bb != null && removed.isNotEmpty) {
      final weights = <String, double>{
        for (final r in removed) r.nodeId: 0.0,
      };
      await bb.appendInference(
        ontologyNodeIds: removed.map((r) => r.nodeId).toList(),
        kgragDocWeights: weights,
        prompt: 'GLYMPHATIC_GC|${removed.map((r) => r.reason).join(';')}',
        userSignatureMaterial: 'glymphatic_gc_daemon|${clock.toIso8601String()}',
        opinionSummary:
            'GC removed ${removed.length} stale/conflicting nodes (Smart Sleep)',
        operationalMode: 'glymphatic_gc',
        at: clock,
      );
    }

    return report;
  }
}
