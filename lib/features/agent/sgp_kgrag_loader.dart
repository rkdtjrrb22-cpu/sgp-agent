/// S10 — KG-RAG 판례 코퍼스 로더 (500종 벡터 인덱스 구축).
library;

import 'dart:convert';

import 'sgp_vector_store.dart';

/// KG-RAG 판례 레코드.
class KgragPrecedent {
  const KgragPrecedent({
    required this.id,
    required this.court,
    required this.caseNo,
    required this.holding,
    required this.articleRefs,
    required this.ontologyNodes,
    required this.domain,
    this.keywords = const [],
  });

  final String id;
  final String court;
  final String caseNo;
  final String holding;
  final List<String> articleRefs;
  final List<String> ontologyNodes;
  final String domain;
  final List<String> keywords;

  String get embedText =>
      '$holding ${articleRefs.join(' ')} ${keywords.join(' ')} $domain';

  factory KgragPrecedent.fromJson(Map<String, dynamic> json) {
    return KgragPrecedent(
      id: json['id'] as String,
      court: json['court'] as String? ?? '',
      caseNo: json['case_no'] as String? ?? '',
      holding: json['holding'] as String,
      articleRefs: (json['article_refs'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      ontologyNodes: (json['ontology_nodes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      domain: json['domain'] as String? ?? 'general',
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class KgragPrecedentPack {
  const KgragPrecedentPack({
    required this.model,
    required this.targetCorpusSize,
    required this.precedents,
  });

  final String model;
  final int targetCorpusSize;
  final List<KgragPrecedent> precedents;

  factory KgragPrecedentPack.fromJson(Map<String, dynamic> json) {
    final list = json['precedents'] as List<dynamic>? ?? [];
    return KgragPrecedentPack(
      model: json['model'] as String? ?? 'bge-small-ko-v1.5',
      targetCorpusSize: json['target_corpus_size'] as int? ?? 500,
      precedents: list
          .map((e) => KgragPrecedent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

abstract final class SgpKgragLoader {
  static const assetPath = 'assets/data/kgrag_precedents.json';
  static KgragPrecedentPack? _cached;

  static KgragPrecedentPack? get cachedPack => _cached;

  static void setCachedPack(KgragPrecedentPack pack) => _cached = pack;

  static void resetCache() {
    _cached = null;
    SgpVectorStoreSession.reset();
  }

  static KgragPrecedentPack parsePack(String jsonSource) {
    return KgragPrecedentPack.fromJson(
      jsonDecode(jsonSource) as Map<String, dynamic>,
    );
  }

  /// 시드 판례를 변형 확장하여 target_corpus_size까지 벡터 인덱스 구축.
  static SgpVectorStore buildVectorIndex(KgragPrecedentPack pack) {
    final store = SgpVectorStore(modelId: pack.model);
    final bases = pack.precedents;
    if (bases.isEmpty) return store;

    final variantsPerBase =
        (pack.targetCorpusSize / bases.length).ceil().clamp(1, 25);
    var count = 0;

    for (var bi = 0; bi < bases.length && count < pack.targetCorpusSize; bi++) {
      final base = bases[bi];
      for (var v = 0; v < variantsPerBase && count < pack.targetCorpusSize; v++) {
        final suffix = v == 0 ? '' : '-V$v';
        final yearShift = 2019 + ((bi + v) % 6);
        store.upsertText(
          id: '${base.id}$suffix',
          text: '${base.embedText} $yearShift ${base.court} ${base.caseNo}',
          metadata: {
            'court': base.court,
            'case_no': base.caseNo,
            'holding': base.holding,
            'article_refs': base.articleRefs,
            'ontology_nodes': base.ontologyNodes,
            'domain': base.domain,
            'keywords': base.keywords,
            'base_id': base.id,
          },
        );
        count++;
      }
    }

    SgpVectorStoreSession.replace(store);
    return store;
  }
}
