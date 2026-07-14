/**
 * ============================================================================
 * PROJECT      : Smart Green Policing Platform (SGP-Agent)
 * MODULE       : Glymphatic Self-Healing Context Purification Engine
 * ARCHITECT    : Inspector KANG, S.G. (41st Riot Police Squadron, KNPA)
 *              : [20-Year Veteran Public Order & Security Operations Commander]
 * PATENT NO    : KR 10-2026-0128052 (Asynchronous Context Flush Mechanism)
 * COPYRIGHT    : Copyright 2026. KANG S.G. & SGP Project Team. All Rights Reserved.
 * SIGNATURE    : 4066 (Eternal Guardian)
 * ============================================================================
 */
/// 백그라운드 시맨틱 정화 엔진 — 인공 수면 모드 Context Flush.
library;



import 'dart:async';

import 'dart:isolate';



import '../agent/sgp_legal_ontology.dart';

import 'sgp_glymphatic_agent_node.dart';

import 'sgp_glymphatic_handshake.dart';
import 'sgp_glymphatic_innovation_engine.dart';
import 'sgp_glymphatic_monitor.dart';
import 'sgp_glymphatic_phagophore_filter.dart';



class GlymphaticFlushReport {

  const GlymphaticFlushReport({

    required this.prunedFragments,

    required this.cacheOptimized,

    required this.recoveredOntologyAlignment,

    required this.success,

    this.readyForSwap = false,

    this.readyState,

    this.errorMessage,

    this.nutrientEdgesInjected = 0,

  });



  final int prunedFragments;

  final bool cacheOptimized;

  final double recoveredOntologyAlignment;

  final bool success;

  final bool readyForSwap;

  final GlymphaticReadyStateReport? readyState;

  final String? errorMessage;

  final int nutrientEdgesInjected;

}



/// Isolate 전달용 파편 DTO.

class _GlymphaticFragmentDto {

  const _GlymphaticFragmentDto({

    required this.token,

    this.ontologyNodeId,

    required this.causalScore,

  });



  final String token;

  final String? ontologyNodeId;

  final double causalScore;



  Map<String, dynamic> toJson() => {

        'token': token,

        'ontologyNodeId': ontologyNodeId,

        'causalScore': causalScore,

      };



  factory _GlymphaticFragmentDto.fromJson(Map<String, dynamic> json) =>

      _GlymphaticFragmentDto(

        token: json['token'] as String,

        ontologyNodeId: json['ontologyNodeId'] as String?,

        causalScore: (json['causalScore'] as num?)?.toDouble() ?? 1.0,

      );

}



/// Isolate 내 노이즈 분류 결과.

class _GlymphaticPrunePlan {

  const _GlymphaticPrunePlan({

    required this.tokensToRemove,

    required this.inferredLinks,

  });



  final List<String> tokensToRemove;

  final Map<String, String> inferredLinks;

}



abstract final class SgpGlymphaticFlusher {

  /// 특허 1·2호 Minor Flush — 오버레이 없이 Phagophore 미세 정제만 수행.
  static Future<GlymphaticFlushReport> minorFlush({
    required SgpGlymphaticAgentNode target,
    required LegalOntologyGraph? ontology,
    required List<String> ontologyAnchors,
  }) async {
    try {
      if (ontology != null) {
        target.inferOntologyLinks(ontology);
      }
      final pruned = PhagophoreFilter.phagophoreProcess(
        target,
        ontology: ontology,
        ontologyAnchors: ontologyAnchors,
      );
      target.optimizeMemoryCache();
      final alignment = target.semanticDeviation(ontologyAnchors);
      return GlymphaticFlushReport(
        prunedFragments: pruned,
        cacheOptimized: true,
        recoveredOntologyAlignment: (1.0 - alignment).clamp(0.0, 1.0),
        success: true,
        readyForSwap: target.readyForSwap,
      );
    } catch (e) {
      return GlymphaticFlushReport(
        prunedFragments: 0,
        cacheOptimized: false,
        recoveredOntologyAlignment: 0,
        success: false,
        readyForSwap: target.readyForSwap,
        errorMessage: e.toString(),
      );
    }
  }

  /// 온톨로지 기준 미연결·인과 파괴 파편 소거 + 핵심 가중치 Pruning.

  ///

  /// CPU 집약 분류는 [Isolate.run]으로 분리하고, 노드 상태 갱신은 메인 Isolate에서 수행한다.

  static Future<GlymphaticFlushReport> flushContextByOntology({

    required SgpGlymphaticAgentNode target,

    required LegalOntologyGraph? ontology,

    required List<String> ontologyAnchors,

  }) async {

    return Future(() async {

      try {

        target.enterSleepMode();

        target.enterFlushing();



        await Future<void>.delayed(Duration.zero);



        if (ontology != null) {

          target.inferOntologyLinks(ontology);

        }



        final plan = await _buildPrunePlanInBackground(

          fragments: target.fragments

              .map(

                (f) => _GlymphaticFragmentDto(

                  token: f.token,

                  ontologyNodeId: f.ontologyNodeId,

                  causalScore: f.causalScore,

                ),

              )

              .toList(growable: false),

          ontology: ontology,

          ontologyAnchors: ontologyAnchors,

        );



        final prunedByPlan = _applyPrunePlan(target, plan);

        final prunedNoise = PhagophoreFilter.phagophoreProcess(
          target,
          ontology: ontology,
          ontologyAnchors: ontologyAnchors,
        );

        target.optimizeMemoryCache();

        _finalizeCleanProbe(target, ontologyAnchors);

        final nutrientEdges = KnowledgeGraphNutrientIsolate.backInjectSurvivors(
          survivors: target.fragments,
        );

        final alignment = target.semanticDeviation(ontologyAnchors);
        target.markClean();



        final readyReport = GlymphaticReadyStateReport(

          nodeId: target.nodeId,

          isClean: true,

          readyForSwap: true,

          retainedFragments: target.fragments.length,

          prunedNoiseFragments: prunedByPlan + prunedNoise,

        );

        target.markReadyForSwap();



        return GlymphaticFlushReport(

          prunedFragments: prunedByPlan + prunedNoise,

          cacheOptimized: true,

          recoveredOntologyAlignment: (1.0 - alignment).clamp(0.0, 1.0),

          success: true,

          readyForSwap: target.readyForSwap,

          readyState: readyReport,

          nutrientEdgesInjected: nutrientEdges,

        );

      } catch (e) {

        target.markReadyForSwap();

        return GlymphaticFlushReport(

          prunedFragments: 0,

          cacheOptimized: false,

          recoveredOntologyAlignment: 0,

          success: false,

          readyForSwap: target.readyForSwap,

          errorMessage: e.toString(),

        );

      }

    });

  }



  static Future<_GlymphaticPrunePlan> _buildPrunePlanInBackground({

    required List<_GlymphaticFragmentDto> fragments,

    required LegalOntologyGraph? ontology,

    required List<String> ontologyAnchors,

  }) async {

    final payload = <String, dynamic>{

      'fragments': fragments.map((f) => f.toJson()).toList(),

      'ontologyIds': ontology?.nodes.map((n) => n.id).toList() ?? const <String>[],

      'ontologyTitles': {

        for (final n in ontology?.nodes ?? const [])

          n.id: n.title,

      },

      'anchors': ontologyAnchors,

    };



    final result = await Isolate.run(() => _classifyNoiseInIsolate(payload));

    return _GlymphaticPrunePlan(

      tokensToRemove: List<String>.from(result['tokensToRemove'] as List),

      inferredLinks: Map<String, String>.from(

        (result['inferredLinks'] as Map).map(

          (k, v) => MapEntry(k as String, v as String),

        ),

      ),

    );

  }



  static Map<String, dynamic> _classifyNoiseInIsolate(Map<String, dynamic> payload) {

    final fragments = (payload['fragments'] as List)

        .cast<Map<String, dynamic>>()

        .map(_GlymphaticFragmentDto.fromJson)

        .toList();

    final ontologyIds = Set<String>.from(payload['ontologyIds'] as List);

    final ontologyTitles = Map<String, String>.from(

      (payload['ontologyTitles'] as Map).map(

        (k, v) => MapEntry(k as String, v as String),

      ),

    );

    final anchors = (payload['anchors'] as List).cast<String>();

    final anchorBlob = anchors.join(' ').toLowerCase();



    final tokensToRemove = <String>[];

    final inferredLinks = <String, String>{};



    for (final fragment in fragments) {

      var nodeId = fragment.ontologyNodeId;

      if (nodeId == null || nodeId.isEmpty) {

        final lower = fragment.token.toLowerCase();

        for (final entry in ontologyTitles.entries) {

          if (lower.contains(entry.key.toLowerCase()) ||

              lower.contains(entry.value.toLowerCase())) {

            nodeId = entry.key;

            inferredLinks[fragment.token] = entry.key;

            break;

          }

        }

      }



      final linked = nodeId != null &&

          (ontologyIds.isEmpty || ontologyIds.contains(nodeId));

      if (linked) continue;



      if (fragment.causalScore < 0.35) {

        tokensToRemove.add(fragment.token);

        continue;

      }



      if (anchors.isEmpty) {

        tokensToRemove.add(fragment.token);

        continue;

      }



      final tokens = fragment.token

          .toLowerCase()

          .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))

          .where((t) => t.length >= 2);

      var overlap = 0;

      var count = 0;

      for (final token in tokens) {

        count++;

        if (anchorBlob.contains(token)) overlap++;

      }

      final lexicalDistance =

          count == 0 ? 1.0 : 1.0 - (overlap / count);

      if (lexicalDistance > 0.65) {

        tokensToRemove.add(fragment.token);

      }

    }



    return {

      'tokensToRemove': tokensToRemove,

      'inferredLinks': inferredLinks,

    };

  }



  static int _applyPrunePlan(
    SgpGlymphaticAgentNode target,
    _GlymphaticPrunePlan plan,
  ) {
    target.relinkFragments(plan.inferredLinks);
    return target.removeTokens(plan.tokensToRemove);
  }

  /// 정화 후 프로브 메트릭을 청정 상태(0 엔트로피·0% 포화)로 맞춘다.
  static void _finalizeCleanProbe(
    SgpGlymphaticAgentNode target,
    List<String> ontologyAnchors,
  ) {
    final linkedOnly = target.fragments.where((f) => f.isOntologyLinked).toList();
    if (linkedOnly.isEmpty) {
      target.clearContext();
      return;
    }

    final unlinked = target.fragments
        .where((fragment) => !fragment.isOntologyLinked)
        .map((fragment) => fragment.token);
    target.removeTokens(unlinked);

    final deviation = target.semanticDeviation(ontologyAnchors);
    if (deviation > SgpGlymphaticMonitor.semanticDeviationThreshold) {
      target.latestOutput = linkedOnly.last.token;
    }
  }
}

