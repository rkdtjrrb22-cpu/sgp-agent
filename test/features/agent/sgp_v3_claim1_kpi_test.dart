/// SGP-Agent v3 Claim-1 KPI — 다급성·암달·면역·글림파틱 정제.
library;

import 'package:test/test.dart';

import 'package:sgp_agent/features/agent/sgp_amdahl_switching_controller.dart';
import 'package:sgp_agent/features/agent/sgp_chaos_catfish.dart';
import 'package:sgp_agent/features/agent/sgp_gesture_urgency_math.dart';
import 'package:sgp_agent/features/agent/sgp_glymphatic_overlay_purifier.dart';
import 'package:sgp_agent/features/agent/sgp_immune_self_evolver.dart';
import 'package:sgp_agent/features/control/sgp_amdahl_gunter_controller.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_policy.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_scheduler.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_smart_sleep.dart';
import 'package:sgp_agent/features/security/sgp_legal_blackbox.dart';

void main() {
  group('Task8 Gesture density', () {
    test('calculateTrajectoryDensity raises compression on high density', () {
      final pts = <SgpTrajectoryPoint>[];
      var t = 1000;
      for (var i = 0; i < 40; i++) {
        pts.add(SgpTrajectoryPoint(
          x: (i % 2) * 80.0,
          y: i * 30.0,
          atMs: t,
        ));
        t += 8;
      }
      final snap =
          SgpGestureUrgencyDetector.calculateTrajectoryDensity(pts);
      expect(snap.trajectoryDensity, greaterThan(0.3));
      expect(snap.compressionDepth, greaterThan(0));
    });

    test('sparse slow path stays low density', () {
      final snap = SgpGestureUrgencyDetector.calculateTrajectoryDensity(const [
        SgpTrajectoryPoint(x: 0, y: 0, atMs: 0),
        SgpTrajectoryPoint(x: 2, y: 1, atMs: 500),
      ]);
      expect(snap.isHighUrgency, isFalse);
      expect(snap.compressionDepth, lessThan(0.4));
    });
  });

  group('Task9 Amdahl switching KPI', () {
    test('peak urgency → sequential core + Minor glymphatic ≤200ms', () {
      final gunter = SgpAmdahlGunterController();
      final gly = SgpGlymphaticScheduler(controller: gunter);
      final ctrl = SgpAmdahlSwitchingController.linked(
        controller: gunter,
        glymphaticScheduler: gly,
      );

      final peak = SgpGestureUrgencySnapshot(
        trajectoryDensity: 0.95,
        compressionDepth: 0.9,
        isHighUrgency: true,
        sampledAt: DateTime.utc(2026, 7, 19),
      );
      expect(peak.isPeakUrgency, isTrue);

      final decision = ctrl.applyUrgency(peak);
      expect(decision.forcedByUrgency, isTrue);
      expect(
        decision.sequentialCores,
        contains(SequentialLegalCore.constitutionArt37Para2Proportionality),
      );
      expect(
        decision.sequentialCores,
        contains(SequentialLegalCore.criminalProcedureMandatory),
      );
      expect(decision.glymphaticMode, GlymphaticFlushMode.minor);
      expect(decision.meetsLatencyKpi, isTrue);
      expect(decision.switchLatencyMs, lessThanOrEqualTo(200));
      expect(gly.userQueryActive, isTrue);
    });
  });

  group('Task10 Immune self-evolver KPI', () {
    test('idle sandbox + catfish → Self-Update 100%', () async {
      final bb = SgpLegalBlackbox();
      final cleaner = SgpGlymphaticSmartSleep(blackbox: bb);
      final catfish = SgpChaosCatfish(blackbox: bb);
      final evolver = SgpImmuneSelfEvolver(catfish: catfish);
      const profile = SgpDeviceIdleProfile(
        isCharging: true,
        idleMinutes: 40,
        hourOfDay: 2,
      );

      final report = await evolver.evolveOnIdle(
        profile: profile,
        cleaner: cleaner,
        fieldQueryText: '단순 분실물 습득 신고 접수',
        now: DateTime.utc(2026, 7, 19, 2, 30),
      );

      expect(evolver.sandbox.allocated, isTrue);
      expect(report.selfUpdated, isTrue);
      expect(report.meetsSelfUpdateKpi, isTrue);
      expect(report.successRate, 1.0);
      expect(report.variantCodes, isNotEmpty);
      expect(bb.verifyChain().valid, isTrue);
    });
  });

  group('Task11 Overlay purifier KPI', () {
    test('LTP + chain + flush → entropy 0 + noise 100% + WORM', () async {
      final bb = SgpLegalBlackbox();
      final purifier = SgpGlymphaticOverlayPurifier(blackbox: bb);

      final report = await purifier.purifyOnDetection(
        crimeCode: 'voice_phishing',
        statements: const [
          '가짜 진술입니다 ㅋㅋ',
          '허위 팩트 주입 시도',
          '대포통장으로 이체 유도함',
          '노이즈',
        ],
        at: DateTime.utc(2026, 7, 19, 12),
      );

      expect(report.activatedChain, contains('voice_phishing'));
      expect(report.activatedChain.length, greaterThan(1));
      expect(report.flushedNoiseCount, greaterThanOrEqualTo(3));
      expect(report.bypassedFacts, contains('대포통장으로 이체 유도함'));
      expect(report.entropyAfter, 0.0);
      expect(report.noiseRemovalRate, 1.0);
      expect(report.meetsIntegrityKpi, isTrue);
      expect(report.blackboxSealed, isTrue);
      expect(bb.verifyChain().valid, isTrue);
      expect(bb.verifyChain().message, contains('100%'));
      expect(
        bb.chain.any((e) => e.operationalMode == 'glymphatic_overlay_purify'),
        isTrue,
      );
    });
  });
}
