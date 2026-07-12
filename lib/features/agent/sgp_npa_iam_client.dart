/// Sprint S6+ — Flutter 클라이언트 경찰 IAM JWT 세션·원격 API 연동 초안.
///
/// MDM·IAM에서 bearer 토큰을 프로비저닝하면 [SgpQuantumLegalRemote]가
/// 원격 resolve 활성 시 자동 사용한다.
library;

import 'sgp_actor_session.dart';
import 'sgp_npa_iam_jwt.dart';

/// MDM·빌드별 원격 API 설정 (MDM 프로비저닝 또는 런타임 configure).
class NpaIamClientConfig {
  const NpaIamClientConfig({
    this.apiBaseUrl = 'https://api.sgp-agent.police.go.kr',
    this.jwtMode = NpaIamJwtMode.claimsOnly,
    this.expectedIssuer = 'https://iam.police.go.kr',
    this.expectedAudience = 'sgp-agent-api',
    this.strictJwtValidation = false,
  });

  final String apiBaseUrl;
  final NpaIamJwtMode jwtMode;
  final String expectedIssuer;
  final String expectedAudience;

  /// true면 클라이언트에서 exp·iss·aud 선검증 (MDM·IAM 연동 후).
  final bool strictJwtValidation;

  NpaIamJwtConfig toVerifierConfig() => NpaIamJwtConfig(
        mode: jwtMode,
        expectedIssuer: expectedIssuer,
        expectedAudience: expectedAudience,
      );
}

/// 경찰 IAM bearer 세션 — 온디바이스 프로비저닝·검증.
abstract final class NpaIamClientSession {
  static NpaIamClientConfig _config = const NpaIamClientConfig();
  static String? _bearerToken;
  static NpaIamJwtVerificationResult? _lastVerification;

  static NpaIamClientConfig get config => _config;

  static NpaIamJwtVerificationResult? get lastVerification => _lastVerification;

  /// MDM 초기 설정·운영 전환 시 1회 호출.
  static void configure(NpaIamClientConfig config) {
    _config = config;
    _refreshVerification();
  }

  /// IAM에서 발급된 JWT 저장 (Bearer 접두사 있어도 무관).
  static void setBearerToken(String? token) {
    if (token == null || token.isEmpty) {
      _bearerToken = null;
      _lastVerification = null;
      return;
    }
    _bearerToken = token.startsWith('Bearer ') ? token.substring(7) : token;
    _refreshVerification();
  }

  static String? get bearerToken => _bearerToken;

  static NpaIamClaims? get claims {
    final v = _lastVerification;
    if (v != null && v.ok) return v.claims;
    if (!_config.strictJwtValidation && _bearerToken != null) {
      return NpaIamClaims.fromBearerToken(_bearerToken);
    }
    return null;
  }

  /// 원격 resolve에 사용 가능한 유효 세션인지.
  static bool get isReadyForRemote {
    if (_bearerToken == null || _bearerToken!.isEmpty) return false;
    if (!_config.strictJwtValidation) return true;
    return _lastVerification?.ok == true;
  }

  static String get apiBaseUrl => _config.apiBaseUrl;

  /// API actor 컨텍스트 — JWT 클레임 우선, 없으면 단말 프로비저닝 폴백.
  static QuantumLegalActorContext actorContext({String? fallbackOrgId}) {
    final c = claims;
    return QuantumLegalActorContext(
      orgId: c?.orgId ?? fallbackOrgId,
      localGovCode: c?.localGovCode,
      taskCategory: c?.taskCategory ?? 'field_arrest',
    );
  }

  static void _refreshVerification() {
    if (_bearerToken == null) {
      _lastVerification = null;
      return;
    }
    if (!_config.strictJwtValidation) {
      _lastVerification = NpaIamJwtVerificationResult(
        ok: true,
        claims: NpaIamClaims.fromBearerToken(_bearerToken),
      );
      return;
    }
    _lastVerification = NpaIamJwtVerifier.verify(
      bearerToken: _bearerToken,
      config: _config.toVerifierConfig(),
    );
  }

  /// 테스트·로그아웃용.
  static void reset() {
    _config = const NpaIamClientConfig();
    _bearerToken = null;
    _lastVerification = null;
  }
}
