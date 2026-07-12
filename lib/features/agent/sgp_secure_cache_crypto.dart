/// S8 — 로컬 민감정보 캐시 AES-256-GCM 봉인 형식.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const kSgpEncryptedCacheExtension = '.sgpcache';
const kSgpCacheCipherAlgorithm = 'AES-256-GCM';
const kSgpCacheEnvelopeVersion = 1;

/// 인증 암호화 결과. AAD는 버전·알고리즘·용도를 고정해 파일 바꿔치기를 방지한다.
class SgpEncryptedCacheEnvelope {
  const SgpEncryptedCacheEnvelope({
    required this.nonce,
    required this.cipherText,
    this.version = kSgpCacheEnvelopeVersion,
    this.algorithm = kSgpCacheCipherAlgorithm,
    this.keyAlias = 'sgp_agent_cache_key_v1',
  });

  final int version;
  final String algorithm;
  final String keyAlias;
  final Uint8List nonce;
  final Uint8List cipherText;

  factory SgpEncryptedCacheEnvelope.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 0;
    final algorithm = json['algorithm'] as String? ?? '';
    if (version != kSgpCacheEnvelopeVersion ||
        algorithm != kSgpCacheCipherAlgorithm) {
      throw const FormatException('지원하지 않는 암호화 캐시 형식입니다.');
    }
    return SgpEncryptedCacheEnvelope(
      version: version,
      algorithm: algorithm,
      keyAlias: json['keyAlias'] as String? ?? 'sgp_agent_cache_key_v1',
      nonce: base64Decode(json['nonce'] as String),
      cipherText: base64Decode(json['cipherText'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'algorithm': algorithm,
        'keyAlias': keyAlias,
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(cipherText),
      };

  String encode() => jsonEncode(toJson());

  static SgpEncryptedCacheEnvelope decode(String value) {
    return SgpEncryptedCacheEnvelope.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }
}

/// 테스트·비 Android 플랫폼에서 재사용 가능한 AES-256-GCM 코어.
///
/// 운영 Android 저장은 동일 봉투 형식과 AAD를 사용하는 Keystore 네이티브
/// 브리지를 통해 처리하여 원시 키가 Dart/파일시스템에 노출되지 않는다.
abstract final class SgpAes256Gcm {
  static const nonceLength = 12;
  static const tagLengthBits = 128;

  static Uint8List encrypt({
    required Uint8List plainText,
    required Uint8List key,
    required Uint8List nonce,
    Uint8List? aad,
  }) {
    _validate(key, nonce);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          tagLengthBits,
          nonce,
          aad ?? cacheAad(),
        ),
      );
    return cipher.process(plainText);
  }

  static Uint8List decrypt({
    required Uint8List cipherText,
    required Uint8List key,
    required Uint8List nonce,
    Uint8List? aad,
  }) {
    _validate(key, nonce);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          tagLengthBits,
          nonce,
          aad ?? cacheAad(),
        ),
      );
    return cipher.process(cipherText);
  }

  static SgpEncryptedCacheEnvelope sealForTest({
    required String plainText,
    required Uint8List key,
    Random? random,
  }) {
    final rng = random ?? Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(nonceLength, (_) => rng.nextInt(256)),
    );
    return SgpEncryptedCacheEnvelope(
      nonce: nonce,
      cipherText: encrypt(
        plainText: Uint8List.fromList(utf8.encode(plainText)),
        key: key,
        nonce: nonce,
      ),
    );
  }

  static String openForTest({
    required SgpEncryptedCacheEnvelope envelope,
    required Uint8List key,
  }) {
    return utf8.decode(
      decrypt(
        cipherText: envelope.cipherText,
        key: key,
        nonce: envelope.nonce,
      ),
    );
  }

  static Uint8List cacheAad() => Uint8List.fromList(
        utf8.encode(
          'SGP-Agent|record-cache|v$kSgpCacheEnvelopeVersion|'
          '$kSgpCacheCipherAlgorithm',
        ),
      );

  static void _validate(Uint8List key, Uint8List nonce) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key.length', 'AES-256 키는 32바이트여야 합니다.');
    }
    if (nonce.length != nonceLength) {
      throw ArgumentError.value(
        nonce.length,
        'nonce.length',
        'GCM nonce는 12바이트여야 합니다.',
      );
    }
  }
}

/// 저장소가 사용하는 암복호화 포트.
abstract interface class SgpCacheCipher {
  Future<String> encrypt(String plainText);

  Future<String> decrypt(String envelopeJson);
}

/// 단위 테스트용 고정 키 구현. 운영 코드에서 사용하지 않는다.
class SgpTestCacheCipher implements SgpCacheCipher {
  SgpTestCacheCipher(this.key);

  final Uint8List key;

  @override
  Future<String> encrypt(String plainText) async {
    return SgpAes256Gcm.sealForTest(plainText: plainText, key: key).encode();
  }

  @override
  Future<String> decrypt(String envelopeJson) async {
    return SgpAes256Gcm.openForTest(
      envelope: SgpEncryptedCacheEnvelope.decode(envelopeJson),
      key: key,
    );
  }
}
