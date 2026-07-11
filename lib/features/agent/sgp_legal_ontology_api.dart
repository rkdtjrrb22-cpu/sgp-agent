/// Sprint S6 — 온톨로지 REST API DTO.
library;

import 'sgp_legal_hierarchy.dart';
import 'sgp_legal_ontology.dart';

class LegalOntologyGraphResponse {
  const LegalOntologyGraphResponse({
    required this.graph,
    this.schemaVersion = '1.0',
  });

  final LegalOntologyGraph graph;
  final String schemaVersion;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'node_count': graph.nodes.length,
        'triple_count': graph.triples.length,
        'nodes': graph.nodes.map((n) => n.toJson()).toList(),
        'triples': graph.triples.map((t) => t.toJson()).toList(),
      };
}

class LegalOntologyTripleQueryRequest {
  const LegalOntologyTripleQueryRequest({
    this.subjectId,
    this.predicate,
    this.objectId,
    this.objectValue,
    this.rootSubjectId,
    this.maxDepth = 3,
  });

  final String? subjectId;
  final String? predicate;
  final String? objectId;
  final String? objectValue;
  final String? rootSubjectId;
  final int maxDepth;

  factory LegalOntologyTripleQueryRequest.fromJson(Map<String, dynamic> json) {
    return LegalOntologyTripleQueryRequest(
      subjectId: json['subject_id'] as String?,
      predicate: json['predicate'] as String?,
      objectId: json['object_id'] as String?,
      objectValue: json['object_value'] as String?,
      rootSubjectId: json['root_subject_id'] as String?,
      maxDepth: json['max_depth'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        if (subjectId != null) 'subject_id': subjectId,
        if (predicate != null) 'predicate': predicate,
        if (objectId != null) 'object_id': objectId,
        if (objectValue != null) 'object_value': objectValue,
        if (rootSubjectId != null) 'root_subject_id': rootSubjectId,
        'max_depth': maxDepth,
      };
}

class LegalOntologyTripleQueryResponse {
  const LegalOntologyTripleQueryResponse({
    required this.triples,
    this.subgraph,
    this.schemaVersion = '1.0',
  });

  final List<LegalOntologyTriple> triples;
  final LegalOntologySubgraph? subgraph;
  final String schemaVersion;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'count': triples.length,
        'triples': triples.map((t) => t.toJson()).toList(),
        if (subgraph != null) 'subgraph': subgraph!.toJson(),
      };
}

class LegalOntologyMigratePreviewResponse {
  const LegalOntologyMigratePreviewResponse({
    required this.nodeCount,
    required this.tripleCount,
    required this.sampleTriples,
    required this.predicateCounts,
  });

  final int nodeCount;
  final int tripleCount;
  final List<LegalOntologyTriple> sampleTriples;
  final Map<String, int> predicateCounts;

  Map<String, dynamic> toJson() => {
        'node_count': nodeCount,
        'triple_count': tripleCount,
        'predicate_counts': predicateCounts,
        'sample_triples': sampleTriples.map((t) => t.toJson()).toList(),
      };
}

/// resolve 응답에 포함되는 온톨로지 컨텍스트 (schema 1.1).
class LegalOntologyResolveContext {
  const LegalOntologyResolveContext({
    required this.chainNodeIds,
    required this.relatedTriples,
  });

  final List<String> chainNodeIds;
  final List<LegalOntologyTriple> relatedTriples;

  Map<String, dynamic> toJson() => {
        'chain_node_ids': chainNodeIds,
        'related_triples': relatedTriples.map((t) => t.toJson()).toList(),
      };

  static LegalOntologyResolveContext? fromHierarchyAndGraph({
    required SgpHierarchyResolution? hierarchy,
    required LegalOntologyGraph? graph,
  }) {
    if (hierarchy == null || graph == null) return null;
    final chainIds = hierarchy.chain.map((n) => n.id).toList();
    if (chainIds.isEmpty) return null;
    return LegalOntologyResolveContext(
      chainNodeIds: chainIds,
      relatedTriples: graph.triplesForChain(chainIds),
    );
  }
}
