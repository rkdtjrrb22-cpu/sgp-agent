/// Sprint S5 — 원격 resolve 클라이언트 (온디바이스 fallback).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sgp_agent_core.dart';
import 'sgp_legal_compliance.dart';
import 'sgp_npa_iam_client.dart';
import 'sgp_quantum_legal_api.dart';
import 'sgp_quantum_legal_engine.dart';

/// POST /v1/quantum-legal/resolve 원격 호출 + 로컬 fallback.
abstract final class SgpQuantumLegalRemote {
  static const defaultBaseUrl = 'http://127.0.0.1:8080';

  /// 원격 resolve 시도 → 실패·비활성 시 [localAnalyze] 결과 반환.
  static Future<SgpQuantumLegalComparison> resolveWithFallback({
    required SgpQuantumLegalComparison Function() localAnalyze,
    required String rawText,
    required LawCheckList checklist,
    String? orgId,
    String? localGovCode,
    String? bearerToken,
    String baseUrl = defaultBaseUrl,
  }) async {
    if (kEnableRemoteResolve && bearerToken != null && bearerToken.isNotEmpty) {
      final remote = await resolveRemote(
        rawText: rawText,
        checklist: checklist,
        orgId: orgId,
        localGovCode: localGovCode,
        bearerToken: bearerToken,
        baseUrl: baseUrl,
      );
      if (remote != null) return remote;
    }
    if (kEnableRemoteResolve && NpaIamClientSession.isReadyForRemote) {
      final remote = await resolveRemote(
        rawText: rawText,
        checklist: checklist,
        orgId: NpaIamClientSession.actorContext(fallbackOrgId: orgId).orgId ?? orgId,
        localGovCode:
            localGovCode ?? NpaIamClientSession.actorContext(fallbackOrgId: orgId).localGovCode,
        bearerToken: NpaIamClientSession.bearerToken!,
        baseUrl: NpaIamClientSession.apiBaseUrl,
      );
      if (remote != null) return remote;
    }
    return localAnalyze();
  }

  static Future<SgpQuantumLegalComparison?> resolveRemote({
    required String rawText,
    required LawCheckList checklist,
    required String? orgId,
    String? localGovCode,
    required String bearerToken,
    String baseUrl = defaultBaseUrl,
  }) async {
    if (!kEnableRemoteResolve) return null;

    final request = QuantumLegalResolveRequest(
      actor: QuantumLegalActorContext(
        orgId: orgId,
        localGovCode: localGovCode,
        taskCategory: 'field_arrest',
      ),
      situation: QuantumLegalSituation(
        rawText: rawText,
        checklist: checklist,
      ),
    );

    try {
      final uri = Uri.parse('$baseUrl/v1/quantum-legal/resolve');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $bearerToken',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        return QuantumLegalResolveResponse.fromJson(map).comparison;
      }
    } catch (_) {
      // fallback
    }
    return null;
  }
}
