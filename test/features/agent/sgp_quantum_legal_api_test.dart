import 'package:test/test.dart';
import 'package:sgp_agent/features/agent/sgp_actor_session.dart';

/// PoC JWT (alg=none) — org_id=KR-NPA
const _testJwt =
    'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.'
    'eyJvcmdfaWQiOiJLUi1OUEEiLCJsb2NhbF9nb3ZfY29kZSI6IjExIiwidGFza19jYXRlZ29yeSI6ImZpZWxkX2FycmVzdCIsInN1YiI6InRlc3QifQ.'
    '';

void main() {
  group('ActorSessionClaims', () {
    test('JWT payload 파싱', () {
      final claims = ActorSessionClaims.fromJwtPayloadString(_testJwt);
      expect(claims?.orgId, 'KR-NPA');
      expect(claims?.localGovCode, '11');
      expect(claims?.taskCategory, 'field_arrest');
    });

    test('actor ↔ JWT 일치', () {
      final claims = ActorSessionClaims.fromJwtPayloadString(_testJwt);
      const actor = QuantumLegalActorContext(orgId: 'KR-NPA', localGovCode: '11');
      expect(actor.matchesClaims(claims), isTrue);
      expect(
        const QuantumLegalActorContext(orgId: 'OTHER').matchesClaims(claims),
        isFalse,
      );
    });
  });

  group('authorizeQuantumLegalRequest', () {
    test('유효 JWT', () {
      expect(
        authorizeQuantumLegalRequest(
          actor: const QuantumLegalActorContext(orgId: 'KR-NPA'),
          bearerToken: 'Bearer $_testJwt',
        ),
        isTrue,
      );
    });

    test('org 불일치', () {
      expect(
        authorizeQuantumLegalRequest(
          actor: const QuantumLegalActorContext(orgId: 'OTHER-ORG'),
          bearerToken: 'Bearer $_testJwt',
        ),
        isFalse,
      );
    });
  });
}
