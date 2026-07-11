/// Sprint S3 — Top-Down 위계 아코디언 트리.
library;

import 'package:flutter/material.dart';

import 'sgp_app_theme.dart';
import 'sgp_legal_hierarchy.dart';

Color hierarchyLevelColor(LegalHierarchyLevel level) => switch (level) {
      LegalHierarchyLevel.constitution => const Color(0xFF818CF8),
      LegalHierarchyLevel.law => SgpFieldColors.navy,
      LegalHierarchyLevel.presidentialDecree => const Color(0xFF38BDF8),
      LegalHierarchyLevel.ministerialRule => const Color(0xFF22D3EE),
      LegalHierarchyLevel.localOrdinance => const Color(0xFF34D399),
      LegalHierarchyLevel.administrativeRule => const Color(0xFFA3E635),
      LegalHierarchyLevel.internalRegulation => SgpFieldColors.cautionOrange,
      LegalHierarchyLevel.manual => SgpFieldColors.textSecondary,
    };

/// parent_id 기반 Top-Down 아코디언 트리.
class SgpLegalHierarchyTreeWidget extends StatelessWidget {
  const SgpLegalHierarchyTreeWidget({super.key, required this.resolution});

  final SgpHierarchyResolution resolution;

  @override
  Widget build(BuildContext context) {
    final forest = SgpLegalHierarchyTreeBuilder.buildForest(resolution.chain);
    if (forest.isEmpty) return const SizedBox.shrink();

    final conflictIds = resolution.conflicts.map((c) => c.lowerNodeId).toSet();

    return Container(
      decoration: BoxDecoration(
        color: SgpFieldColors.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SgpFieldColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < forest.length; i++)
            _HierarchyTreeTile(
              treeNode: forest[i],
              depth: 0,
              conflictNodeIds: conflictIds,
              initiallyExpanded: i == 0,
            ),
          if (resolution.conflicts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in resolution.conflicts.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '⚠️ ${c.message}',
                        style: TextStyle(
                          fontSize: 9,
                          color: SgpFieldColors.cautionOrange.withValues(alpha: 0.95),
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HierarchyTreeTile extends StatelessWidget {
  const _HierarchyTreeTile({
    required this.treeNode,
    required this.depth,
    required this.conflictNodeIds,
    this.initiallyExpanded = false,
  });

  final LegalHierarchyTreeNode treeNode;
  final int depth;
  final Set<String> conflictNodeIds;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final node = treeNode.node;
    final color = hierarchyLevelColor(node.level);
    final hasConflict = conflictNodeIds.contains(node.id);
    final hasChildren = treeNode.children.isNotEmpty;
    final localCode = node.scope['local_gov_code'];

    final titleRow = Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            'LV${node.level.value}',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            node.title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: SgpFieldColors.textPrimary,
            ),
          ),
        ),
        if (localCode != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '지자체 $localCode',
              style: const TextStyle(fontSize: 8, color: SgpFieldColors.textSecondary),
            ),
          ),
        if (hasConflict)
          Icon(Icons.warning_amber_rounded, size: 14, color: SgpFieldColors.cautionOrange),
      ],
    );

    if (!hasChildren && node.summary == null && node.articles.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(8 + depth * 10.0, 6, 8, 6),
        child: titleRow,
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.fromLTRB(8 + depth * 10.0, 0, 8, 0),
        childrenPadding: EdgeInsets.fromLTRB(12 + depth * 10.0, 0, 8, 4),
        initiallyExpanded: initiallyExpanded,
        iconColor: SgpFieldColors.textSecondary,
        collapsedIconColor: SgpFieldColors.textSecondary,
        title: titleRow,
        children: [
          if (node.summary != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  node.summary!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: SgpFieldColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          if (node.articles.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                node.articles.join(' · '),
                style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.9)),
              ),
            ),
          if (hasChildren)
            Column(
              children: [
                for (final child in treeNode.children)
                  _HierarchyTreeTile(
                    treeNode: child,
                    depth: depth + 1,
                    conflictNodeIds: conflictNodeIds,
                    initiallyExpanded: child.node.level.value <= 3,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
