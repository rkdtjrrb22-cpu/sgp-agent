/// Sprint S6 — 경찰청 IAM JWT 실무 연동 규격·검증.
library;

import 'dart:convert';

import 'sgp_actor_session.dart';
import 'sgp_npa_iam_jwks.dart';

/// 경찰 IAM JWT 검증 모드.
enum NpaIamJwtMode {
  /// PoC — payload 파싱만 (서명 미검증, S5 호환).
  none,

  /// 운영 — exp·iss·aud·nbf 클레임 검증 (서명은 API Gateway·JWKS 위임).
  claimsOnly,

  /// 운영+ — claimsOnly + JWKS URL 설정 필수 (서명 검증은 게이트웨이 문서화).
  strict,
}

/// 경찰 IAM JWT 확장 클레임 (실무 연동 규격 초안).
class NpaIamClaims extends ActorSessionClaims {
  const NpaIamClaims({
    super.orgId,
    super.localGovCode,
    super.taskCategory,
    super.sub,
    this.iss,
    this.aud,
    this.exp,
    this.iat,
    this.nbf,
    this.jti,
    this.stationId,
    this.deptCode,
    this.rankCode,
    this.officerId,
  });

  final String? iss;
  final String? aud;
  final int? exp;
  final int? iat;
  final int? nbf;
  final String? jti;
  final String? stationId;
  final String? deptCode;
  final String? rankCode;
  final String? officerId;

  factory NpaIamClaims.fromJson(Map<String, dynamic> json) {
    return NpaIamClaims(
      orgId: json['org_id'] as String?,
      localGovCode: json['local_gov_code'] as String?,
      taskCategory: json['task_category'] as String?,
      sub: json['sub'] as String?,
      iss: json['iss'] as String?,
      aud: _audToString(json['aud']),
      exp: _epoch(json['exp']),
      iat: _epoch(json['iat']),
      nbf: _epoch(json['nbf']),
      jti: json['jti'] as String?,
      stationId: json['station_id'] as String?,
      deptCode: json['dept_code'] as String?,
      rankCode: json['rank_code'] as String?,
      officerId: json['officer_id'] as String? ?? json['sub'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (iss != null) 'iss': iss,
        if (aud != null) 'aud': aud,
        if (exp != null) 'exp': exp,
        if (iat != null) 'iat': iat,
        if (nbf != null) 'nbf': nbf,
        if (jti != null) 'jti': jti,
        if (stationId != null) 'station_id': stationId,
        if (deptCode != null) 'dept_code': deptCode,
        if (rankCode != null) 'rank_code': rankCode,
        if (officerId != null) 'officer_id': officerId,
      };

  static NpaIamClaims? fromBearerToken(String? bearerToken) {
    if (bearerToken == null || bearerToken.isEmpty) return null;
    final token =
        bearerToken.startsWith('Bearer ') ? bearerToken.substring(7) : bearerToken;
    return fromJwtPayloadString(token);
  }

  static NpaIamClaims? fromJwtPayloadString(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      final padded =
          pad == 0 ? normalized : normalized.padRight(normalized.length + (4 - pad), '=');
      final decoded = utf8.decode(base64Url.decode(padded));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return NpaIamClaims.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  bool isExpiredAt(DateTime now) {
    if (exp == null) return false;
    return now.isAfter(DateTime.fromMillisecondsSinceEpoch(exp! * 1000, isUtc: true));
  }

  bool isNotYetValidAt(DateTime now) {
    if (nbf == null) return false;
    return now.isBefore(DateTime.fromMillisecondsSinceEpoch(nbf! * 1000, isUtc: true));
  }
}

class NpaIamJwtConfig {
  const NpaIamJwtConfig({
    this.mode = NpaIamJwtMode.none,
    this.expectedIssuer = 'https://iam.police.go.kr',
    this.expectedAudience = 'sgp-agent-api',
    this.jwksUrl,
    this.verifyJwksSignature = false,
    this.clock = const _UtcClock(),
  });

  final NpaIamJwtMode mode;
  final String expectedIssuer;
  final String expectedAudience;
  final String? jwksUrl;
  final bool verifyJwksSignature;
  final Clock clock;

  factory NpaIamJwtConfig.fromEnvironment(Map<String, String> env) {
    final modeRaw = env['NPA_IAM_JWT_MODE'] ?? 'none';
    final mode = switch (modeRaw.toLowerCase()) {
      'claims' || 'claims_only' => NpaIamJwtMode.claimsOnly,
      'strict' => NpaIamJwtMode.strict,
      _ => NpaIamJwtMode.none,
    };
    return NpaIamJwtConfig(
      mode: mode,
      expectedIssuer: env['NPA_IAM_ISSUER'] ?? 'https://iam.police.go.kr',
      expectedAudience: env['NPA_IAM_AUDIENCE'] ?? 'sgp-agent-api',
      jwksUrl: env['NPA_IAM_JWKS_URL'],
      verifyJwksSignature: _envBool(env['NPA_IAM_VERIFY_JWKS'], defaultValue: mode != NpaIamJwtMode.none),
    );
  }

  bool get shouldVerifyJwksSignature =>
      verifyJwksSignature &&
      (mode == NpaIamJwtMode.claimsOnly || mode == NpaIamJwtMode.strict) &&
      jwksUrl != null &&
      jwksUrl!.isNotEmpty;
}

bool _envBool(String? raw, {required bool defaultValue}) {
  if (raw == null || raw.isEmpty) return defaultValue;
  return raw.toLowerCase() == 'true' || raw == '1';
}

abstract class Clock {
  DateTime now();
}

class _UtcClock implements Clock {
  const _UtcClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class NpaIamJwtVerificationResult {
  const NpaIamJwtVerificationResult({
    required this.ok,
    this.claims,
    this.error,
  });

  final bool ok;
  final NpaIamClaims? claims;
  final String? error;
}

abstract final class NpaIamJwtVerifier {
  static NpaIamJwtVerificationResult verify({
    required String? bearerToken,
    NpaIamJwtConfig config = const NpaIamJwtConfig(),
    NpaIamJwksVerifier? jwksVerifier,
  }) {
    final rawToken = _extractToken(bearerToken);
    if (rawToken == null) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'invalid_jwt');
    }

    final claims = NpaIamClaims.fromJwtPayloadString(rawToken);
    if (claims == null) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'invalid_jwt');
    }

    if (config.mode == NpaIamJwtMode.none) {
      if (claims.orgId == null) {
        return const NpaIamJwtVerificationResult(ok: false, error: 'missing_org_id');
      }
      return NpaIamJwtVerificationResult(ok: true, claims: claims);
    }

    final now = config.clock.now();
    if (claims.isExpiredAt(now)) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'token_expired');
    }
    if (claims.isNotYetValidAt(now)) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'token_not_yet_valid');
    }
    if (claims.iss != null && claims.iss != config.expectedIssuer) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'issuer_mismatch');
    }
    if (claims.aud != null && claims.aud != config.expectedAudience) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'audience_mismatch');
    }
    if (claims.orgId == null) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'missing_org_id');
    }

    if (config.mode == NpaIamJwtMode.strict &&
        (config.jwksUrl == null || config.jwksUrl!.isEmpty)) {
      return const NpaIamJwtVerificationResult(
        ok: false,
        error: 'jwks_url_required_for_strict_mode',
      );
    }

    final sigResult = _verifyJwksSignature(
      rawToken: rawToken,
      config: config,
      jwksVerifier: jwksVerifier,
    );
    if (sigResult != null) return sigResult;

    return NpaIamJwtVerificationResult(ok: true, claims: claims);
  }

  static NpaIamJwtVerificationResult? _verifyJwksSignature({
    required String rawToken,
    required NpaIamJwtConfig config,
    NpaIamJwksVerifier? jwksVerifier,
  }) {
    if (!config.shouldVerifyJwksSignature) return null;

    final alg = _jwtAlg(rawToken);
    if (alg == null) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'invalid_jwt_header');
    }
    if (alg.toLowerCase() == 'none') {
      return const NpaIamJwtVerificationResult(ok: false, error: 'unsigned_token_rejected');
    }
    if (alg != 'RS256') {
      return NpaIamJwtVerificationResult(ok: false, error: 'unsupported_alg:$alg');
    }
    if (jwksVerifier == null || !jwksVerifier.hasCache) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'jwks_not_ready');
    }
    if (!jwksVerifier.verifyRs256Signature(rawToken)) {
      return const NpaIamJwtVerificationResult(ok: false, error: 'invalid_signature');
    }
    return null;
  }

  static String? _jwtAlg(String jwt) {
    final parts = jwt.split('.');
    if (parts.isEmpty) return null;
    try {
      final normalized = parts[0].replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      final padded =
          pad == 0 ? normalized : normalized.padRight(normalized.length + (4 - pad), '=');
      final map = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      return map['alg'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String? _extractToken(String? bearerToken) {
    if (bearerToken == null || bearerToken.isEmpty) return null;
    return bearerToken.startsWith('Bearer ') ? bearerToken.substring(7) : bearerToken;
  }

  /// actor body와 JWT 클레임 정합성 (S5 호환 + 경찰 IAM 확장).
  static bool authorizeActor({
    required QuantumLegalActorContext actor,
    required String? bearerToken,
    NpaIamJwtConfig config = const NpaIamJwtConfig(),
    NpaIamJwksVerifier? jwksVerifier,
  }) {
    final result = verify(
      bearerToken: bearerToken,
      config: config,
      jwksVerifier: jwksVerifier,
    );
    if (!result.ok) return false;
    return actor.matchesClaims(result.claims);
  }
}

String? _audToString(Object? aud) {
  if (aud == null) return null;
  if (aud is String) return aud;
  if (aud is List && aud.isNotEmpty) return aud.first.toString();
  return aud.toString();
}

int? _epoch(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// 고정 시계 — 테스트용.
class FixedClock implements Clock {
  const FixedClock(this.fixed);

  final DateTime fixed;

  @override
  DateTime now() => fixed;
}
