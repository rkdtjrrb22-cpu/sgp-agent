/// Sprint S5 — JWT·Actor 세션 클레임 (pure Dart, 테스트·서버 공용).
library;

import 'dart:convert';

/// JWT payload에서 추출하는 조직·지역·업무 세션 클레임.
class ActorSessionClaims {
  const ActorSessionClaims({
    this.orgId,
    this.localGovCode,
    this.taskCategory,
    this.sub,
  });

  final String? orgId;
  final String? localGovCode;
  final String? taskCategory;
  final String? sub;

  factory ActorSessionClaims.fromJson(Map<String, dynamic> json) {
    return ActorSessionClaims(
      orgId: json['org_id'] as String?,
      localGovCode: json['local_gov_code'] as String?,
      taskCategory: json['task_category'] as String?,
      sub: json['sub'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (orgId != null) 'org_id': orgId,
        if (localGovCode != null) 'local_gov_code': localGovCode,
        if (taskCategory != null) 'task_category': taskCategory,
        if (sub != null) 'sub': sub,
      };

  /// JWT 문자열(Bearer 제외)에서 payload 클레임 파싱 — 서명 검증은 별도.
  static ActorSessionClaims? fromJwtPayloadString(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      final padded =
          pad == 0 ? normalized : normalized.padRight(normalized.length + (4 - pad), '=');
      final decoded = utf8.decode(base64Url.decode(padded));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return ActorSessionClaims.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

/// API actor 컨텍스트 (request body).
class QuantumLegalActorContext {
  const QuantumLegalActorContext({
    this.orgId,
    this.localGovCode,
    this.taskCategory = 'field_arrest',
  });

  final String? orgId;
  final String? localGovCode;
  final String? taskCategory;

  factory QuantumLegalActorContext.fromJson(Map<String, dynamic> json) {
    return QuantumLegalActorContext(
      orgId: json['org_id'] as String?,
      localGovCode: json['local_gov_code'] as String?,
      taskCategory: json['task_category'] as String? ?? 'field_arrest',
    );
  }

  Map<String, dynamic> toJson() => {
        if (orgId != null) 'org_id': orgId,
        if (localGovCode != null) 'local_gov_code': localGovCode,
        if (taskCategory != null) 'task_category': taskCategory,
      };

  bool matchesClaims(ActorSessionClaims? claims) {
    if (claims == null) return false;
    if (orgId != null && claims.orgId != null && orgId != claims.orgId) return false;
    if (localGovCode != null &&
        claims.localGovCode != null &&
        localGovCode != claims.localGovCode) {
      return false;
    }
    return claims.orgId != null;
  }
}

bool authorizeQuantumLegalRequest({
  required QuantumLegalActorContext actor,
  required String? bearerToken,
}) {
  if (bearerToken == null || bearerToken.isEmpty) return false;
  final token = bearerToken.startsWith('Bearer ') ? bearerToken.substring(7) : bearerToken;
  final claims = ActorSessionClaims.fromJwtPayloadString(token);
  return actor.matchesClaims(claims);
}
