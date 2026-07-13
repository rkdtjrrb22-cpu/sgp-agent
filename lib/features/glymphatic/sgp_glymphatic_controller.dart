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
/// 글림파틱 핑퐁 트래픽 라우터 및 자가 치유 컨트롤러.
library;



import 'dart:async';



import '../agent/sgp_legal_ontology.dart';

import '../agent/sgp_legal_ontology_session.dart';

import 'sgp_glymphatic_agent_node.dart';

import 'sgp_glymphatic_flusher.dart';

import 'sgp_glymphatic_handshake.dart';

import 'sgp_glymphatic_innovation_engine.dart';

import 'sgp_glymphatic_monitor.dart';



/// 라우팅 결과 — 무중단 핸드오프 시 패킷 손실 방지용.

class GlymphaticRouteResult {

  const GlymphaticRouteResult({

    required this.nodeId,

    required this.accepted,

    required this.failoverOccurred,

    this.redirectedFrom,

  });



  final String nodeId;

  final bool accepted;

  final bool failoverOccurred;

  final String? redirectedFrom;

}



/// 핑퐁 스위칭 이벤트 로그.

class GlymphaticHealEvent {

  const GlymphaticHealEvent({

    required this.timestamp,

    required this.triggers,

    required this.previousActiveId,

    required this.newActiveId,

    required this.handshake,

    required this.flushReport,

  });



  final DateTime timestamp;

  final List<GlymphaticTrigger> triggers;

  final String previousActiveId;

  final String newActiveId;

  final GlymphaticHandshakeResult handshake;

  final GlymphaticFlushReport flushReport;



  bool get handshakeConfirmed => handshake.confirmed && handshake.isLossless;

}



/// SGP 듀얼 에이전트 매니저 (Main / Shadow).

class SgpGlymphaticController {

  SgpGlymphaticController({

    SgpGlymphaticAgentNode? mainAgent,

    SgpGlymphaticAgentNode? shadowAgent,

    LegalOntologyGraph? ontology,

    this.maxWindowTokens = 8192,

  })  : mainNode = mainAgent ?? SgpGlymphaticAgentNode(nodeId: 'main'),

        shadowNode = shadowAgent ?? SgpGlymphaticAgentNode(nodeId: 'shadow'),

        _ontology = ontology {

    mainNode.activate();

    shadowNode.markReadyForSwap();

    _active = mainNode;

    _shadow = shadowNode;

  }



  static const patentApplicationNo = '10-2026-0128052';
  static const architectSignature =
      SgpGlymphaticInnovationEngine.architectSignature;



  final SgpGlymphaticAgentNode mainNode;

  final SgpGlymphaticAgentNode shadowNode;

  final int maxWindowTokens;



  late SgpGlymphaticAgentNode _active;

  late SgpGlymphaticAgentNode _shadow;

  LegalOntologyGraph? _ontology;



  bool _isFlushing = false;

  bool _monitorRunning = false;

  Timer? _monitorTimer;

  DateTime _lastIngressAt = DateTime.now();

  int _queueIngressSinceIdle = 0;

  final List<String> _pendingTraffic = [];

  final List<GlymphaticHealEvent> healLog = [];

  GlymphaticHandshakeResult? _lastHandshake;



  SgpGlymphaticAgentNode get activeNode => _active;

  SgpGlymphaticAgentNode get shadowNodeRef => _shadow;

  SgpGlymphaticAgentNode get standbyNode => _shadow;

  bool get isFlushing => _isFlushing;

  bool get isReadyForSwap => _shadow.readyForSwap;

  int get pendingPacketCount => _pendingTraffic.length;

  GlymphaticHandshakeResult? get lastHandshake => _lastHandshake;



  void attachOntology(LegalOntologyGraph? graph) => _ontology = graph;



  List<String> _ontologyAnchors() {

    final graph = _ontology ?? SgpLegalOntologySession.instance.graph;

    if (graph == null || graph.nodes.isEmpty) {

      return const [

        '형사소송법',

        '정당방위',

        '현장 수사',

        '증거 보전',

        '체포 절차',

      ];

    }

    return graph.nodes

        .take(64)

        .map((n) => '${n.id} ${n.title}')

        .toList(growable: false);

  }



  /// 현장 데이터 유입 — 핑퐁 라우터 진입점.

  GlymphaticRouteResult routeTraffic(String payload) {

    _lastIngressAt = DateTime.now();

    _queueIngressSinceIdle++;



    if (_active.isThrottled && !_shadow.isThrottled) {

      _shadow.appendContext(payload);

      _pendingTraffic.add(payload);

      return GlymphaticRouteResult(

        nodeId: _shadow.nodeId,

        accepted: true,

        failoverOccurred: true,

        redirectedFrom: _active.nodeId,

      );

    }



    if (_active.isThrottled) {

      _pendingTraffic.add(payload);

      return GlymphaticRouteResult(

        nodeId: _active.nodeId,

        accepted: false,

        failoverOccurred: false,

      );

    }



    _active.appendContext(payload);

    return GlymphaticRouteResult(

      nodeId: _active.nodeId,

      accepted: true,

      failoverOccurred: false,

    );

  }



  /// 추론 완료 후 메트릭 기록.

  void recordInference({

    required String nodeId,

    required String output,

    required double latencyMs,

  }) {

    final node = nodeId == _active.nodeId ? _active : _shadow;

    node.recordOutput(output);

    node.recordLatency(latencyMs);

  }



  GlymphaticMonitorSnapshot monitorOnce({Duration? idleOverride}) {

    final idle = idleOverride ??

        DateTime.now().difference(_lastIngressAt);

    final ingress = _queueIngressSinceIdle;

    return SgpGlymphaticMonitor.evaluate(

      node: _active,

      ontologyAnchors: _ontologyAnchors(),

      idleDuration: idle,

      queueIngressCount: ingress,

    );

  }



  Future<void> startMonitorLoop({Duration? interval}) async {

    if (_monitorRunning) return;

    _monitorRunning = true;

    _monitorTimer?.cancel();

    _monitorTimer = Timer.periodic(

      interval ?? SgpGlymphaticMonitor.monitorInterval,

      (_) => unawaited(_onMonitorTick()),

    );

  }



  void stopMonitorLoop() {

    _monitorRunning = false;

    _monitorTimer?.cancel();

    _monitorTimer = null;

  }



  Future<void> _onMonitorTick() async {

    final snapshot = monitorOnce();

    if (snapshot.shouldHeal) {

      await triggerSelfHealing(triggers: snapshot.triggers);

    }

  }



  /// 핑퐁 스왑 + 핸드셰이킹 — Shadow가 Active 컨텍스트·온톨로지 세션을 즉시 이어받는다.

  GlymphaticHandshakeResult _performPingPongHandshaking() {

    final previousActive = _active;

    previousActive.throttle();



    final pending = List<String>.from(_pendingTraffic);

    final handshake = _shadow.handoverFrom(

      previousActive,

      pendingPackets: pending,

    );

    _pendingTraffic.clear();

    _lastHandshake = handshake;



    final oldActive = _active;

    _active = _shadow;

    _shadow = oldActive;



    return handshake;

  }



  /// 트리거 접수 시 핑퐁 Failover + 백그라운드 정화.

  Future<GlymphaticHealEvent?> triggerSelfHealing({

    List<GlymphaticTrigger>? triggers,

  }) async {

    if (_isFlushing) return null;

    _isFlushing = true;



    final previousActiveId = _active.nodeId;

    final handshake = _performPingPongHandshaking();

    if (!handshake.confirmed) {

      _isFlushing = false;

      return null;

    }



    final flushTarget = _shadow;

    final flushReport = await SgpGlymphaticFlusher.flushContextByOntology(

      target: flushTarget,

      ontology: _ontology ?? SgpLegalOntologySession.instance.graph,

      ontologyAnchors: _ontologyAnchors(),

    );



    final event = GlymphaticHealEvent(

      timestamp: DateTime.now(),

      triggers: triggers ??

          const [GlymphaticTrigger.semanticPollution],

      previousActiveId: previousActiveId,

      newActiveId: _active.nodeId,

      handshake: handshake,

      flushReport: flushReport,

    );

    healLog.add(event);



    _queueIngressSinceIdle = 0;

    _isFlushing = false;

    return event;

  }



  void dispose() {

    stopMonitorLoop();

  }

}



/// 전역 글림파틱 세션.

abstract final class SgpGlymphaticSession {

  static SgpGlymphaticController? _controller;



  static SgpGlymphaticController get instance =>

      _controller ??= SgpGlymphaticController();



  static void replace(SgpGlymphaticController controller) =>

      _controller = controller;



  static void reset() {

    _controller?.dispose();

    _controller = null;

  }

}

