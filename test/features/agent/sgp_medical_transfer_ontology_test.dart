import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_civil_complaint_data.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:sgp_agent/features/agent/sgp_medical_custody_engine.dart';
import 'package:test/test.dart';

void main() {
  group('S8-MED MedicalTransferOntology', () {
    late CivilComplaintNodePack pack;
    late LegalOntologyGraph graph;

    setUp(() {
      final json = File('assets/data/civil_complaint_nodes.json').readAsStringSync();
      pack = CivilComplaintNodePack.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final seedJson =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      final seedNodes = (jsonDecode(seedJson) as List<dynamic>)
          .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
          .toList();
      graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: LegalOntologyMigrator.graphFromNodes(seedNodes),
        pack: pack,
      );
    });

    test('freezes_timeline 트리플 — 임의동행 분기', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'CC-TYPE-MED-TRANSFER-VOLUNTARY' &&
              t.predicate == LegalPredicate.freezesTimeline &&
              t.objectValue == 'true',
        ),
        isTrue,
      );
    });

    test('requires_guard 트리플 — 현행범·긴급체포 후 이송', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'CC-TYPE-MED-TRANSFER-ARREST' &&
              t.predicate == LegalPredicate.requiresGuard &&
              t.objectValue == 'true',
        ),
        isTrue,
      );
    });

    test('MED-TRANSFER · CUSTODY-MGMT · POLICE-GUARD 관할 연결', () {
      final hits = graph.query(
        subjectId: 'CC-TYPE-MED-TRANSFER-ARREST',
        predicate: LegalPredicate.hasJurisdiction,
        objectId: 'MED-TRANSFER',
      );
      expect(hits, isNotEmpty);
      expect(
        graph.query(
          subjectId: 'CC-TYPE-MED-TRANSFER-ARREST',
          predicate: LegalPredicate.hasJurisdiction,
          objectId: 'POLICE-GUARD',
        ),
        isNotEmpty,
      );
    });

    test('routeFromText — 응급 병원 이송 → CC-TYPE-MED-TRANSFER-ARREST', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '가해자가 의식불명이라 119로 응급 병원 이송 중 현행범 체포 상태',
        pack,
        graph: graph,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-MED-TRANSFER-ARREST');
      expect(route.type.isMedicalTransferGuide, isTrue);
    });

    test('routeFromText — 임의동행 선이송 → CC-TYPE-MED-TRANSFER-VOLUNTARY', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '피의자 임의동행으로 병원 선이송 치료 동행',
        pack,
        graph: graph,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-MED-TRANSFER-VOLUNTARY');
      expect(route.type.freezesTimeline, isTrue);
    });

    test('SgpMedicalCustodyTimeline — A분기 48h 잔여 분 계산', () {
      final arrestAt = DateTime(2026, 7, 12, 13);
      final now = arrestAt.add(const Duration(hours: 43));
      final deadline = SgpMedicalCustodyTimeline.compute(
        session: SgpMedicalTransferSession(
          branch: MedTransferBranch.arrestAfter,
          arrestAt: arrestAt,
          status: MedTransferStatus.inTransit,
        ),
        now: now,
      );
      expect(deadline.timelineFrozen, isFalse);
      expect(deadline.remainingMinutes, 5 * 60);
      expect(deadline.isCritical, isTrue);
    });

    test('SgpMedicalCustodyTimeline — B분기 시한 정지·도주 우려 상향', () {
      final deadline = SgpMedicalCustodyTimeline.compute(
        session: SgpMedicalTransferSession(
          branch: MedTransferBranch.voluntaryFirst,
          arrestAt: DateTime(2026, 7, 12, 10),
          status: MedTransferStatus.erAdmission,
        ),
      );
      expect(deadline.timelineFrozen, isTrue);
      expect(deadline.remainingMinutes, isNull);
      expect(deadline.flightRisk, MedFlightRiskLevel.elevated);
    });

    test('validateCross — 계호 2인 미만 경고', () {
      final warnings = SgpMedicalCustodyTimeline.validateCross(
        SgpMedicalTransferSession(
          branch: MedTransferBranch.arrestAfter,
          arrestAt: DateTime(2026, 7, 12, 12),
          status: MedTransferStatus.erAdmission,
          guardCount: 1,
        ),
      );
      expect(warnings.any((w) => w.contains('2인 1조')), isTrue);
    });

    test('buildSituationReportParagraph — 이송 후 계호 지침 자동 문안', () {
      final session = SgpMedicalTransferSession(
        branch: MedTransferBranch.arrestAfter,
        arrestAt: DateTime(2026, 7, 12, 13),
        subjectName: 'OOO',
        hospitalName: 'OO병원',
        injuryDescription: '우측 대퇴부 열상',
        guardCount: 2,
        status: MedTransferStatus.inTransit,
      );
      final deadline = SgpMedicalCustodyTimeline.compute(session: session);
      final paragraph = SgpMedicalCustodyTimeline.buildSituationReportParagraph(
        session: session,
        deadline: deadline,
      );
      expect(paragraph, contains('OOO'));
      expect(paragraph, contains('OO병원'));
      expect(paragraph, contains('2인 1조'));
      expect(paragraph, contains('48h'));
    });
  });
}
