/// Sprint S6+ — 프로덕션 법령 동기화 Cron (재시도·운영 키 강제·exit code).
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
  final requireLiveKey = _envBool(env['LAW_SYNC_REQUIRE_LIVE_KEY']);
  final maxRetries = int.tryParse(env['LAW_API_MAX_RETRIES'] ?? '') ?? 3;
  final retryDelayMs = int.tryParse(env['LAW_API_RETRY_DELAY_MS'] ?? '') ?? 1500;

  final seedFile = File(seedPath);
  if (!seedFile.existsSync()) {
    stderr.writeln('FATAL: seed not found: $seedPath');
    exit(1);
  }

  final client = LawApiClient(
    lawGoKrOcKey: env['LAW_GO_KR_OC_KEY'],
    dataGoKrServiceKey: env['DATA_GO_KR_SERVICE_KEY'],
    maxRetries: maxRetries,
    retryDelayMs: retryDelayMs,
  );

  stdout.writeln('=== S6+ production law sync ===');
  stdout.writeln('credentials: ${client.hasLiveCredentials ? 'live' : 'missing'}');
  stdout.writeln('require_live_key: $requireLiveKey | retries: $maxRetries');

  if (requireLiveKey && !client.hasLiveCredentials) {
    stderr.writeln('FATAL: LAW_SYNC_REQUIRE_LIVE_KEY=true but API key missing');
    exit(2);
  }

  final fetch = await client.fetchNationalLaws(allowOfflineStub: !requireLiveKey);

  for (final w in fetch.warnings) {
    stderr.writeln('WARN: $w');
  }
  for (final e in fetch.errors) {
    stderr.writeln(
      'ERROR: ${e.query} [${e.kind.name}] attempts=${e.attempts} ${e.message ?? ''}',
    );
  }

  if (requireLiveKey && !fetch.isLive) {
    stderr.writeln('FATAL: live fetch failed under LAW_SYNC_REQUIRE_LIVE_KEY');
    exit(2);
  }

  if (requireLiveKey && fetch.hasErrors) {
    stderr.writeln('FATAL: partial API errors under production mode');
    exit(2);
  }

  final apiNodes = client.mapToLegalNodes(fetch);
  final seedNodes = (jsonDecode(seedFile.readAsStringSync()) as List<dynamic>)
      .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
      .toList();

  final merged = _mergeNodes(seedNodes, apiNodes);
  final triples = LegalOntologyMigrator.triplesFromNodes(merged);

  final seedIds = seedNodes.map((n) => n.id).toSet();
  final added = merged.where((n) => !seedIds.contains(n.id)).length;

  stdout.writeln('fetch source: ${fetch.source} | laws: ${fetch.laws.length}');
  stdout.writeln('seed: ${seedNodes.length} | merged: ${merged.length} | added: $added');
  stdout.writeln('triples: ${triples.length} | api_errors: ${fetch.errors.length}');

  final outFile = File(outputPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(merged.map((n) => n.toJson()).toList()),
  );
  stdout.writeln('Wrote nodes: $outputPath');

  await File(sqlOutputPath).writeAsString(_buildTripleUpsertSql(triples));
  stdout.writeln('Wrote SQL: $sqlOutputPath');

  client.close();

  if (fetch.hasErrors && fetch.isLive) {
    stdout.writeln('PARTIAL_OK — some queries failed');
    exit(3);
  }

  stdout.writeln('OK');
  exit(0);
}

bool _envBool(String? raw) => raw != null && (raw.toLowerCase() == 'true' || raw == '1');

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
  return byId.values.toList()..sort((a, b) => a.level.value.compareTo(b.level.value));
}

String _buildTripleUpsertSql(List<LegalOntologyTriple> triples) {
  final buf = StringBuffer()
    ..writeln('-- S6+ legal_triples UPSERT (generated)')
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
