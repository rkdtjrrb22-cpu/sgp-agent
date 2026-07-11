/// Sprint S5 — 법제처 LV1~4 노드 동기화 Cron PoC.
///
/// 실행: `dart run tool/cron/sync_law_nodes.dart`
///
/// 실제 법제처 API 연동 전 — 로컬 시드와 외부 JSON diff·병합 리포트.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final seedPath = args.isNotEmpty ? args[0] : 'assets/data/legal_hierarchy_seed.json';
  final incomingPath = args.length > 1 ? args[1] : seedPath;

  final seedFile = File(seedPath);
  final incomingFile = File(incomingPath);
  if (!seedFile.existsSync() || !incomingFile.existsSync()) {
    stderr.writeln('Usage: dart run tool/cron/sync_law_nodes.dart [seed] [incoming]');
    exit(1);
  }

  final seed = _parseNodes(seedFile.readAsStringSync());
  final incoming = _parseNodes(incomingFile.readAsStringSync());

  final seedIds = seed.map((n) => n['id'] as String).toSet();
  final incomingIds = incoming.map((n) => n['id'] as String).toSet();

  final added = incoming.where((n) => !seedIds.contains(n['id'])).toList();
  final removed = seed.where((n) => !incomingIds.contains(n['id'])).toList();
  final updated = <Map<String, dynamic>>[];

  for (final node in incoming) {
    final id = node['id'] as String;
    if (!seedIds.contains(id)) continue;
    final old = seed.firstWhere((n) => n['id'] == id);
    if (jsonEncode(old) != jsonEncode(node)) updated.add(node);
  }

  final lv14 = incoming.where((n) => (n['level'] as int) <= 4).length;

  stdout.writeln('=== legal_nodes sync report ===');
  stdout.writeln('seed: ${seed.length} nodes | incoming: ${incoming.length} | LV1~4: $lv14');
  stdout.writeln('added: ${added.length} | updated: ${updated.length} | removed: ${removed.length}');

  for (final n in added) {
    stdout.writeln('  + ${n['id']} LV${n['level']} ${n['title']}');
  }
  for (final n in updated) {
    stdout.writeln('  ~ ${n['id']} ${n['title']}');
  }
  for (final n in removed) {
    stdout.writeln('  - ${n['id']} ${n['title']}');
  }

  if (added.isEmpty && updated.isEmpty && removed.isEmpty) {
    stdout.writeln('No changes — skip DB write.');
    exit(0);
  }

  stdout.writeln('\nMerged output ready for legal_hierarchy OTA channel.');
}

List<Map<String, dynamic>> _parseNodes(String source) {
  final list = jsonDecode(source) as List<dynamic>;
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
