/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent-2 Preventive Flush Scheduler + Lane Resolver
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052 (Work-Cycle Idle Major Flush)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 근무 주기(Idle Window) 기반 Major/Minor 세척 레인 결정.
library;

import 'sgp_glymphatic_monitor.dart';

/// 세척 실행 깊이.
enum GlymphaticFlushMode {
  /// 핑퐁 스왑 + 풀 Context Flush (화면 잠금 가능).
  major,

  /// Phagophore 미세 정제만 (오버레이 없음).
  minor,
}

/// UI 제시 방식.
enum GlymphaticFlushPresentation {
  /// 휴면 윈도우 — 오버레이 + 입력 락 + Major Flush.
  majorOverlay,

  /// 다급성 또는 비휴면 — 오버레이 바이패스 + Minor Flush.
  minorBackground,
}

/// 특허 2호·1호 연계 스케줄러/레인 해석기.
abstract final class SgpGlymphaticFlushPolicy {
  /// 앱 조작 없음 → Deep Sleep Zone (Major Flush 허용).
  static const Duration idleWindow = Duration(minutes: 10);

  /// 특허 3호 Fail-Safe — 오버레이 최대 유지 시간.
  static const Duration maxFlushTimeout = Duration(milliseconds: 3500);

  /// Monitor D 트리거와 동일한 휴면 임계 (단일한 명명 규칙).
  static const Duration workCycleIdle = SgpGlymphaticMonitor.idleTriggerDuration;

  static GlymphaticFlushPresentation resolve({
    required bool isUrgentSituation,
    required DateTime lastUserInteractionTime,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (isUrgentSituation) {
      return GlymphaticFlushPresentation.minorBackground;
    }
    final idleFor = clock.difference(lastUserInteractionTime);
    if (idleFor >= idleWindow) {
      return GlymphaticFlushPresentation.majorOverlay;
    }
    return GlymphaticFlushPresentation.minorBackground;
  }

  static GlymphaticFlushMode modeFor(GlymphaticFlushPresentation presentation) {
    return presentation == GlymphaticFlushPresentation.majorOverlay
        ? GlymphaticFlushMode.major
        : GlymphaticFlushMode.minor;
  }

  static bool allowsOverlay(GlymphaticFlushPresentation presentation) =>
      presentation == GlymphaticFlushPresentation.majorOverlay;
}
