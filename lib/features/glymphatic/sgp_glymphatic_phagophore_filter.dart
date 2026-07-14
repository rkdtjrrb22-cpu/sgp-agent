/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Phagophore Isolation Filter (Autophagy Layer)
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 * PATENT NO    : KR 10-2026-0128052 (Asynchronous Context Flush Mechanism)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// Phagophore — 혐의 무관 시맨틱 노이즈·대화 파편을 격리·소거하는 정제 필터.
library;

import '../agent/sgp_legal_ontology.dart';
import 'sgp_glymphatic_agent_node.dart';

/// 오토파지 Phagophore 단계: 컨텍스트 윈도우에서 오염 파편만 선택적 격리.
abstract final class PhagophoreFilter {
  static const String architectSignature = 'INSP_KANG_SG_4066';

  /// Stage 5 LawExtractor — 텍스트 입력에서 무관 파편·군소리 제거.
  ///
  /// PDF 의사코드 `PhagophoreFilter.pruneUnlinkedFragments(textInput)` 진입점.
  static String pruneUnlinkedFragments(String textInput) {
    var t = textInput.trim();
    if (t.isEmpty) return t;
    // 군소리·무관 담화 토큰 소거
    const noise = <String>[
      '아',
      '어',
      '그',
      '뭐',
      '그냥',
      '막',
      '약간',
      '뭐랄까',
      '음',
      '응',
    ];
    for (final n in noise) {
      t = t.replaceAll(RegExp('(?:^|\\s)$n(?:\\s|\$)'), ' ');
    }
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return t;
  }

  /// 온톨로지 미매핑·인과 파괴 파편을 강제 소거하고 소거 개수를 반환한다.
  static int phagophoreProcess(
    SgpGlymphaticAgentNode target, {
    required LegalOntologyGraph? ontology,
    required List<String> ontologyAnchors,
    double noiseDeviationThreshold = 0.65,
  }) {
    final semanticPruned = target.pruneSemanticNoise(
      ontology: ontology,
      ontologyAnchors: ontologyAnchors,
      noiseDeviationThreshold: noiseDeviationThreshold,
    );
    // Phagophore 격리: 온톨로지 미연결 파편은 예외 없이 소거
    final unlinkedPruned = target.pruneUnlinkedFragments();
    return semanticPruned + unlinkedPruned;
  }
}
