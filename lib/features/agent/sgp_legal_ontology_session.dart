/// 로컬 온톨로지 세션 — Docker·법제처 API 없이 시드 기반 Triples 강제 로드.
library;

import 'sgp_civil_complaint_data.dart';
import 'sgp_civil_complaint_router.dart';
import 'sgp_legal_hierarchy.dart';
import 'sgp_legal_ontology.dart';

/// 앱·스텁 서버 공용 — legal_hierarchy 시드에서 SPO 그래프를 메모리에 유지.
class SgpLegalOntologySession {
  SgpLegalOntologySession._();

  static final SgpLegalOntologySession instance = SgpLegalOntologySession._();

  LegalOntologyGraph? _graph;
  String _source = 'uninitialized';
  CivilComplaintNodePack? _complaintPack;

  bool get isLoaded => _graph != null;

  LegalOntologyGraph? get graph => _graph;

  CivilComplaintNodePack? get complaintPack => _complaintPack;

  int get nodeCount => _graph?.nodes.length ?? 0;

  int get tripleCount => _graph?.triples.length ?? 0;

  int get glymphaticNutrientCount => _glymphaticNutrientTriples.length;

  List<LegalOntologyTriple> get glymphaticNutrientTriples =>
      List.unmodifiable(_glymphaticNutrientTriples);

  String get source => _source;

  final List<LegalOntologyTriple> _glymphaticNutrientTriples = [];

  /// [아이디어 C] 글림파틱 정화 생존 파편 → KG 엣지 Back-Injection 수용.
  void absorbGlymphaticNutrients(List<LegalOntologyTriple> triples) {
    _glymphaticNutrientTriples.addAll(triples);
  }

  /// 위계 레지스트리 로드 후 온톨로지 그래프·트리플 생성.
  void loadFromRegistry({SgpLegalHierarchyRegistry? registry}) {
    final reg = registry ?? SgpLegalHierarchyRegistry.instance;
    if (!reg.isLoaded) {
      _graph = null;
      _source = 'registry_not_loaded';
      return;
    }
    var graph = LegalOntologyMigrator.graphFromRegistry(reg);
    if (_complaintPack != null) {
      graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: graph,
        pack: _complaintPack!,
      );
    }
    _graph = graph;
    _source = _complaintPack == null
        ? 'legal_hierarchy_seed'
        : 'legal_hierarchy_seed+civil_complaint';
  }

  /// S7-D — 민원 노드 팩 병합 후 그래프 재구성.
  void attachCivilComplaintPack(CivilComplaintNodePack pack) {
    _complaintPack = pack;
    if (SgpLegalHierarchyRegistry.instance.isLoaded) {
      loadFromRegistry();
    }
  }

  /// 시드 JSON 문자열에서 직접 로드 (테스트·스텁 서버).
  void loadFromSeedJson(String seedJson, {CivilComplaintNodePack? complaintPack}) {
    if (complaintPack != null) {
      _complaintPack = complaintPack;
    }
    SgpLegalHierarchyRegistry.instance.loadFromJson(seedJson);
    loadFromRegistry();
    _source = _complaintPack == null ? 'seed_json' : 'seed_json+civil_complaint';
  }

  /// 현장 텍스트·체인 노드에 연결된 트리플 추출.
  List<LegalOntologyTriple> triplesForComparison(SgpHierarchyResolution? hierarchy) {
    if (_graph == null || hierarchy == null || hierarchy.isEmpty) return const [];
    return _graph!.triplesForChain(hierarchy.chain.map((n) => n.id).toList());
  }

  /// 지자체 코드·도메인 기준 서브그래프 (크로스 필터 시연용).
  LegalOntologySubgraph? subgraphForLocalGov({
    String rootId = 'KR-CONST-001',
    int maxDepth = 4,
  }) {
    return _graph?.subgraphFrom(rootSubjectId: rootId, maxDepth: maxDepth);
  }

  void reset() {
    _graph = null;
    _complaintPack = null;
    _glymphaticNutrientTriples.clear();
    _source = 'uninitialized';
  }
}
