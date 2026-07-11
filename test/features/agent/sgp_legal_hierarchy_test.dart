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

  group('SgpLegalHierarchyTreeBuilder', () {
    test('buildForest — parent_id 트리 구조', () {
      SgpLegalHierarchyRegistry.instance.loadFromJson('''
[
  {"id":"KR-CONST-001","level":1,"title":"헌법","parent_id":null,"scope":{"country":"KR"},"domain_tags":["all"]},
  {"id":"KR-LAW-CRIMINAL","level":2,"title":"형법","parent_id":"KR-CONST-001","scope":{"country":"KR"},"domain_tags":["criminal"]},
  {"id":"KR-LOCAL-11-ORD","level":5,"title":"서울 조례","parent_id":"KR-LAW-CRIMINAL","scope":{"country":"KR","local_gov_code":"11"},"domain_tags":["criminal"]},
  {"id":"KR-LOCAL-11-RULE","level":6,"title":"서울 규칙","parent_id":"KR-LOCAL-11-ORD","scope":{"country":"KR","local_gov_code":"11"},"domain_tags":["criminal"]}
]
''');

      final resolution = SgpLegalHierarchyEngine.resolve(
        context: const LegalHierarchyContext(localGovCode: '11', domainTags: {'criminal'}),
        anchorNodeIds: {'KR-LAW-CRIMINAL'},
      );

      final forest = SgpLegalHierarchyTreeBuilder.buildForest(resolution.chain);
      expect(forest.length, 1);
      expect(forest.first.node.id, 'KR-CONST-001');
      expect(forest.first.children.single.node.id, 'KR-LAW-CRIMINAL');
      expect(forest.first.children.single.children.single.node.id, 'KR-LOCAL-11-ORD');
    });
  });

  group('inferLocalGovCodeFromText', () {
    test('서울·부산 키워드', () {
      expect(inferLocalGovCodeFromText('서울 강남구 현장'), '11');
      expect(inferLocalGovCodeFromText('부산 해운대'), '26');
      expect(inferLocalGovCodeFromText('일반 사건'), isNull);
    });
  });

  group('LV5~6 local_gov_code 필터', () {
    test('서울 조례만 포함·부산 제외', () {
      SgpLegalHierarchyRegistry.instance.loadFromJson('''
[
  {"id":"KR-CONST-001","level":1,"title":"헌법","parent_id":null,"scope":{"country":"KR"},"domain_tags":["all"]},
  {"id":"KR-LAW-CRIMINAL","level":2,"title":"형법","parent_id":"KR-CONST-001","scope":{"country":"KR"},"domain_tags":["criminal"]},
  {"id":"KR-LOCAL-11-ORD","level":5,"title":"서울 조례","parent_id":"KR-LAW-CRIMINAL","scope":{"country":"KR","local_gov_code":"11"},"domain_tags":["criminal"]},
  {"id":"KR-LOCAL-26-ORD","level":5,"title":"부산 조례","parent_id":"KR-LAW-CRIMINAL","scope":{"country":"KR","local_gov_code":"26"},"domain_tags":["criminal"]}
]
''');

      final seoul = SgpLegalHierarchyEngine.resolve(
        context: const LegalHierarchyContext(localGovCode: '11', domainTags: {'criminal'}),
        anchorNodeIds: {'KR-LAW-CRIMINAL'},
      );
      expect(seoul.chain.any((n) => n.id == 'KR-LOCAL-11-ORD'), isTrue);
      expect(seoul.chain.any((n) => n.id == 'KR-LOCAL-26-ORD'), isFalse);
    });
  });

  group('S4 — SgpHierarchyIngestPipeline', () {
    test('조문 추출·정규화·중복 제거', () {
      final articles = SgpHierarchyIngestPipeline.extractArticles(
        '체포는 형사소송법 제200조의2 및 제 212 조에 따른다. 제212조 재언급.',
      );
      expect(articles, contains('제200조의2'));
      expect(articles, contains('제212조'));
      expect(articles.where((a) => a == '제212조').length, 1);
    });

    test('상위법 조문 링크 추론 — 문장 근접 매칭', () {
      final result = SgpHierarchyIngestPipeline.inferArticleLinks(
        '체포현장 압수는 형사소송법 제216조에 근거한다.\n'
        '영상녹화는 경찰관 직무집행법 제10조의2 고지가 필요하다.',
      );
      expect(result.links.length, 2);
      expect(
        result.links.any((l) => l.upperNodeId == 'KR-LAW-CRIM-PROC' && l.article == '제216조'),
        isTrue,
      );
      expect(
        result.links.any((l) => l.upperNodeId == 'KR-LAW-POLICE-DUTY' && l.article == '제10조의2'),
        isTrue,
      );
      expect(result.unresolved, isEmpty);
    });

    test('상위법 미상 조문 — unresolved 처리', () {
      final result = SgpHierarchyIngestPipeline.inferArticleLinks('내부 지침 제5조에 따른다.');
      expect(result.links, isEmpty);
      expect(result.unresolved, contains('제5조'));
    });

    test('ingest — LV8 매뉴얼 노드 생성·태깅', () {
      final report = SgpHierarchyIngestPipeline.ingest(
        HierarchyIngestSource(
          id: 'MANUAL-TEST-001',
          title: '테스트 채증 매뉴얼',
          level: LegalHierarchyLevel.manual,
          parentId: 'ORG-NPA-EVIDENCE-GUIDE',
          rawText: '바디캠 채증 시 경찰관 직무집행법 제10조의2 고지를 이행한다.',
          scope: const {'org_id': 'KR-NPA', 'task_category': 'field_arrest'},
          sourceName: 'test_manual.md',
        ),
      );

      expect(report.node.level, LegalHierarchyLevel.manual);
      expect(report.node.conflictCheck, isTrue);
      expect(report.node.domainTags, contains('evidence'));
      expect(report.node.linkedArticles.single.upperNodeId, 'KR-LAW-POLICE-DUTY');
      expect(report.node.source, 'test_manual.md');
      expect(report.requiresManualReview, isFalse);
    });

    test('ingest — 상위법 링크 없으면 수기 확인 경고', () {
      final report = SgpHierarchyIngestPipeline.ingest(
        HierarchyIngestSource(
          id: 'ORG-TEST-002',
          title: '근거 불명 규정',
          level: LegalHierarchyLevel.internalRegulation,
          parentId: 'KR-LAW-CRIM-PROC',
          rawText: '내부 절차 제3조에 따라 처리한다.',
          scope: const {'org_id': 'KR-NPA'},
        ),
      );
      expect(report.requiresManualReview, isTrue);
      expect(report.warnings, isNotEmpty);
    });

    test('toJson/fromJson — linked_articles 왕복', () {
      final report = SgpHierarchyIngestPipeline.ingest(
        HierarchyIngestSource(
          id: 'MANUAL-TEST-003',
          title: '왕복 매뉴얼',
          level: LegalHierarchyLevel.manual,
          parentId: 'ORG-NPA-INVEST-RULE',
          rawText: '체포현장 압수는 형사소송법 제216조에 근거한다.',
          scope: const {'org_id': 'KR-NPA', 'task_category': 'field_arrest'},
        ),
      );
      final restored = LegalHierarchyNode.fromJson(report.node.toJson());
      expect(restored.linkedArticles.single.upperNodeId, 'KR-LAW-CRIM-PROC');
      expect(restored.linkedArticles.single.article, '제216조');
    });
  });
}
