import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology_session.dart';
import 'package:test/test.dart';

void main() {
  group('SgpLegalOntologySession', () {
    late String seedJson;

    setUp(() {
      seedJson = File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      SgpLegalOntologySession.instance.reset();
      SgpLegalHierarchyRegistry.instance.loadFromJson(seedJson);
    });

    test('loadFromSeedJson — 100+ triples from S6 seed', () {
      SgpLegalOntologySession.instance.loadFromSeedJson(seedJson);
      final session = SgpLegalOntologySession.instance;

      expect(session.isLoaded, isTrue);
      expect(session.tripleCount, greaterThanOrEqualTo(100));
      expect(session.source, 'seed_json');
    });

    test('loadFromRegistry — graph matches migrator output', () {
      SgpLegalOntologySession.instance.loadFromRegistry();

      final expected = LegalOntologyMigrator.graphFromRegistry(
        SgpLegalHierarchyRegistry.instance,
      );
      expect(
        SgpLegalOntologySession.instance.tripleCount,
        expected.triples.length,
      );
    });

    test('triplesForComparison — hierarchy engine chain-linked triples', () {
      SgpLegalOntologySession.instance.loadFromRegistry();
      final anchors = SgpLegalHierarchyEngine.inferAnchorIds(
        domainTags: domainTagsForIncidentKey('mutual_combat'),
        includeProcedure: true,
        includeEvidence: false,
        includeOrgManual: false,
      );
      final hierarchy = SgpLegalHierarchyEngine.resolve(
        context: LegalHierarchyContext(
          orgId: 'KR-NPA',
          taskCategory: 'field_arrest',
          localGovCode: '11',
          domainTags: domainTagsForIncidentKey('mutual_combat'),
        ),
        anchorNodeIds: anchors,
      );

      final triples = SgpLegalOntologySession.instance.triplesForComparison(
        hierarchy,
      );
      expect(triples, isNotEmpty);
    });
  });
}
