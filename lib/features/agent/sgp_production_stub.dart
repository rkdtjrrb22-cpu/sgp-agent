/// Docker·법제처 API 없이 프로덕션 스택을 에뮬레이션하는 오프라인 스텁.
library;

import 'sgp_legal_compliance.dart';
import 'sgp_legal_hierarchy.dart';
import 'sgp_legal_ontology_session.dart';
import 'sgp_production_config.dart';
import 'sgp_quantum_legal_api.dart';
import 'sgp_quantum_legal_engine.dart';

export 'sgp_production_config.dart' show kLawSyncRequireLiveKey, kUseProductionStub;

abstract final class SgpProductionStub {
  /// 원격 resolve 대신 로컬 스텁 경로 사용 여부.
  static bool get isActive =>
      kUseProductionStub && !kEnableRemoteResolve;

  static String get modeLabel => isActive ? 'offline_stub' : 'remote_or_disabled';

  /// 온톨로지 세션·로컬 analyze 기반 resolve (서버/Docker 불필요).
  static QuantumLegalResolveResponse resolveLocal({
    required QuantumLegalResolveRequest request,
    required SgpQuantumLegalComparison Function() localAnalyze,
  }) {
    _ensureOntologyLoaded();

    final comparison = localAnalyze();
    return QuantumLegalResolveResponse.fromComparison(
      comparison,
      resolvedBy: 'local_stub',
      ontologyGraph: SgpLegalOntologySession.instance.graph,
    );
  }

  /// Cron/배치가 오프라인 스텁 모드인지.
  static bool get lawSyncUsesOfflineStub => !kLawSyncRequireLiveKey;

  static void _ensureOntologyLoaded() {
    final session = SgpLegalOntologySession.instance;
    if (!session.isLoaded && SgpLegalHierarchyRegistry.instance.isLoaded) {
      session.loadFromRegistry();
    }
  }
}
