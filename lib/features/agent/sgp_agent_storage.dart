/// SGP-Agent 로컬 저장·조회 (AES-256-GCM + Android Keystore).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../native/sgp_native_bridge.dart';
import 'sgp_agent_core.dart';
import 'sgp_agent_storage_io.dart';
import 'sgp_secure_cache_crypto.dart';

export 'sgp_agent_storage_io.dart'
    show
        SavedRecordSummary,
        formatRecordTimestamp,
        kLegacyRecordExtension,
        kRecordFilePrefix,
        migrateLegacyAgentRecords,
        sampleRecordJson;

SgpCacheCipher? _configuredCipher;

/// 앱 시작 시 Android Keystore 기반 암복호화 어댑터를 등록한다.
void configureAgentStorageCipher(SgpCacheCipher cipher) {
  _configuredCipher = cipher;
}

SgpCacheCipher _cipher([SgpCacheCipher? override]) {
  return override ?? _configuredCipher ?? SgpNativeBridge.cacheCipher;
}

Future<Directory> getAgentStorageDirectory() async {
  return getApplicationDocumentsDirectory();
}

Future<String> getAgentStoragePathLabel() async {
  final dir = await getAgentStorageDirectory();
  return dir.path.replaceFirst('/data/user/0/', '');
}

Future<File> saveAgentRecord(
  AgentRecord record, {
  Directory? directory,
  SgpCacheCipher? cipher,
}) async {
  final dir = directory ?? await getAgentStorageDirectory();
  return saveAgentRecordJsonEncrypted(
    recordJson: record.toJson(),
    directory: dir,
    cipher: _cipher(cipher),
  );
}

Future<List<SavedRecordSummary>> listSavedRecords({
  Directory? directory,
  SgpCacheCipher? cipher,
  bool migrateLegacy = true,
}) async {
  final dir = directory ?? await getAgentStorageDirectory();
  return listSavedRecordsEncrypted(
    directory: dir,
    cipher: _cipher(cipher),
    migrateLegacy: migrateLegacy,
  );
}

Future<AgentRecord?> loadAgentRecord(
  String filePath, {
  SgpCacheCipher? cipher,
}) async {
  final json = await loadAgentRecordJsonEncrypted(
    filePath: filePath,
    cipher: _cipher(cipher),
  );
  if (json == null) return null;
  return _agentRecordFromJson(json);
}

AgentRecord _agentRecordFromJson(Map<String, dynamic> json) {
  return AgentRecord(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    rawText: json['rawText'] as String,
    checklist: LawCheckList.fromJson(
      Map<String, dynamic>.from(json['checklist'] as Map? ?? {}),
    ),
    prompt: json['prompt'] as String? ?? '',
    output: json['output'] as String? ?? '',
    selfJudgmentConfirmed: json['selfJudgmentConfirmed'] as bool? ?? false,
    advancedAnalysis: json['advancedAnalysis'] == null
        ? null
        : Map<String, dynamic>.from(json['advancedAnalysis'] as Map),
    procedureTimeline: json['procedureTimeline'] == null
        ? null
        : Map<String, dynamic>.from(json['procedureTimeline'] as Map),
    quantumLegalAnalysis: json['quantumLegalAnalysis'] == null
        ? null
        : Map<String, dynamic>.from(json['quantumLegalAnalysis'] as Map),
  );
}

Future<bool> deleteAgentRecord(String filePath) {
  return deleteAgentRecordFile(filePath);
}

Future<int> deleteAllAgentRecords() async {
  final dir = await getAgentStorageDirectory();
  return deleteAllAgentRecordFiles(dir);
}

/// 테스트·디버그용 — JSON 직렬화 검증.
String encodeAgentRecordJson(AgentRecord record) => jsonEncode(record.toJson());
