/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent Claim-1 — Gesture Trajectory Density (Pure Dart)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 다급성 인지부 순수 연산 — Flutter 비의존.
library;

/// 궤적 샘플 포인트.
class SgpTrajectoryPoint {
  const SgpTrajectoryPoint({
    required this.x,
    required this.y,
    required this.atMs,
  });

  final double x;
  final double y;
  final int atMs;
}

/// 다급성·압축 심도 스냅샷.
class SgpGestureUrgencySnapshot {
  const SgpGestureUrgencySnapshot({
    required this.trajectoryDensity,
    required this.compressionDepth,
    required this.isHighUrgency,
    required this.sampledAt,
    this.pathLengthPx = 0,
    this.spanMs = 0,
  });

  final double trajectoryDensity;
  final double compressionDepth;
  final bool isHighUrgency;
  final DateTime sampledAt;
  final double pathLengthPx;
  final int spanMs;

  bool get isPeakUrgency =>
      trajectoryDensity >= SgpGestureUrgencyDetector.peakThreshold;
}

/// [청구항 1] 다급성 인지부.
abstract final class SgpGestureUrgencyDetector {
  static const densityThreshold = 0.58;
  static const peakThreshold = 0.82;

  /// 단위 시간(ms)당 이동 거리 및 좌표 조밀도.
  static SgpGestureUrgencySnapshot calculateTrajectoryDensity(
    List<SgpTrajectoryPoint> points, {
    DateTime? at,
  }) {
    if (points.length < 2) {
      return SgpGestureUrgencySnapshot(
        trajectoryDensity: 0,
        compressionDepth: 0,
        isHighUrgency: false,
        sampledAt: at ?? DateTime.now(),
      );
    }

    var path = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      path += _sqrt(dx * dx + dy * dy);
    }

    final spanMs = (points.last.atMs - points.first.atMs).clamp(1, 1 << 30);
    final velocity = path / spanMs;

    var minX = points.first.x, maxX = points.first.x;
    var minY = points.first.y, maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final boxDiag = _sqrt(
      (maxX - minX) * (maxX - minX) + (maxY - minY) * (maxY - minY),
    ).clamp(1.0, double.infinity);
    final compactness = (path / boxDiag).clamp(0.0, 8.0) / 8.0;
    final speedNorm = (velocity / 2.5).clamp(0.0, 1.0);
    final density =
        (0.55 * speedNorm + 0.45 * compactness).clamp(0.0, 1.0);

    final compression = density >= densityThreshold
        ? (0.35 + density * 0.65).clamp(0.0, 1.0)
        : density * 0.35;

    return SgpGestureUrgencySnapshot(
      trajectoryDensity: density,
      compressionDepth: compression,
      isHighUrgency: density >= densityThreshold,
      sampledAt: at ?? DateTime.now(),
      pathLengthPx: path,
      spanMs: spanMs,
    );
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    var r = v;
    for (var i = 0; i < 10; i++) {
      r = 0.5 * (r + v / r);
    }
    return r;
  }
}
