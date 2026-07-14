/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : KG-RAG Laws Loader (10 Judicial Domains)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// kgrag_laws.json → LawOntology 카탈로그 병합 (Flutter 비의존).
library;

import 'dart:convert';

import 'sgp_law_extractor.dart';

class KgragLawDomain {
  const KgragLawDomain({
    required this.id,
    required this.label,
    required this.probe,
  });

  final String id;
  final String label;
  final String probe;

  factory KgragLawDomain.fromJson(Map<String, dynamic> json) => KgragLawDomain(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        probe: json['probe'] as String? ?? '',
      );
}

class KgragLawsPack {
  const KgragLawsPack({
    required this.version,
    required this.domains,
    required this.nodes,
  });

  final String version;
  final List<KgragLawDomain> domains;
  final List<HierarchicalLawNode> nodes;

  factory KgragLawsPack.fromJson(Map<String, dynamic> json) {
    return KgragLawsPack(
      version: json['version'] as String? ?? '',
      domains: (json['domains'] as List<dynamic>? ?? const [])
          .map((e) => KgragLawDomain.fromJson(e as Map<String, dynamic>))
          .toList(),
      nodes: (json['nodes'] as List<dynamic>? ?? const [])
          .map((e) => HierarchicalLawNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static KgragLawsPack parse(String raw) =>
      KgragLawsPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

abstract final class SgpKgragLawsLoader {
  static const assetPath = 'assets/data/kgrag_laws.json';

  /// 팩을 LawOntology에 병합하고 도메인 프로브로 수직 추출 검증.
  static Map<String, HierarchicalLawSet> verifyDomainIntegrity(
    KgragLawsPack pack,
  ) {
    LawOntology.registerExternalCatalog(pack.nodes);
    final out = <String, HierarchicalLawSet>{};
    for (final d in pack.domains) {
      out[d.id] = SgpLawExtractor.extract(d.probe);
    }
    return out;
  }
}
