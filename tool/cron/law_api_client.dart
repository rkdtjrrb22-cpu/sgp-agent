/// Sprint S6 — 국가법령정보센터·공공데이터포털 API 클라이언트.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// 법제처 DRF API 응답을 legal_nodes 시드 형식으로 매핑.
class LawApiClient {
  LawApiClient({
    this.lawGoKrOcKey,
    this.dataGoKrServiceKey,
    this.baseUrl = 'http://www.law.go.kr/DRF',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// 국가법령정보센터 Open API OC 키 (law.go.kr 신청).
  final String? lawGoKrOcKey;

  /// 공공데이터포털 서비스키 (선택 — 동일 법령 API 미러).
  final String? dataGoKrServiceKey;

  final String baseUrl;
  final http.Client _http;

  bool get hasLiveCredentials =>
      (lawGoKrOcKey != null && lawGoKrOcKey!.isNotEmpty) ||
      (dataGoKrServiceKey != null && dataGoKrServiceKey!.isNotEmpty);

  /// LV1~4 대상 국가법령 목록 조회 (형사·절차 핵심법 기본 쿼리).
  Future<LawApiFetchResult> fetchNationalLaws({
    List<String> queries = const [
      '형법',
      '형사소송법',
      '경찰관 직무집행법',
      '가정폭력범죄의 처벌 등에 관한 특례법',
    ],
  }) async {
    if (!hasLiveCredentials) {
      return LawApiFetchResult(
        source: 'offline_stub',
        laws: _offlineStubLaws(queries),
        warnings: const [
          'LAW_GO_KR_OC_KEY / DATA_GO_KR_SERVICE_KEY 미설정 — 오프라인 스텁 사용',
        ],
      );
    }

    final laws = <Map<String, dynamic>>[];
    final warnings = <String>[];

    for (final query in queries) {
      try {
        final uri = _buildSearchUri(query);
        final response = await _http.get(uri).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          warnings.add('$query: HTTP ${response.statusCode}');
          continue;
        }
        final parsed = _parseLawSearchResponse(response.body, query);
        laws.addAll(parsed);
      } catch (e) {
        warnings.add('$query: $e');
      }
    }

    if (laws.isEmpty) {
      warnings.add('live fetch empty — falling back to offline stub');
      return LawApiFetchResult(
        source: 'offline_fallback',
        laws: _offlineStubLaws(queries),
        warnings: warnings,
      );
    }

    return LawApiFetchResult(
      source: 'law_go_kr',
      laws: laws,
      warnings: warnings,
    );
  }

  Uri _buildSearchUri(String query) {
    final key = lawGoKrOcKey ?? dataGoKrServiceKey!;
    final params = {
      'OC': key,
      'target': 'law',
      'type': 'JSON',
      'query': query,
    };
    return Uri.parse('$baseUrl/lawSearch.do').replace(queryParameters: params);
  }

  List<Map<String, dynamic>> _parseLawSearchResponse(String body, String query) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return [];

    final law = decoded['LawSearch'] ?? decoded['lawSearch'];
    if (law is! Map<String, dynamic>) return [];

    final items = law['law'];
    if (items == null) return [];

    final list = items is List ? items : [items];
    return list.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return {
        'law_id': map['법령ID'] ?? map['lawId'] ?? map['id'],
        'law_name': map['법령명한글'] ?? map['lawName'] ?? query,
        'law_type': map['법령구분명'] ?? map['lawType'] ?? '법률',
        'promulgation_date': map['공포일자'] ?? map['promulgationDate'],
        'enforcement_date': map['시행일자'] ?? map['enforcementDate'],
        'query': query,
      };
    }).toList();
  }

  /// API·스텁 결과 → legal_nodes (LV2~4) 시드 노드.
  List<Map<String, dynamic>> mapToLegalNodes(LawApiFetchResult result) {
    final nodes = <Map<String, dynamic>>[];
    var seq = 0;

    nodes.add({
      'id': 'KR-CONST-001',
      'level': 1,
      'title': '대한민국 헌법',
      'parent_id': null,
      'scope': {'country': 'KR'},
      'filter_keys': ['global_default'],
      'domain_tags': ['all'],
      'source': result.source,
    });

    for (final law in result.laws) {
      seq++;
      final name = law['law_name']?.toString() ?? 'UNKNOWN';
      final level = _levelFromLawType(law['law_type']?.toString());
      final id = 'KR-LAW-API-${seq.toString().padLeft(4, '0')}';
      nodes.add({
        'id': id,
        'level': level,
        'title': name,
        'parent_id': 'KR-CONST-001',
        'scope': {'country': 'KR', 'law_id': law['law_id']?.toString()},
        'filter_keys': ['api_sync:${law['query']}'],
        'domain_tags': _domainTagsForLawName(name),
        'source': 'law_api:${result.source}',
        if (law['enforcement_date'] != null)
          'summary': '시행 ${law['enforcement_date']}',
      });
    }

    return nodes;
  }

  int _levelFromLawType(String? type) {
    if (type == null) return 2;
    if (type.contains('헌법')) return 1;
    if (type.contains('대통령령')) return 3;
    if (type.contains('총리령') || type.contains('부령') || type.contains('훈령')) {
      return 4;
    }
    return 2;
  }

  List<String> _domainTagsForLawName(String name) {
    if (name.contains('형사소송')) return ['criminal', 'procedure', 'arrest'];
    if (name.contains('형법')) return ['criminal', 'violence', 'property'];
    if (name.contains('가정폭력')) return ['criminal', 'domestic_violence'];
    if (name.contains('경찰')) return ['criminal', 'procedure', 'police'];
    return ['criminal'];
  }

  List<Map<String, dynamic>> _offlineStubLaws(List<String> queries) {
    return queries
        .map(
          (q) => {
            'law_id': 'STUB-${q.hashCode.abs()}',
            'law_name': q,
            'law_type': '법률',
            'query': q,
            'enforcement_date': null,
          },
        )
        .toList();
  }

  void close() => _http.close();
}

class LawApiFetchResult {
  const LawApiFetchResult({
    required this.source,
    required this.laws,
    this.warnings = const [],
  });

  final String source;
  final List<Map<String, dynamic>> laws;
  final List<String> warnings;
}
