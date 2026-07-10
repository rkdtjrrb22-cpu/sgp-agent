/// SGP-Agent 로컬 JSON 저장·조회.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'sgp_agent_core.dart';

const kRecordFilePrefix = 'sgp_agent_';

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

  /// adb/파일 관리자용 짧은 경로 표시.
  String get displayPath => filePath.replaceFirst('/data/user/0/', '');

  static SavedRecordSummary fromFile(File file) {
    final name = file.uri.pathSegments.last;
    final id = name.replaceFirst(kRecordFilePrefix, '').replaceFirst('.json', '');

    DateTime createdAt = file.lastModifiedSync();
    var preview = '';
    var confirmed = false;

    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          createdAt;
      final raw = json['rawText'] as String? ?? '';
      preview = raw.length > 48 ? '${raw.substring(0, 48)}…' : raw;
      confirmed = json['selfJudgmentConfirmed'] as bool? ?? false;
    } catch (_) {
      preview = '(파일 읽기 오류)';
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

Future<Directory> getAgentStorageDirectory() async {
  return getApplicationDocumentsDirectory();
}

Future<String> getAgentStoragePathLabel() async {
  final dir = await getAgentStorageDirectory();
  return dir.path.replaceFirst('/data/user/0/', '');
}

Future<File> saveAgentRecord(AgentRecord record) async {
  final dir = await getAgentStorageDirectory();
  final file = File('${dir.path}/$kRecordFilePrefix${record.id}.json');
  await file.writeAsString(jsonEncode(record.toJson()));
  return file;
}

Future<List<SavedRecordSummary>> listSavedRecords() async {
  final dir = await getAgentStorageDirectory();
  if (!dir.existsSync()) return [];

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && f.path.contains(kRecordFilePrefix))
      .toList()
    ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

  return files.map(SavedRecordSummary.fromFile).toList();
}

Future<AgentRecord?> loadAgentRecord(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return null;

  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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

/// 단일 JSON 조서 파일 삭제. 성공 시 true.
Future<bool> deleteAgentRecord(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return false;
  await file.delete();
  return true;
}

/// 모든 sgp_agent_*.json 기록 삭제. 삭제된 건수 반환.
Future<int> deleteAllAgentRecords() async {
  final dir = await getAgentStorageDirectory();
  if (!dir.existsSync()) return 0;

  var count = 0;
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.json')) continue;
    if (!entity.path.contains(kRecordFilePrefix)) continue;
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
