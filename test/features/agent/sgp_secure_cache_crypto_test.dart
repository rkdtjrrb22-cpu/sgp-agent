import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:sgp_agent/features/agent/sgp_secure_cache_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('S8 SgpAes256Gcm', () {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));

    test('AES-256-GCM 봉인→복호화 왕복', () {
      final envelope = SgpAes256Gcm.sealForTest(
        plainText: '112 무전: 피의자 현행범 체포',
        key: key,
        random: Random(7),
      );

      expect(envelope.algorithm, kSgpCacheCipherAlgorithm);
      expect(envelope.nonce, hasLength(12));
      expect(
        SgpAes256Gcm.openForTest(envelope: envelope, key: key),
        '112 무전: 피의자 현행범 체포',
      );
    });

    test('암호문에는 평문·개인정보가 노출되지 않음', () {
      const sensitive = '홍길동 900101-1234567';
      final encoded = SgpAes256Gcm.sealForTest(
        plainText: sensitive,
        key: key,
      ).encode();

      expect(encoded, isNot(contains('홍길동')));
      expect(encoded, isNot(contains('900101')));
      expect(utf8.encode(encoded), isNot(containsAll(utf8.encode(sensitive))));
    });

    test('인증 태그 위변조 시 복호화 거부', () {
      final envelope = SgpAes256Gcm.sealForTest(
        plainText: '증거 무결성',
        key: key,
        random: Random(9),
      );
      final tampered = Uint8List.fromList(envelope.cipherText);
      tampered[tampered.length - 1] ^= 0x01;

      expect(
        () => SgpAes256Gcm.openForTest(
          envelope: SgpEncryptedCacheEnvelope(
            nonce: envelope.nonce,
            cipherText: tampered,
          ),
          key: key,
        ),
        throwsA(anything),
      );
    });

    test('다른 AES 키로 복호화 거부', () {
      final envelope = SgpAes256Gcm.sealForTest(
        plainText: '키 격리',
        key: key,
        random: Random(11),
      );
      final wrongKey = Uint8List.fromList(List<int>.filled(32, 0xA5));

      expect(
        () => SgpAes256Gcm.openForTest(
          envelope: envelope,
          key: wrongKey,
        ),
        throwsA(anything),
      );
    });

    test('봉투 JSON 직렬화가 version·algorithm·keyAlias를 보존', () {
      final envelope = SgpAes256Gcm.sealForTest(
        plainText: 'cache envelope',
        key: key,
        random: Random(13),
      );
      final restored = SgpEncryptedCacheEnvelope.decode(envelope.encode());

      expect(restored.version, kSgpCacheEnvelopeVersion);
      expect(restored.algorithm, kSgpCacheCipherAlgorithm);
      expect(restored.keyAlias, 'sgp_agent_cache_key_v1');
      expect(restored.nonce, envelope.nonce);
      expect(restored.cipherText, envelope.cipherText);
    });
  });
}
