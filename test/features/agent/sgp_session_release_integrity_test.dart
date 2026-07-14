import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_kgrag_laws_loader.dart';
import 'package:sgp_agent/features/agent/sgp_law_extractor.dart';
import 'package:sgp_agent/features/agent/sgp_law_offgrid_sync.dart';
import 'package:sgp_agent/features/agent/sgp_session_recovery_manager.dart';
import 'package:test/test.dart';

void main() {
  group('SgpSessionRecoveryManager', () {
    test('autosave flush → restore recovers 100% fields', () async {
      final dir = await Directory.systemTemp.createTemp('sgp_session_rec_');
      try {
        final mgr = SgpSessionRecoveryManager(directory: dir);
        final cp = SgpSessionCheckpoint(
          rawText: '드론 촬영 민원 · 물리력 가이드 확인 중',
          savedAt: DateTime(2026, 7, 14, 15, 50),
          operationalMode: 'field',
          checklistJson: {'isWeaponUsed': false},
          hierarchicalLawJson: SgpLawExtractor.extract('드론 불법비행').toJson(),
          physicalThreatLevel: 'activeResistance',
          forceExecutionLogged: true,
          selfJudgmentAccepted: true,
        );
        await mgr.flush(cp);
        expect(mgr.autosaveCount, 1);

        final mgr2 = SgpSessionRecoveryManager(directory: dir);
        final restored = await mgr2.restore();
        expect(restored, isNotNull);
        expect(restored!.rawText, cp.rawText);
        expect(restored.operationalMode, 'field');
        expect(restored.forceExecutionLogged, isTrue);
        expect(restored.selfJudgmentAccepted, isTrue);
        expect(restored.physicalThreatLevel, 'activeResistance');
        expect(restored.hierarchicalLawJson, isNotNull);
        expect(restored.hasRecoverableContent, isTrue);
        expect(SgpSessionRecoveryManager.forbidsNetworkEgress, isTrue);

        await mgr2.clear();
        expect(await mgr2.restore(), isNull);
        mgr.dispose();
        mgr2.dispose();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('10대 사법 도메인 kgrag_laws 정합성', () {
    late KgragLawsPack pack;

    setUp(() {
      LawOntology.resetToSeed();
      pack = KgragLawsPack.parse(
        File('assets/data/kgrag_laws.json').readAsStringSync(),
      );
    });

    tearDown(LawOntology.resetToSeed);

    test('pack has 10 domains and required special statutes', () {
      expect(pack.domains.length, 10);
      final ids = pack.nodes.map((n) => n.id).toSet();
      expect(ids, contains('KR-AVIATION-SAFE'));
      expect(ids, contains('KR-ASSEMBLY-DEMO'));
      expect(ids, contains('KR-VIENNA-DIPLOMATIC'));
      expect(ids, contains('KR-EMS'));
      expect(ids, contains('KR-DISASTER-SAFETY'));
      expect(ids, contains('KR-ANIMAL-PROTECT'));
    });

    test('each domain probe extracts unbroken LV1–LV4 vertical set', () {
      final results = SgpKgragLawsLoader.verifyDomainIntegrity(pack);
      expect(results.length, 10);

      void expectStatute(String probeKey, String statuteId) {
        final set = SgpLawExtractor.extract(probeKey);
        expect(
          set.specialStatute.any((n) => n.id == statuteId) ||
              set.executiveRule.any((n) => n.parentIds.contains(statuteId)),
          isTrue,
          reason: 'probe="$probeKey" should reach $statuteId',
        );
        expect(set.constitution, isNotEmpty);
      }

      expectStatute('드론 불법 비행', 'KR-AVIATION-SAFE');
      expectStatute('집회시위 대경법', 'KR-ASSEMBLY-DEMO');
      expectStatute('비엔나 협약 외교공관', 'KR-VIENNA-DIPLOMATIC');
      expectStatute('응급실 응급의료 방해', 'KR-EMS');
      expectStatute('재난안전 대피 통제', 'KR-DISASTER-SAFETY');
      expectStatute('동물보호 목줄 미착용', 'KR-ANIMAL-PROTECT');

      for (final entry in results.entries) {
        expect(
          entry.value.constitution,
          isNotEmpty,
          reason: 'domain ${entry.key} missing LV1',
        );
      }
    });
  });

  group('Offline banner / release compile contract', () {
    test('offline sync always exposes banner label for closed-net deploy', () {
      final sync = SgpLawOffGridSync(
        forbidsNetworkEgress: true,
        seed: SgpLawSnapshot.seed(
          syncTime: DateTime(2026, 7, 14, 15, 19),
        ),
      );
      expect(sync.isOfflineMode, isTrue);
      expect(sync.subtleBannerLabel, contains('오프라인 보호막 모드 가동 중'));
      expect(sync.subtleBannerLabel, contains('2026-07-14 15:19'));
    });

    test('release-build.cmd contains obfuscate + split-debug-info', () {
      final cmd = File('scripts/release-build.cmd').readAsStringSync();
      expect(cmd, contains('--release'));
      expect(cmd, contains('--obfuscate'));
      expect(cmd, contains('--split-debug-info'));
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
    });
  });
}
