/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent-3 Flush Guard (Pure Dart Fail-Safe)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 오버레이 세션 가드 — 입력 락 + Max Flush Timeout (VM 테스트 가능).
library;

import 'dart:async';

import 'sgp_glymphatic_flush_policy.dart';
import 'sgp_glymphatic_input_lock.dart';

/// UI 버스가 위임하는 순수 세션 가드.
class SgpGlymphaticFlushGuard {
  SgpGlymphaticFlushGuard({SgpGlymphaticInputLock? inputLock})
      : inputLock = inputLock ?? SgpGlymphaticInputLock();

  final SgpGlymphaticInputLock inputLock;

  bool _flushInProgress = false;
  bool _overlayBypassed = false;
  bool _forcedUnlockByTimeout = false;
  Timer? _maxFlushTimeout;
  void Function()? onChanged;

  bool get flushInProgress => _flushInProgress;
  bool get overlayVisible => _flushInProgress && !_overlayBypassed;
  bool get overlayBypassed => _overlayBypassed;
  bool get forcedUnlockByTimeout => _forcedUnlockByTimeout;
  bool get inputQueuePaused => inputLock.isPaused;

  Future<T> runFlushSession<T>(
    Future<T> Function() action, {
    bool allowOverlay = true,
    Duration? maxTimeout,
  }) async {
    _forcedUnlockByTimeout = false;
    _overlayBypassed = !allowOverlay;
    _maxFlushTimeout?.cancel();

    if (allowOverlay) {
      _flushInProgress = true;
      inputLock.pause();
      _notify();
      _maxFlushTimeout = Timer(
        maxTimeout ?? SgpGlymphaticFlushPolicy.maxFlushTimeout,
        _forceUnlockFailSafe,
      );
    } else {
      _flushInProgress = false;
      _notify();
    }

    try {
      return await action();
    } finally {
      _maxFlushTimeout?.cancel();
      _maxFlushTimeout = null;
      if (allowOverlay) {
        if (inputLock.isPaused) {
          inputLock.resume();
        }
        _flushInProgress = false;
      }
      _overlayBypassed = false;
      _notify();
    }
  }

  void _forceUnlockFailSafe() {
    _forcedUnlockByTimeout = true;
    _overlayBypassed = false;
    if (inputLock.isPaused) {
      inputLock.resume();
    }
    _flushInProgress = false;
    _notify();
  }

  void _notify() => onChanged?.call();

  void dispose() {
    _maxFlushTimeout?.cancel();
    if (inputLock.isPaused) {
      inputLock.resume(drainBuffer: false);
    }
  }
}
