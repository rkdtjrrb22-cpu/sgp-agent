/// Hybrid Architecture v2 — Edge / Smart Sleep / Blackbox / Catfish KPI 검증.
library;

import 'dart:io';

import 'package:test/test.dart';

import 'package:sgp_agent/features/agent/sgp_chaos_catfish.dart';
import 'package:sgp_agent/features/control/sgp_amdahl_gunter_controller.dart';
import 'package:sgp_agent/features/control/sgp_edge_hybrid_scheduler.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_policy.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_scheduler.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_smart_sleep.dart';
import 'package:sgp_agent/features/security/sgp_legal_blackbox.dart';
import 'package:sgp_agent/features/security/sgp_legal_blackbox_resiliency.dart';

void main() {
  group('Task4 Edge-Hybrid KPI', () {
    test('offline switch latency < 200ms and Local warm pool', () {
      final c = SgpAmdahlGunterController();
      final edge = SgpEdgeHybridScheduler(c);
      final result = edge.applyNetworkProbe(SgpNetworkProbe.offline);
      expect(result.placement, SgpInferencePlacement.edgeLocal);
      expect(result.cloudSlotsForcedZero, isTrue);
      expect(result.localPoolSlots, 2);
      expect(result.meetsSwitchLatencyKpi, isTrue);
      expect(result.switchLatencyMs, lessThan(200));
      expect(c.pool.maxSlots, 2);
    });

    test('RTT>1500ms triggers edge hybrid', () {
      final c = SgpAmdahlGunterController();
      final edge = SgpEdgeHybridScheduler(c);
      final result = edge.applyNetworkProbe(
        const SgpNetworkProbe(
          rttMs: 1800,
          packetLossRate: 0.05,
          retransmissionDelayMs: 400,
        ),
      );
      expect(result.placement, SgpInferencePlacement.edgeLocal);
      expect(c.lastDecision?.edgeHybrid, isTrue);
    });

    test('packet loss spikes raise α/β retransmission cost', () {
      final c = SgpAmdahlGunterController(alpha: 0.08, beta: 0.012);
      final beforeA = c.alpha;
      final beforeB = c.beta;
      c.observe(
        const SgpResourceSample(
          cpuAvailability: 0.8,
          memoryAvailability: 0.8,
          queryTrafficRate: 1,
          packetLossRate: 0.4,
          retransmissionDelayMs: 4000,
          networkRttMs: 2000,
        ),
      );
      expect(c.alpha, greaterThan(beforeA));
      expect(c.beta, greaterThan(beforeB));
    });

    test('healthy network stays cloud hybrid', () {
      final edge = SgpEdgeHybridScheduler(SgpAmdahlGunterController());
      final result = edge.applyNetworkProbe(
        const SgpNetworkProbe(rttMs: 40, packetLossRate: 0.01),
      );
      expect(result.placement, SgpInferencePlacement.cloudHybrid);
      expect(result.cloudSlotsForcedZero, isFalse);
    });
  });

  group('Task5 Smart Sleep / GC KPI', () {
    test('deep night activates Major I/O even from idle budget', () async {
      final c = SgpAmdahlGunterController();
      final sched = SgpGlymphaticScheduler(controller: c);
      final budget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.95,
          memoryAvailability: 0.95,
          queryTrafficRate: 0.1,
        ),
        idleProfile: const SgpDeviceIdleProfile(
          isCharging: true,
          idleMinutes: 40,
          hourOfDay: 2,
          backgroundCpuShare: 0.1,
        ),
      );
      expect(budget.allowClean, isTrue);
      expect(budget.preferredMode, GlymphaticFlushMode.major);
      expect(budget.smartSleepActive || budget.ioLimit > 0.5, isTrue);
    });

    test('concurrent user query keeps delay impact < 5% (Minor throttle)',
        () async {
      final c = SgpAmdahlGunterController();
      final sched = SgpGlymphaticScheduler(controller: c);
      final idleBudget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.9,
          memoryAvailability: 0.9,
          queryTrafficRate: 0.2,
        ),
        idleProfile: const SgpDeviceIdleProfile(
          isCharging: true,
          idleMinutes: 30,
          hourOfDay: 3,
        ),
      );
      sched.markUserQueryStarted();
      final busyBudget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.5,
          memoryAvailability: 0.5,
          queryTrafficRate: 3,
        ),
        idleProfile: const SgpDeviceIdleProfile(
          isCharging: true,
          idleMinutes: 30,
          hourOfDay: 3,
          userQueryActive: true,
        ),
      );
      expect(busyBudget.preferredMode, GlymphaticFlushMode.minor);
      expect(busyBudget.ioLimit, lessThan(idleBudget.ioLimit * 0.5 + 0.01));
    });

    test('GC removes conflicting lower-court and logs to blackbox', () async {
      final bb = SgpLegalBlackbox();
      final sleep = SgpGlymphaticSmartSleep(blackbox: bb);
      final now = DateTime.utc(2026, 7, 17);
      final report = await sleep.garbageCollect(
        profile: const SgpDeviceIdleProfile(
          isCharging: true,
          idleMinutes: 30,
          hourOfDay: 2,
        ),
        now: now,
        nodes: [
          KgPrecedentNode(
            id: 'SC-2024',
            title: '대법원',
            courtLevel: 'supreme',
            decidedAt: DateTime.utc(2024, 1, 1),
            statuteRefs: const ['형법20'],
          ),
          KgPrecedentNode(
            id: 'DC-2018',
            title: '지방법원 구판례',
            courtLevel: 'district',
            decidedAt: DateTime.utc(2018, 1, 1),
            statuteRefs: const ['형법20'],
            supersededBySupreme: true,
          ),
          KgPrecedentNode(
            id: 'ADMIN-OLD',
            title: '낡은 예규',
            courtLevel: 'admin',
            decidedAt: DateTime.utc(2010, 1, 1),
            isStaleAdminRule: true,
          ),
        ],
      );
      expect(report.removedCount, greaterThanOrEqualTo(2));
      expect(report.smartSleepActive, isTrue);
      expect(bb.length, 1);
      expect(bb.chain.first.operationalMode, 'glymphatic_gc');
      expect(bb.verifyChain().valid, isTrue);
    });
  });

  group('Task6 Blackbox resiliency KPI', () {
    test(
        'intranet disconnect queues enclave; reconnect restores without StateError',
        () async {
      final localDir = await Directory.systemTemp.createTemp('sgp_bb_local_');
      final ledgerDir = await Directory.systemTemp.createTemp('sgp_bb_ledger_');
      final enclaveDir = await Directory.systemTemp.createTemp('sgp_bb_enc_');
      addTearDown(() {
        localDir.deleteSync(recursive: true);
        ledgerDir.deleteSync(recursive: true);
        enclaveDir.deleteSync(recursive: true);
      });

      final bb = SgpLegalBlackbox(directory: localDir);
      await bb.appendInference(
        ontologyNodeIds: const ['N1'],
        kgragDocWeights: const {'c1': 0.9},
        prompt: 'p1',
        userSignatureMaterial: 's1',
        at: DateTime.utc(2026, 7, 17, 1),
      );
      await bb.appendInference(
        ontologyNodeIds: const ['N2'],
        kgragDocWeights: const {'c2': 0.8},
        prompt: 'p2',
        userSignatureMaterial: 's2',
        at: DateTime.utc(2026, 7, 17, 2),
      );

      final resiliency = SgpLegalBlackboxResiliency(
        blackbox: bb,
        ledger: SgpDirectoryLedgerSink(ledgerDir),
      );

      resiliency.setIntranetReachable(false);
      final queued = await resiliency.mirrorPending();
      expect(queued.queuedInEnclave, greaterThan(0));
      await resiliency.checkpointEnclave(enclaveDir);

      final resiliency2 = SgpLegalBlackboxResiliency(
        blackbox: bb,
        ledger: SgpDirectoryLedgerSink(ledgerDir),
      );
      await resiliency2.recoverEnclave(enclaveDir);
      expect(resiliency2.enclave.length, greaterThan(0));

      final restored = await resiliency2.restoreAfterReconnect();
      expect(restored.ok, isTrue);
      expect(bb.verifyChain().valid, isTrue);
      expect(bb.verifyChain().entryCount, greaterThanOrEqualTo(2));

      final again = await resiliency2.mirrorPending();
      expect(again.skippedExisting, greaterThan(0));
      expect(bb.verifyChain().message, contains('100%'));
    });

    test('force power-cut: hash integrity remains 100%', () async {
      final dir = await Directory.systemTemp.createTemp('sgp_bb_pwr_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bb = SgpLegalBlackbox(directory: dir);
      for (var i = 0; i < 5; i++) {
        await bb.appendInference(
          ontologyNodeIds: ['N$i'],
          kgragDocWeights: {'d$i': 0.5 + i * 0.05},
          prompt: 'prompt-$i',
          userSignatureMaterial: 'sig-$i',
          at: DateTime.utc(2026, 7, 17, 10, i),
        );
      }
      final bb2 = SgpLegalBlackbox(directory: dir);
      expect(await bb2.loadFromDisk(), 5);
      final audit = bb2.verifyChain();
      expect(audit.valid, isTrue);
      expect(audit.entryCount, 5);
      expect(audit.message, contains('100%'));
    });
  });

  group('Task7 SGP-Catfish symbiotic KPI', () {
    test('inject→glymphatic clean→WORM integrity 100% with FP=0', () async {
      final bb = SgpLegalBlackbox();
      final cleaner = SgpGlymphaticSmartSleep(blackbox: bb);
      final catfish = SgpChaosCatfish(blackbox: bb);
      const profile = SgpDeviceIdleProfile(
        isCharging: true,
        idleMinutes: 40,
        hourOfDay: 2,
      );
      final base = [
        KgPrecedentNode(
          id: 'SC-OK',
          title: '대법원 정상',
          courtLevel: 'supreme',
          decidedAt: DateTime.utc(2025, 1, 1),
          statuteRefs: const ['형법20'],
        ),
        KgPrecedentNode(
          id: 'LV2-OK',
          title: '형법 정상',
          courtLevel: 'supreme',
          decidedAt: DateTime.utc(2023, 1, 1),
        ),
      ];

      final report = await catfish.runSymbioticCycle(
        baseGraph: base,
        profile: profile,
        cleaner: cleaner,
        now: DateTime.utc(2026, 7, 17, 3),
      );

      expect(report.injected, isNotEmpty);
      expect(report.detectionComplete, isTrue);
      expect(report.meetsZeroFalsePositiveKpi, isTrue);
      expect(report.falsePositives, isEmpty);
      expect(report.falseNegatives, isEmpty);
      expect(report.entropyAfter, lessThan(report.entropyBefore));
      expect(report.blackboxSealed, isTrue);
      expect(bb.length, greaterThanOrEqualTo(2));
      final audit = bb.verifyChain();
      expect(audit.valid, isTrue);
      expect(audit.message, contains('100%'));
      expect(
        bb.chain.any((e) => e.operationalMode == 'catfish_symbiosis'),
        isTrue,
      );
    });

    test('non-idle skips injection (no false tension)', () async {
      final catfish = SgpChaosCatfish();
      final graph = [
        KgPrecedentNode(
          id: 'ONLY',
          title: '정상',
          courtLevel: 'supreme',
          decidedAt: DateTime.utc(2025, 1, 1),
        ),
      ];
      final out = catfish.injectIfIdle(
        graph: graph,
        profile: const SgpDeviceIdleProfile(
          isCharging: false,
          idleMinutes: 1,
          hourOfDay: 14,
          userQueryActive: true,
        ),
      );
      expect(out.length, 1);
      expect(catfish.activeMarkers, isEmpty);
    });

    test('trainUntilZeroFp converges FP to 0%', () async {
      final bb = SgpLegalBlackbox();
      final cleaner = SgpGlymphaticSmartSleep(blackbox: bb);
      final catfish = SgpChaosCatfish(blackbox: bb);
      final reports = await catfish.trainUntilZeroFp(
        baseGraph: [
          KgPrecedentNode(
            id: 'SC',
            title: '대법원',
            courtLevel: 'supreme',
            decidedAt: DateTime.utc(2024, 6, 1),
            statuteRefs: const ['형법20'],
          ),
        ],
        profile: const SgpDeviceIdleProfile(
          isCharging: true,
          idleMinutes: 30,
          hourOfDay: 1,
        ),
        cleaner: cleaner,
        maxCycles: 5,
        now: DateTime.utc(2026, 7, 17, 4),
      );
      expect(reports, isNotEmpty);
      expect(reports.last.meetsZeroFalsePositiveKpi, isTrue);
      expect(bb.verifyChain().valid, isTrue);
    });
  });
}
