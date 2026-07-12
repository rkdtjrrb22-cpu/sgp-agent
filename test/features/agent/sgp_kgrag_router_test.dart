import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_civil_complaint_data.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_router.dart';
import 'package:sgp_agent/features/agent/sgp_embedding.dart';
import 'package:sgp_agent/features/agent/sgp_kgrag_loader.dart';
import 'package:sgp_agent/features/agent/sgp_kgrag_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:sgp_agent/features/agent/sgp_vector_store.dart';
import 'package:test/test.dart';

void main() {
  group('S10 KG-RAG Hybrid Engine', () {
    late KgragPrecedentPack kgragPack;
    late SgpVectorStore vectorStore;
    late CivilComplaintNodePack complaintPack;
    late LegalOntologyGraph graph;

    const dogScenario =
        '이웃집 맹견이 목줄 없이 달려들어 방어하려다 발로 찼는데 주인이 폭행죄라며 소리칩니다.';

    setUp(() {
      SgpVectorStoreSession.reset();
      SgpKgragLoader.resetCache();

      final kgragJson =
          File('assets/data/kgrag_precedents.json').readAsStringSync();
      kgragPack = SgpKgragLoader.parsePack(kgragJson);
      vectorStore = SgpKgragLoader.buildVectorIndex(kgragPack);

      final ccJson =
          File('assets/data/civil_complaint_nodes.json').readAsStringSync();
      complaintPack = CivilComplaintNodePack.fromJson(
        jsonDecode(ccJson) as Map<String, dynamic>,
      );

      final seedJson =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      final seedNodes = (jsonDecode(seedJson) as List<dynamic>)
          .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
          .toList();
      final base = LegalOntologyMigrator.graphFromNodes(seedNodes);
      graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: base,
        pack: complaintPack,
      );
    });

    test('SgpEmbedding — 64차원 bge-small-ko 호환', () {
      final v = SgpEmbedding.embed('정당방위 긴급피난');
      expect(v.length, SgpEmbedding.dimension);
      expect(SgpEmbedding.modelId, 'bge-small-ko-v1.5');
    });

    test('SgpEmbedding — 동일 텍스트 결정론 임베딩', () {
      final a = SgpEmbedding.embed('개물림 방어');
      final b = SgpEmbedding.embed('개물림 방어');
      expect(SgpEmbedding.cosineSimilarity(a, b), closeTo(1.0, 0.001));
    });

    test('SgpEmbedding — 유사 텍스트 코사인 > 비유사', () {
      final dog = SgpEmbedding.embed('개 물림 긴급피난 방어');
      final similar = SgpEmbedding.embed('맹견 공격 정당방위');
      final unrelated = SgpEmbedding.embed('교통범칙금 이의신청');
      expect(
        SgpEmbedding.cosineSimilarity(dog, similar),
        greaterThan(SgpEmbedding.cosineSimilarity(dog, unrelated)),
      );
    });

    test('SgpVectorStore — upsert·corpusSize', () {
      final store = SgpVectorStore();
      store.upsertText(id: 'T1', text: '테스트 판례');
      expect(store.corpusSize, 1);
    });

    test('SgpVectorStore — 코사인 Top-K 검색', () {
      final hits = vectorStore.search('정당방위 개 물림', topK: 3);
      expect(hits, isNotEmpty);
      expect(hits.first.score, greaterThan(0.1));
    });

    test('SgpKgragLoader — 시드 판례 25종 이상', () {
      expect(kgragPack.precedents.length, greaterThanOrEqualTo(25));
      expect(kgragPack.model, 'bge-small-ko-v1.5');
    });

    test('SgpKgragLoader — 700종 벡터 인덱스 구축', () {
      expect(vectorStore.corpusSize, 700);
    });

    test('SgpVectorStore — JSON export/import 라운드트립', () {
      final exported = vectorStore.exportJson();
      final store2 = SgpVectorStore();
      store2.importJson(exported);
      expect(store2.corpusSize, 700);
    });

    test('SgpKgragRouter — 빈 쿼리 null', () {
      expect(
        SgpKgragRouter.reasonFromText('', complaintPack: complaintPack),
        isNull,
      );
    });

    test('SgpKgragRouter — 맹견·방어 시나리오 추론', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r, isNotNull);
      expect(r!.isHighConfidence, isTrue);
    });

    test('SgpKgragRouter — 환각 방지 가드 PASS', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.hallucinationGuardPass, isTrue);
    });

    test('SgpKgragRouter — 정당방위 확률 High 구간', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.selfDefenseProbability, greaterThan(0.65));
    });

    test('SgpKgragRouter — 권고 조치 긴급피난·폭행 입건 지양', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.recommendedAction, contains('긴급피난'));
      expect(r.recommendedAction, contains('폭행'));
    });

    test('SgpKgragRouter — 온톨로지 Shield 노드', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.ontologyShield.legalNodeIds, isNotEmpty);
    });

    test('SgpKgragRouter — promptContext PRECEDENT 바인딩', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.promptContext, contains('PRECEDENT'));
      expect(r.promptContext, contains('END CONTEXT'));
    });

    test('SgpKgragRouter — promptContext KG_NODES', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.promptContext, contains('KG_NODES'));
    });

    test('SgpKgragRouter — 민원 라우트 연동', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.ontologyShield.complaintRoute, isNotNull);
    });

    test('SgpKgragRouter — 목줄·행정 분기 (순수 행정 쿼리)', () {
      final r = SgpKgragRouter.reasonFromText(
        '개 목줄 안 하고 산책해요',
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.ontologyShield.branchResult, isNotNull);
      expect(r.ontologyShield.branchResult!.isCriminal, isFalse);
    });

    test('SgpKgragRouter — 판례 히트 유사도', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.precedentHits, isNotEmpty);
      expect(r.precedentHits.first.similarity, greaterThan(0.1));
    });

    test('SgpKgragRouter — matchedCorpusCount > 0', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.matchedCorpusCount, greaterThan(0));
    });

    test('SgpKgragRouter — confidenceLabel', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(['High', 'Medium', 'Low'], contains(r!.confidenceLabel));
    });

    test('SgpKgragRouter — promptContext TRIPLE 바인딩', () {
      final r = SgpKgragRouter.reasonFromText(
        '개 목줄 미착용 신고',
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.promptContext, contains('TRIPLE'));
    });

    test('SgpKgragRouter — 권고 조치 비어있지 않음', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.recommendedAction.length, greaterThan(20));
    });

    test('SgpVectorStore — minScore 필터', () {
      final hits = vectorStore.search('xyz unrelated noise', minScore: 0.99);
      expect(hits, isEmpty);
    });

    test('KgragPrecedentHit — court·caseNo 메타', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      final hit = r!.precedentHits.first;
      expect(hit.court, isNotEmpty);
      expect(hit.holding, isNotEmpty);
    });

    test('SgpKgragRouter — 쌍방 폭행 쿼리 판례 매칭', () {
      final r = SgpKgragRouter.reasonFromText(
        '쌍방 폭행 서로 주고받았는데 정당방위 주장',
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.precedentHits, isNotEmpty);
    });

    test('SgpKgragRouter — 개물림 형사 분기 프롬프트', () {
      final r = SgpKgragRouter.reasonFromText(
        '개한테 물려서 병원 갔어요',
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.promptContext, contains('ENFORCEMENT'));
    });

    test('SgpKgragRouter — ontology triples has_jurisdiction', () {
      final r = SgpKgragRouter.reasonFromText(
        '개 목줄 미착용 신고',
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(
        r!.ontologyShield.triples.any(
          (t) => t.predicate == LegalPredicate.hasJurisdiction,
        ),
        isTrue,
      );
    });

    test('SgpKgragRouter — confidence >= 0.45 고신뢰', () {
      final r = SgpKgragRouter.reasonFromText(
        dogScenario,
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: vectorStore,
      );
      expect(r!.confidence, greaterThanOrEqualTo(0.45));
    });

    test('SgpKgragRouter — SC-2024-DOG-EMERGENCY 코퍼스 존재', () {
      final ids = vectorStore.records.map((r) => r.id).toSet();
      expect(ids.any((id) => id.startsWith('SC-2024-DOG-EMERGENCY')), isTrue);
    });
  });
}
