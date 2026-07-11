import 'dart:convert';

import 'package:sgp_agent/features/agent/sgp_actor_session.dart';
import 'package:sgp_agent/features/agent/sgp_npa_iam_jwt.dart';
import 'package:test/test.dart';

/// 경찰 IAM JWT 테스트 payload — exp=4102444800 (2100-01-01 UTC)
Map<String, dynamic> _validPayload() => {
      'iss': 'https://iam.police.go.kr',
      'aud': 'sgp-agent-api',
      'sub': 'officer-1',
      'org_id': 'KR-NPA',
      'local_gov_code': '11',
      'task_category': 'field_arrest',
      'station_id': '1140000',
      'rank_code': 'PO',
      'exp': 4102444800,
      'iat': 1735686000,
    };

String _makeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}')).replaceAll('=', '');
  final body =
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$header.$body.';
}

void main() {
  group('NpaIamClaims', () {
    test('확장 클레임 파싱', () {
      final claims = NpaIamClaims.fromJson(_validPayload());
      expect(claims.orgId, 'KR-NPA');
      expect(claims.stationId, '1140000');
      expect(claims.rankCode, 'PO');
      expect(claims.iss, 'https://iam.police.go.kr');
    });

    test('만료 토큰 거부 (claims 모드)', () {
      final config = NpaIamJwtConfig(
        mode: NpaIamJwtMode.claimsOnly,
        clock: FixedClock(DateTime.utc(2026, 7, 12)),
      );
      final token = 'Bearer ${_makeJwt({..._validPayload(), 'exp': 1})}';
      final result = NpaIamJwtVerifier.verify(bearerToken: token, config: config);
      expect(result.ok, isFalse);
      expect(result.error, 'token_expired');
    });

    test('iss/aud 불일치 거부', () {
      const config = NpaIamJwtConfig(mode: NpaIamJwtMode.claimsOnly);
      final token =
          'Bearer ${_makeJwt({..._validPayload(), 'iss': 'https://evil.example'})}';
      final result = NpaIamJwtVerifier.verify(bearerToken: token, config: config);
      expect(result.ok, isFalse);
      expect(result.error, 'issuer_mismatch');
    });

    test('authorizeActor — org 일치', () {
      final token = 'Bearer ${_makeJwt(_validPayload())}';
      expect(
        NpaIamJwtVerifier.authorizeActor(
          actor: const QuantumLegalActorContext(orgId: 'KR-NPA'),
          bearerToken: token,
          config: const NpaIamJwtConfig(mode: NpaIamJwtMode.claimsOnly),
        ),
        isTrue,
      );
    });

    test('strict 모드 — JWKS URL 필수', () {
      final token = 'Bearer ${_makeJwt(_validPayload())}';
      final result = NpaIamJwtVerifier.verify(
        bearerToken: token,
        config: const NpaIamJwtConfig(mode: NpaIamJwtMode.strict),
      );
      expect(result.ok, isFalse);
      expect(result.error, 'jwks_url_required_for_strict_mode');
    });
  });
}
