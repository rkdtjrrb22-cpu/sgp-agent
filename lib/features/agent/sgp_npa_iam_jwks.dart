/// Sprint S6+ — 경찰 IAM JWKS fetch·RS256 서명 검증 (pure Dart).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

/// JWKS 단일 RSA 공개키.
class NpaIamJwk {
  const NpaIamJwk({
    required this.kid,
    required this.kty,
    required this.alg,
    required this.n,
    required this.e,
    this.use,
  });

  final String kid;
  final String kty;
  final String alg;
  final String n;
  final String e;
  final String? use;

  factory NpaIamJwk.fromJson(Map<String, dynamic> json) {
    return NpaIamJwk(
      kid: json['kid'] as String? ?? '',
      kty: json['kty'] as String? ?? 'RSA',
      alg: json['alg'] as String? ?? 'RS256',
      n: json['n'] as String? ?? '',
      e: json['e'] as String? ?? '',
      use: json['use'] as String?,
    );
  }

  RSAPublicKey toRsaPublicKey() {
    return RSAPublicKey(_base64UrlToBigInt(n), _base64UrlToBigInt(e));
  }
}

/// JWKS 키 집합.
class NpaIamJwksKeySet {
  const NpaIamJwksKeySet({required this.keys});

  final List<NpaIamJwk> keys;

  factory NpaIamJwksKeySet.fromJson(Map<String, dynamic> json) {
    final raw = json['keys'] as List<dynamic>? ?? [];
    return NpaIamJwksKeySet(
      keys: raw
          .map((e) => NpaIamJwk.fromJson(e as Map<String, dynamic>))
          .where((k) => k.kty == 'RSA' && k.n.isNotEmpty && k.e.isNotEmpty)
          .toList(),
    );
  }

  NpaIamJwk? findByKid(String? kid) {
    if (kid != null && kid.isNotEmpty) {
      for (final key in keys) {
        if (key.kid == kid) return key;
      }
    }
    return keys.isNotEmpty ? keys.first : null;
  }
}

/// JWKS 캐시·RS256 서명 검증기.
class NpaIamJwksVerifier {
  NpaIamJwksVerifier({
    http.Client? httpClient,
    this.cacheTtl = const Duration(hours: 1),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration cacheTtl;

  NpaIamJwksKeySet? _cache;
  DateTime? _cachedAt;
  String? _cachedUrl;

  bool get hasCache => _cache != null;

  /// 테스트용 JWKS 캐시 주입.
  void seedKeySetForTest(NpaIamJwksKeySet keySet) {
    _cache = keySet;
    _cachedAt = DateTime.now();
    _cachedUrl = 'test://jwks';
  }

  /// 서버 기동 시 JWKS 프리로드.
  Future<bool> warmUp(String? jwksUrl) async {
    if (jwksUrl == null || jwksUrl.isEmpty) return false;
    try {
      await _fetch(jwksUrl);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// JWT RS256 서명 검증. alg=none 토큰은 false (PoC 토큰 — 서명 검증 생략은 호출측에서 판단).
  bool verifyRs256Signature(String jwt, {NpaIamJwksKeySet? keySet}) {
    final keys = keySet ?? _cache;
    if (keys == null || keys.keys.isEmpty) return false;

    final parts = jwt.split('.');
    if (parts.length != 3) return false;

    Map<String, dynamic> header;
    try {
      header = _decodeJsonPart(parts[0]);
    } catch (_) {
      return false;
    }

    final alg = header['alg'] as String? ?? '';
    if (alg.toLowerCase() == 'none') return false;

    if (alg != 'RS256') return false;

    final kid = header['kid'] as String?;
    final jwk = keys.findByKid(kid);
    if (jwk == null) return false;

    try {
      final signed = utf8.encode('${parts[0]}.${parts[1]}');
      final sig = _decodeBase64Url(parts[2]);
      final publicKey = jwk.toRsaPublicKey();
      final verifier = RSASigner(SHA256Digest(), '060960864801650304020105');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));
      return verifier.verifySignature(
        Uint8List.fromList(signed),
        RSASignature(sig),
      );
    } catch (_) {
      return false;
    }
  }

  Future<NpaIamJwksKeySet> fetch(String jwksUrl) => _fetch(jwksUrl);

  Future<NpaIamJwksKeySet> _fetch(String jwksUrl) async {
    if (_cache != null &&
        _cachedUrl == jwksUrl &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < cacheTtl) {
      return _cache!;
    }

    final response = await _http
        .get(Uri.parse(jwksUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw JwksFetchException('JWKS fetch failed: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final keySet = NpaIamJwksKeySet.fromJson(decoded);
    if (keySet.keys.isEmpty) {
      throw const FormatException('JWKS contains no RSA keys');
    }

    _cache = keySet;
    _cachedAt = DateTime.now();
    _cachedUrl = jwksUrl;
    return keySet;
  }

  void close() => _http.close();
}

class JwksFetchException implements Exception {
  const JwksFetchException(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> _decodeJsonPart(String part) {
  final normalized = part.replaceAll('-', '+').replaceAll('_', '/');
  final pad = normalized.length % 4;
  final padded = pad == 0 ? normalized : normalized.padRight(normalized.length + (4 - pad), '=');
  return jsonDecode(utf8.decode(base64.decode(padded))) as Map<String, dynamic>;
}

Uint8List _decodeBase64Url(String part) {
  var normalized = part.replaceAll('-', '+').replaceAll('_', '/');
  final pad = normalized.length % 4;
  if (pad > 0) normalized = normalized.padRight(normalized.length + (4 - pad), '=');
  return Uint8List.fromList(base64.decode(normalized));
}

BigInt _base64UrlToBigInt(String value) {
  final bytes = _decodeBase64Url(value);
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) + BigInt.from(b);
  }
  return result;
}

/// 테스트용 RSA 키쌍·서명 JWT 생성.
class NpaIamJwtTestSigner {
  static ({RSAPublicKey publicKey, RSAPrivateKey privateKey, String kid}) generate() {
    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 1024, 64),
          SecureRandom('Fortuna')..seed(KeyParameter(_seedBytes(32))),
        ),
      );
    final pair = keyGen.generateKeyPair();
    return (
      publicKey: pair.publicKey,
      privateKey: pair.privateKey,
      kid: 'test-kid',
    );
  }

  static String signRs256({
    required Map<String, dynamic> header,
    required Map<String, dynamic> payload,
    required RSAPrivateKey privateKey,
  }) {
    final headerB64 = _encodePart(header);
    final payloadB64 = _encodePart(payload);
    final content = utf8.encode('$headerB64.$payloadB64');
    final signer = RSASigner(SHA256Digest(), '060960864801650304020105');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(Uint8List.fromList(content)).bytes;
    return '$headerB64.$payloadB64.${_base64UrlEncode(sig)}';
  }

  static NpaIamJwksKeySet keySetFromPublic(RSAPublicKey key, {String kid = 'test-kid'}) {
    final n = _bigIntToBase64Url(key.modulus!);
    final e = _bigIntToBase64Url(key.exponent!);
    return NpaIamJwksKeySet(
      keys: [
        NpaIamJwk(kid: kid, kty: 'RSA', alg: 'RS256', n: n, e: e, use: 'sig'),
      ],
    );
  }
}

String _encodePart(Map<String, dynamic> json) =>
    _base64UrlEncode(utf8.encode(jsonEncode(json)));

String _base64UrlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

String _bigIntToBase64Url(BigInt value) {
  if (value == BigInt.zero) return '';
  var v = value;
  final out = <int>[];
  while (v > BigInt.zero) {
    out.insert(0, (v & BigInt.from(0xff)).toInt());
    v = v >> 8;
  }
  return _base64UrlEncode(out);
}

Uint8List _seedBytes(int len) => Uint8List.fromList(List.generate(len, (i) => i + 1));
