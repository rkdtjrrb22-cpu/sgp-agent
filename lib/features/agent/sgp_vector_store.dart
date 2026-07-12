/// S10 — 로컬 벡터 저장소 (SQLite Vector 호환 JSON 인덱스).
library;

import 'dart:convert';

import 'sgp_embedding.dart';

/// 벡터 레코드.
class SgpVectorRecord {
  const SgpVectorRecord({
    required this.id,
    required this.text,
    required this.embedding,
    this.metadata = const {},
  });

  final String id;
  final String text;
  final List<double> embedding;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'embedding': embedding,
        'metadata': metadata,
      };

  factory SgpVectorRecord.fromJson(Map<String, dynamic> json) {
    return SgpVectorRecord(
      id: json['id'] as String,
      text: json['text'] as String,
      embedding: (json['embedding'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// 코사인 유사도 검색 결과.
class SgpVectorSearchHit {
  const SgpVectorSearchHit({
    required this.record,
    required this.score,
  });

  final SgpVectorRecord record;
  final double score;
}

/// 온디바이스 벡터 DB (인메모리 + JSON 영속화).
class SgpVectorStore {
  SgpVectorStore({this.modelId = SgpEmbedding.modelId});

  final String modelId;
  final List<SgpVectorRecord> _records = [];

  int get corpusSize => _records.length;
  List<SgpVectorRecord> get records => List.unmodifiable(_records);

  void clear() => _records.clear();

  void upsert(SgpVectorRecord record) {
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
  }

  void upsertText({
    required String id,
    required String text,
    Map<String, dynamic> metadata = const {},
  }) {
    upsert(
      SgpVectorRecord(
        id: id,
        text: text,
        embedding: SgpEmbedding.embed(text),
        metadata: metadata,
      ),
    );
  }

  /// 코사인 유사도 Top-K 검색.
  List<SgpVectorSearchHit> search(
    String query, {
    int topK = 5,
    double minScore = 0.12,
  }) {
    final qEmb = SgpEmbedding.embed(query);
    final hits = <SgpVectorSearchHit>[];
    for (final r in _records) {
      final score = SgpEmbedding.cosineSimilarity(qEmb, r.embedding);
      if (score >= minScore) {
        hits.add(SgpVectorSearchHit(record: r, score: score));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    if (hits.length <= topK) return hits;
    return hits.sublist(0, topK);
  }

  /// JSON 직렬화 (로컬 SQLite Vector 확장 대체 영속 레이어).
  String exportJson() => jsonEncode({
        'model_id': modelId,
        'dimension': SgpEmbedding.dimension,
        'corpus_size': _records.length,
        'records': _records.map((r) => r.toJson()).toList(),
      });

  void importJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    _records
      ..clear()
      ..addAll(
        (map['records'] as List<dynamic>)
            .map((e) => SgpVectorRecord.fromJson(e as Map<String, dynamic>)),
      );
  }
}

/// 싱글턴 — 앱 전역 KG-RAG 벡터 인덱스.
abstract final class SgpVectorStoreSession {
  static SgpVectorStore? _store;

  static SgpVectorStore get instance => _store ??= SgpVectorStore();

  static void reset() => _store = null;

  static void replace(SgpVectorStore store) => _store = store;
}
