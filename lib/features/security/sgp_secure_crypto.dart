/// S13 — 온디바이스 철통 보안 커널 (생체인증 게이트 + KG-RAG RAM 로드).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../agent/sgp_kgrag_loader.dart';
import '../agent/sgp_secure_cache_crypto.dart';

/// 생체인증 포트 — 운영 단말은 네이티브 브리지로 교체.
abstract interface class SgpBiometricAuthPort {
  Future<bool> authenticate({required String reason});
}

/// 테스트·데스크톱용 시뮬레이션 게이트.
class SgpSimulatedBiometricAuth implements SgpBiometricAuthPort {
  bool _granted = false;

  void grantForTest() => _granted = true;

  void revoke() => _granted = false;

  @override
  Future<bool> authenticate({required String reason}) async => _granted;
}

abstract final class SgpSecureCrypto {
  static const corpusKeyAlias = 'sgp_kgrag_corpus_v1';
  static const targetCorpusSize = 800;

  static String? _ramCorpusJson;

  /// RAM에 복호화된 코퍼스만 존재하는지.
  static bool get isCorpusUnlockedInRam => _ramCorpusJson != null;

  /// RAM 상주 코퍼스 즉시 소거.
  static void wipeRamCorpus() {
    _ramCorpusJson = null;
  }

  /// kgrag_precedents.json 평문을 AES-256-GCM 봉인.
  static SgpEncryptedCacheEnvelope sealCorpus({
    required String plainJson,
    required Uint8List key,
  }) {
    return SgpAes256Gcm.sealForTest(plainText: plainJson, key: key);
  }

  /// 생체인증 성공 시에만 RAM에 복호화·적재.
  static Future<String> unlockCorpusToRam({
    required SgpEncryptedCacheEnvelope envelope,
    required Uint8List key,
    required SgpBiometricAuthPort biometric,
    String reason = 'KG-RAG 800종 판례 DB 접근',
  }) async {
    final ok = await biometric.authenticate(reason: reason);
    if (!ok) {
      throw StateError('생체인증 실패 — kgrag_precedents.json 복호화 거부');
    }
    final json = SgpAes256Gcm.openForTest(envelope: envelope, key: key);
    _ramCorpusJson = json;
    return json;
  }

  /// RAM에 로드된 코퍼스로 벡터 인덱스 구축.
  static KgragPrecedentPack loadPackFromRam() {
    final json = _ramCorpusJson;
    if (json == null) {
      throw StateError('RAM에 복호화된 코퍼스 없음 — 생체인증 후 unlock 필요');
    }
    return SgpKgragLoader.parsePack(json);
  }

  /// 봉인→생체 unlock→파싱 왕복 (테스트·초기화).
  static Future<KgragPrecedentPack> unlockAndParse({
    required String plainJson,
    required Uint8List key,
    required SgpBiometricAuthPort biometric,
  }) async {
    final envelope = sealCorpus(plainJson: plainJson, key: key);
    await unlockCorpusToRam(
      envelope: envelope,
      key: key,
      biometric: biometric,
    );
    final pack = loadPackFromRam();
    if (pack.targetCorpusSize != targetCorpusSize) {
      throw FormatException(
        'target_corpus_size ${pack.targetCorpusSize} != $targetCorpusSize',
      );
    }
    return pack;
  }

  /// 봉인 JSON 문자열 (저장용).
  static String encodeEnvelope(SgpEncryptedCacheEnvelope envelope) =>
      envelope.encode();

  static SgpEncryptedCacheEnvelope decodeEnvelope(String encoded) =>
      SgpEncryptedCacheEnvelope.decode(encoded);

  /// 코퍼스 무결성 해시 (테스트용).
  static String corpusFingerprint(String plainJson) {
    final bytes = utf8.encode(plainJson);
    return base64Encode(bytes.sublist(0, bytes.length.clamp(0, 32)));
  }

  /// 온디바이스 코퍼스 키 (운영 단말은 Secure Enclave/Keystore 바인딩).
  static Uint8List corpusKeyMaterial() =>
      Uint8List.fromList(List<int>.filled(32, 0x4B));
}
