import 'dart:io';

import 'package:sgp_agent/features/evidence/sgp_electronic_seizure_report.dart';
import 'package:sgp_agent/features/evidence/sgp_evidence_coc_engine.dart';
import 'package:sgp_agent/features/evidence/sgp_evidence_coc_secure_store.dart';
import 'package:sgp_agent/features/evidence/sgp_evidence_scenario_pipeline.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_agent_node.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_phagophore_filter.dart';
import 'package:test/test.dart';

void main() {
  group('Evidence CoC engine', () {
    test('SHA-256 is deterministic hex', () {
      final a = SgpEvidenceCoCEngine.computeSha256Hex('field-hash');
      final b = SgpEvidenceCoCEngine.computeSha256Hex('field-hash');
      expect(a, b);
      expect(a.length, 64);
    });

    test('full dump text triggers red-path blind spots', () {
      final spots = SgpEvidenceCoCEngine.scanBlindSpots(
        '피의자 스마트폰을 통째로 전체복사 했습니다',
      );
      expect(spots, contains(EvidenceBlindSpot.fullDumpDetected));
      expect(spots, contains(EvidenceBlindSpot.nonRelatedSeizureRisk));
    });

    test('digital seizure without hash/participation flags spots', () {
      final session = SgpEvidenceCoCEngine.createSession(
        rawText: '음주측정 거부 후 스마트폰 임의제출 받았습니다',
      );
      expect(session.blindSpots, contains(EvidenceBlindSpot.hashMissing));
      expect(
        session.blindSpots,
        contains(EvidenceBlindSpot.participationNotNotified),
      );
      expect(session.trafficLight, EvidenceCoCTrafficLight.red);
    });

    test('forced sequence blocks skipping steps', () {
      var session = SgpEvidenceCoCEngine.createSession(
        rawText: '블랙박스 임의제출',
      );
      expect(
        () => SgpEvidenceCoCEngine.completeStep(
          session,
          EvidenceCoCStep.hashExtracted,
        ),
        throwsStateError,
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
        hashSourcePayload: 'bbox|v1',
      );
      expect(session.steps[EvidenceCoCStep.hashExtracted]!.hashValue, isNotNull);
      session = SgpEvidenceCoCEngine.completeStep(
        session,
        EvidenceCoCStep.participationNotified,
      );
      expect(session.isFullyCompliant, isTrue);
      expect(session.trafficLight, EvidenceCoCTrafficLight.green);
    });
  });

  group('Evidence scenario pipeline', () {
    test('dui + assault + phone → mixed cards', () {
      final result = SgpEvidenceScenarioPipeline.run(
        '음주측정 거부하며 경찰관 폭행, 피의자 스마트폰·블랙박스 임의제출',
      );
      expect(result.kind, EvidenceScenarioKind.mixed);
      expect(result.crimeFacts.length, greaterThanOrEqualTo(2));
      expect(result.integrityChecklist, isNotEmpty);
      expect(result.supplementaryWarning, contains('보완수사'));
    });

    test('report markdown includes CoC and signature', () {
      final pipeline = SgpEvidenceScenarioPipeline.run(
        '스마트폰 임의제출 해시 미추출',
      );
      final md = SgpElectronicSeizureReport.buildMarkdown(
        chainOfCustody: pipeline.chainOfCustody,
        rawText: '스마트폰 임의제출',
        pipeline: pipeline,
      );
      expect(md, contains('전자정보 압수·수색 결과보고서'));
      expect(md, contains('INSP_KANG_SG_4066'));
      expect(md, contains('Chain of Custody'));
    });
  });

  group('P3 Phagophore & Secure Vault', () {
    test('PhagophoreFilter.phagophoreProcess removes unlinked noise', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.appendContext('noise-blob');
      node.appendContext('형사소송법 체포', ontologyNodeId: 'KR-LAW-001');
      final pruned = PhagophoreFilter.phagophoreProcess(
        node,
        ontology: null,
        ontologyAnchors: const ['형사소송법 체포'],
      );
      expect(pruned, greaterThan(0));
    });

    test('evidenceCoC secure store round-trip offline only', () async {
      expect(SgpEvidenceCoCSecureStore.forbidsNetworkEgress, isTrue);
      final dir = await Directory.systemTemp.createTemp('sgp_coc_vault_');
      try {
        var session = SgpEvidenceCoCEngine.createSession(
          rawText: '스마트폰 임의제출',
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
          hashSourcePayload: 'phone|offline',
        );
        final file = await SgpEvidenceCoCSecureStore.persistSession(
          session,
          directory: dir,
        );
        expect(file.path, contains(SgpEvidenceCoCSecureStore.filePrefix));
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
