/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent Claim-1 — Gesture Trajectory Density Urgency Cognition
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 다급성 인지부 — Flutter Listener/Scroll 궤적 수집 + 순수 밀도 연산.
library;

import 'package:flutter/widgets.dart';

import 'sgp_gesture_urgency_math.dart';

export 'sgp_gesture_urgency_math.dart';

/// Flutter Listener 확장 — 터치 다운/무브/스크롤 궤적 수집.
class SgpGestureUrgencyScope extends StatefulWidget {
  const SgpGestureUrgencyScope({
    super.key,
    required this.child,
    this.onUrgency,
    this.windowMs = 400,
  });

  final Widget child;
  final void Function(SgpGestureUrgencySnapshot snapshot)? onUrgency;
  final int windowMs;

  @override
  State<SgpGestureUrgencyScope> createState() => _SgpGestureUrgencyScopeState();
}

class _SgpGestureUrgencyScopeState extends State<SgpGestureUrgencyScope> {
  final List<SgpTrajectoryPoint> _pts = [];

  void _push(Offset o) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _pts.add(SgpTrajectoryPoint(x: o.dx, y: o.dy, atMs: now));
    final cutoff = now - widget.windowMs;
    _pts.removeWhere((p) => p.atMs < cutoff);
    widget.onUrgency?.call(
      SgpGestureUrgencyDetector.calculateTrajectoryDensity(_pts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _push(e.localPosition),
      onPointerMove: (e) => _push(e.localPosition),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification) {
            final dy = n.scrollDelta ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            _pts.add(SgpTrajectoryPoint(x: 0, y: dy.abs() * 10, atMs: now));
            widget.onUrgency?.call(
              SgpGestureUrgencyDetector.calculateTrajectoryDensity(_pts),
            );
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
