import 'dart:io';
import 'dart:typed_data';

import 'package:sgp_agent/features/agent/sgp_agent_storage_io.dart';
import 'package:sgp_agent/features/agent/sgp_secure_cache_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('S8 AgentRecord encrypted storage', () {
    late Directory directory;
    late SgpTestCacheCipher cipher;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sgp_cache_test_');
      cipher = SgpTestCacheCipher(
        Uint8List.fromList(List<int>.generate(32, (i) => 255 - i)),
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('신규 조서는 .sgpcache AES 봉투로만 저장', () async {
      const rawText = '민감한 현장 무전 원문';
      final recordJson = sampleRecordJson(id: 'encrypted-1', rawText: rawText);
      final file = await saveAgentRecordJsonEncrypted(
        recordJson: recordJson,
        directory: directory,
        cipher: cipher,
      );

      expect(file.path, endsWith(kSgpEncryptedCacheExtension));
      final disk = await file.readAsString();
      expect(disk, isNot(contains(rawText)));
      expect(SgpEncryptedCacheEnvelope.decode(disk).algorithm, 'AES-256-GCM');

      final loaded = await loadAgentRecordJsonEncrypted(
        filePath: file.path,
        cipher: cipher,
      );
      expect(loaded?['rawText'], rawText);
      expect(loaded?['selfJudgmentConfirmed'], isTrue);
    });

    test('기존 평문 JSON을 검증 후 암호화 파일로 자동 마이그레이션', () async {
      const rawText = '평문 삭제 대상';
      final legacy = File('${directory.path}/sgp_agent_legacy.json');
      await legacy.writeAsString(
        '{"id":"legacy","createdAt":"2026-07-12T12:00:00.000",'
        '"rawText":"$rawText","checklist":{},"prompt":"p","output":"o",'
        '"selfJudgmentConfirmed":false}',
      );

      final count = await migrateLegacyAgentRecords(
        directory: directory,
        cipher: cipher,
      );

      expect(count, 1);
      expect(await legacy.exists(), isFalse);
      final encrypted = File('${directory.path}/sgp_agent_legacy.sgpcache');
      expect(await encrypted.exists(), isTrue);
      expect(await encrypted.readAsString(), isNot(contains(rawText)));
      expect(
        (await loadAgentRecordJsonEncrypted(
          filePath: encrypted.path,
          cipher: cipher,
        ))?['rawText'],
        rawText,
      );
    });

    test('암호화 목록은 복호화된 미리보기만 메모리에서 생성', () async {
      await saveAgentRecordJsonEncrypted(
        recordJson: sampleRecordJson(
          id: 'summary',
          rawText: '목록 미리보기용 보안 기록',
        ),
        directory: directory,
        cipher: cipher,
      );

      final summaries = await listSavedRecordsEncrypted(
        directory: directory,
        cipher: cipher,
      );

      expect(summaries, hasLength(1));
      expect(summaries.single.rawTextPreview, '목록 미리보기용 보안 기록');
      expect(summaries.single.fileName, endsWith('.sgpcache'));
    });
  });
}
