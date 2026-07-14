import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_law_extractor.dart';
import 'package:sgp_agent/features/agent/sgp_law_offgrid_sync.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_phagophore_filter.dart';
import 'package:test/test.dart';

void main() {
  group('SgpLawExtractor Stage 5', () {
    test('Phagophore pruneUnlinkedFragments cleans noise tokens', () {
      final cleaned = PhagophoreFilter.pruneUnlinkedFragments('아 그냥 소란 막 피움');
      expect(cleaned.contains('소란'), isTrue);
      expect(cleaned.split(' ').contains('아'), isFalse);
    });

    test('drunk disturbance → LV2 공연음란 · LV3 경범죄 · LV4 가이드 + LV1 헌법', () {
      final set = SgpLawExtractor.extract(
        '술 취한 자가 옷을 벗고 소란을 피우고 있습니다',
      );
      expect(set.executiveRule, isNotEmpty);
      expect(set.specialStatute.any((n) => n.id == 'KR-MINOR-OFFENSE'), isTrue);
      expect(
        set.basicCode.any((n) => n.id == 'KR-CRIM-PUBLIC-INDECENCY'),
        isTrue,
      );
      expect(set.constitution, isNotEmpty);
      expect(
        set.constitution.any((n) => n.id.contains('CONST')),
        isTrue,
      );
    });

    test('summary trial forms catalog is 123', () {
      expect(SummaryTrialFormCatalog.build().length, 123);
      expect(SummaryTrialFormCatalog.build().first['title'], '즉결심판 청구서');
    });
  });

  group('Off-Grid Law Snapshot', () {
    test('heartbeat timeout >1.5s falls back without throwing', () async {
      final remote = LawSnapshotMockRemote(
        delay: const Duration(milliseconds: 2000),
      );
      final hb = LawHeartbeatMonitor(
        timeout: const Duration(milliseconds: 1500),
      );
      final sync = SgpLawOffGridSync(
        remote: remote,
        heartbeat: hb,
        forbidsNetworkEgress: false,
        seed: SgpLawSnapshot.seed(
          syncTime: DateTime(2026, 7, 14, 15, 19),
        ),
      );
      final before = sync.activeSnapshot.lastSuccessfulSyncTime;
      final snap = await sync.syncOrResidual();
      expect(hb.offlineOnly, isTrue);
      expect(snap.lastSuccessfulSyncTime, before);
      expect(sync.subtleBannerLabel, contains('오프라인 보호막'));
      expect(sync.subtleBannerLabel, contains('15:19'));
    });

    test('AES vault persist/load residual', () async {
      final dir = await Directory.systemTemp.createTemp('sgp_law_snap_');
      try {
        final seed = SgpLawSnapshot.seed();
        await SgpLawSnapshotVault.persist(seed, directory: dir);
        final loaded = await SgpLawSnapshotVault.load(directory: dir);
        expect(loaded, isNotNull);
        expect(loaded!.summaryTrialForms.length, 123);
        expect(SgpLawSnapshotVault.forbidsNetworkEgress, isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('offline residual returns under 100ms seamless', () async {
      final sync = SgpLawOffGridSync(forbidsNetworkEgress: true);
      final sw = Stopwatch()..start();
      final snap = sync.residualNow();
      sw.stop();
      expect(snap.summaryTrialForms.length, 123);
      expect(sw.elapsedMilliseconds, lessThan(100));
      expect(sync.isOfflineMode, isTrue);
    });
  });
}
