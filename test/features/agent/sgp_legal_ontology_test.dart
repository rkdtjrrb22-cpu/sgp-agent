import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:test/test.dart';

void main() {
  group('LegalOntologyMigrator', () {
    late List<LegalHierarchyNode> nodes;

    setUp(() {
      nodes = [
        const LegalHierarchyNode(
          id: 'ROOT',
          level: LegalHierarchyLevel.constitution,
          title: '헌법',
        ),
        LegalHierarchyNode(
          id: 'LAW-A',
          level: LegalHierarchyLevel.law,
          title: '형법',
          parentId: 'ROOT',
          domainTags: ['criminal'],
        ),
        LegalHierarchyNode(
          id: 'MANUAL-1',
          level: LegalHierarchyLevel.manual,
          title: '체포 매뉴얼',
          parentId: 'LAW-A',
          conflictCheck: true,
          linkedArticles: const [
            ArticleLink(upperNodeId: 'LAW-A', article: '제212조', note: '체포요건'),
          ],
          source: 'manual.pdf',
        ),
      ];
    });

    test('parent_id → is_subordinate_to', () {
      final triples = LegalOntologyMigrator.triplesFromNodes(nodes);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'LAW-A' &&
              t.predicate == LegalPredicate.isSubordinateTo &&
              t.objectId == 'ROOT',
        ),
        isTrue,
      );
    });

    test('linked_articles → cites_article + governed_by', () {
      final triples = LegalOntologyMigrator.triplesFromNodes(nodes);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'MANUAL-1' &&
              t.predicate == LegalPredicate.citesArticle &&
              t.objectValue == '제212조',
        ),
        isTrue,
      );
    });

    test('domain_tags → applies_to_domain', () {
      final triples = LegalOntologyMigrator.triplesFromNodes(nodes);
      expect(
        triples.any(
          (t) =>
              t.subjectId == 'LAW-A' &&
              t.predicate == LegalPredicate.appliesToDomain &&
              t.objectValue == 'criminal',
        ),
        isTrue,
      );
    });

    test('graph subgraph BFS', () {
      final graph = LegalOntologyMigrator.graphFromNodes(nodes);
      final sub = graph.subgraphFrom(rootSubjectId: 'ROOT', maxDepth: 2);
      expect(sub.nodeIds, containsAll(['ROOT', 'LAW-A', 'MANUAL-1']));
      expect(sub.triples, isNotEmpty);
    });

    test('triplesForChain — 체인 관련 트리플만', () {
      final graph = LegalOntologyMigrator.graphFromNodes(nodes);
      final related = graph.triplesForChain(['MANUAL-1', 'LAW-A']);
      expect(related, isNotEmpty);
      expect(
        related.every(
          (t) =>
              {'MANUAL-1', 'LAW-A'}.contains(t.subjectId) ||
              {'MANUAL-1', 'LAW-A'}.contains(t.objectId),
        ),
        isTrue,
      );
    });
  });
}
