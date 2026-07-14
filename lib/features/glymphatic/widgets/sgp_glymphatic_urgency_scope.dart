/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Urgency HCI Scope (Listener)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// Listener 기반 다급성 제스처 스코프.
library;

import 'package:flutter/material.dart';

import '../sgp_glymphatic_urgency_detector.dart';

/// 터치·스크롤을 [SgpGlymphaticUrgencyDetector]에 피딩하는 랩퍼.
class SgpGlymphaticUrgencyScope extends StatelessWidget {
  const SgpGlymphaticUrgencyScope({
    super.key,
    required this.detector,
    required this.child,
    this.onUserInteraction,
  });

  final SgpGlymphaticUrgencyDetector detector;
  final Widget child;
  final VoidCallback? onUserInteraction;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        detector.onPointerDown();
        onUserInteraction?.call();
      },
      onPointerSignal: (_) {
        onUserInteraction?.call();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;
            detector.onScrollPixels(metrics.pixels);
            onUserInteraction?.call();
          }
          return false;
        },
        child: child,
      ),
    );
  }
}
