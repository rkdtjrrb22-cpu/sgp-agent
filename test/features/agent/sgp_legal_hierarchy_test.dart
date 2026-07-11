import 'dart:convert';

import 'package:test/test.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';

const _inlineSeed = '''
[
  {"id":"KR-CONST-001","level":1,"title":"대한민국 헌법","parent_id":null,"scope":{"country":"KR"},"domain_tags":["all"]},
  {"id":"KR-LAW-CRIMINAL","level":2,"title":"형법","parent_id":"KR-CONST-001","scope":{"country":"KR"},"domain_tags":["criminal"]},
  {"id":"KR-LAW-CRIM-PROC","level":2,"title":"형사소송법","parent_id":"KR-CONST-001","scope":{"country":"KR"},"domain_tags":["criminal","procedure"]},
  {"id":"KR-LAW-ANIMAL","level":2,"title":"동물보호법","parent_id":"KR-CONST-001","scope":{"country":"KR"},"domain_tags":["animal","criminal"]},
  {"id":"ORG-NPA-INVEST-RULE","level":7,"title":"경찰 수사규칙","parent_id":"KR-LAW-CRIM-PROC","scope":{"org_id":"KR-NPA"},"conflict_check":true,"domain_tags":["procedure"]},
  {"id":"MANUAL-SGP-FIELD-001","level":8,"title":"SGP 현장 매뉴얼","parent_id":"ORG-NPA-INVEST-RULE","scope":{"org_id":"KR-NPA","task_category":"field_arrest"},"domain_tags":["procedure"]}
]
''';

void main() {
  setUp(() {
    SgpLegalHierarchyRegistry.instance.loadFromJson(_inlineSeed);
  });

  group('SgpLegalHierarchyRegistry', () {
    test('시드 JSON 로드 — 6노드', () {
      expect(SgpLegalHierarchyRegistry.instance.isLoaded, isTrue);
      expect(SgpLegalHierarchyRegistry.instance.allNodes.length, 6);
    });

    test('ancestorsOf — 형소법 → 헌법 체인', () {
      final chain = SgpLegalHierarchyRegistry.instance.ancestorsOf('KR-LAW-CRIM-PROC');
      expect(chain.first.level, LegalHierarchyLevel.constitution);
      expect(chain.any((n) => n.id == 'KR-LAW-CRIM-PROC'), isTrue);
    });

    test('순환 parent_id 감지', () {
      final list = jsonDecode(_inlineSeed) as List<dynamic>;
      final broken = List<Map<String, dynamic>>.from(
        list.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      broken.add({
        'id': 'CYCLE-A',
        'level': 2,
        'title': '순환 A',
        'parent_id': 'CYCLE-B',
        'scope': {'country': 'KR'},
        'domain_tags': ['criminal'],
      });
      broken.add({
        'id': 'CYCLE-B',
        'level': 2,
        'title': '순환 B',
        'parent_id': 'CYCLE-A',
        'scope': {'country': 'KR'},
        'domain_tags': ['criminal'],
      });

      expect(
        () => SgpLegalHierarchyRegistry.instance.loadFromJson(jsonEncode(broken)),
        throwsStateError,
      );
    });
  });

  group('SgpLegalHierarchyEngine', () {
    test('형사 앵커 — 헌법·형법·형소법·내부규정·매뉴얼 체인', () {
      final anchors = SgpLegalHierarchyEngine.inferAnchorIds(
        domainTags: {'criminal', 'procedure'},
        includeProcedure: true,
        includeEvidence: false,
        includeOrgManual: true,
      );

      final resolution = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext.fieldPolice,
        anchorNodeIds: anchors,
      );

      expect(resolution.chain, isNotEmpty);
      expect(resolution.chain.first.level, LegalHierarchyLevel.constitution);
      expect(resolution.chain.any((n) => n.id == 'KR-LAW-CRIMINAL'), isTrue);
      expect(resolution.chain.any((n) => n.id == 'MANUAL-SGP-FIELD-001'), isTrue);
    });

    test('동물 사건 — 동물보호법 앵커', () {
      final anchors = SgpLegalHierarchyEngine.inferAnchorIds(
        domainTags: domainTagsForIncidentKey('dog_bite_incident'),
        includeProcedure: true,
        includeEvidence: false,
        includeOrgManual: false,
      );

      final resolution = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext(
          orgId: 'KR-NPA',
          taskCategory: 'field_arrest',
          domainTags: domainTagsForIncidentKey('dog_bite_incident'),
        ),
        anchorNodeIds: anchors,
      );

      expect(resolution.chain.any((n) => n.id == 'KR-LAW-ANIMAL'), isTrue);
      expect(resolution.primaryLawTitle, anyOf('형법', '동물보호법'));
    });

    test('LV7 conflict_check — 상위법 경고', () {
      final resolution = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext.fieldPolice,
        anchorNodeIds: {'ORG-NPA-INVEST-RULE', 'MANUAL-SGP-FIELD-001'},
      );

      expect(resolution.hasUpperLawWarnings, isTrue);
      expect(resolution.conflicts, isNotEmpty);
      expect(resolution.conflicts.first.lowerNodeId, 'ORG-NPA-INVEST-RULE');
    });

    test('JSON 직렬화 왕복', () {
      final resolution = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext.fieldPolice,
        anchorNodeIds: {'KR-LAW-CRIMINAL'},
      );

      final restored = SgpHierarchyResolution.fromJson(resolution.toJson());
      expect(restored.chain.length, resolution.chain.length);
      expect(restored.primaryLawTitle, resolution.primaryLawTitle);
    });
  });

  group('HierarchyConflictResolver', () {
    test('상위법 우선 가이드 병합', () {
      final resolution = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext.fieldPolice,
        anchorNodeIds: {'ORG-NPA-INVEST-RULE'},
      );

      final resolved = HierarchyConflictResolver.resolve(
        hierarchy: resolution,
        perspectives: const [
          HierarchyPerspectiveRef(
            id: 'p1',
            kind: 'criminal',
            law: '형법 제260조',
            weightScore: 0.5,
          ),
          HierarchyPerspectiveRef(
            id: 'p2',
            kind: 'special',
            law: '가정폭력처벌법',
            weightScore: 0.8,
          ),
        ],
        baseActionGuidance: '테스트 지침',
      );

      expect(resolved.hasUpperLawWarnings, isTrue);
      expect(resolved.actionGuidance, contains('상위법 우선'));
      expect(resolved.actionGuidance, contains('테스트 지침'));
      expect(resolved.upperLawNotices, isNotEmpty);
    });

    test('Cross-Filter — 민법 관점 demote', () {
      final resolution = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext(
          orgId: 'KR-NPA',
          taskCategory: 'field_arrest',
          domainTags: {'animal', 'criminal'},
        ),
        anchorNodeIds: {'KR-LAW-ANIMAL', 'KR-LAW-CRIMINAL'},
      );

      final partition = SgpHierarchyCrossFilter.partition(
        const [
          HierarchyPerspectiveRef(
            id: 'crim',
            kind: 'criminal',
            law: '형법 제266조',
            weightScore: 0.5,
          ),
          HierarchyPerspectiveRef(
            id: 'civil',
            kind: 'civil',
            law: '민법 제759조',
            weightScore: 0.35,
          ),
        ],
        resolution,
      );

      expect(partition.matched, contains('crim'));
      expect(partition.demoted, contains('civil'));
    });
  });

  group('domainTagsForIncidentKey', () {
    test('교통·가정폭력 태그', () {
      expect(domainTagsForIncidentKey('traffic_incident'), contains('traffic'));
      expect(domainTagsForIncidentKey('domestic_violence'), contains('domestic_violence'));
    });
  });
}
