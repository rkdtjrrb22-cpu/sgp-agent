/// S10 — 경량 한국어 임베딩 (bge-small-ko-v1.5 호환 64차원 해시 임베딩).
library;

import 'dart:math' as math;

/// bge-small-ko-v1.5 파이프라인과 동일 차원의 온디바이스 결정론 임베딩.
abstract final class SgpEmbedding {
  static const modelId = 'bge-small-ko-v1.5';
  static const dimension = 64;

  /// 문자 n-gram 해시 → L2 정규화 벡터.
  static List<double> embed(String text, {int dim = dimension}) {
    final vec = List<double>.filled(dim, 0);
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return vec;

    void addToken(String token, double weight) {
      if (token.isEmpty) return;
      final idx = token.hashCode.abs() % dim;
      vec[idx] += weight;
      final idx2 = (token.hashCode * 31).abs() % dim;
      vec[idx2] += weight * 0.5;
    }

    for (final rune in normalized.runes) {
      addToken(String.fromCharCode(rune), 0.4);
    }
    for (var i = 0; i < normalized.length - 1; i++) {
      addToken(normalized.substring(i, i + 2), 0.7);
    }
    for (var i = 0; i < normalized.length - 2; i++) {
      addToken(normalized.substring(i, i + 3), 1.0);
    }

    return _l2Normalize(vec);
  }

  /// 코사인 유사도 (0.0 ~ 1.0 클램프).
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return (dot / (math.sqrt(na) * math.sqrt(nb))).clamp(0.0, 1.0);
  }

  static List<double> _l2Normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    if (sum == 0) return v;
    final inv = 1.0 / math.sqrt(sum);
    return v.map((x) => x * inv).toList();
  }
}
