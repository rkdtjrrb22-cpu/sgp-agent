/// S8 — 암호화 스토리지 초기화·복호화 무결성 9종.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sgp_agent/features/agent/sgp_agent_storage_io.dart';
import 'package:sgp_agent/features/agent/sgp_secure_cache_crypto.dart';
import 'package:test/test.dart';

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));
  final wrongKey = Uint8List.fromList(List<int>.generate(32, (i) => 200 - i));

  group('S8 암호화 스토리지 무결성', () {
    test('1. 잘못된 키로 복호화하면 실패한다', () {
      final envelope = SgpAes256Gcm.sealForTest(plainText: '기밀 조서', key: key);
      expect(
        () => SgpAes256Gcm.openForTest(envelope: envelope, key: wrongKey),
        throwsA(anything),
      );
    });

    test('2. cipherText 1바이트 변조 시 GCM 인증이 거부한다', () {
      final envelope = SgpAes256Gcm.sealForTest(plainText: '변조 방지', key: key);
      final tampered = Uint8List.fromList(envelope.cipherText);
      tampered[0] ^= 0xFF;
      expect(
        () => SgpAes256Gcm.decrypt(
          cipherText: tampered,
          key: key,
          nonce: envelope.nonce,
        ),
        throwsA(anything),
      );
    });

    test('3. nonce 변조 시 복호화가 실패한다', () {
      final envelope = SgpAes256Gcm.sealForTest(plainText: 'nonce 검증', key: key);
      final badNonce = Uint8List.fromList(envelope.nonce);
      badNonce[3] ^= 0x55;
      expect(
        () => SgpAes256Gcm.decrypt(
          cipherText: envelope.cipherText,
          key: key,
          nonce: badNonce,
        ),
        throwsA(anything),
      );
    });

    test('4. 지원하지 않는 봉투 버전은 거부한다', () {
      final envelope = SgpAes256Gcm.sealForTest(plainText: 'v-check', key: key);
      final json = envelope.toJson()..['version'] = 99;
      expect(
        () => SgpEncryptedCacheEnvelope.fromJson(json),
        throwsFormatException,
      );
    });

    test('5. 지원하지 않는 알고리즘은 거부한다', () {
      final envelope = SgpAes256Gcm.sealForTest(plainText: 'alg-check', key: key);
      final json = envelope.toJson()..['algorithm'] = 'AES-128-CBC';
      expect(
        () => SgpEncryptedCacheEnvelope.fromJson(json),
        throwsFormatException,
      );
    });

    test('6. AES-256이 아닌 키 길이는 거부한다', () {
      final shortKey = Uint8List(16);
      expect(
        () => SgpAes256Gcm.encrypt(
          plainText: Uint8List.fromList(utf8.encode('짧은 키')),
          key: shortKey,
          nonce: Uint8List(SgpAes256Gcm.nonceLength),
        ),
        throwsArgumentError,
      );
    });

    test('7. 12바이트가 아닌 GCM nonce는 거부한다', () {
      expect(
        () => SgpAes256Gcm.encrypt(
          plainText: Uint8List.fromList(utf8.encode('nonce 길이')),
          key: key,
          nonce: Uint8List(8),
        ),
        throwsArgumentError,
      );
    });

    test('8. 스토리지 초기화 — 빈 디렉터리는 빈 목록, 저장 시 자동 생성', () async {
      final cipher = SgpTestCacheCipher(key);
      final root = await Directory.systemTemp.createTemp('sgp_integrity_');
      addTearDown(() => root.delete(recursive: true));

      final fresh = Directory('${root.path}/nested/records');
      expect(
        await listSavedRecordsEncrypted(directory: fresh, cipher: cipher),
        isEmpty,
      );

      final file = await saveAgentRecordJsonEncrypted(
        recordJson: sampleRecordJson(id: 'init-1', rawText: '초기화 검증'),
        directory: fresh,
        cipher: cipher,
      );
      expect(await fresh.exists(), isTrue);
      expect(file.path, endsWith(kSgpEncryptedCacheExtension));

      final listed =
          await listSavedRecordsEncrypted(directory: fresh, cipher: cipher);
      expect(listed, hasLength(1));
      expect(listed.single.rawTextPreview, '초기화 검증');
    });

    test('9. 전체 폐기 시 암호화 파일이 디스크에 남지 않는다', () async {
      final cipher = SgpTestCacheCipher(key);
      final dir = await Directory.systemTemp.createTemp('sgp_wipe_');
      addTearDown(() => dir.delete(recursive: true));

      for (var i = 0; i < 3; i++) {
        await saveAgentRecordJsonEncrypted(
          recordJson: sampleRecordJson(id: 'wipe-$i', rawText: '폐기 대상 $i'),
          directory: dir,
          cipher: cipher,
        );
      }

      final deleted = await deleteAllAgentRecordFiles(dir);
      expect(deleted, 3);
      final remaining = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(kSgpEncryptedCacheExtension));
      expect(remaining, isEmpty);
    });
  });
}
