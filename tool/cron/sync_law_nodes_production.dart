/// Sprint S6 — 프로덕션 법령 동기화 Cron (법제처·공공데이터 API).
///
/// 환경 변수:
///   LAW_GO_KR_OC_KEY      — 국가법령정보센터 OC
///   DATA_GO_KR_SERVICE_KEY — 공공데이터포털 서비스키 (대체)
///   OUTPUT_PATH           — 병합 JSON 출력 (기본: build/legal_nodes_sync.json)
///   SEED_PATH             — 기존 시드 (기본: assets/data/legal_hierarchy_seed.json)
///
/// 실행:
///   dart run tool/cron/sync_law_nodes_production.dart
import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';

import 'law_api_client.dart';

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final seedPath = args.isNotEmpty ? args[0] : (env['SEED_PATH'] ?? 'assets/data/legal_hierarchy_seed.json');
  final outputPath = env['OUTPUT_PATH'] ?? 'build/legal_nodes_sync.json';
  final sqlOutputPath = env['SQL_OUTPUT_PATH'] ?? 'build/legal_triples_upsert.sql';

  final seedFile = File(seedPath);
  if (!seedFile.existsSync()) {
    stderr.writeln('Seed not found: $seedPath');
    exit(1);
  }

  final client = LawApiClient(
    lawGoKrOcKey: env['LAW_GO_KR_OC_KEY'],
    dataGoKrServiceKey: env['DATA_GO_KR_SERVICE_KEY'],
  );

  stdout.writeln('=== S6 production law sync ===');
  stdout.writeln('credentials: ${client.hasLiveCredentials ? 'live' : 'offline_stub'}');

  final fetch = await client.fetchNationalLaws();
  for (final w in fetch.warnings) {
    stderr.writeln('WARN: $w');
  }

  final apiNodes = client.mapToLegalNodes(fetch);
  final seedNodes = (jsonDecode(seedFile.readAsStringSync()) as List<dynamic>)
      .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
      .toList();

  final merged = _mergeNodes(seedNodes, apiNodes);
  final triples = LegalOntologyMigrator.triplesFromNodes(merged);

  final seedIds = seedNodes.map((n) => n.id).toSet();
  final mergedIds = merged.map((n) => n.id).toSet();
  final added = merged.where((n) => !seedIds.contains(n.id)).length;
  final removed = seedNodes.where((n) => !mergedIds.contains(n.id)).length;

  stdout.writeln('fetch source: ${fetch.source} | laws: ${fetch.laws.length}');
  stdout.writeln('seed: ${seedNodes.length} | merged: ${merged.length}');
  stdout.writeln('added: $added | removed: $removed | triples: ${triples.length}');

  final outFile = File(outputPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(merged.map((n) => n.toJson()).toList()),
  );
  stdout.writeln('Wrote nodes: $outputPath');

  final sql = _buildTripleUpsertSql(triples);
  final sqlFile = File(sqlOutputPath);
  await sqlFile.writeAsString(sql);
  stdout.writeln('Wrote SQL: $sqlOutputPath');

  client.close();
}

List<LegalHierarchyNode> _mergeNodes(
  List<LegalHierarchyNode> seed,
  List<Map<String, dynamic>> apiMaps,
) {
  final byId = {for (final n in seed) n.id: n};

  for (final map in apiMaps) {
    final node = LegalHierarchyNode.fromJson(map);
    if (byId.containsKey(node.id)) continue;
    if (node.id.startsWith('KR-LAW-API-')) {
      byId[node.id] = node;
    }
  }

  return byId.values.toList()
    ..sort((a, b) => a.level.value.compareTo(b.level.value));
}

String _buildTripleUpsertSql(List<LegalOntologyTriple> triples) {
  final buf = StringBuffer()
    ..writeln('-- S6 legal_triples UPSERT (generated)')
    ..writeln('BEGIN;');

  for (final t in triples) {
    final objectId = t.objectId == null ? 'NULL' : "'${_escape(t.objectId!)}'";
    final objectValue = t.objectValue == null ? 'NULL' : "'${_escape(t.objectValue!)}'";
    final source = t.source == null ? 'NULL' : "'${_escape(t.source!)}'";

    buf.writeln(
      "INSERT INTO legal_triples (subject_id, predicate, object_id, object_value, confidence, source) "
      "VALUES ('${_escape(t.subjectId)}', '${t.predicate.apiValue}', $objectId, $objectValue, "
      "${t.confidence}, $source) "
      "ON CONFLICT (subject_id, predicate, object_id, object_value) DO UPDATE "
      "SET confidence = EXCLUDED.confidence, source = EXCLUDED.source, updated_at = now();",
    );
  }

  buf.writeln('COMMIT;');
  return buf.toString();
}

String _escape(String s) => s.replaceAll("'", "''");
