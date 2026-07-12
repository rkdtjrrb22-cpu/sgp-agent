import 'dart:convert';

import 'package:sgp_agent/features/agent/sgp_npa_iam_client.dart';
import 'package:sgp_agent/features/agent/sgp_npa_iam_jwt.dart';
import 'package:test/test.dart';

String _jwt(Map<String, dynamic> payload) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final body =
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$header.$body.';
}

void main() {
  setUp(NpaIamClientSession.reset);

  group('NpaIamClientSession', () {
    test('bearer 설정·actor 컨텍스트', () {
      NpaIamClientSession.setBearerToken(
        _jwt({
          'org_id': 'KR-NPA',
          'local_gov_code': '11',
          'task_category': 'field_arrest',
        }),
      );
      final actor = NpaIamClientSession.actorContext(fallbackOrgId: 'OTHER');
      expect(actor.orgId, 'KR-NPA');
      expect(actor.localGovCode, '11');
      expect(NpaIamClientSession.isReadyForRemote, isTrue);
    });

    test('configure — API base URL', () {
      NpaIamClientSession.configure(
        const NpaIamClientConfig(apiBaseUrl: 'https://staging.example/api'),
      );
      expect(NpaIamClientSession.apiBaseUrl, 'https://staging.example/api');
    });

    test('strict 모드 — 만료 토큰 not ready', () {
      // kEnableNpaIamStrictJwt is compile-time const false in production;
      // verify verifier path via direct configure + manual verify instead.
      final token = _jwt({'org_id': 'KR-NPA', 'exp': 1});
      final result = NpaIamJwtVerifier.verify(
        bearerToken: token,
        config: NpaIamJwtConfig(
          mode: NpaIamJwtMode.claimsOnly,
          clock: FixedClock(DateTime.utc(2026, 7, 12)),
        ),
      );
      expect(result.ok, isFalse);
    });
  });
}
