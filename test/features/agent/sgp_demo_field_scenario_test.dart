import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_demo_field_scenario_data.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology_session.dart';
import 'package:test/test.dart';

void main() {
  group('SgpDemoFieldScenario', () {
    late SgpDemoFieldScenario scenario;

    setUp(() {
      final json = File('assets/data/demo_field_scenario.json').readAsStringSync();
      scenario = SgpDemoFieldScenario.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      SgpLegalOntologySession.instance.reset();
      final seed = File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      SgpLegalHierarchyRegistry.instance.loadFromJson(seed);
      SgpLegalOntologySession.instance.loadFromRegistry();
    });

    test('loads gangnam mutual combat scenario', () {
      expect(scenario.id, 'demo_mutual_combat_gangnam');
      expect(scenario.radioText, contains('강남'));
      expect(scenario.expected.incidentType, 'mutual_combat');
      expect(scenario.expected.arrestType, 'currentOffender');
      expect(scenario.verificationSteps, isNotEmpty);
    });

    test('matchesArrestSuggestion — 현행범 체포', () {
      expect(
        scenario.matchesArrestSuggestion(scenario.radioText),
        isTrue,
      );
    });

    test('verifyAnalysisSnapshot passes for expected demo values', () {
      final result = scenario.verifyAnalysisSnapshot(
        incidentTypeJsonKey: 'mutual_combat',
        hierarchyChainTitles: const ['헌법', '형법', '형사소송법'],
        urgencyLevelName: 'caution',
      );
      expect(result.ok, isTrue, reason: result.issues.join('; '));
    });

    test('ontology triple count meets demo minimum', () {
      expect(
        SgpLegalOntologySession.instance.tripleCount,
        greaterThanOrEqualTo(scenario.expected.ontologyTripleCountMin),
      );
    });
  });
}
