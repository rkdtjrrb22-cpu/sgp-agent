import 'package:sgp_agent/features/agent/sgp_npa_iam_jwt.dart';
import 'package:sgp_agent/features/agent/sgp_npa_iam_jwks.dart';
import 'package:test/test.dart';

void main() {
  group('NpaIamJwksVerifier', () {
    test('JWKS JSON 파싱', () {
      final keySet = NpaIamJwksKeySet.fromJson({
        'keys': [
          {
            'kty': 'RSA',
            'kid': 'kid-1',
            'alg': 'RS256',
            'n': 'q',
            'e': 'AQAB',
            'use': 'sig',
          },
        ],
      });
      expect(keySet.keys.length, 1);
      expect(keySet.findByKid('kid-1')?.kid, 'kid-1');
    });

    test('RS256 서명 검증 — 키쌍 왕복', () {
      final material = NpaIamJwtTestSigner.generate();
      final keySet = NpaIamJwtTestSigner.keySetFromPublic(
        material.publicKey,
        kid: material.kid,
      );

      final token = NpaIamJwtTestSigner.signRs256(
        header: {'alg': 'RS256', 'typ': 'JWT', 'kid': material.kid},
        payload: {
          'iss': 'https://iam.police.go.kr',
          'aud': 'sgp-agent-api',
          'org_id': 'KR-NPA',
          'exp': 4102444800,
        },
        privateKey: material.privateKey,
      );

      final verifier = NpaIamJwksVerifier();
      expect(verifier.verifyRs256Signature(token, keySet: keySet), isTrue);

      final tampered = '${token}x';
      expect(verifier.verifyRs256Signature(tampered, keySet: keySet), isFalse);
    });

    test('claims+JWKS — RS256 통과·none 거부', () {
      final material = NpaIamJwtTestSigner.generate();
      final keySet = NpaIamJwtTestSigner.keySetFromPublic(
        material.publicKey,
        kid: material.kid,
      );
      final jwks = NpaIamJwksVerifier()..seedKeySetForTest(keySet);

      const config = NpaIamJwtConfig(
        mode: NpaIamJwtMode.claimsOnly,
        jwksUrl: 'https://iam.police.go.kr/.well-known/jwks.json',
        verifyJwksSignature: true,
      );

      final signed = NpaIamJwtTestSigner.signRs256(
        header: {'alg': 'RS256', 'typ': 'JWT', 'kid': material.kid},
        payload: {
          'iss': 'https://iam.police.go.kr',
          'aud': 'sgp-agent-api',
          'org_id': 'KR-NPA',
          'exp': 4102444800,
        },
        privateKey: material.privateKey,
      );

      final ok = NpaIamJwtVerifier.verify(
        bearerToken: signed,
        config: config,
        jwksVerifier: jwks,
      );
      expect(ok.ok, isTrue);

      final unsigned = NpaIamJwtVerifier.verify(
        bearerToken:
            'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.'
            'eyJpc3MiOiJodHRwczovL2lhbS5wb2xpY2UuZ28ua3IiLCJhdWQiOiJzZ3AtYWdlbnQtYXBpIiwib3JnX2lkIjoiS1ItTlBBIiwiZXhwIjo0MTAyNDQ0ODAwfQ.'
            '',
        config: config,
        jwksVerifier: jwks,
      );
      expect(unsigned.ok, isFalse);
      expect(unsigned.error, 'unsigned_token_rejected');
    });
  });
}
