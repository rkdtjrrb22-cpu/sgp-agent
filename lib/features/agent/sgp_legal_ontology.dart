/// Sprint S6 — 법령 온톨로지(SPO·의미망) 모델 및 legal_nodes 마이그레이션.
library;

import 'sgp_legal_hierarchy.dart';

// ---------------------------------------------------------------------------
// Predicate — Subject-Predicate-Object 관계 유형
// ---------------------------------------------------------------------------

enum LegalPredicate {
  /// 하위법 → 상위법 (기존 parent_id)
  isSubordinateTo('is_subordinate_to'),

  /// 조문 인용·준거 (기존 linked_articles)
  citesArticle('cites_article'),

  /// 도메인 태그 적용
  appliesToDomain('applies_to_domain'),

  /// 상위법 충돌 후보
  conflictsWith('conflicts_with'),

  /// 조직 규정·매뉴얼의 상위법 준거
  governedBy('governed_by'),

  /// 파싱·시드 출처
  derivedFrom('derived_from'),

  /// S7-D — 민원 유형 → 관할 부서·기관
  hasJurisdiction('has_jurisdiction'),

  /// S7-D — 민원 유형 → 필요 서류
  requiresDocument('requires_document');

  const LegalPredicate(this.apiValue);

  final String apiValue;

  static LegalPredicate? fromApiValue(String value) {
    for (final p in LegalPredicate.values) {
      if (p.apiValue == value) return p;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Triple · Graph
// ---------------------------------------------------------------------------

/// SPO 트리플 — subject는 legal_nodes.id, object는 노드 ID 또는 리터럴 값.
class LegalOntologyTriple {
  const LegalOntologyTriple({
    required this.subjectId,
    required this.predicate,
    this.objectId,
    this.objectValue,
    this.confidence = 1.0,
    this.source,
    this.metadata = const {},
  });

  final String subjectId;
  final LegalPredicate predicate;
  final String? objectId;
  final String? objectValue;
  final double confidence;
  final String? source;
  final Map<String, String> metadata;

  String get id => [
        subjectId,
        predicate.apiValue,
        objectId ?? '',
        objectValue ?? '',
      ].join('|');

  factory LegalOntologyTriple.fromJson(Map<String, dynamic> json) {
    final predicate = LegalPredicate.fromApiValue(json['predicate'] as String);
    if (predicate == null) {
      throw FormatException('unknown predicate: ${json['predicate']}');
    }
    return LegalOntologyTriple(
      subjectId: json['subject_id'] as String,
      predicate: predicate,
      objectId: json['object_id'] as String?,
      objectValue: json['object_value'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      source: json['source'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'predicate': predicate.apiValue,
        if (objectId != null) 'object_id': objectId,
        if (objectValue != null) 'object_value': objectValue,
        'confidence': confidence,
        if (source != null) 'source': source,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

/// legal_nodes + triples 의미망.
class LegalOntologyGraph {
  LegalOntologyGraph({
    required List<LegalHierarchyNode> nodes,
    required List<LegalOntologyTriple> triples,
  })  : _nodes = {for (final n in nodes) n.id: n},
        _triples = List.unmodifiable(triples);

  final Map<String, LegalHierarchyNode> _nodes;
  final List<LegalOntologyTriple> _triples;

  List<LegalHierarchyNode> get nodes => _nodes.values.toList();

  List<LegalOntologyTriple> get triples => _triples;

  LegalHierarchyNode? nodeById(String id) => _nodes[id];

  List<LegalOntologyTriple> query({
    String? subjectId,
    LegalPredicate? predicate,
    String? objectId,
    String? objectValue,
  }) {
    return _triples.where((t) {
      if (subjectId != null && t.subjectId != subjectId) return false;
      if (predicate != null && t.predicate != predicate) return false;
      if (objectId != null && t.objectId != objectId) return false;
      if (objectValue != null && t.objectValue != objectValue) return false;
      return true;
    }).toList();
  }

  /// subject 기준 BFS 의미망 서브그래프 (parent·자식·인용·도메인 링크).
  LegalOntologySubgraph subgraphFrom({
    required String rootSubjectId,
    int maxDepth = 3,
    Set<LegalPredicate>? predicates,
  }) {
    final allowed = predicates ??
        {
          LegalPredicate.isSubordinateTo,
          LegalPredicate.citesArticle,
          LegalPredicate.appliesToDomain,
          LegalPredicate.governedBy,
          LegalPredicate.hasJurisdiction,
          LegalPredicate.requiresDocument,
        };

    final visitedNodes = <String>{};
    final visitedTriples = <String>{};
    final frontier = <(String, int)>[(rootSubjectId, 0)];

    while (frontier.isNotEmpty) {
      final (subject, depth) = frontier.removeAt(0);
      if (!visitedNodes.add(subject)) continue;

      for (final triple in _triplesForNode(subject, allowed)) {
        if (!visitedTriples.add(triple.id)) continue;
        if (depth >= maxDepth) continue;

        final nextIds = _neighborIds(triple, subject);
        for (final next in nextIds) {
          frontier.add((next, depth + 1));
        }
      }
    }

    return LegalOntologySubgraph(
      rootSubjectId: rootSubjectId,
      nodeIds: visitedNodes,
      triples: _triples.where((t) => visitedTriples.contains(t.id)).toList(),
    );
  }

  /// resolve 응답용 — 위계 체인 노드에 연결된 트리플만 추출.
  List<LegalOntologyTriple> triplesForChain(List<String> nodeIds) {
    final ids = nodeIds.toSet();
    return _triples
        .where(
          (t) =>
              ids.contains(t.subjectId) ||
              (t.objectId != null && ids.contains(t.objectId)),
        )
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'schema_version': '1.0',
        'node_count': _nodes.length,
        'triple_count': _triples.length,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'triples': _triples.map((t) => t.toJson()).toList(),
      };

  factory LegalOntologyGraph.fromJson(Map<String, dynamic> json) {
    final nodeList = (json['nodes'] as List<dynamic>? ?? [])
        .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final tripleList = (json['triples'] as List<dynamic>? ?? [])
        .map((e) => LegalOntologyTriple.fromJson(e as Map<String, dynamic>))
        .toList();
    return LegalOntologyGraph(nodes: nodeList, triples: tripleList);
  }

  Iterable<LegalOntologyTriple> _triplesForNode(
    String nodeId,
    Set<LegalPredicate> allowed,
  ) sync* {
    for (final t in _triples) {
      if (!allowed.contains(t.predicate)) continue;
      if (t.subjectId == nodeId || t.objectId == nodeId) yield t;
    }
  }

  List<String> _neighborIds(LegalOntologyTriple triple, String fromNodeId) {
    if (triple.subjectId == fromNodeId && triple.objectId != null) {
      return [triple.objectId!];
    }
    if (triple.objectId == fromNodeId && triple.subjectId != fromNodeId) {
      return [triple.subjectId];
    }
    return const [];
  }
}

class LegalOntologySubgraph {
  const LegalOntologySubgraph({
    required this.rootSubjectId,
    required this.nodeIds,
    required this.triples,
  });

  final String rootSubjectId;
  final Set<String> nodeIds;
  final List<LegalOntologyTriple> triples;

  Map<String, dynamic> toJson() => {
        'root_subject_id': rootSubjectId,
        'node_ids': nodeIds.toList(),
        'triples': triples.map((t) => t.toJson()).toList(),
      };
}

// ---------------------------------------------------------------------------
// Migrator — legal_nodes(JSON/DB) → ontology triples
// ---------------------------------------------------------------------------

abstract final class LegalOntologyMigrator {
  /// 시드·DB legal_nodes 배열을 SPO 트리플로 변환 (parent_id·linked_articles·domain_tags).
  static List<LegalOntologyTriple> triplesFromNodes(List<LegalHierarchyNode> nodes) {
    final triples = <LegalOntologyTriple>[];
    final seen = <String>{};

    void add(LegalOntologyTriple t) {
      if (seen.add(t.id)) triples.add(t);
    }

    for (final node in nodes) {
      if (node.parentId != null) {
        add(
          LegalOntologyTriple(
            subjectId: node.id,
            predicate: LegalPredicate.isSubordinateTo,
            objectId: node.parentId,
            source: node.source ?? 'hierarchy_seed',
          ),
        );
      }

      for (final link in node.linkedArticles) {
        add(
          LegalOntologyTriple(
            subjectId: node.id,
            predicate: LegalPredicate.citesArticle,
            objectId: link.upperNodeId,
            objectValue: link.article,
            source: node.source ?? 'ingest_pipeline',
            metadata: ifNotEmpty(note: link.note),
          ),
        );
        add(
          LegalOntologyTriple(
            subjectId: node.id,
            predicate: LegalPredicate.governedBy,
            objectId: link.upperNodeId,
            objectValue: link.article,
            source: node.source ?? 'ingest_pipeline',
          ),
        );
      }

      for (final tag in node.domainTags) {
        add(
          LegalOntologyTriple(
            subjectId: node.id,
            predicate: LegalPredicate.appliesToDomain,
            objectValue: tag,
            source: 'domain_tags',
          ),
        );
      }

      if (node.conflictCheck) {
        final parent = node.parentId;
        if (parent != null) {
          add(
            LegalOntologyTriple(
              subjectId: node.id,
              predicate: LegalPredicate.conflictsWith,
              objectId: parent,
              objectValue: 'conflict_check',
              confidence: 0.5,
              source: 'conflict_check_flag',
            ),
          );
        }
      }

      if (node.source != null) {
        add(
          LegalOntologyTriple(
            subjectId: node.id,
            predicate: LegalPredicate.derivedFrom,
            objectValue: node.source,
            source: 'node_metadata',
          ),
        );
      }
    }

    return triples;
  }

  static LegalOntologyGraph graphFromNodes(List<LegalHierarchyNode> nodes) {
    return LegalOntologyGraph(
      nodes: nodes,
      triples: triplesFromNodes(nodes),
    );
  }

  static LegalOntologyGraph graphFromRegistry(SgpLegalHierarchyRegistry registry) {
    return graphFromNodes(registry.allNodes);
  }

  /// PostgreSQL UPSERT용 행 (tool/cron·서버 배치).
  static List<Map<String, dynamic>> tripleRowsForSql(
    List<LegalOntologyTriple> triples,
  ) {
    return triples
        .map(
          (t) => {
            'subject_id': t.subjectId,
            'predicate': t.predicate.apiValue,
            'object_id': t.objectId,
            'object_value': t.objectValue,
            'confidence': t.confidence,
            'source': t.source,
            'metadata': t.metadata,
          },
        )
        .toList();
  }
}

Map<String, String> ifNotEmpty({String? note}) {
  if (note == null || note.isEmpty) return {};
  return {'note': note};
}
