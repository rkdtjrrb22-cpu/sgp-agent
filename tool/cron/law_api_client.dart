/// Sprint S6+ — 국가법령정보센터·공공데이터포털 API 클라이언트 (재시도·예외 분류).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// 법령 API 오류 유형.
enum LawApiErrorKind {
  missingCredentials,
  httpError,
  timeout,
  parseError,
  emptyResponse,
  rateLimited,
  unknown,
}

class LawApiQueryError {
  const LawApiQueryError({
    required this.query,
    required this.kind,
    this.message,
    this.statusCode,
    this.attempts = 1,
  });

  final String query;
  final LawApiErrorKind kind;
  final String? message;
  final int? statusCode;
  final int attempts;
}

/// 법제처 DRF API 응답을 legal_nodes 시드 형식으로 매핑.
class LawApiClient {
  LawApiClient({
    this.lawGoKrOcKey,
    this.dataGoKrServiceKey,
    this.baseUrl = 'http://www.law.go.kr/DRF',
    this.maxRetries = 3,
    this.retryDelayMs = 1500,
    this.interQueryDelayMs = 400,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String? lawGoKrOcKey;
  final String? dataGoKrServiceKey;
  final String baseUrl;
  final int maxRetries;
  final int retryDelayMs;
  final int interQueryDelayMs;
  final http.Client _http;

  bool get hasLiveCredentials =>
      (lawGoKrOcKey != null && lawGoKrOcKey!.isNotEmpty) ||
      (dataGoKrServiceKey != null && dataGoKrServiceKey!.isNotEmpty);

  Future<LawApiFetchResult> fetchNationalLaws({
    List<String> queries = const [
      '형법',
      '형사소송법',
      '경찰관 직무집행법',
      '가정폭력범죄의 처벌 등에 관한 특례법',
    ],
    bool allowOfflineStub = true,
  }) async {
    if (!hasLiveCredentials) {
      if (!allowOfflineStub) {
        return LawApiFetchResult(
          source: 'error',
          laws: const [],
          errors: const [
            LawApiQueryError(
              query: '*',
              kind: LawApiErrorKind.missingCredentials,
              message: 'LAW_GO_KR_OC_KEY / DATA_GO_KR_SERVICE_KEY required',
            ),
          ],
        );
      }
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
    final errors = <LawApiQueryError>[];

    for (var i = 0; i < queries.length; i++) {
      final query = queries[i];
      if (i > 0 && interQueryDelayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: interQueryDelayMs));
      }

      final outcome = await _fetchQueryWithRetry(query);
      if (outcome.laws.isNotEmpty) {
        laws.addAll(outcome.laws);
      }
      if (outcome.error != null) {
        errors.add(outcome.error!);
        warnings.add('$query: ${outcome.error!.kind.name} — ${outcome.error!.message}');
      }
    }

    if (laws.isEmpty) {
      if (!allowOfflineStub) {
        return LawApiFetchResult(
          source: 'error',
          laws: const [],
          warnings: warnings,
          errors: errors,
        );
      }
      warnings.add('live fetch empty — falling back to offline stub');
      return LawApiFetchResult(
        source: 'offline_fallback',
        laws: _offlineStubLaws(queries),
        warnings: warnings,
        errors: errors,
      );
    }

    return LawApiFetchResult(
      source: errors.isEmpty ? 'law_go_kr' : 'law_go_kr_partial',
      laws: laws,
      warnings: warnings,
      errors: errors,
    );
  }

  Future<({List<Map<String, dynamic>> laws, LawApiQueryError? error})> _fetchQueryWithRetry(
    String query,
  ) async {
    LawApiQueryError? lastError;

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final uri = _buildSearchUri(query);
        final response = await _http.get(uri).timeout(const Duration(seconds: 30));

        if (response.statusCode == 429) {
          lastError = LawApiQueryError(
            query: query,
            kind: LawApiErrorKind.rateLimited,
            statusCode: 429,
            message: 'rate limited',
            attempts: attempt,
          );
        } else if (response.statusCode != 200) {
          lastError = LawApiQueryError(
            query: query,
            kind: LawApiErrorKind.httpError,
            statusCode: response.statusCode,
            message: response.body.length > 120
                ? '${response.body.substring(0, 120)}...'
                : response.body,
            attempts: attempt,
          );
        } else {
          try {
            final parsed = _parseLawSearchResponse(response.body, query);
            if (parsed.isEmpty) {
              lastError = LawApiQueryError(
                query: query,
                kind: LawApiErrorKind.emptyResponse,
                message: 'no law items in response',
                attempts: attempt,
              );
            } else {
              return (laws: parsed, error: null);
            }
          } catch (e) {
            lastError = LawApiQueryError(
              query: query,
              kind: LawApiErrorKind.parseError,
              message: e.toString(),
              attempts: attempt,
            );
          }
        }
      } on Exception catch (e) {
        final isTimeout = e.toString().contains('TimeoutException');
        lastError = LawApiQueryError(
          query: query,
          kind: isTimeout ? LawApiErrorKind.timeout : LawApiErrorKind.unknown,
          message: e.toString(),
          attempts: attempt,
        );
      }

      if (attempt < maxRetries) {
        await Future<void>.delayed(Duration(milliseconds: retryDelayMs * attempt));
      }
    }

    return (laws: <Map<String, dynamic>>[], error: lastError);
  }

  Uri _buildSearchUri(String query) {
    final key = lawGoKrOcKey ?? dataGoKrServiceKey!;
    return Uri.parse('$baseUrl/lawSearch.do').replace(
      queryParameters: {
        'OC': key,
        'target': 'law',
        'type': 'JSON',
        'query': query,
      },
    );
  }

  List<Map<String, dynamic>> _parseLawSearchResponse(String body, String query) {
    if (body.trim().isEmpty) return [];

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('expected JSON object');
    }

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
      nodes.add({
        'id': 'KR-LAW-API-${seq.toString().padLeft(4, '0')}',
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
    this.errors = const [],
  });

  final String source;
  final List<Map<String, dynamic>> laws;
  final List<String> warnings;
  final List<LawApiQueryError> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get isLive => source == 'law_go_kr' || source == 'law_go_kr_partial';
}
