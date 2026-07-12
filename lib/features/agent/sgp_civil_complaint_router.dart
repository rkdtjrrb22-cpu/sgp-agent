/// S7-D — 민원 의도 분석·온톨로지 라우팅 엔진.
library;

import 'sgp_civil_complaint_data.dart';
import 'sgp_legal_ontology.dart';

abstract final class SgpCivilComplaintRouter {
  /// civil_complaint_nodes.json → has_jurisdiction / requires_document 트리플.
  static List<LegalOntologyTriple> triplesFromPack(CivilComplaintNodePack pack) {
    final triples = <LegalOntologyTriple>[];
    final seen = <String>{};

    void add(LegalOntologyTriple t) {
      if (seen.add(t.id)) triples.add(t);
    }

    for (final type in pack.types) {
      for (final j in type.jurisdictions) {
        add(
          LegalOntologyTriple(
            subjectId: type.id,
            predicate: LegalPredicate.hasJurisdiction,
            objectId: j.agencyId,
            objectValue: j.scope ?? j.agencyName,
            source: 'civil_complaint_seed',
            metadata: {
              if (j.phone != null) 'phone': j.phone!,
              if (j.transfer) 'transfer': 'true',
            },
          ),
        );
      }

      for (final doc in type.requiredDocuments) {
        add(
          LegalOntologyTriple(
            subjectId: type.id,
            predicate: LegalPredicate.requiresDocument,
            objectValue: doc.docType,
            source: 'civil_complaint_seed',
            metadata: {
              'label': doc.label,
              'required': doc.required.toString(),
            },
          ),
        );
      }

      add(
        LegalOntologyTriple(
          subjectId: type.id,
          predicate: LegalPredicate.appliesToDomain,
          objectValue: 'civil_complaint',
          source: 'civil_complaint_seed',
        ),
      );
    }

    return triples;
  }

  /// 시드 위계 노드 + 민원 트리플 통합 그래프.
  static LegalOntologyGraph mergeComplaintTriples({
    required LegalOntologyGraph base,
    required CivilComplaintNodePack pack,
  }) {
    final extra = triplesFromPack(pack);
    return LegalOntologyGraph(
      nodes: base.nodes,
      triples: [...base.triples, ...extra],
    );
  }

  /// 자연어 → 민원 유형 라우팅 (키워드·의도 패턴 점수).
  static CivilComplaintRouteResult? routeFromText(
    String rawText,
    CivilComplaintNodePack pack, {
    LegalOntologyGraph? graph,
  }) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    CivilComplaintType? best;
    var bestScore = 0.0;
    var bestKeywords = <String>[];

    for (final type in pack.types) {
      final (score, hits) = _scoreType(text, type);
      if (score > bestScore) {
        bestScore = score;
        best = type;
        bestKeywords = hits;
      }
    }

    if (best == null || bestScore <= 0) return null;

    final tripleCount = graph == null
        ? 0
        : graph
            .query(subjectId: best.id)
            .where(
              (t) =>
                  t.predicate == LegalPredicate.hasJurisdiction ||
                  t.predicate == LegalPredicate.requiresDocument,
            )
            .length;

    return CivilComplaintRouteResult(
      type: best,
      matchedKeywords: bestKeywords,
      confidence: bestScore.clamp(0.0, 1.0),
      ontologyTripleCount: tripleCount,
    );
  }

  static (double, List<String>) _scoreType(String text, CivilComplaintType type) {
    var score = 0.0;
    final hits = <String>[];

    for (final kw in type.keywords) {
      if (text.contains(kw)) {
        score += 0.25;
        hits.add(kw);
      }
    }

    for (final pattern in type.intentPatterns) {
      try {
        if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
          score += 0.35;
          hits.add('~$pattern');
        }
      } catch (_) {
        // ignore invalid pattern in seed
      }
    }

    return (score, hits);
  }

  /// 그래프에서 유형별 관할·서류 조회.
  static ({
    List<LegalOntologyTriple> jurisdictions,
    List<LegalOntologyTriple> documents,
  }) queryRouteOntology(LegalOntologyGraph graph, String typeId) {
    return (
      jurisdictions: graph.query(
        subjectId: typeId,
        predicate: LegalPredicate.hasJurisdiction,
      ),
      documents: graph.query(
        subjectId: typeId,
        predicate: LegalPredicate.requiresDocument,
      ),
    );
  }
}
