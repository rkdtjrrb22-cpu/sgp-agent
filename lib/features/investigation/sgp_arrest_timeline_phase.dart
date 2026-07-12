/// S11 — 48시간 인치 타임라인 게이지 단계 (순수 Dart).
library;

/// 체포 후 경과에 따른 게이지 단계.
enum ArrestTimelineBarPhase {
  /// T+0 ~ T+45h — 안전 구간.
  safe,

  /// T+45h ~ T+46h — 영장 초안 검토.
  warrantReview,

  /// T+46h ~ T+48h — 48시간 시한 임박.
  critical,
}

ArrestTimelineBarPhase resolveArrestBarPhase({
  required DateTime t0,
  required DateTime now,
}) {
  final elapsed = now.difference(t0);
  if (elapsed >= const Duration(hours: 46)) {
    return ArrestTimelineBarPhase.critical;
  }
  if (elapsed >= const Duration(hours: 45)) {
    return ArrestTimelineBarPhase.warrantReview;
  }
  return ArrestTimelineBarPhase.safe;
}
