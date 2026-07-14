/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent-1 Urgency Detector (HCI Overlay Bypass)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052 (Urgency Gesture / Overlay Bypass)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 다급성 스크롤·터치 밀도 감지 — 글림파틱 오버레이 바이패스 HCI.
library;

/// 특허 1호: 현장 다급성 제스처 인식기 (순수 Dart — VM 테스트 가능).
class SgpGlymphaticUrgencyDetector {
  SgpGlymphaticUrgencyDetector({
    this.scrollVelocityThresholdPxPerSec = 1800.0,
    this.touchDensityThresholdPerSec = 4.0,
    this.urgencyHoldDuration = const Duration(seconds: 3),
    this.touchWindow = const Duration(seconds: 1),
    this.onChanged,
  });

  /// 초당 스크롤 속도 임계치(px/s).
  final double scrollVelocityThresholdPxPerSec;

  /// 1초 창 내 터치 횟수 임계치.
  final double touchDensityThresholdPerSec;

  /// 다급성 판정 유지 시간.
  final Duration urgencyHoldDuration;

  /// 터치 빈도 측정 윈도우.
  final Duration touchWindow;

  void Function()? onChanged;

  final List<DateTime> _touchTimestamps = <DateTime>[];
  DateTime? _urgencyUntil;
  DateTime? _lastScrollSampleAt;
  double _lastScrollPixels = 0;
  bool _isUrgentSituation = false;

  bool get isUrgentSituation {
    _refreshUrgency(DateTime.now());
    return _isUrgentSituation;
  }

  /// 테스트/시뮬레이터용 — 스크롤 속도(px/s)를 직접 주입.
  void injectScrollVelocity(double pxPerSec, {DateTime? now}) {
    final t = now ?? DateTime.now();
    if (pxPerSec.abs() >= scrollVelocityThresholdPxPerSec) {
      _armUrgency(t);
    }
  }

  /// 스크롤 위치 샘플 — Listener/ScrollController에서 호출.
  void onScrollPixels(double pixels, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final prevAt = _lastScrollSampleAt;
    final prevPx = _lastScrollPixels;
    _lastScrollSampleAt = t;
    _lastScrollPixels = pixels;
    if (prevAt == null) return;
    final dtMs = t.difference(prevAt).inMilliseconds;
    if (dtMs <= 0) return;
    final velocity = ((pixels - prevPx).abs() * 1000.0) / dtMs;
    if (velocity >= scrollVelocityThresholdPxPerSec) {
      _armUrgency(t);
    }
  }

  /// 포인터 다운 — 연타 밀도 측정.
  void onPointerDown({DateTime? now}) {
    final t = now ?? DateTime.now();
    _touchTimestamps.add(t);
    _touchTimestamps.removeWhere(
      (stamp) => t.difference(stamp) > touchWindow,
    );
    final density =
        _touchTimestamps.length / touchWindow.inMilliseconds * 1000.0;
    if (density >= touchDensityThresholdPerSec) {
      _armUrgency(t);
    }
  }

  /// 일반 인터랙션 — 다급성 만료만 재평가.
  void noteCalmInteraction() {
    _refreshUrgency(DateTime.now());
  }

  void clearUrgency() {
    _isUrgentSituation = false;
    _urgencyUntil = null;
    _touchTimestamps.clear();
    onChanged?.call();
  }

  void dispose() {
    _touchTimestamps.clear();
    _urgencyUntil = null;
  }

  void _armUrgency(DateTime t) {
    _urgencyUntil = t.add(urgencyHoldDuration);
    final was = _isUrgentSituation;
    _isUrgentSituation = true;
    if (!was) {
      onChanged?.call();
    }
  }

  void _refreshUrgency(DateTime t) {
    final until = _urgencyUntil;
    final still = until != null && t.isBefore(until);
    if (_isUrgentSituation && !still) {
      _isUrgentSituation = false;
      _urgencyUntil = null;
      onChanged?.call();
    }
  }
}
