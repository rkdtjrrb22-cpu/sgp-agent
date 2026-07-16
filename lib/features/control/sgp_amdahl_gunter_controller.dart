/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Amdahl / Gunter Autonomic Performance Controller
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 암달·건터 법칙 기반 현장/내근 하이브리드 자율 튜닝 컨트롤러.
///
/// Speedup_Amdahl = 1 / ((1-P) + P/N)
/// Speedup_Gunter(N) = N / (1 + α(N-1) + β N(N-1))
/// N_max = √((1-α)/β)
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

/// 부하·가용성 샘플 (온디바이스 추정값, 0.0~1.0).
class SgpResourceSample {
  const SgpResourceSample({
    required this.cpuAvailability,
    required this.memoryAvailability,
    required this.queryTrafficRate,
    this.betaConsistencyLoad = 0.0,
    this.timestamp,
  });

  /// 1.0 = 유휴, 0.0 = 포화.
  final double cpuAvailability;
  final double memoryAvailability;

  /// 초당 쿼리 유입량 (정규화 전 원시값).
  final double queryTrafficRate;

  /// 법령·판례 동기화 일관성 비용 부하 (β 패널티 추정).
  final double betaConsistencyLoad;

  final DateTime? timestamp;

  double get headroom =>
      ((cpuAvailability + memoryAvailability) / 2).clamp(0.0, 1.0);

  bool get isPeakTraffic =>
      queryTrafficRate >= 4.0 || betaConsistencyLoad >= 0.55;
}

/// 자율 조정 결정 스냅샷.
class SgpAutonomicDecision {
  const SgpAutonomicDecision({
    required this.nMax,
    required this.activeAgents,
    required this.asyncQueueBuffer,
    required this.glymphaticIoLimit,
    required this.allowGlymphaticClean,
    required this.amdahlSpeedup,
    required this.gunterSpeedup,
    required this.parallelFractionP,
    required this.alpha,
    required this.beta,
  });

  final int nMax;
  final int activeAgents;
  final int asyncQueueBuffer;
  final double glymphaticIoLimit;
  final bool allowGlymphaticClean;
  final double amdahlSpeedup;
  final double gunterSpeedup;
  final double parallelFractionP;
  final double alpha;
  final double beta;
}

/// Active Agent Pool — 건터 N 제한 하의 동시 워커 슬롯.
class SgpActiveAgentPool {
  SgpActiveAgentPool({int initialSlots = 2})
      : _slots = math.max(1, initialSlots);

  int _slots;
  int _inFlight = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  int get maxSlots => _slots;
  int get inFlight => _inFlight;
  int get queued => _waiters.length;

  void resize(int n) {
    _slots = math.max(1, n);
    _drain();
  }

  Future<T> run<T>(Future<T> Function() work) async {
    while (_inFlight >= _slots) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _inFlight++;
    try {
      return await work();
    } finally {
      _inFlight--;
      _drain();
    }
  }

  void _drain() {
    while (_inFlight < _slots && _waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (!next.isCompleted) next.complete();
    }
  }
}

/// 암달/건터 수학 유틸 (순수 함수).
abstract final class SgpAmdahlGunterMath {
  /// Speedup = 1 / ((1-P) + P/N)
  static double amdahlSpeedup({
    required double parallelFractionP,
    required int n,
  }) {
    final p = parallelFractionP.clamp(0.0, 1.0);
    final workers = math.max(1, n);
    final denom = (1.0 - p) + (p / workers);
    return denom <= 0 ? double.infinity : 1.0 / denom;
  }

  /// Speedup(N) = N / (1 + α(N-1) + β N(N-1))
  static double gunterSpeedup({
    required int n,
    required double alpha,
    required double beta,
  }) {
    final workers = math.max(1, n);
    final a = alpha.clamp(0.0, 1.0);
    final b = math.max(0.0, beta);
    final denom =
        1.0 + a * (workers - 1) + b * workers * (workers - 1);
    return denom <= 0 ? 0.0 : workers / denom;
  }

  /// N_max = √((1-α)/β) — β→0 이면 상한 클램프.
  static int nMax({
    required double alpha,
    required double beta,
    int hardCap = 16,
    int hardFloor = 1,
  }) {
    final a = alpha.clamp(0.0, 0.999);
    final b = beta;
    if (b <= 1e-12) return hardCap;
    final raw = math.sqrt((1.0 - a) / b);
    if (raw.isNaN || raw.isInfinite) return hardFloor;
    return raw.round().clamp(hardFloor, hardCap);
  }

  /// 정수 N에서 Gunter 곡선이 꺾이는 정점 탐색 (검증용).
  static int nMaxByScan({
    required double alpha,
    required double beta,
    int hardCap = 16,
  }) {
    var bestN = 1;
    var bestS = gunterSpeedup(n: 1, alpha: alpha, beta: beta);
    for (var n = 2; n <= hardCap; n++) {
      final s = gunterSpeedup(n: n, alpha: alpha, beta: beta);
      if (s > bestS) {
        bestS = s;
        bestN = n;
      }
    }
    return bestN;
  }
}

/// 자율 튜닝 피드백 루프 + 현장 Optimistic 큐 계측.
class SgpAmdahlGunterController {
  SgpAmdahlGunterController({
    double alpha = 0.08,
    double beta = 0.012,
    int initialAgents = 2,
    this.targetParallelFraction = 0.95,
    this.hardCap = 16,
  })  : _alpha = alpha.clamp(0.0, 0.999),
        _beta = math.max(1e-9, beta),
        pool = SgpActiveAgentPool(initialSlots: initialAgents);

  /// 현장 목표 P (비동기 이벤트 루프).
  final double targetParallelFraction;
  final int hardCap;

  double _alpha;
  double _beta;
  int _parallelTicks = 0;
  int _sequentialTicks = 0;
  int _asyncQueueBuffer = 32;
  SgpAutonomicDecision? _lastDecision;
  final Queue<DateTime> _ingressWindow = Queue<DateTime>();

  final SgpActiveAgentPool pool;

  double get alpha => _alpha;
  double get beta => _beta;
  int get asyncQueueBuffer => _asyncQueueBuffer;
  SgpAutonomicDecision? get lastDecision => _lastDecision;

  /// 관측된 병렬 비율 P.
  double get parallelFractionP {
    final total = _parallelTicks + _sequentialTicks;
    if (total == 0) return targetParallelFraction;
    return (_parallelTicks / total).clamp(0.0, 1.0);
  }

  bool get meetsFieldParallelSla => parallelFractionP >= targetParallelFraction;

  void setContentionParams({double? alpha, double? beta}) {
    if (alpha != null) _alpha = alpha.clamp(0.0, 0.999);
    if (beta != null) _beta = math.max(1e-9, beta);
  }

  /// 비동기(병렬) 구간 — KG-RAG·죄명 검색 등.
  void recordParallelWork() => _parallelTicks++;

  /// 순차(1-P) 구간 — 생체인식·전자서명·영장 최종승인.
  void recordSequentialGate() => _sequentialTicks++;

  void noteQueryIngress([DateTime? at]) {
    final t = at ?? DateTime.now();
    _ingressWindow.add(t);
    final cutoff = t.subtract(const Duration(seconds: 5));
    while (_ingressWindow.isNotEmpty &&
        _ingressWindow.first.isBefore(cutoff)) {
      _ingressWindow.removeFirst();
    }
  }

  double get queryTrafficRate => _ingressWindow.length / 5.0;

  /// 부하 샘플 반영 → N_max·버퍼·글림파틱 I/O 재계산.
  SgpAutonomicDecision observe(SgpResourceSample sample) {
    // 피크 타임: β 패널티 상승 반영
    final effectiveBeta = math.max(
      _beta,
      _beta * (1.0 + sample.betaConsistencyLoad * 3.0),
    );
    if (sample.isPeakTraffic) {
      _beta = math.min(0.25, effectiveBeta);
      _asyncQueueBuffer = math.min(256, (_asyncQueueBuffer * 1.5).round());
    } else {
      _beta = math.max(1e-9, _beta * 0.98 + 0.012 * 0.02);
      _asyncQueueBuffer = math.max(32, (_asyncQueueBuffer * 0.95).round());
    }

    final nMax = SgpAmdahlGunterMath.nMax(
      alpha: _alpha,
      beta: _beta,
      hardCap: hardCap,
    );
    // 가용 헤드룸에 따라 실제 슬롯 하향
    final headroomSlots =
        math.max(1, (nMax * sample.headroom).round()).clamp(1, nMax);
    pool.resize(headroomSlots);

    final p = parallelFractionP;
    final amdahl = SgpAmdahlGunterMath.amdahlSpeedup(
      parallelFractionP: p,
      n: headroomSlots,
    );
    final gunter = SgpAmdahlGunterMath.gunterSpeedup(
      n: headroomSlots,
      alpha: _alpha,
      beta: _beta,
    );

    // 글림파틱: 헤드룸 임계 이상에서만 I/O 허용
    final ioLimit = _glymphaticIoLimit(sample);
    final allowClean = sample.headroom >= 0.28 && !sample.isPeakTraffic;

    final decision = SgpAutonomicDecision(
      nMax: nMax,
      activeAgents: headroomSlots,
      asyncQueueBuffer: _asyncQueueBuffer,
      glymphaticIoLimit: ioLimit,
      allowGlymphaticClean: allowClean,
      amdahlSpeedup: amdahl,
      gunterSpeedup: gunter,
      parallelFractionP: p,
      alpha: _alpha,
      beta: _beta,
    );
    _lastDecision = decision;
    return decision;
  }

  double _glymphaticIoLimit(SgpResourceSample sample) {
    if (sample.headroom < 0.28) return 0.0;
    if (sample.isPeakTraffic) return 0.15;
    // 선형 스케일: headroom 0.28→0, 1.0→1.0
    return ((sample.headroom - 0.28) / 0.72).clamp(0.0, 1.0);
  }

  /// 현장 Optimistic UI — 즉시 ACK 후 백그라운드 큐에 실작업 적재.
  Future<T> enqueueOptimisticFieldQuery<T>({
    required T Function() optimisticAck,
    required Future<T> Function() backgroundWork,
  }) async {
    noteQueryIngress();
    recordParallelWork();
    final ack = optimisticAck();
    unawaited(pool.run(backgroundWork));
    return ack;
  }

  /// 내근 대용량 — 풀 슬롯에서 동기 완료 대기 (팩트체크 전 병렬 추출).
  Future<T> runInvestigationAnalysis<T>(Future<T> Function() work) {
    noteQueryIngress();
    recordParallelWork();
    return pool.run(work);
  }
}
