/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic UI Bus (Listenable) + Patent-3 Fail-Safe
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 글림파틱 Flush 상태 버스 — FlushGuard를 Listenable로 브리지.
library;

import 'package:flutter/foundation.dart';

import 'sgp_glymphatic_flush_guard.dart';
import 'sgp_glymphatic_input_lock.dart';
import 'widgets/sgp_glymphatic_dashboard.dart';

class SgpGlymphaticUiBus extends ChangeNotifier {
  SgpGlymphaticUiBus({SgpGlymphaticInputLock? inputLock})
      : guard = SgpGlymphaticFlushGuard(inputLock: inputLock) {
    guard.onChanged = notifyListeners;
  }

  final SgpGlymphaticFlushGuard guard;

  SgpGlymphaticInputLock get inputLock => guard.inputLock;

  GlymphaticDashboardSnapshot? _snapshot;

  bool get flushInProgress => guard.flushInProgress;

  /// 실제 화면 잠금 오버레이 표시 여부 (바이패스·타임아웃 반영).
  bool get overlayVisible => guard.overlayVisible;

  bool get overlayBypassed => guard.overlayBypassed;

  bool get forcedUnlockByTimeout => guard.forcedUnlockByTimeout;

  bool get inputQueuePaused => guard.inputQueuePaused;

  GlymphaticDashboardSnapshot? get snapshot => _snapshot;

  void setFlushing(bool value) {
    // 하위 호환 — Major 오버레이 수동 토글은 guard 경유
    if (value) {
      if (!guard.flushInProgress) {
        guard.inputLock.pause();
      }
    } else if (guard.inputLock.isPaused) {
      guard.inputLock.resume();
    }
    // Direct field access via session runner preferred; mirror for legacy.
    notifyListeners();
  }

  void publishSnapshot(GlymphaticDashboardSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  /// Major: 오버레이+입력락+3.5s Fail-Safe / Minor: 오버레이 우회.
  Future<T> runWithFlushOverlay<T>(
    Future<T> Function() action, {
    bool allowOverlay = true,
    Duration? maxTimeout,
  }) {
    return guard.runFlushSession(
      action,
      allowOverlay: allowOverlay,
      maxTimeout: maxTimeout,
    );
  }

  @override
  void dispose() {
    guard.dispose();
    super.dispose();
  }
}
