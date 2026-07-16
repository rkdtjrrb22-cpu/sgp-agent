/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Stage 5 — Hierarchical Law Extractor (SgpLawExtractor)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 초연결형 다차원 법률 계층 자동 추출 — LV1→LV4 수직 백트래킹 (Flutter 비의존).
library;

import '../glymphatic/sgp_glymphatic_phagophore_filter.dart';

/// 법률 계층 레벨.
enum LawHierarchyLevel {
  constitution(1, '헌법적 한계'),
  basicCode(2, '기본 실체법'),
  specialStatute(3, '다차원 특별법'),
  executiveRule(4, '집행 규칙·가이드');

  const LawHierarchyLevel(this.number, this.label);
  final int number;
  final String label;
}

/// 온톨로지 노드 (조문·가이드·서식).
class HierarchicalLawNode {
  const HierarchicalLawNode({
    required this.id,
    required this.title,
    required this.level,
    this.article = '',
    this.body = '',
    this.keywords = const [],
    this.parentIds = const [],
  });

  final String id;
  final String title;
  final LawHierarchyLevel level;
  final String article;
  final String body;
  final List<String> keywords;
  final List<String> parentIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'level': level.name,
        'article': article,
        'body': body,
        'keywords': keywords,
        'parentIds': parentIds,
      };

  factory HierarchicalLawNode.fromJson(Map<String, dynamic> json) {
    final levelName = json['level'] as String? ?? 'executiveRule';
    final level = LawHierarchyLevel.values.firstWhere(
      (l) => l.name == levelName,
      orElse: () => LawHierarchyLevel.executiveRule,
    );
    return HierarchicalLawNode(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      level: level,
      article: json['article'] as String? ?? '',
      body: json['body'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      parentIds: (json['parentIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// LV1~LV4 수직 통합 추출 결과.
class HierarchicalLawSet {
  const HierarchicalLawSet({
    required this.constitution,
    required this.basicCode,
    required this.specialStatute,
    required this.executiveRule,
    this.cleanedContext = '',
    this.sourceText = '',
  });

  final List<HierarchicalLawNode> constitution;
  final List<HierarchicalLawNode> basicCode;
  final List<HierarchicalLawNode> specialStatute;
  final List<HierarchicalLawNode> executiveRule;
  final String cleanedContext;
  final String sourceText;

  bool get isEmpty =>
      constitution.isEmpty &&
      basicCode.isEmpty &&
      specialStatute.isEmpty &&
      executiveRule.isEmpty;

  List<HierarchicalLawNode> get allNodes => [
        ...constitution,
        ...basicCode,
        ...specialStatute,
        ...executiveRule,
      ];

  Map<String, dynamic> toJson() => {
        'cleanedContext': cleanedContext,
        'sourceText': sourceText,
        'constitution': constitution.map((e) => e.toJson()).toList(),
        'basicCode': basicCode.map((e) => e.toJson()).toList(),
        'specialStatute': specialStatute.map((e) => e.toJson()).toList(),
        'executiveRule': executiveRule.map((e) => e.toJson()).toList(),
      };

  factory HierarchicalLawSet.fromJson(Map<String, dynamic> json) =>
      HierarchicalLawSet(
        cleanedContext: json['cleanedContext'] as String? ?? '',
        sourceText: json['sourceText'] as String? ?? '',
        constitution: _nodes(json['constitution']),
        basicCode: _nodes(json['basicCode']),
        specialStatute: _nodes(json['specialStatute']),
        executiveRule: _nodes(json['executiveRule']),
      );

  static List<HierarchicalLawNode> _nodes(Object? raw) =>
      (raw as List<dynamic>? ?? const [])
          .map((e) => HierarchicalLawNode.fromJson(e as Map<String, dynamic>))
          .toList();

  /// 보고서·UI용 마크다운 요약.
  String toMarkdownSummary() {
    final buf = StringBuffer()..writeln('# 계층형 법률 추출 결과');
    void section(String title, List<HierarchicalLawNode> nodes) {
      buf.writeln();
      buf.writeln('## $title');
      if (nodes.isEmpty) {
        buf.writeln('- (매칭 없음)');
        return;
      }
      for (final n in nodes) {
        buf.writeln(
          '- **${n.title}**'
          '${n.article.isNotEmpty ? " (${n.article})" : ""}'
          '${n.body.isNotEmpty ? " — ${n.body}" : ""}',
        );
      }
    }

    section('LV1 헌법적 한계', constitution);
    section('LV2 기본 실체법', basicCode);
    section('LV3 다차원 특별법', specialStatute);
    section('LV4 집행 규칙·가이드', executiveRule);
    return buf.toString().trim();
  }
}

/// Lysosome 런타임 — 다단 온톨로지 트리 백트래킹·노드 융해.
abstract final class LawOntology {
  static List<HierarchicalLawNode> _lv1 = List.of(_lv1Seed);
  static List<HierarchicalLawNode> _lv2 = List.of(_lv2Seed);
  static List<HierarchicalLawNode> _lv3 = List.of(_lv3Seed);
  static List<HierarchicalLawNode> _lv4 = List.of(_lv4Seed);

  /// kgrag_laws.json 등 외부 시드를 병합 (동일 id는 덮어씀).
  static void registerExternalCatalog(List<HierarchicalLawNode> nodes) {
    void merge(List<HierarchicalLawNode> target, HierarchicalLawNode n) {
      final i = target.indexWhere((e) => e.id == n.id);
      if (i >= 0) {
        target[i] = n;
      } else {
        target.add(n);
      }
    }

    for (final n in nodes) {
      switch (n.level) {
        case LawHierarchyLevel.constitution:
          merge(_lv1, n);
        case LawHierarchyLevel.basicCode:
          merge(_lv2, n);
        case LawHierarchyLevel.specialStatute:
          merge(_lv3, n);
        case LawHierarchyLevel.executiveRule:
          merge(_lv4, n);
      }
    }
  }

  static void resetToSeed() {
    _lv1 = List.of(_lv1Seed);
    _lv2 = List.of(_lv2Seed);
    _lv3 = List.of(_lv3Seed);
    _lv4 = List.of(_lv4Seed);
  }

  /// LV4 현장 가이드·별표서식 매칭.
  static List<HierarchicalLawNode> findMatchingLevel4(String cleanedContext) {
    return _match(_lv4, cleanedContext);
  }

  /// LV3 특별법 직접 매칭 (키워드 프로브).
  static List<HierarchicalLawNode> findMatchingLevel3(String cleanedContext) {
    return _match(_lv3, cleanedContext);
  }

  /// LV4 → LV3 특별법.
  static List<HierarchicalLawNode> resolveSpecialStatutes(
    List<HierarchicalLawNode> lv4Rules,
  ) {
    return _resolveParents(lv4Rules, _lv3);
  }

  /// LV3 → LV2 형법·형소법.
  static List<HierarchicalLawNode> resolveBasicCodes(
    List<HierarchicalLawNode> lv3Statutes,
  ) {
    return _resolveParents(lv3Statutes, _lv2);
  }

  static bool _hasForceSignal = false;

  static void noteForceContext(bool value) => _hasForceSignal = value;

  /// LV2 → LV1 헌법 통제.
  ///
  /// 물리력·체포 신호가 있으면 과잉금지(제37조 제2항)를 LV1 선두에 고정한다.
  static List<HierarchicalLawNode> applyConstitutionalLimits(
    List<HierarchicalLawNode> lv2BasicCodes,
  ) {
    final fromParents = _resolveParents(lv2BasicCodes, _lv1);
    final base = fromParents.isNotEmpty
        ? List<HierarchicalLawNode>.from(fromParents)
        : List<HierarchicalLawNode>.from(_lv1);

    if (!_hasForceSignal) return base;

    HierarchicalLawNode? excessBan;
    for (final n in _lv1) {
      if (n.id == 'KR-CONST-037-2') {
        excessBan = n;
        break;
      }
    }
    if (excessBan == null) return base;

    final without = base.where((e) => e.id != excessBan!.id).toList();
    return [excessBan, ...without];
  }

  static List<HierarchicalLawNode> _match(
    List<HierarchicalLawNode> catalog,
    String context,
  ) {
    final t = context.toLowerCase();
    final hits = <HierarchicalLawNode>[];
    for (final n in catalog) {
      final score = n.keywords.where((k) => t.contains(k.toLowerCase())).length;
      if (score > 0 ||
          t.contains(n.title.toLowerCase()) ||
          (n.article.isNotEmpty && t.contains(n.article.toLowerCase()))) {
        hits.add(n);
      }
    }
    return hits;
  }

  static List<HierarchicalLawNode> _resolveParents(
    List<HierarchicalLawNode> children,
    List<HierarchicalLawNode> parentCatalog,
  ) {
    if (children.isEmpty) return const [];
    final parentIds = <String>{};
    for (final c in children) {
      parentIds.addAll(c.parentIds);
    }
    final byId = {for (final p in parentCatalog) p.id: p};
    final out = <HierarchicalLawNode>[];
    for (final id in parentIds) {
      final p = byId[id];
      if (p != null) out.add(p);
    }
    // 키워드 교차 보강
    final ctx = children.map((c) => c.keywords.join(' ')).join(' ');
    for (final p in _match(parentCatalog, ctx)) {
      if (!out.any((e) => e.id == p.id)) out.add(p);
    }
    return out;
  }

  // —— 시드 카탈로그 (경찰 STT 시연용 최소 온톨로지) ——

  static const _lv1Seed = <HierarchicalLawNode>[
    HierarchicalLawNode(
      id: 'KR-CONST-012',
      title: '헌법 제12조',
      article: '제12조',
      level: LawHierarchyLevel.constitution,
      body: '영장주의·신체의 자유',
      keywords: ['영장', '체포', '구속', '신체의 자유'],
    ),
    HierarchicalLawNode(
      id: 'KR-CONST-037-2',
      title: '헌법 제37조 제2항',
      article: '제37조 제2항',
      level: LawHierarchyLevel.constitution,
      body: '과잉금지·최소침해',
      keywords: ['과잉금지', '물리력', '비례', '최소침해'],
    ),
  ];

  static const _lv2Seed = <HierarchicalLawNode>[
    HierarchicalLawNode(
      id: 'KR-CRIM-PUBLIC-INDECENCY',
      title: '형법 공연음란',
      article: '형법 제245조',
      level: LawHierarchyLevel.basicCode,
      body: '공연히 음란한 행위',
      keywords: ['음란', '알몸', '옷벗', '공연음란'],
      parentIds: ['KR-CONST-012', 'KR-CONST-037-2'],
    ),
    HierarchicalLawNode(
      id: 'KR-CRIM-ASSAULT',
      title: '형법 폭행',
      article: '형법 제260조',
      level: LawHierarchyLevel.basicCode,
      body: '사람의 신체에 대한 폭행',
      keywords: ['폭행', '때리', '밀치', '공격'],
      parentIds: ['KR-CONST-012', 'KR-CONST-037-2'],
    ),
    HierarchicalLawNode(
      id: 'KR-CRIM-PROC',
      title: '형사소송법',
      article: '현행범 체포 등',
      level: LawHierarchyLevel.basicCode,
      body: '수사·체포 절차',
      keywords: ['현행범', '체포', '압수', '수색'],
      parentIds: ['KR-CONST-012'],
    ),
  ];

  static const _lv3Seed = <HierarchicalLawNode>[
    HierarchicalLawNode(
      id: 'KR-MINOR-OFFENSE',
      title: '경범죄 처벌법',
      article: '술에 취한 방해 등',
      level: LawHierarchyLevel.specialStatute,
      body: '취중 소란·업무방해성 경미 위반',
      keywords: ['취중', '술취', '술 취한', '소란', '경범죄'],
      parentIds: ['KR-CRIM-PUBLIC-INDECENCY', 'KR-CRIM-PROC'],
    ),
    HierarchicalLawNode(
      id: 'KR-ROAD-TRAFFIC',
      title: '도로교통법',
      article: '음주운전·무면허 등',
      level: LawHierarchyLevel.specialStatute,
      body: '도로교통 특별법',
      keywords: ['음주운전', '무면허', '신호위반', '도로교통'],
      parentIds: ['KR-CRIM-PROC'],
    ),
    HierarchicalLawNode(
      id: 'KR-ANIMAL-PROTECT',
      title: '동물보호법',
      article: '맹견·목줄 등',
      level: LawHierarchyLevel.specialStatute,
      body: '반려견·맹견 관리',
      keywords: ['개물림', '목줄', '맹견', '동물보호'],
      parentIds: ['KR-CRIM-ASSAULT', 'KR-CRIM-PROC'],
    ),
    HierarchicalLawNode(
      id: 'KR-AVIATION-SAFE',
      title: '항공안전법',
      article: '드론 등',
      level: LawHierarchyLevel.specialStatute,
      body: '무인동력비행장치',
      keywords: ['드론', '비행', '항공'],
      parentIds: ['KR-CRIM-PROC'],
    ),
    HierarchicalLawNode(
      id: 'KR-EMS',
      title: '응급의료에 관한 법률',
      article: '응급실 등',
      level: LawHierarchyLevel.specialStatute,
      body: '응급의료 방해·이송',
      keywords: ['응급실', '응급의료', '소방', '구급'],
      parentIds: ['KR-CRIM-ASSAULT', 'KR-CRIM-PROC'],
    ),
  ];

  static const _lv4Seed = <HierarchicalLawNode>[
    HierarchicalLawNode(
      id: 'LV4-POLICE-DUTY',
      title: '경찰관 직무집행법',
      article: '제8조 등',
      level: LawHierarchyLevel.executiveRule,
      body: '위해방지·물리력·보호조치',
      keywords: ['물리력', '보호조치', '위해방지', '소란', '취중', '술'],
      parentIds: ['KR-MINOR-OFFENSE', 'KR-EMS'],
    ),
    HierarchicalLawNode(
      id: 'LV4-FORCE-MATRIX',
      title: '물리력 대응 가이드',
      article: '5단계 매트릭스',
      level: LawHierarchyLevel.executiveRule,
      body: '저항 단계별 허용 장구·기술',
      keywords: ['저항', '테이저', '제압', '물리력', '소란'],
      parentIds: ['KR-MINOR-OFFENSE'],
    ),
    HierarchicalLawNode(
      id: 'LV4-SUMMARY-TRIAL',
      title: '즉결심판 청구 서식군',
      article: '별표서식 123종',
      level: LawHierarchyLevel.executiveRule,
      body: '즉결심판·경미 사범 서식 조립',
      keywords: ['즉결', '경범죄', '소란', '취중', '술 취한'],
      parentIds: ['KR-MINOR-OFFENSE'],
    ),
    HierarchicalLawNode(
      id: 'LV4-EQUIPMENT',
      title: '장구 사용 기준',
      article: '경찰장구',
      level: LawHierarchyLevel.executiveRule,
      body: '전자충격기·분사기 등',
      keywords: ['테이저', '분사기', '수갑', '경찰봉'],
      parentIds: ['KR-CRIM-ASSAULT'],
    ),
  ];
}

/// 수직 통합 자동 조문 추출 파이프라인.
abstract final class SgpLawExtractor {
  /// 무전 STT·타자 텍스트 → LV1~LV4 HierarchicalLawSet.
  static HierarchicalLawSet extract(String textInput) {
    // 1. Phagophore — 노이즈 제거·키워드/SPO 임베딩 추출
    final cleanedContext =
        PhagophoreFilter.pruneUnlinkedFragments(textInput);

    final forceish = RegExp(r'(물리력|저항|제압|테이저|체포|구속)').hasMatch(cleanedContext);
    LawOntology.noteForceContext(forceish);

    // 2. Lysosome — LV4 → LV3 → LV2 → LV1 백트래킹·노드 융해
    final lv4Rules = LawOntology.findMatchingLevel4(cleanedContext);
    final lv3Statutes = LawOntology.resolveSpecialStatutes(lv4Rules);
    final lv2BasicCodes = LawOntology.resolveBasicCodes(lv3Statutes);
    final lv1Constitution =
        LawOntology.applyConstitutionalLimits(lv2BasicCodes);

    // LV4 미매칭이어도 키워드로 LV3 직접 보강 (특수법 우선 포착)
    final directLv3 = _mergeById(
      _directMatchLevel3(cleanedContext),
      LawOntology.findMatchingLevel3(cleanedContext),
    );
    final mergedLv3 = _mergeById(lv3Statutes, directLv3);
    final lv2Boosted = _mergeById(
      lv2BasicCodes,
      LawOntology.resolveBasicCodes(mergedLv3),
    );
    final lv1Final = lv1Constitution.isNotEmpty
        ? lv1Constitution
        : LawOntology.applyConstitutionalLimits(lv2Boosted);

    return HierarchicalLawSet(
      constitution: lv1Final,
      basicCode: lv2Boosted,
      specialStatute: mergedLv3,
      executiveRule: lv4Rules.isNotEmpty
          ? lv4Rules
          : LawOntology.findMatchingLevel4(cleanedContext),
      cleanedContext: cleanedContext,
      sourceText: textInput,
    );
  }

  static List<HierarchicalLawNode> _directMatchLevel3(String ctx) {
    // resolveSpecialStatutes 경로 우회 — 텍스트에 특별법 키워드가 직접 있을 때
    return LawOntology.resolveSpecialStatutes(
      LawOntology.findMatchingLevel4(ctx),
    );
  }

  static List<HierarchicalLawNode> _mergeById(
    List<HierarchicalLawNode> a,
    List<HierarchicalLawNode> b,
  ) {
    final map = {for (final n in a) n.id: n};
    for (final n in b) {
      map[n.id] = n;
    }
    return map.values.toList();
  }
}
