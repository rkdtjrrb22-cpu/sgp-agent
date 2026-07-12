/// S8 — AgentRecord 로컬 저장 IO (Flutter 비의존, 암호화 필수).
library;

import 'dart:convert';
import 'dart:io';

import 'sgp_secure_cache_crypto.dart';

const kRecordFilePrefix = 'sgp_agent_';
const kLegacyRecordExtension = '.json';

/// 저장된 조서 파일 요약.
class SavedRecordSummary {
  const SavedRecordSummary({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.rawTextPreview,
    required this.selfJudgmentConfirmed,
  });

  final String id;
  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final String rawTextPreview;
  final bool selfJudgmentConfirmed;

  String get displayPath => filePath.replaceFirst('/data/user/0/', '');

  static Future<SavedRecordSummary> fromFile(
    File file, {
    required SgpCacheCipher cipher,
  }) async {
    final name = file.uri.pathSegments.last;
    final id = name
        .replaceFirst(kRecordFilePrefix, '')
        .replaceFirst(kSgpEncryptedCacheExtension, '')
        .replaceFirst(kLegacyRecordExtension, '');

    DateTime createdAt = await file.lastModified();
    var preview = '';
    var confirmed = false;

    try {
      final json = jsonDecode(await readRecordPlainText(file, cipher: cipher))
          as Map<String, dynamic>;
      createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          createdAt;
      final transcript = json['rawText'] as String? ?? '';
      preview = transcript.length > 48
          ? '${transcript.substring(0, 48)}…'
          : transcript;
      confirmed = json['selfJudgmentConfirmed'] as bool? ?? false;
    } catch (_) {
      preview = '(암호화 파일 읽기 오류)';
    }

    return SavedRecordSummary(
      id: id,
      filePath: file.path,
      fileName: name,
      createdAt: createdAt,
      rawTextPreview: preview,
      selfJudgmentConfirmed: confirmed,
    );
  }
}

Future<String> readRecordPlainText(
  File file, {
  required SgpCacheCipher cipher,
}) async {
  final raw = await file.readAsString();
  if (file.path.endsWith(kSgpEncryptedCacheExtension)) {
    return cipher.decrypt(raw);
  }
  return raw;
}

Future<File> saveAgentRecordJsonEncrypted({
  required Map<String, dynamic> recordJson,
  required Directory directory,
  required SgpCacheCipher cipher,
}) async {
  if (!await directory.exists()) await directory.create(recursive: true);
  final id = recordJson['id'] as String;
  final file = File(
    '${directory.path}/$kRecordFilePrefix$id$kSgpEncryptedCacheExtension',
  );
  final encrypted = await cipher.encrypt(jsonEncode(recordJson));
  await file.writeAsString(encrypted, flush: true);
  return file;
}

Future<List<SavedRecordSummary>> listSavedRecordsEncrypted({
  required Directory directory,
  required SgpCacheCipher cipher,
  bool migrateLegacy = true,
}) async {
  if (!await directory.exists()) return [];

  if (migrateLegacy) {
    await migrateLegacyAgentRecords(directory: directory, cipher: cipher);
  }

  final files = directory
      .listSync()
      .whereType<File>()
      .where(
        (f) =>
            f.path.contains(kRecordFilePrefix) &&
            (f.path.endsWith(kSgpEncryptedCacheExtension) ||
                f.path.endsWith(kLegacyRecordExtension)),
      )
      .toList()
    ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

  return Future.wait(
    files.map((file) => SavedRecordSummary.fromFile(file, cipher: cipher)),
  );
}

Future<Map<String, dynamic>?> loadAgentRecordJsonEncrypted({
  required String filePath,
  required SgpCacheCipher cipher,
}) async {
  final file = File(filePath);
  if (!file.existsSync()) return null;
  return jsonDecode(await readRecordPlainText(file, cipher: cipher))
      as Map<String, dynamic>;
}

Future<int> migrateLegacyAgentRecords({
  required Directory directory,
  required SgpCacheCipher cipher,
}) async {
  if (!await directory.exists()) return 0;
  var migrated = 0;

  for (final entity in directory.listSync().whereType<File>()) {
    if (!entity.path.contains(kRecordFilePrefix) ||
        !entity.path.endsWith(kLegacyRecordExtension)) {
      continue;
    }

    final plainText = await entity.readAsString();
    jsonDecode(plainText) as Map<String, dynamic>;

    final targetPath = entity.path.replaceFirst(
      RegExp(r'\.json$'),
      kSgpEncryptedCacheExtension,
    );
    final target = File(targetPath);
    final temporary = File('$targetPath.tmp');
    final encrypted = await cipher.encrypt(plainText);
    await temporary.writeAsString(encrypted, flush: true);

    final verified = await cipher.decrypt(await temporary.readAsString());
    if (verified != plainText) {
      await temporary.delete();
      throw StateError('레거시 기록 암호화 검증에 실패했습니다.');
    }
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
    await entity.delete();
    migrated++;
  }

  return migrated;
}

Future<bool> deleteAgentRecordFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return false;
  await file.delete();
  return true;
}

Future<int> deleteAllAgentRecordFiles(Directory directory) async {
  if (!await directory.exists()) return 0;

  var count = 0;
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    if (!entity.path.contains(kRecordFilePrefix)) continue;
    if (!entity.path.endsWith(kSgpEncryptedCacheExtension) &&
        !entity.path.endsWith(kLegacyRecordExtension)) {
      continue;
    }
    await entity.delete();
    count++;
  }
  return count;
}

String formatRecordTimestamp(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} $h:$m:$s';
}

Map<String, dynamic> sampleRecordJson({
  required String id,
  required String rawText,
  bool selfJudgmentConfirmed = true,
}) {
  return {
    'id': id,
    'createdAt': DateTime(2026, 7, 12, 12).toIso8601String(),
    'rawText': rawText,
    'checklist': const <String, dynamic>{},
    'prompt': 'prompt',
    'output': 'output',
    'selfJudgmentConfirmed': selfJudgmentConfirmed,
  };
}
