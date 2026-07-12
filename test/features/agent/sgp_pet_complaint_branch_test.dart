import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_civil_complaint_branch.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_data.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:test/test.dart';

void main() {
  group('S9 Pet & Civil Complaint Fusion', () {
    late CivilComplaintNodePack pack;
    late List<LegalHierarchyNode> seedNodes;

    setUp(() {
      final json =
          File('assets/data/civil_complaint_nodes.json').readAsStringSync();
      pack = CivilComplaintNodePack.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      final seedJson =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      seedNodes = (jsonDecode(seedJson) as List<dynamic>)
          .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    CivilComplaintType typeById(String id) =>
        pack.types.firstWhere((t) => t.id == id);

    test('routeFromText — 개 목줄 미착용 → CC-TYPE-PET-LEASH', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '옆집 개가 목줄 없이 산책하는데 어떻게 해요?',
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-PET-LEASH');
      expect(route.isHighConfidence, isTrue);
    });

    test('routeFromText — 개 물림 사고 → CC-TYPE-PET-BITE', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '개한테 물려서 병원 가서 봉합했어요',
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-PET-BITE');
      expect(route.isHighConfidence, isTrue);
    });

    test('routeFromText — 층간 소음 → CC-TYPE-NOISE', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '윗집 층간 소음 때문에 잠을 못 자요',
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-NOISE');
    });

    test('routeFromText — 고소장 접수 → CC-TYPE-COMPLAINT-INTAKE', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '고소장 접수하려고 왔는데 어디로 가나요?',
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-COMPLAINT-INTAKE');
    });

    test('branch — 목줄 미착용 행정 → 지자체 이관', () {
      final type = typeById('CC-TYPE-PET-LEASH');
      final branch = SgpCivilComplaintBranchRouter.infer(
        type: type,
        rawText: '개 목줄 안 하고 다녀요',
      );
      expect(branch.branch, CivilComplaintEnforcementBranch.localGovTransfer);
      expect(branch.legalNodeIds, contains('KR-RULE-ANIMAL-ART16'));
      expect(branch.legalNodeIds, contains('AGENCY-LOCAL-ENV-ANIMAL'));
    });

    test('branch — 목줄 + 물림 정황 → 형사과 수사', () {
      final type = typeById('CC-TYPE-PET-LEASH');
      final branch = SgpCivilComplaintBranchRouter.infer(
        type: type,
        rawText: '목줄 없는 개한테 물려서 피해 봤어요',
      );
      expect(branch.branch, CivilComplaintEnforcementBranch.criminalInvestigation);
      expect(branch.legalNodeIds, contains('KR-CRIM-266-NEGLIGENCE'));
    });

    test('branch — 개물림 → 형사과 + 동물보호법·과실치상 노드', () {
      final type = typeById('CC-TYPE-PET-BITE');
      final branch = SgpCivilComplaintBranchRouter.infer(
        type: type,
        rawText: '개 물림 사고 교상 당했습니다',
      );
      expect(branch.isCriminal, isTrue);
      expect(branch.legalNodeIds, containsAll([
        'KR-RULE-ANIMAL-ART16',
        'KR-CRIM-266-NEGLIGENCE',
        'KR-CRIM-257-BODILY',
        'ORG-POLICE-CRIMINAL-INVEST',
      ]));
    });

    test('branch — 층간소음 단순 → 지자체 이관', () {
      final type = typeById('CC-TYPE-NOISE');
      final branch = SgpCivilComplaintBranchRouter.infer(
        type: type,
        rawText: '층간 소음이 너무 심해요',
      );
      expect(branch.branch, CivilComplaintEnforcementBranch.localGovTransfer);
    });

    test('branch — 층간소음 + 폭력 → 형사과 수사', () {
      final type = typeById('CC-TYPE-NOISE');
      final branch = SgpCivilComplaintBranchRouter.infer(
        type: type,
        rawText: '층간 소음 때문에 올라가서 싸웠어요 폭행당했어요',
      );
      expect(branch.branch, CivilComplaintEnforcementBranch.criminalInvestigation);
    });

    test('branch — 고소장 접수 → 형사과 수사 착수', () {
      final type = typeById('CC-TYPE-COMPLAINT-INTAKE');
      final branch = SgpCivilComplaintBranchRouter.infer(
        type: type,
        rawText: '고소장 접수합니다',
      );
      expect(branch.branch, CivilComplaintEnforcementBranch.criminalInvestigation);
      expect(branch.legalNodeIds, contains('ORG-POLICE-CRIMINAL-INVEST'));
    });

    test('legal seed — S9 반려견·형사 규칙 노드 7종 존재', () {
      const ids = [
        'KR-RULE-ANIMAL-ART16',
        'KR-RULE-ANIMAL-ART97-PENALTY',
        'KR-CRIM-266-NEGLIGENCE',
        'KR-CRIM-257-BODILY',
        'AGENCY-LOCAL-ENV-ANIMAL',
        'ORG-POLICE-CRIMINAL-INVEST',
      ];
      final nodeIds = seedNodes.map((n) => n.id).toSet();
      for (final id in ids) {
        expect(nodeIds, contains(id), reason: 'missing $id');
      }
      expect(pack.types.any((t) => t.id == 'CC-TYPE-PET-LEASH'), isTrue);
      expect(pack.types.any((t) => t.id == 'CC-TYPE-PET-BITE'), isTrue);
    });

    test('route + branch extension — 현장 문장 통합 추론', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        '개 물림 사고로 병원 갔어요',
        pack,
      );
      expect(route, isNotNull);
      final branch = route!.inferEnforcement('개 물림 사고로 병원 갔어요');
      expect(branch.isCriminal, isTrue);
      expect(
        SgpCivilComplaintBranchRouter.branchLabel(branch.branch),
        '형사과 수사 착수',
      );

      final graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: LegalOntologyMigrator.graphFromNodes(seedNodes),
        pack: pack,
      );
      final juris = graph.query(
        subjectId: 'CC-TYPE-PET-BITE',
        predicate: LegalPredicate.hasJurisdiction,
        objectId: 'ORG-POLICE-CRIMINAL-INVEST',
      );
      expect(juris, isNotEmpty);
    });

    test('triplesFromPack — PET-LEASH → AGENCY-LOCAL-ENV-ANIMAL 관할', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'CC-TYPE-PET-LEASH' &&
              t.predicate == LegalPredicate.hasJurisdiction &&
              t.objectId == 'AGENCY-LOCAL-ENV-ANIMAL',
        ),
        isTrue,
      );
    });

    test('triplesFromPack — PET-BITE → medical_record 서류', () {
      final triples = SgpCivilComplaintRouter.triplesFromPack(pack);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'CC-TYPE-PET-BITE' &&
              t.predicate == LegalPredicate.requiresDocument &&
              t.objectValue == 'medical_record',
        ),
        isTrue,
      );
    });

    test('branchLabel — 이관·형사 라벨 고정 문자열', () {
      expect(
        SgpCivilComplaintBranchRouter.branchLabel(
          CivilComplaintEnforcementBranch.localGovTransfer,
        ),
        '지자체 환경과·동물보호과 이관',
      );
      expect(
        SgpCivilComplaintBranchRouter.branchLabel(
          CivilComplaintEnforcementBranch.criminalInvestigation,
        ),
        '형사과 수사 착수',
      );
    });

    test('complaint pack — 반려견 유형 포함 15종 이상', () {
      expect(pack.types.length, greaterThanOrEqualTo(15));
      expect(
        pack.types.where((t) => t.id.startsWith('CC-TYPE-PET-')).length,
        2,
      );
    });
  });
}
