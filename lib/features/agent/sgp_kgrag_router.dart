/// S10 — KG-RAG 하이브리드 Three-Track 라우터 (온톨로지 + 벡터 DB + LLM 컨텍스트).
library;

import 'sgp_civil_complaint_branch.dart';
import 'sgp_civil_complaint_data.dart';
import 'sgp_civil_complaint_router.dart';
import 'sgp_kgrag_loader.dart';
import 'sgp_legal_ontology.dart';
import 'sgp_vector_store.dart';

/// 벡터 검색 판례 히트.
class KgragPrecedentHit {
  const KgragPrecedentHit({
    required this.id,
    required this.court,
    required this.caseNo,
    required this.holding,
    required this.similarity,
    required this.articleRefs,
    required this.ontologyNodes,
  });

  final String id;
  final String court;
  final String caseNo;
  final String holding;
  final double similarity;
  final List<String> articleRefs;
  final List<String> ontologyNodes;
}

/// 온톨로지 가이드레일 (KG Shield).
class KgragOntologyShield {
  const KgragOntologyShield({
    required this.legalNodeIds,
    required this.triples,
    this.complaintRoute,
    this.branchResult,
  });

  final List<String> legalNodeIds;
  final List<LegalOntologyTriple> triples;
  final CivilComplaintRouteResult? complaintRoute;
  final CivilComplaintBranchResult? branchResult;
}

/// KG-RAG 추론 결과.
class KgragReasoningResult {
  const KgragReasoningResult({
    required this.query,
    required this.ontologyShield,
    required this.precedentHits,
    required this.promptContext,
    required this.recommendedAction,
    required this.selfDefenseProbability,
    required this.confidenceLabel,
    required this.matchedCorpusCount,
    required this.hallucinationGuardPass,
    required this.confidence,
  });

  final String query;
  final KgragOntologyShield ontologyShield;
  final List<KgragPrecedentHit> precedentHits;
  final String promptContext;
  final String recommendedAction;
  final double selfDefenseProbability;
  final String confidenceLabel;
  final int matchedCorpusCount;
  final bool hallucinationGuardPass;
  final double confidence;

  bool get isHighConfidence => confidence >= 0.45;

  int get precedentMatchCount => precedentHits.length;
}

abstract final class SgpKgragRouter {
  static final _selfDefenseKw =
      RegExp(r'(정당방위|긴급피난|방어|막으|피해|물림|물어|개|맹견|발로|찼|폭행죄)');
  static final _mutualKw = RegExp(r'(쌍방|서로|싸웠|폭행|맞았|주인이)');

  /// Three-Track 하이브리드 추론.
  static KgragReasoningResult? reasonFromText(
    String rawText, {
    required CivilComplaintNodePack? complaintPack,
    LegalOntologyGraph? graph,
    SgpVectorStore? vectorStore,
    int topK = 5,
  }) {
    final query = rawText.trim();
    if (query.isEmpty) return null;

    final store = vectorStore ?? SgpVectorStoreSession.instance;
    if (store.corpusSize == 0) return null;

    // Track 1 — 온톨로지 가이드레일
    CivilComplaintRouteResult? route;
    CivilComplaintBranchResult? branch;
    if (complaintPack != null) {
      route = SgpCivilComplaintRouter.routeFromText(query, complaintPack, graph: graph);
      if (route != null) {
        branch = route.inferEnforcement(query);
      }
    }

    final nodeIds = <String>{};
    final triples = <LegalOntologyTriple>[];

    if (branch != null) {
      nodeIds.addAll(branch.legalNodeIds);
    }
    if (route != null && graph != null) {
      final juris = graph.query(
        subjectId: route.type.id,
        predicate: LegalPredicate.hasJurisdiction,
      );
      triples.addAll(juris);
      for (final t in juris) {
        if (t.objectId != null) nodeIds.add(t.objectId!);
      }
      final docs = graph.query(
        subjectId: route.type.id,
        predicate: LegalPredicate.requiresDocument,
      );
      triples.addAll(docs);
    }

    // 정당방위·긴급피난 기본 노드
    if (_selfDefenseKw.hasMatch(query)) {
      nodeIds.addAll(['KR-LAW-CRIMINAL', 'KR-CRIM-257-BODILY']);
    }

    // Track 2 — 벡터 DB 코사인 유사도 검색
    final hits = store.search(query, topK: topK);
    final precedentHits = hits.map(_hitFromVector).toList();
    for (final h in precedentHits) {
      nodeIds.addAll(h.ontologyNodes);
    }

    // Track 3 — 프롬프트 컨텍스트 조립
    final promptContext = _assemblePromptContext(
      query: query,
      nodeIds: nodeIds.toList(),
      triples: triples,
      hits: precedentHits,
      branch: branch,
      route: route,
    );

    final selfDefProb = _estimateSelfDefenseProbability(
      query: query,
      hits: precedentHits,
      branch: branch,
    );

    final matchCount = store.search(query, topK: 87, minScore: 0.08).length;
    final confidence = _computeConfidence(
      route: route,
      hits: precedentHits,
      nodeIds: nodeIds,
      selfDefProb: selfDefProb,
    );

    final guardPass = nodeIds.isNotEmpty &&
        precedentHits.isNotEmpty &&
        precedentHits.first.similarity >= 0.12;

    final action = _buildRecommendedAction(
      query: query,
      selfDefProb: selfDefProb,
      branch: branch,
      guardPass: guardPass,
    );

    return KgragReasoningResult(
      query: query,
      ontologyShield: KgragOntologyShield(
        legalNodeIds: nodeIds.toList(),
        triples: triples,
        complaintRoute: route,
        branchResult: branch,
      ),
      precedentHits: precedentHits,
      promptContext: promptContext,
      recommendedAction: action,
      selfDefenseProbability: selfDefProb,
      confidenceLabel: _confidenceLabel(selfDefProb, confidence),
      matchedCorpusCount: matchCount,
      hallucinationGuardPass: guardPass,
      confidence: confidence,
    );
  }

  static KgragPrecedentHit _hitFromVector(SgpVectorSearchHit hit) {
    final m = hit.record.metadata;
    return KgragPrecedentHit(
      id: hit.record.id,
      court: m['court'] as String? ?? '',
      caseNo: m['case_no'] as String? ?? '',
      holding: m['holding'] as String? ?? hit.record.text,
      similarity: hit.score,
      articleRefs: (m['article_refs'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      ontologyNodes: (m['ontology_nodes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static String _assemblePromptContext({
    required String query,
    required List<String> nodeIds,
    required List<LegalOntologyTriple> triples,
    required List<KgragPrecedentHit> hits,
    CivilComplaintBranchResult? branch,
    CivilComplaintRouteResult? route,
  }) {
    final buf = StringBuffer()
      ..writeln('[KG-RAG CONTEXT BINDING]')
      ..writeln('QUERY: $query');

    if (route != null) {
      buf.writeln('COMPLAINT_TYPE: ${route.type.id} (${route.type.title})');
    }
    if (branch != null) {
      buf.writeln(
        'ENFORCEMENT: ${SgpCivilComplaintBranchRouter.branchLabel(branch.branch)}',
      );
      buf.writeln('RATIONALE: ${branch.rationale}');
    }

    if (nodeIds.isNotEmpty) {
      buf.writeln('KG_NODES: ${nodeIds.join(', ')}');
    }

    for (final t in triples.take(8)) {
      buf.writeln(
        'TRIPLE: ${t.subjectId} ${t.predicate.apiValue} ${t.objectId ?? t.objectValue}',
      );
    }

    for (final h in hits) {
      buf.writeln(
        'PRECEDENT[${h.court} ${h.caseNo} sim=${(h.similarity * 100).round()}%]: ${h.holding}',
      );
    }

    buf.writeln('[END CONTEXT — LLM MUST CITE ABOVE ONLY]');
    return buf.toString();
  }

  static double _estimateSelfDefenseProbability({
    required String query,
    required List<KgragPrecedentHit> hits,
    CivilComplaintBranchResult? branch,
  }) {
    var prob = 0.35;
    if (_selfDefenseKw.hasMatch(query)) prob += 0.25;
    if (_mutualKw.hasMatch(query) && query.contains('방어')) prob += 0.15;
    if (hits.any((h) => _domainLike(h, 'self_defense') || _domainLike(h, 'emergency'))) {
      prob += 0.2;
    }
    if (hits.isNotEmpty) {
      prob += hits.first.similarity * 0.25;
    }
    if (branch != null && !branch.isCriminal) prob += 0.05;
    if (branch != null && branch.isCriminal && query.contains('물림')) {
      prob += 0.1;
    }
    return prob.clamp(0.0, 1.0);
  }

  static double _computeConfidence({
    CivilComplaintRouteResult? route,
    required List<KgragPrecedentHit> hits,
    required Set<String> nodeIds,
    required double selfDefProb,
  }) {
    var c = 0.2;
    if (route != null) c += route.confidence * 0.35;
    if (hits.isNotEmpty) c += hits.first.similarity * 0.35;
    if (nodeIds.length >= 3) c += 0.1;
    c += selfDefProb * 0.15;
    return c.clamp(0.0, 1.0);
  }

  static String _confidenceLabel(double selfDefProb, double confidence) {
    if (selfDefProb >= 0.75 && confidence >= 0.55) return 'High';
    if (selfDefProb >= 0.5 || confidence >= 0.4) return 'Medium';
    return 'Low';
  }

  static String _buildRecommendedAction({
    required String query,
    required double selfDefProb,
    CivilComplaintBranchResult? branch,
    required bool guardPass,
  }) {
    if (!guardPass) {
      return '온톨로지·판례 교차 검증 미충족 — 추가 사실관계 확인 후 조치.';
    }

    if (_dogDefenseScenario(query)) {
      return '현장 조치 지침: 현행 폭행 혐의 입건 대상 아님 고지. '
          '긴급피난 성립 확률 매우 높음 명시 및 소견서 확보 안내.';
    }

    if (selfDefProb >= 0.75) {
      return '정당방위·긴급피난 성립 가능성 높음 — 쌍방 입건 지양, '
          '선제공격·흉기 주도권·피해 규모 재검토 후 피의자·피해자 구분.';
    }

    if (branch != null && branch.isCriminal) {
      return '형사과 수사 착수 검토 — ${branch.rationale}';
    }

    if (branch != null && !branch.isCriminal) {
      return '지자체 행정 이관 안내 — ${branch.rationale}';
    }

    return 'KG-RAG 교차 검증 완료 — 온톨로지·판례 근거에 따른 조치 지침 생성.';
  }

  /// 앱 기동 시 벡터 인덱스 초기화.
  static SgpVectorStore initializeFromPack(KgragPrecedentPack pack) =>
      SgpKgragLoader.buildVectorIndex(pack);

  static bool _dogDefenseScenario(String query) {
    final animal = RegExp(r'(개|맹견|견|반려견)');
    final attack = RegExp(r'(물|맹견|달려|공격)');
    final defense = RegExp(r'(방어|긴급피난|찼|발로)');
    return animal.hasMatch(query) && attack.hasMatch(query) && defense.hasMatch(query);
  }

  static bool _domainLike(KgragPrecedentHit hit, String token) =>
      hit.holding.contains(token) ||
      hit.id.toLowerCase().contains(token.replaceAll('_', '-'));
}
