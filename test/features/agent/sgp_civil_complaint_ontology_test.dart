import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_civil_complaint_data.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology_session.dart';
import 'package:test/test.dart';

void main() {
  group('S7-D CivilComplaintOntology', () {
    late CivilComplaintNodePack pack;
    late List<LegalHierarchyNode> seedNodes;

    setUp(() {
      final json = File('assets/data/civil_complaint_nodes.json').readAsStringSync();
      pack = CivilComplaintNodePack.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final seedJson =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      seedNodes = (jsonDecode(seedJson) as List<dynamic>)
          .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('has_jurisdiction 트리플 — 민원 유형→관할 기관', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'CC-TYPE-LICENSE-REISSUE' &&
              t.predicate == LegalPredicate.hasJurisdiction &&
              t.objectId == 'AGENCY-KOROAD',
        ),
        isTrue,
      );
    });

    test('requires_document 트리플 — 필요 서류', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'CC-TYPE-CYBER-FRAUD' &&
              t.predicate == LegalPredicate.requiresDocument &&
              t.objectValue == 'transfer_receipt',
        ),
        isTrue,
      );
    });

    test('LegalPredicate.fromApiValue — has_jurisdiction / requires_document', () {
      expect(
        LegalPredicate.fromApiValue('has_jurisdiction'),
        LegalPredicate.hasJurisdiction,
      );
      expect(
        LegalPredicate.fromApiValue('requires_document'),
        LegalPredicate.requiresDocument,
      );
    });

    test('triplesFromPack — 중복 트리플 ID 제거', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      final ids = triples.map((t) => t.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('mergeComplaintTriples — 기본 그래프에 민원 트리플 병합', () {
      final base = LegalOntologyMigrator.graphFromNodes(seedNodes);
      final merged = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: base,
        pack: pack,
      );
      expect(merged.triples.length, greaterThan(base.triples.length));
    });

    test('query — hasJurisdiction CC-TYPE-NOISE → 지자체', () {
      final base = LegalOntologyMigrator.graphFromNodes(seedNodes);
      final graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: base,
        pack: pack,
      );
      final hits = graph.query(
        subjectId: 'CC-TYPE-NOISE',
        predicate: LegalPredicate.hasJurisdiction,
        objectId: 'AGENCY-LOCAL-GOV',
      );
      expect(hits, isNotEmpty);
    });

    test('subgraphFrom — CC-ROOT 하위 민원 카테고리 도달', () {
      final base = LegalOntologyMigrator.graphFromNodes(seedNodes);
      final graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: base,
        pack: pack,
      );
      final sub = graph.subgraphFrom(
        rootSubjectId: 'CC-ROOT-POLICE-COMPLAINT',
        maxDepth: 2,
      );
      expect(sub.nodeIds, contains('CC-CAT-TRAFFIC'));
    });

    test('routeFromText — 면허증 분실 → CC-TYPE-LICENSE-REISSUE', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '면허증 잃어버렸는데 어디서 만들어요?',
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-LICENSE-REISSUE');
      expect(route.isHighConfidence, isTrue);
    });

    test('routeFromText — 주차 분쟁 → CC-TYPE-ILLEGAL-PARKING (경찰 이관 경고)', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '옆집이랑 주차 때문에 싸웠는데 경찰이 와서 딱지 좀 떼줘요',
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-ILLEGAL-PARKING');
      expect(route.type.policeDispatchWarning, isTrue);
    });

    test('SgpLegalOntologySession — 시드+민원 팩 통합 로드', () {
      SgpLegalOntologySession.instance.reset();
      final seedJson =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      SgpLegalOntologySession.instance.loadFromSeedJson(
        seedJson,
        complaintPack: pack,
      );
      final session = SgpLegalOntologySession.instance;
      expect(session.isLoaded, isTrue);
      expect(session.tripleCount, greaterThanOrEqualTo(120));
      expect(session.source, contains('civil_complaint'));
      expect(
        session.graph!.query(predicate: LegalPredicate.hasJurisdiction),
        isNotEmpty,
      );
    });
  });
}
