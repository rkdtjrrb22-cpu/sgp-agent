/// Amdahl / Gunter / Glymphatic Scheduler / Legal Blackbox 통합 검증.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';

import 'package:sgp_agent/features/agent/sgp_investigation_hyperlink_verifier.dart';
import 'package:sgp_agent/features/agent/sgp_kgrag_router.dart';
import 'package:sgp_agent/features/control/sgp_amdahl_gunter_controller.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_policy.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_scheduler.dart';
import 'package:sgp_agent/features/security/sgp_legal_blackbox.dart';

void main() {
  group('Amdahl / Gunter math', () {
    test('Amdahl speedup grows with N when P high', () {
      final s1 = SgpAmdahlGunterMath.amdahlSpeedup(
        parallelFractionP: 0.95,
        n: 1,
      );
      final s8 = SgpAmdahlGunterMath.amdahlSpeedup(
        parallelFractionP: 0.95,
        n: 8,
      );
      expect(s8, greaterThan(s1));
      expect(s8, closeTo(1 / (0.05 + 0.95 / 8), 1e-9));
    });

    test('Gunter N_max = sqrt((1-α)/β)', () {
      const alpha = 0.08;
      const beta = 0.012;
      final nMax = SgpAmdahlGunterMath.nMax(alpha: alpha, beta: beta);
      final expected = math.sqrt((1 - alpha) / beta).round().clamp(1, 16);
      expect(nMax, expected);
    });

    test('peak β lowers N_max', () {
      final low = SgpAmdahlGunterMath.nMax(alpha: 0.08, beta: 0.01);
      final high = SgpAmdahlGunterMath.nMax(alpha: 0.08, beta: 0.08);
      expect(high, lessThan(low));
    });
  });

  group('Autonomic controller', () {
    test('observe resizes pool to N_max · headroom', () {
      final c = SgpAmdahlGunterController(alpha: 0.08, beta: 0.012);
      final d = c.observe(
        const SgpResourceSample(
          cpuAvailability: 1.0,
          memoryAvailability: 1.0,
          queryTrafficRate: 1.0,
        ),
      );
      expect(d.activeAgents, d.nMax);
      expect(c.pool.maxSlots, d.activeAgents);
    });

    test('peak traffic expands async buffer and lowers slots', () {
      final c = SgpAmdahlGunterController(alpha: 0.08, beta: 0.012);
      final calm = c.observe(
        const SgpResourceSample(
          cpuAvailability: 0.9,
          memoryAvailability: 0.9,
          queryTrafficRate: 0.5,
        ),
      );
      final peak = c.observe(
        const SgpResourceSample(
          cpuAvailability: 0.4,
          memoryAvailability: 0.4,
          queryTrafficRate: 8.0,
          betaConsistencyLoad: 0.7,
        ),
      );
      expect(
        peak.asyncQueueBuffer,
        greaterThanOrEqualTo(calm.asyncQueueBuffer),
      );
      expect(peak.activeAgents, lessThanOrEqualTo(calm.activeAgents));
      expect(peak.allowGlymphaticClean, isFalse);
    });

    test('field parallel SLA target P≥0.95 with parallel-only ticks', () {
      final c = SgpAmdahlGunterController();
      for (var i = 0; i < 100; i++) {
        c.recordParallelWork();
      }
      expect(c.parallelFractionP, greaterThanOrEqualTo(0.95));
      expect(c.meetsFieldParallelSla, isTrue);
    });

    test('agent pool serializes beyond N', () async {
      final pool = SgpActiveAgentPool(initialSlots: 1);
      var concurrent = 0;
      var maxSeen = 0;
      Future<void> job() async {
        concurrent++;
        if (concurrent > maxSeen) maxSeen = concurrent;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        concurrent--;
      }

      await Future.wait([pool.run(job), pool.run(job), pool.run(job)]);
      expect(maxSeen, 1);
    });
  });

  group('Glymphatic scheduler', () {
    test('defers clean under low headroom', () async {
      final c = SgpAmdahlGunterController();
      final sched = SgpGlymphaticScheduler(controller: c);
      var ran = 0;
      final budget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.1,
          memoryAvailability: 0.1,
          queryTrafficRate: 6.0,
          betaConsistencyLoad: 0.8,
        ),
        work: (_) async => ran++,
      );
      expect(budget.allowClean, isFalse);
      expect(ran, 0);
      expect(sched.deferredTicks, greaterThan(0));
    });

    test('scales I/O when headroom high', () async {
      final c = SgpAmdahlGunterController();
      final sched = SgpGlymphaticScheduler(controller: c);
      final budget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.95,
          memoryAvailability: 0.9,
          queryTrafficRate: 0.2,
        ),
        work: (_) async {},
      );
      expect(budget.allowClean, isTrue);
      expect(budget.ioLimit, greaterThan(0.5));
      expect(budget.preferredMode, GlymphaticFlushMode.major);
      expect(budget.fragmentBatchSize, greaterThan(0));
    });

    test('user query forces minor + reduced batch', () async {
      final c = SgpAmdahlGunterController();
      final sched = SgpGlymphaticScheduler(controller: c);
      sched.markUserQueryStarted();
      final budget = await sched.forceTick(
        sample: const SgpResourceSample(
          cpuAvailability: 0.5,
          memoryAvailability: 0.5,
          queryTrafficRate: 1.0,
        ),
        work: (_) async {},
      );
      expect(budget.preferredMode, GlymphaticFlushMode.minor);
    });
  });

  group('Legal blackbox WORM', () {
    test('provenance chain hashes and verifies', () async {
      final bb = SgpLegalBlackbox();
      final a = await bb.appendInference(
        ontologyNodeIds: const ['NODE-A'],
        kgragDocWeights: const {'2020도1': 0.91},
        prompt: 'prompt-alpha',
        userSignatureMaterial: 'sig-1',
        opinionSummary: '의견A',
      );
      final b = await bb.appendInference(
        ontologyNodeIds: const ['NODE-B'],
        kgragDocWeights: const {'2019도2': 0.77},
        prompt: 'prompt-beta',
        userSignatureMaterial: 'sig-2',
      );
      expect(b.prevEntryHash, a.entryHash);
      final audit = bb.verifyChain();
      expect(audit.valid, isTrue);
      expect(audit.entryCount, 2);
    });

    test('WORM disk rejects overwrite', () async {
      final dir = await Directory.systemTemp.createTemp('sgp_bb_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bb = SgpLegalBlackbox(directory: dir);
      final fixed = DateTime.utc(2026, 7, 16, 12);
      final e = await bb.appendInference(
        ontologyNodeIds: const ['W'],
        kgragDocWeights: const {},
        prompt: 'worm',
        userSignatureMaterial: 'officer',
        at: fixed,
      );
      expect(e.entryId, isNotEmpty);
      expect(bb.verifyChain().valid, isTrue);

      // 새 인스턴스(빈 메모리)로 동일 entryId 파일 재기록 시도 → WORM 위반
      final bb2 = SgpLegalBlackbox(directory: dir);
      await expectLater(
        bb2.appendInference(
          ontologyNodeIds: const ['W'],
          kgragDocWeights: const {},
          prompt: 'worm',
          userSignatureMaterial: 'officer',
          at: fixed,
        ),
        throwsA(isA<StateError>()),
      );

      final reloaded = SgpLegalBlackbox(directory: dir);
      expect(await reloaded.loadFromDisk(), 1);
      expect(reloaded.verifyChain().valid, isTrue);
    });
  });

  group('Investigation hyperlink 1-P reduction', () {
    test('assembled session meets ≥70% review reduction', () {
      const result = KgragReasoningResult(
        query: '정당방위',
        ontologyShield: KgragOntologyShield(
          legalNodeIds: ['형법20', '경직법'],
          triples: [],
        ),
        precedentHits: [
          KgragPrecedentHit(
            id: '1',
            court: '대법원',
            caseNo: '2020도1',
            holding: '정당방위 인정',
            similarity: 0.9,
            articleRefs: [],
            ontologyNodes: [],
          ),
        ],
        promptContext: 'ctx',
        recommendedAction: '현행범 체포 요건 재검토',
        selfDefenseProbability: 0.8,
        confidenceLabel: 'High',
        matchedCorpusCount: 1,
        hallucinationGuardPass: true,
        confidence: 0.8,
      );
      final session = SgpInvestigationHyperlinkVerifier.assemble(result);
      expect(session.total, greaterThanOrEqualTo(3));
      expect(session.meetsSeventyPercentReduction, isTrue);
      expect(session.estimatedReviewTimeReduction, greaterThanOrEqualTo(0.70));
    });
  });
}
