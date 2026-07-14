/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent-3 Input Buffer Lock (Race Condition Guard)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052 (Input Queue / STT Pause Transaction)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 오버레이 트리거와 동시 입력 큐·STT 스트림 일시정지 트랜잭션.
library;

import 'dart:collection';

/// 특허 3호: 입력 버퍼 락 + 재개 동기화.
class SgpGlymphaticInputLock {
  final Queue<String> _buffered = Queue<String>();
  bool _paused = false;

  /// STT/음성 스트림 pause — UI가 바인딩.
  void Function()? onPauseSttStream;

  /// STT/음성 스트림 resume.
  void Function()? onResumeSttStream;

  /// 버퍼 flush 시 페이로드 전달 (재개 후).
  void Function(String payload)? onDrainPayload;

  bool get isPaused => _paused;

  int get bufferedCount => _buffered.length;

  /// 오버레이 직전 동기 트랜잭션 — 큐 수용 + STT pause.
  void pause() {
    if (_paused) return;
    _paused = true;
    onPauseSttStream?.call();
  }

  /// 세척 종료 또는 Fail-Safe 타임아웃 시 재개.
  void resume({bool drainBuffer = true}) {
    if (!_paused) return;
    _paused = false;
    onResumeSttStream?.call();
    if (drainBuffer) {
      while (_buffered.isNotEmpty) {
        final payload = _buffered.removeFirst();
        onDrainPayload?.call(payload);
      }
    } else {
      _buffered.clear();
    }
  }

  /// 락 중 유입된 텍스트/터치 버퍼. pause 중이 아니면 즉시 전달.
  void enqueueOrPass(String payload) {
    if (_paused) {
      _buffered.addLast(payload);
      return;
    }
    onDrainPayload?.call(payload);
  }

  void clearBuffer() => _buffered.clear();
}
