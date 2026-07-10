import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:test/test.dart';

const _prefix = 'sgp_agent_';

void main() {
  test('AgentRecord round-trip JSON', () {
    final record = AgentRecord(
      id: '999',
      createdAt: DateTime(2026, 7, 10, 14, 0),
      rawText: '피해자 남편 폭행',
      checklist: LawCheckList(isWeaponUsed: true),
      prompt: 'p',
      output: 'o',
      selfJudgmentConfirmed: true,
    );
    final json = record.toJson();
    final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

    expect(decoded['id'], '999');
    expect(decoded['rawText'], contains('남편'));
    expect(
      LawCheckList.fromJson(
        Map<String, dynamic>.from(decoded['checklist'] as Map),
      ).isWeaponUsed,
      isTrue,
    );
  });

  test('local json file delete pattern', () async {
    final dir = await Directory.systemTemp.createTemp('sgp_del_');
    final f1 = File('${dir.path}/$_prefix' '1.json');
    final f2 = File('${dir.path}/$_prefix' '2.json');
    final other = File('${dir.path}/other.json');
    await f1.writeAsString('{}');
    await f2.writeAsString('{}');
    await other.writeAsString('{}');

    var count = 0;
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.json')) continue;
      if (!entity.path.contains(_prefix)) continue;
      await entity.delete();
      count++;
    }

    expect(count, 2);
    expect(dir.listSync().whereType<File>().length, 1);
    await dir.delete(recursive: true);
  });
}
