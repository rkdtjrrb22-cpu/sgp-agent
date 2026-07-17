/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Async Isolation Scheduler (Gunter I/O Scaling)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 글림파틱 세척을 사용자 쿼리와 충돌하지 않도록 백그라운드 데몬으로 격리.
///
/// 건터 컨트롤러의 glymphaticIoLimit / allowGlymphaticClean에 따라
/// I/O 강도를 동적으로 스케일링한다.
library;

import 'dart:async';

import '../control/sgp_amdahl_gunter_controller.dart';
import 'sgp_glymphatic_flush_policy.dart';
import 'sgp_glymphatic_smart_sleep.dart';

/// 글림파틱 백그라운드 세척 I/O 예산.
class GlymphaticIoBudget {
  const GlymphaticIoBudget({
    required this.ioLimit,
    required this.allowClean,
    required this.preferredMode,
    required this.fragmentBatchSize,
    this.smartSleepActive = false,
  });

  /// 0.0 = 정지, 1.0 = 최대 강도.
  final double ioLimit;
  final bool allowClean;
  final GlymphaticFlushMode preferredMode;

  /// 한 틱당 처리할 파편 상한 (I/O 스케일).
  final int fragmentBatchSize;

  final bool smartSleepActive;

  static const idle = GlymphaticIoBudget(
    ioLimit: 0,
    allowClean: false,
    preferredMode: GlymphaticFlushMode.minor,
    fragmentBatchSize: 0,
  );
}

/// 세척 작업 콜백 — Isolate/컨트롤러 트리거는 호출측이 주입.
typedef GlymphaticCleanWork = Future<void> Function(GlymphaticIoBudget budget);

/// 유휴 Major 세척 직후 메기 공생 훅 (선택).
typedef CatfishIdleHook = Future<void> Function(
  GlymphaticIoBudget budget,
  SgpDeviceIdleProfile profile,
);

/// 건터 기반 글림파틱 백그라운드 스케줄러 (Worker Thread 역할).
class SgpGlymphaticScheduler {
  SgpGlymphaticScheduler({
    required this.controller,
    this.tickInterval = const Duration(seconds: 2),
    this.headroomThreshold = 0.28,
    SgpGlymphaticSmartSleep? smartSleep,
  }) : smartSleep = smartSleep ?? SgpGlymphaticSmartSleep();

  final SgpAmdahlGunterController controller;
  final Duration tickInterval;
  final double headroomThreshold;
  final SgpGlymphaticSmartSleep smartSleep;

  Timer? _daemon;
  bool _tickInFlight = false;
  bool _userQueryActive = false;
  int _deferredTicks = 0;
  GlymphaticIoBudget _lastBudget = GlymphaticIoBudget.idle;
  GlymphaticCleanWork? _cleanWork;
  CatfishIdleHook? catfishIdleHook;
  SgpDeviceIdleProfile Function()? idleProfileProvider;

  GlymphaticIoBudget get lastBudget => _lastBudget;
  bool get isDaemonRunning => _daemon != null;
  int get deferredTicks => _deferredTicks;
  bool get userQueryActive => _userQueryActive;

  /// 사용자 쿼리 진입 — 세척과 충돌 방지 플래그.
  void markUserQueryStarted() => _userQueryActive = true;

  void markUserQueryFinished() => _userQueryActive = false;

  /// 현재 리소스·트래픽으로 I/O 예산 산출.
  GlymphaticIoBudget resolveBudget(
    SgpResourceSample sample, {
    SgpDeviceIdleProfile? idleProfile,
  }) {
    final decision = controller.observe(sample);
    final profile = idleProfile ??
        idleProfileProvider?.call() ??
        SgpDeviceIdleProfile(
          isCharging: false,
          idleMinutes: 0,
          hourOfDay: DateTime.now().hour,
          userQueryActive: _userQueryActive,
        );

    GlymphaticIoBudget budget;
    if (!decision.allowGlymphaticClean || decision.glymphaticIoLimit <= 0) {
      budget = GlymphaticIoBudget.idle;
    } else if (_userQueryActive && sample.headroom < 0.55) {
      final limit = decision.glymphaticIoLimit * 0.25;
      budget = GlymphaticIoBudget(
        ioLimit: limit,
        allowClean: limit > 0.05,
        preferredMode: GlymphaticFlushMode.minor,
        fragmentBatchSize: mathMax(1, (8 * limit).round()),
      );
      budget = smartSleep.throttleForConcurrentQuery(budget);
    } else {
      final mode = sample.headroom >= 0.75 && !_userQueryActive
          ? GlymphaticFlushMode.major
          : GlymphaticFlushMode.minor;
      final batch = mathMax(1, (48 * decision.glymphaticIoLimit).round());
      budget = GlymphaticIoBudget(
        ioLimit: decision.glymphaticIoLimit,
        allowClean: true,
        preferredMode: mode,
        fragmentBatchSize: batch,
      );
    }

    budget = smartSleep.boostBudgetIfSmartSleep(
      base: budget,
      profile: profile.copyWith(userQueryActive: _userQueryActive),
    );

    if (_userQueryActive) {
      budget = smartSleep.throttleForConcurrentQuery(budget);
    }

    _lastBudget = budget;
    return _lastBudget;
  }

  /// 백그라운드 데몬 기동 — [cleanWork]는 Worker에서 비동기 실행.
  void startDaemon({
    required GlymphaticCleanWork cleanWork,
    SgpResourceSample Function()? sampleProvider,
  }) {
    stopDaemon();
    _cleanWork = cleanWork;
    _daemon = Timer.periodic(tickInterval, (_) {
      unawaited(_onTick(sampleProvider));
    });
  }

  void stopDaemon() {
    _daemon?.cancel();
    _daemon = null;
  }

  Future<void> _onTick(SgpResourceSample Function()? sampleProvider) async {
    if (_tickInFlight) return;
    final work = _cleanWork;
    if (work == null) return;

    _tickInFlight = true;
    try {
      final sample = sampleProvider?.call() ??
          SgpResourceSample(
            cpuAvailability: _userQueryActive ? 0.4 : 0.7,
            memoryAvailability: 0.65,
            queryTrafficRate: controller.queryTrafficRate,
          );
      final budget = resolveBudget(sample);
      if (!budget.allowClean || budget.ioLimit <= 0) {
        _deferredTicks++;
        return;
      }
      await work(budget);
      final profile = idleProfileProvider?.call() ??
          SgpDeviceIdleProfile(
            isCharging: false,
            idleMinutes: 0,
            hourOfDay: DateTime.now().hour,
            userQueryActive: _userQueryActive,
          );
      if (budget.smartSleepActive &&
          profile.allowsSmartSleep &&
          catfishIdleHook != null) {
        await catfishIdleHook!(budget, profile);
      }
    } finally {
      _tickInFlight = false;
    }
  }

  /// 즉시 1회 스케줄 평가 (테스트·강제 틱).
  Future<GlymphaticIoBudget> forceTick({
    required SgpResourceSample sample,
    GlymphaticCleanWork? work,
    SgpDeviceIdleProfile? idleProfile,
  }) async {
    final budget = resolveBudget(sample, idleProfile: idleProfile);
    final w = work ?? _cleanWork;
    if (w != null && budget.allowClean) {
      await w(budget);
    } else if (!budget.allowClean) {
      _deferredTicks++;
    }
    return budget;
  }
}

int mathMax(int a, int b) => a > b ? a : b;
