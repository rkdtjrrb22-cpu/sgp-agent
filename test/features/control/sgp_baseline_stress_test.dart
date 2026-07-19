/// 가상 치안 음영지역·대부하 스트레스 검증 (하이브리드 v2 베이스라인).
///
/// 시나리오: 터널/지하 RTT 폭증, 패킷 유실, 동시 쿼리 폭주, Catfish 자정.
library;

import 'dart:async';

import 'package:test/test.dart';

import 'package:sgp_agent/features/agent/sgp_chaos_catfish.dart';
import 'package:sgp_agent/features/control/sgp_amdahl_gunter_controller.dart';
import 'package:sgp_agent/features/control/sgp_edge_hybrid_scheduler.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_policy.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_scheduler.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_smart_sleep.dart';
import 'package:sgp_agent/features/security/sgp_legal_blackbox.dart';

void main() {
  group('음영지역 Edge-Hybrid 스트레스', () {
    test('터널 진입: RTT 계단식 악화 → Edge 전환 < 200ms, Cloud N 차단', () {
      final c = SgpAmdahlGunterController();
      final edge = SgpEdgeHybridScheduler(c);

      // 지상 → 양호
      var r = edge.applyNetworkProbe(
        const SgpNetworkProbe(rttMs: 45, packetLossRate: 0.0),
      );
      expect(r.placement, SgpInferencePlacement.cloudHybrid);

      // 지하 진입 직전
      r = edge.applyNetworkProbe(
        const SgpNetworkProbe(rttMs: 900, packetLossRate: 0.08),
      );
      expect(r.placement, SgpInferencePlacement.cloudHybrid);

      // 터널 심부 — 음영
      final sw = Stopwatch()..start();
      r = edge.applyNetworkProbe(
        const SgpNetworkProbe(
          rttMs: 2200,
          packetLossRate: 0.35,
          retransmissionDelayMs: 3500,
          connected: true,
        ),
      );
      sw.stop();
      expect(r.placement, SgpInferencePlacement.edgeLocal);
      expect(r.cloudSlotsForcedZero, isTrue);
      expect(r.meetsSwitchLatencyKpi, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(200));
      expect(c.pool.maxSlots, 2);
    });

    test('엘리베이터·완전 단절 연속 프로브에서도 프리징 없이 Local 풀 유지', () async {
      final c = SgpAmdahlGunterController();
      final edge = SgpEdgeHybridScheduler(c);
      for (var i = 0; i < 50; i++) {
        final r = edge.applyNetworkProbe(SgpNetworkProbe.offline);
        expect(r.placement, SgpInferencePlacement.edgeLocal);
        expect(c.pool.maxSlots, greaterThanOrEqualTo(1));
      }
      // 동시 작업이 슬롯 초과해도 데드락 없이 완료
      final jobs = <Future<int>>[];
      for (var i = 0; i < 8; i++) {
        jobs.add(c.pool.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return i;
        }));
      }
      final results = await Future.wait(jobs);
      expect(results.length, 8);
    });

    test('음영 복구 후 Cloud Hybrid 복귀', () {
      final edge = SgpEdgeHybridScheduler(SgpAmdahlGunterController());
      edge.applyNetworkProbe(SgpNetworkProbe.offline);
      expect(edge.isEdgeLocal, isTrue);
      final back = edge.applyNetworkProbe(
        const SgpNetworkProbe(rttMs: 60, packetLossRate: 0.01),
      );
      expect(back.placement, SgpInferencePlacement.cloudHybrid);
      expect(edge.isEdgeLocal, isFalse);
    });
  });

  group('대부하 Gunter/Amdahl 스트레스', () {
    test('교대·집단 치안 피크: β 상승·버퍼 확장·슬롯 하향', () {
      final c = SgpAmdahlGunterController(alpha: 0.08, beta: 0.012);
      final calm = c.observe(
        const SgpResourceSample(
          cpuAvailability: 0.9,
          memoryAvailability: 0.9,
          queryTrafficRate: 0.5,
        ),
      );
      SgpAutonomicDecision? peak;
      for (var i = 0; i < 20; i++) {
        c.noteQueryIngress();
        peak = c.observe(
          const SgpResourceSample(
            cpuAvailability: 0.25,
            memoryAvailability: 0.3,
            queryTrafficRate: 12,
            betaConsistencyLoad: 0.75,
            packetLossRate: 0.22,
            retransmissionDelayMs: 2800,
            networkRttMs: 1600,
          ),
        );
      }
      expect(peak, isNotNull);
      expect(peak!.asyncQueueBuffer, greaterThanOrEqualTo(calm.asyncQueueBuffer));
      expect(peak.activeAgents, lessThanOrEqualTo(calm.activeAgents));
      expect(peak.edgeHybrid, isTrue);
    });

    test('동시 100 병렬 틱에서도 P≥0.95 유지 가능', () {
      final c = SgpAmdahlGunterController();
      for (var i = 0; i < 100; i++) {
        c.recordParallelWork();
        c.noteQueryIngress();
      }
      // 순차 게이트는 전자서명 등 소수만
      for (var i = 0; i < 3; i++) {
        c.recordSequentialGate();
      }
      expect(c.parallelFractionP, greaterThanOrEqualTo(0.95));
      expect(c.meetsFieldParallelSla, isTrue);
    });

    test('Agent Pool N=2에서 32 동시 작업 직렬화·완료', () async {
      final pool = SgpActiveAgentPool(initialSlots: 2);
      var maxConcurrent = 0;
      var concurrent = 0;
      Future<void> job() async {
        concurrent++;
        if (concurrent > maxConcurrent) maxConcurrent = concurrent;
        await Future<void>.delayed(const Duration(milliseconds: 8));
        concurrent--;
      }

      await Future.wait(List.generate(32, (_) => pool.run(job)));
      expect(maxConcurrent, lessThanOrEqualTo(2));
    });
  });

  group('글림파틱·Catfish 대부하 공생', () {
    test('쿼리 폭주 중 Major→Minor 스로틀 (응답 간섭 최소화)', () async {
      final c = SgpAmdahlGunterController();
      final sched = SgpGlymphaticScheduler(controller: c);
      final sleepBudget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.95,
          memoryAvailability: 0.9,
          queryTrafficRate: 0.1,
        ),
        idleProfile: const SgpDeviceIdleProfile(
          isCharging: true,
          idleMinutes: 40,
          hourOfDay: 2,
        ),
      );
      expect(sleepBudget.preferredMode, GlymphaticFlushMode.major);

      sched.markUserQueryStarted();
      final underFire = <GlymphaticIoBudget>[];
      for (var i = 0; i < 15; i++) {
        underFire.add(
          await sched.forceTick(
            sample: SgpResourceSample(
              cpuAvailability: 0.4,
              memoryAvailability: 0.45,
              queryTrafficRate: 5.0 + i * 0.2,
            ),
            idleProfile: const SgpDeviceIdleProfile(
              isCharging: true,
              idleMinutes: 40,
              hourOfDay: 2,
              userQueryActive: true,
            ),
          ),
        );
      }
      expect(
        underFire.every((b) => b.preferredMode == GlymphaticFlushMode.minor),
        isTrue,
      );
      final avgIo =
          underFire.map((b) => b.ioLimit).reduce((a, b) => a + b) /
              underFire.length;
      expect(avgIo, lessThan(sleepBudget.ioLimit * 0.55));
    });

    test('연속 Catfish 사이클 WORM 체인 100% · FP=0', () async {
      final bb = SgpLegalBlackbox();
      final cleaner = SgpGlymphaticSmartSleep(blackbox: bb);
      final catfish = SgpChaosCatfish(blackbox: bb);
      const profile = SgpDeviceIdleProfile(
        isCharging: true,
        idleMinutes: 35,
        hourOfDay: 3,
      );
      final base = [
        KgPrecedentNode(
          id: 'SC-BASE',
          title: '대법원',
          courtLevel: 'supreme',
          decidedAt: DateTime.utc(2025, 1, 1),
          statuteRefs: const ['형법20'],
        ),
      ];
      var clock = DateTime.utc(2026, 7, 19, 3);
      for (var i = 0; i < 5; i++) {
        final r = await catfish.runSymbioticCycle(
          baseGraph: base,
          profile: profile,
          cleaner: cleaner,
          now: clock,
        );
        expect(r.meetsZeroFalsePositiveKpi, isTrue);
        expect(r.detectionComplete, isTrue);
        clock = clock.add(const Duration(seconds: 2));
      }
      final audit = bb.verifyChain();
      expect(audit.valid, isTrue);
      expect(audit.message, contains('100%'));
      expect(bb.length, greaterThanOrEqualTo(5));
    });
  });
}
