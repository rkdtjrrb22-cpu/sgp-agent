/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Patent Verification Scenario (3-Claim Demo)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 특허 명세서 제출용 — 다급성 우회 ➔ 휴면 Major ➔ Fail-Safe 타임아웃 순차 검증.
library;

import 'dart:async';
import 'dart:io';

import 'package:sgp_agent/features/evidence/sgp_evidence_coc_engine.dart';
import 'package:sgp_agent/features/evidence/sgp_evidence_coc_secure_store.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_controller.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_guard.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_policy.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_urgency_detector.dart';
import 'package:test/test.dart';

void main() {
  group('patent_verification_scenario (P4 3-Claim Sequence)', () {
    test('1→2→3: urgency bypass → idle major → max flush timeout unlock',
        () async {
      // ─── 특허 1호: 다급성 스크롤 → 오버레이 바이패스 ───
      final detector = SgpGlymphaticUrgencyDetector(
        scrollVelocityThresholdPxPerSec: 1800,
        urgencyHoldDuration: const Duration(seconds: 3),
      );
      final controller = SgpGlymphaticController();
      final now = DateTime.utc(2026, 7, 14, 12, 0, 0);

      controller.noteUserInteraction(now);
      detector.injectScrollVelocity(2200, now: now);
      expect(detector.isUrgentSituation, isTrue);

      final urgentLane = SgpGlymphaticFlushPolicy.resolve(
        isUrgentSituation: detector.isUrgentSituation,
        lastUserInteractionTime: controller.lastUserInteractionTime,
        now: now,
      );
      expect(urgentLane, GlymphaticFlushPresentation.minorBackground);
      expect(SgpGlymphaticFlushPolicy.allowsOverlay(urgentLane), isFalse);
      expect(
        SgpGlymphaticFlushPolicy.modeFor(urgentLane),
        GlymphaticFlushMode.minor,
      );

      final minorEvent = await controller.triggerSelfHealing(
        mode: GlymphaticFlushMode.minor,
      );
      expect(minorEvent, isNotNull);
      expect(minorEvent!.flushReport.success, isTrue);
      expect(minorEvent.previousActiveId, minorEvent.newActiveId);

      // ─── 특허 2호: 10분+ Idle → Major Overlay 레인 ───
      detector.clearUrgency();
      final idleAt = now.add(const Duration(minutes: 11));
      final idleLane = SgpGlymphaticFlushPolicy.resolve(
        isUrgentSituation: false,
        lastUserInteractionTime: controller.lastUserInteractionTime,
        now: idleAt,
      );
      expect(idleLane, GlymphaticFlushPresentation.majorOverlay);
      expect(SgpGlymphaticFlushPolicy.allowsOverlay(idleLane), isTrue);
      expect(
        SgpGlymphaticFlushPolicy.modeFor(idleLane),
        GlymphaticFlushMode.major,
      );

      final busyLane = SgpGlymphaticFlushPolicy.resolve(
        isUrgentSituation: false,
        lastUserInteractionTime: idleAt,
        now: idleAt,
      );
      expect(busyLane, GlymphaticFlushPresentation.minorBackground);

      // ─── 특허 3호: 입력 락 + 3.5초 Max Flush Timeout Fail-Safe ───
      final guard = SgpGlymphaticFlushGuard();
      var sttPaused = false;
      guard.inputLock.onPauseSttStream = () => sttPaused = true;
      guard.inputLock.onResumeSttStream = () => sttPaused = false;

      final slowWork = Completer<void>();
      final runFuture = guard.runFlushSession(
        allowOverlay: true,
        maxTimeout: SgpGlymphaticFlushPolicy.maxFlushTimeout,
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 4500));
          slowWork.complete();
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(guard.overlayVisible, isTrue);
      expect(guard.inputQueuePaused, isTrue);
      expect(sttPaused, isTrue);
      guard.inputLock.enqueueOrPass('race-buffer-packet');
      expect(guard.inputLock.bufferedCount, greaterThan(0));

      await Future<void>.delayed(const Duration(milliseconds: 3600));
      expect(guard.forcedUnlockByTimeout, isTrue);
      expect(guard.overlayVisible, isFalse);
      expect(guard.inputQueuePaused, isFalse);
      expect(sttPaused, isFalse);

      await runFuture;
      expect(slowWork.isCompleted, isTrue);

      guard.dispose();
      controller.dispose();
      detector.dispose();
    });

    test('AES evidenceCoC vault remains offline-only during P4', () async {
      expect(SgpEvidenceCoCSecureStore.forbidsNetworkEgress, isTrue);
      final dir = await Directory.systemTemp.createTemp('sgp_p4_vault_');
      try {
        var session = SgpEvidenceCoCEngine.createSession(
          rawText: '블랙박스 임의제출',
        );
        session = SgpEvidenceCoCEngine.completeStep(
          session,
          EvidenceCoCStep.possessorClarified,
        );
        session = SgpEvidenceCoCEngine.completeStep(
          session,
          EvidenceCoCStep.selectiveSeizure,
        );
        session = SgpEvidenceCoCEngine.completeStep(
          session,
          EvidenceCoCStep.hashExtracted,
          hashSourcePayload: 'bbox|p4-patent',
        );
        final file = await SgpEvidenceCoCSecureStore.persistSession(
          session,
          directory: dir,
        );
        final loaded = await SgpEvidenceCoCSecureStore.loadFile(file);
        expect(loaded, isNotNull);
        expect(
          loaded!.steps[EvidenceCoCStep.hashExtracted]!.hashValue,
          session.steps[EvidenceCoCStep.hashExtracted]!.hashValue,
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
