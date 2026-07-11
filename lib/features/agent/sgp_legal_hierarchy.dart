/// 8단계 법적 위계(LV 1~8) — Parent_ID 트리·필터·양자 매칭 엔진 (Sprint S1).
library;

import 'dart:convert';

// ---------------------------------------------------------------------------
// LV 1~8 층위
// ---------------------------------------------------------------------------

enum LegalHierarchyLevel {
  constitution(1, '헌법'),
  law(2, '법률'),
  presidentialDecree(3, '대통령령'),
  ministerialRule(4, '총리령·부령'),
  localOrdinance(5, '조례'),
  administrativeRule(6, '규칙'),
  internalRegulation(7, '내부 규정'),
  manual(8, '매뉴얼');

  const LegalHierarchyLevel(this.value, this.label);

  final int value;
  final String label;

  static LegalHierarchyLevel fromInt(int v) => LegalHierarchyLevel.values.firstWhere(
        (e) => e.value == v,
        orElse: () => LegalHierarchyLevel.law,
      );
}

// ---------------------------------------------------------------------------
// 노드 · 컨텍스트 · 충돌 · 해석 결과
// ---------------------------------------------------------------------------

/// 법령 위계 그래프의 단일 노드.
class LegalHierarchyNode {
  const LegalHierarchyNode({
    required this.id,
    required this.level,
    required this.title,
    this.parentId,
    this.scope = const {},
    this.filterKeys = const [],
    this.domainTags = const [],
    this.articles = const [],
    this.summary,
    this.conflictCheck = false,
  });

  final String id;
  final LegalHierarchyLevel level;
  final String title;
  final String? parentId;
  final Map<String, String> scope;
  final List<String> filterKeys;
  final List<String> domainTags;
  final List<String> articles;
  final String? summary;

  /// true면 상위법(LV 1~4)과 충돌 시 ⚠️ 경고 대상.
  final bool conflictCheck;

  factory LegalHierarchyNode.fromJson(Map<String, dynamic> json) {
    return LegalHierarchyNode(
      id: json['id'] as String,
      level: LegalHierarchyLevel.fromInt(json['level'] as int),
      title: json['title'] as String,
      parentId: json['parent_id'] as String?,
      scope: (json['scope'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
      filterKeys: (json['filter_keys'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      domainTags: (json['domain_tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      articles: (json['articles'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      summary: json['summary'] as String?,
      conflictCheck: json['conflict_check'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level.value,
        'title': title,
        'parent_id': parentId,
        'scope': scope,
        'filter_keys': filterKeys,
        'domain_tags': domainTags,
        if (articles.isNotEmpty) 'articles': articles,
        if (summary != null) 'summary': summary,
        if (conflictCheck) 'conflict_check': true,
      };

  String get levelBadge => 'LV${level.value} ${level.label}';
}

/// 상·하위법 충돌 경고.
class HierarchyConflict {
  const HierarchyConflict({
    required this.lowerNodeId,
    required this.upperNodeId,
    required this.message,
  });

  final String lowerNodeId;
  final String upperNodeId;
  final String message;

  Map<String, dynamic> toJson() => {
        'lowerNodeId': lowerNodeId,
        'upperNodeId': upperNodeId,
        'message': message,
      };

  factory HierarchyConflict.fromJson(Map<String, dynamic> json) {
    return HierarchyConflict(
      lowerNodeId: json['lowerNodeId'] as String,
      upperNodeId: json['upperNodeId'] as String,
      message: json['message'] as String,
    );
  }
}

/// 필터링에 사용하는 환경 파라미터.
class LegalHierarchyContext {
  const LegalHierarchyContext({
    this.country = 'KR',
    this.localGovCode,
    this.orgId = 'KR-NPA',
    this.taskCategory = 'field_arrest',
    this.domainTags = const {},
  });

  final String country;
  final String? localGovCode;
  final String? orgId;
  final String? taskCategory;
  final Set<String> domainTags;

  /// SGP-Agent 현장 수사관 기본 컨텍스트.
  static const fieldPolice = LegalHierarchyContext(
    orgId: 'KR-NPA',
    taskCategory: 'field_arrest',
    domainTags: {'criminal', 'procedure'},
  );
}

/// 위계 해석 결과 — Top-Down 체인 + 충돌.
class SgpHierarchyResolution {
  const SgpHierarchyResolution({
    required this.chain,
    required this.conflicts,
    required this.primaryLawTitle,
    required this.hasUpperLawWarnings,
  });

  /// LV 1 → LV 8 순 정렬된 준거법 체인.
  final List<LegalHierarchyNode> chain;

  final List<HierarchyConflict> conflicts;
  final String? primaryLawTitle;
  final bool hasUpperLawWarnings;

  bool get isEmpty => chain.isEmpty;

  Map<String, dynamic> toJson() => {
        'chain': chain.map((n) => n.toJson()).toList(),
        'conflicts': conflicts.map((c) => c.toJson()).toList(),
        'primaryLawTitle': primaryLawTitle,
        'hasUpperLawWarnings': hasUpperLawWarnings,
      };

  factory SgpHierarchyResolution.fromJson(Map<String, dynamic> json) {
    return SgpHierarchyResolution(
      chain: (json['chain'] as List<dynamic>? ?? [])
          .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      conflicts: (json['conflicts'] as List<dynamic>? ?? [])
          .map((e) => HierarchyConflict.fromJson(e as Map<String, dynamic>))
          .toList(),
      primaryLawTitle: json['primaryLawTitle'] as String?,
      hasUpperLawWarnings: json['hasUpperLawWarnings'] as bool? ?? false,
    );
  }

  static const empty = SgpHierarchyResolution(
    chain: [],
    conflicts: [],
    primaryLawTitle: null,
    hasUpperLawWarnings: false,
  );
}

// ---------------------------------------------------------------------------
// 레지스트리 — JSON 로드 · Parent_ID 인덱스
// ---------------------------------------------------------------------------

class SgpLegalHierarchyRegistry {
  SgpLegalHierarchyRegistry._();

  static final SgpLegalHierarchyRegistry instance = SgpLegalHierarchyRegistry._();

  static const assetPath = 'assets/data/legal_hierarchy_seed.json';

  final Map<String, LegalHierarchyNode> _byId = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<LegalHierarchyNode> get allNodes => _byId.values.toList();

  LegalHierarchyNode? nodeById(String id) => _byId[id];

  Future<void> initialize({required Future<String> Function() loadAsset}) async {
    if (_loaded) return;
    loadFromJson(await loadAsset());
  }

  void loadFromJson(String source) {
    _byId.clear();
    final list = jsonDecode(source) as List<dynamic>;
    for (final item in list) {
      final node = LegalHierarchyNode.fromJson(item as Map<String, dynamic>);
      _byId[node.id] = node;
    }
    _validateNoCycles();
    _loaded = true;
  }

  void _validateNoCycles() {
    for (final id in _byId.keys) {
      final seen = <String>{};
      var current = id;
      while (true) {
        if (!seen.add(current)) {
          throw StateError('Legal hierarchy cycle detected at $current');
        }
        final parent = _byId[current]?.parentId;
        if (parent == null) break;
        current = parent;
      }
    }
  }

  /// parent_id를 따라 LV 1까지 상향 체인.
  List<LegalHierarchyNode> ancestorsOf(String nodeId) {
    final chain = <LegalHierarchyNode>[];
    var current = _byId[nodeId];
    final visited = <String>{};
    while (current != null) {
      if (!visited.add(current.id)) break;
      chain.add(current);
      final pid = current.parentId;
      if (pid == null) break;
      current = _byId[pid];
    }
    return chain.reversed.toList();
  }
}

// ---------------------------------------------------------------------------
// 필터 · 해석 엔진
// ---------------------------------------------------------------------------

abstract final class SgpLegalHierarchyEngine {
  static const _anchorByDomain = <String, List<String>>{
    'animal': ['KR-LAW-ANIMAL', 'KR-LAW-CRIMINAL'],
    'domestic_violence': ['KR-LAW-DV', 'KR-LAW-CRIMINAL'],
    'traffic': ['KR-LAW-TRAFFIC'],
    'procedure': ['KR-LAW-CRIM-PROC'],
    'evidence': ['KR-LAW-POLICE-DUTY'],
    'criminal': ['KR-LAW-CRIMINAL', 'KR-LAW-CRIM-PROC'],
  };

  /// 사건 유형·체크리스트·텍스트로 앵커 노드 ID 목록 추론.
  static Set<String> inferAnchorIds({
    required Set<String> domainTags,
    required bool includeProcedure,
    required bool includeEvidence,
    required bool includeOrgManual,
  }) {
    final anchors = <String>{};
    for (final tag in domainTags) {
      for (final id in _anchorByDomain[tag] ?? const []) {
        anchors.add(id);
      }
    }
    if (anchors.isEmpty) {
      anchors.addAll(_anchorByDomain['criminal']!);
    }
    if (includeProcedure) {
      anchors.add('KR-LAW-CRIM-PROC');
    }
    if (includeEvidence) {
      anchors.add('KR-LAW-POLICE-DUTY');
    }
    if (includeOrgManual) {
      anchors.add('ORG-NPA-INVEST-RULE');
      anchors.add('MANUAL-SGP-FIELD-001');
    }
    return anchors;
  }

  /// 환경 컨텍스트 + 앵커 노드 → 위계 체인·충돌 해석.
  static SgpHierarchyResolution resolve({
    required LegalHierarchyContext context,
    required Set<String> anchorNodeIds,
  }) {
    final registry = SgpLegalHierarchyRegistry.instance;
    if (!registry.isLoaded || anchorNodeIds.isEmpty) {
      return SgpHierarchyResolution.empty;
    }

    final merged = <String, LegalHierarchyNode>{};

    void absorbChain(String startId) {
      for (final node in registry.ancestorsOf(startId)) {
        if (_matchesContext(node, context)) {
          merged[node.id] = node;
        }
      }
    }

    for (final id in anchorNodeIds) {
      if (registry.nodeById(id) != null) {
        absorbChain(id);
      }
    }

    for (final node in registry.allNodes) {
      if (node.level.value >= 7 && _matchesContext(node, context)) {
        merged[node.id] = node;
        for (final ancestor in registry.ancestorsOf(node.id)) {
          merged[ancestor.id] = ancestor;
        }
      }
    }

    final chain = merged.values.toList()
      ..sort((a, b) => a.level.value.compareTo(b.level.value));

    final conflicts = _detectConflicts(chain, registry);
    final primaryLaw = chain.where((n) => n.level == LegalHierarchyLevel.law).firstOrNull;

    return SgpHierarchyResolution(
      chain: chain,
      conflicts: conflicts,
      primaryLawTitle: primaryLaw?.title,
      hasUpperLawWarnings: conflicts.isNotEmpty,
    );
  }

  static bool _matchesContext(LegalHierarchyNode node, LegalHierarchyContext ctx) {
    final scope = node.scope;
    if (scope['country'] != null && scope['country'] != ctx.country) {
      return false;
    }
    if (node.level.value >= 5) {
      final loc = scope['local_gov_code'];
      if (loc != null && loc != ctx.localGovCode) return false;
    }
    if (node.level.value >= 7) {
      final org = scope['org_id'];
      if (org != null && org != ctx.orgId) return false;
    }
    if (node.level.value >= 8) {
      final task = scope['task_category'];
      if (task != null && task != ctx.taskCategory) return false;
    }
    if (node.domainTags.contains('all')) return true;
    if (ctx.domainTags.isEmpty) return true;
    return node.domainTags.any(ctx.domainTags.contains);
  }

  static List<HierarchyConflict> _detectConflicts(
    List<LegalHierarchyNode> chain,
    SgpLegalHierarchyRegistry registry,
  ) {
    final conflicts = <HierarchyConflict>[];
    final chainIds = chain.map((n) => n.id).toSet();
    final upperLaws = chain.where((n) => n.level.value <= 4).toList();

    for (final node in chain) {
      if (!node.conflictCheck || node.level.value < 7) continue;

      LegalHierarchyNode? nearestUpper;
      for (final ancestor in registry.ancestorsOf(node.id)) {
        if (ancestor.level.value <= 4 && chainIds.contains(ancestor.id)) {
          nearestUpper = ancestor;
          break;
        }
      }
      nearestUpper ??= upperLaws.isNotEmpty ? upperLaws.first : null;

      if (nearestUpper != null) {
        conflicts.add(
          HierarchyConflict(
            lowerNodeId: node.id,
            upperNodeId: nearestUpper.id,
            message:
                '「${node.title}」(LV${node.level.value})은 '
                '상위 「${nearestUpper.title}」(LV${nearestUpper.level.value})에 '
                '저촉될 수 없습니다. 상위법 기준 가이드를 우선 적용하십시오.',
          ),
        );
      }
    }
    return conflicts;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

/// IncidentType → domain_tags (양자 엔진 연동용).
Set<String> domainTagsForIncidentKey(String incidentJsonKey) {
  return switch (incidentJsonKey) {
    'dog_bite_incident' => {'animal', 'criminal', 'special'},
    'domestic_violence' => {'domestic_violence', 'criminal', 'special', 'procedure'},
    'stalking' => {'criminal', 'special', 'procedure'},
    'mutual_combat' => {'criminal', 'procedure'},
    'traffic_incident' => {'traffic', 'criminal'},
    'road_occupancy' => {'criminal', 'procedure'},
    'civil_dispute' => {'criminal', 'procedure'},
    _ => {'criminal', 'procedure'},
  };
}
