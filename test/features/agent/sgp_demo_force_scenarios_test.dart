import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_constitutional_force_engine.dart';
import 'package:sgp_agent/features/agent/sgp_demo_force_scenarios_data.dart';
import 'package:test/test.dart';

void main() {
  group('SgpDemoForceScenarioPack', () {
    late SgpDemoForceScenarioPack pack;

    setUp(() {
      final json = File('assets/data/demo_force_scenarios.json').readAsStringSync();
      pack = SgpDemoForceScenarioPack.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    });

    test('loads 6 force demo presets', () {
      expect(pack.scenarios.length, 6);
    });

    test('stage 2 taser excess preset triggers IsExcessive', () {
      final scenario = pack.scenarios.firstWhere(
        (s) => s.id == 'force_stage_2_taser_excess',
      );
      final resistance =
          SgpConstitutionalForceEngine.detectResistanceFromText(scenario.radioText)!;
      final force =
          SgpConstitutionalForceEngine.detectForceTierFromText(scenario.radioText)!;
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: resistance,
        forceTier: force,
      );
      expect(scenario.expectedExcessive, isTrue);
      expect(a.isExcessive, isTrue);
    });

    test('stage 1 compliance preset is lawful', () {
      final scenario = pack.scenarios.firstWhere(
        (s) => s.id == 'force_stage_1_compliance',
      );
      final resistance =
          SgpConstitutionalForceEngine.detectResistanceFromText(scenario.radioText)!;
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: resistance,
        forceTier: PoliceForceTier.verbalControl,
      );
      expect(a.isExcessive, isFalse);
    });
  });
}
