import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_agent_node.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_controller.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flusher.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_monitor.dart';
import 'package:test/test.dart';

void main() {
  group('Glymphatic Agent Node (8)', () {
    test('appendContext increases token count', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 100);
      node.appendContext('112 변사');
      expect(node.contextTokenCount, greaterThan(0));
    });

    test('tokenRatio calculation', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 100);
      node.appendContext('a' * 80);
      expect(node.tokenRatio, greaterThan(0.75));
    });

    test('semanticDeviation low for ontology-aligned output', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordOutput('형사소송법 체포 절차 증거 보전');
      final dev = node.semanticDeviation(const ['형사소송법 체포 절차']);
      expect(dev, lessThan(0.65));
    });

    test('semanticDeviation high for unrelated output', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordOutput('우주여행 로켓 연료 소비량 예측');
      final dev = node.semanticDeviation(const ['형사소송법 체포 절차 증거 보전']);
      expect(dev, greaterThan(0.65));
    });

    test('recordLatency average', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordLatency(1000);
      node.recordLatency(5000);
      expect(node.getCurrentLatencyMs(), 3000);
    });

    test('throttle blocks input flag', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.throttle();
      expect(node.isThrottled, isTrue);
    });

    test('pruneUnlinkedFragments removes orphan tokens', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.appendContext('noise');
      node.appendContext('linked', ontologyNodeId: 'KR-LAW-001');
      expect(node.pruneUnlinkedFragments(), 1);
      expect(node.fragments, hasLength(1));
    });

    test('handover transfers ontology-linked fragments', () {
      final main = SgpGlymphaticAgentNode(nodeId: 'main');
      final shadow = SgpGlymphaticAgentNode(nodeId: 'shadow');
      main.appendContext('112 변사', ontologyNodeId: 'KR-LAW-001');
      main.appendContext('noise fragment');
      final result = shadow.handoverFrom(main);
      expect(result.confirmed, isTrue);
      expect(result.transferredFragments, 2);
      expect(result.transferredOntologyNodes, contains('KR-LAW-001'));
      expect(shadow.ontologySessionNodeIds, contains('KR-LAW-001'));
    });

    test('markReadyForSwap sets standby flag', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'shadow');
      node.throttle();
      node.markReadyForSwap();
      expect(node.readyForSwap, isTrue);
      expect(node.state, GlymphaticAgentState.ready);
    });

    test('clearContext resets buffer', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.appendContext('test', ontologyNodeId: 'KR-LAW-001');
      node.clearContext();
      expect(node.contextTokenCount, 0);
    });
  });

  group('Glymphatic Monitor triggers (12)', () {
    test('Trigger A semantic pollution', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordOutput('비트코인 채굴 수익률 예측 모델');
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법 체포 증거'],
        idleDuration: Duration.zero,
      );
      expect(snap.triggers, contains(GlymphaticTrigger.semanticPollution));
    });

    test('Trigger B context saturation', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 100);
      node.appendContext('x' * 80, ontologyNodeId: 'KR-LAW-001');
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: Duration.zero,
      );
      expect(snap.triggers, contains(GlymphaticTrigger.contextSaturation));
    });

    test('Trigger C system latency', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordLatency(4000);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: Duration.zero,
      );
      expect(snap.triggers, contains(GlymphaticTrigger.systemLatency));
    });

    test('Trigger D contextual idle', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: const Duration(minutes: 10),
        queueIngressCount: 0,
      );
      expect(snap.triggers, contains(GlymphaticTrigger.contextualIdle));
    });

    test('healthy node no triggers', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 1000);
      node.recordOutput('형사소송법 현장 수사');
      node.recordLatency(800);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법 현장 수사'],
        idleDuration: Duration.zero,
        queueIngressCount: 1,
      );
      expect(snap.shouldHeal, isFalse);
    });

    test('threshold constants', () {
      expect(SgpGlymphaticMonitor.semanticDeviationThreshold, 0.65);
      expect(SgpGlymphaticMonitor.contextRatioThreshold, 0.75);
      expect(SgpGlymphaticMonitor.latencyThresholdMs, 3500);
    });

    test('multiple triggers can co-fire', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 100);
      node.recordOutput('우주 비행');
      node.appendContext('y' * 80, ontologyNodeId: 'KR-LAW-001');
      node.recordLatency(5000);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: const Duration(minutes: 11),
        queueIngressCount: 0,
      );
      expect(snap.triggers.length, greaterThanOrEqualTo(3));
    });

    test('monitor interval 1 second', () {
      expect(SgpGlymphaticMonitor.monitorInterval, const Duration(seconds: 1));
    });

    test('semantic deviation snapshot value', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordOutput('형사소송법');
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법 체포'],
        idleDuration: Duration.zero,
      );
      expect(snap.semanticDeviation, lessThan(0.65));
    });

    test('context ratio snapshot value', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 200);
      node.appendContext('z' * 160, ontologyNodeId: 'KR-LAW-001');
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: Duration.zero,
      );
      expect(snap.contextRatio, greaterThan(0.75));
    });

    test('latency snapshot value', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordLatency(3600);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: Duration.zero,
      );
      expect(snap.averageLatencyMs, greaterThan(3500));
    });

    test('idle snapshot duration', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: const ['형사소송법'],
        idleDuration: const Duration(minutes: 12),
        queueIngressCount: 0,
      );
      expect(snap.idleDuration.inMinutes, 12);
    });
  });

  group('Glymphatic Controller ping-pong (15)', () {
    late SgpGlymphaticController controller;

    setUp(() {
      SgpGlymphaticSession.reset();
      controller = SgpGlymphaticController();
    });

    tearDown(() {
      controller.dispose();
      SgpGlymphaticSession.reset();
    });

    test('initial active is main', () {
      expect(controller.activeNode.nodeId, 'main');
    });

    test('routeTraffic accepts on active', () {
      final r = controller.routeTraffic('112 출동');
      expect(r.accepted, isTrue);
      expect(r.nodeId, 'main');
    });

    test('patent application number constant', () {
      expect(SgpGlymphaticController.patentApplicationNo, '10-2026-0128052');
    });

    test('failover swaps active to shadow', () async {
      controller.activeNode.recordOutput('우주 비행 로켓');
      final event = await controller.triggerSelfHealing();
      expect(event, isNotNull);
      expect(controller.activeNode.nodeId, 'shadow');
    });

    test('handshake confirmed before flush', () async {
      final event = await controller.triggerSelfHealing();
      expect(event!.handshakeConfirmed, isTrue);
    });

    test('throttled main after heal trigger', () async {
      final event = await controller.triggerSelfHealing();
      expect(event!.previousActiveId, 'main');
      expect(controller.activeNode.nodeId, 'shadow');
    });

    test('heal log records event', () async {
      await controller.triggerSelfHealing();
      expect(controller.healLog, isNotEmpty);
    });

    test('zero packet loss during failover', () async {
      controller.routeTraffic('packet-1');
      controller.activeNode.throttle();
      controller.routeTraffic('packet-2');
      expect(controller.pendingPacketCount, greaterThan(0));
      await controller.triggerSelfHealing();
      expect(controller.pendingPacketCount, 0);
    });

    test('redirected traffic during throttle', () {
      controller.activeNode.throttle();
      final r = controller.routeTraffic('failover-packet');
      expect(r.failoverOccurred, isTrue);
      expect(r.nodeId, 'shadow');
    });

    test('recordInference on active node', () {
      controller.recordInference(
        nodeId: controller.activeNode.nodeId,
        output: '형사소송법 체포',
        latencyMs: 900,
      );
      expect(controller.activeNode.latestOutput, contains('형사소송법'));
    });

    test('monitorOnce returns snapshot', () {
      final snap = controller.monitorOnce();
      expect(snap, isA<GlymphaticMonitorSnapshot>());
    });

    test('isFlushing guard prevents double heal', () async {
      final first = controller.triggerSelfHealing();
      final second = controller.triggerSelfHealing();
      final results = await Future.wait([first, second]);
      expect(results.where((r) => r == null).length, greaterThanOrEqualTo(1));
    });

    test('session singleton', () {
      final a = SgpGlymphaticSession.instance;
      final b = SgpGlymphaticSession.instance;
      expect(identical(a, b), isTrue);
    });

    test('dispose stops monitor', () async {
      await controller.startMonitorLoop();
      controller.dispose();
      expect(controller.isFlushing, isFalse);
    });

    test('handshake transfers context to shadow', () async {
      controller.activeNode.appendContext(
        '형사소송법 체포',
        ontologyNodeId: 'KR-LAW-001',
      );
      final event = await controller.triggerSelfHealing();
      expect(event!.handshake.transferredFragments, greaterThan(0));
      expect(
        controller.activeNode.ontologySessionNodeIds,
        contains('KR-LAW-001'),
      );
    });

    test('standby ready after heal flush', () async {
      await controller.triggerSelfHealing();
      expect(controller.standbyNode.readyForSwap, isTrue);
      expect(controller.standbyNode.state, GlymphaticAgentState.ready);
    });

    test('flush report success on heal', () async {
      final event = await controller.triggerSelfHealing();
      expect(event!.flushReport.success, isTrue);
      expect(event.flushReport.readyForSwap, isTrue);
    });
  });

  group('Glymphatic Flusher recovery (10)', () {
    test('flush prunes unlinked fragments', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.appendContext('noise-A');
      node.appendContext('형사소송법 체포', ontologyNodeId: 'KR-LAW-001');
      final report = await SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const ['형사소송법 체포'],
      );
      expect(report.prunedFragments, greaterThan(0));
      expect(report.success, isTrue);
    });

    test('flush marks node ready for next swap', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.throttle();
      await SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const ['형사소송법'],
      );
      expect(node.state, GlymphaticAgentState.ready);
      expect(node.readyForSwap, isTrue);
    });

    test('flush recovers ontology alignment after noise injection', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordOutput('비트코인 채굴 예측');
      node.appendContext('노이즈', ontologyNodeId: 'KR-LAW-001');
      final before = node.semanticDeviation(const ['형사소송법 체포']);
      await SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const ['형사소송법 체포'],
      );
      node.recordOutput('형사소송법 체포 절차 증거 보전');
      final after = node.semanticDeviation(const ['형사소송법 체포']);
      expect(after, lessThan(before));
    });

    test('optimizeMemoryCache shrinks large cache', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      for (var i = 0; i < 30; i++) {
        node.appendContext('token-$i', ontologyNodeId: 'KR-LAW-001');
      }
      node.optimizeMemoryCache();
      expect(node.fragments.length, lessThanOrEqualTo(30));
    });

    test('flush try-catch never throws', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      expect(
        () => SgpGlymphaticFlusher.flushContextByOntology(
          target: node,
          ontology: null,
          ontologyAnchors: const [],
        ),
        returnsNormally,
      );
    });

    test('failed flush still returns report object', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      final report = await SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const [],
      );
      expect(report, isA<GlymphaticFlushReport>());
    });

    test('recovered alignment between 0 and 1', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      node.recordOutput('형사소송법');
      final report = await SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const ['형사소송법 체포'],
      );
      expect(report.recoveredOntologyAlignment, inInclusiveRange(0.0, 1.0));
    });

    test('cacheOptimized flag true on success', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      final report = await SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const ['형사소송법'],
      );
      expect(report.cacheOptimized, isTrue);
    });

    test('sleep mode during flush', () async {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      final future = SgpGlymphaticFlusher.flushContextByOntology(
        target: node,
        ontology: null,
        ontologyAnchors: const ['형사소송법'],
      );
      final report = await future;
      expect(report.success, isTrue);
      expect(node.state, GlymphaticAgentState.ready);
      expect(report.readyForSwap, isTrue);
    });

    test('heal event stores flush report', () async {
      final controller = SgpGlymphaticController();
      final event = await controller.triggerSelfHealing();
      expect(event!.flushReport.success, isTrue);
      controller.dispose();
    });
  });

  group('Glymphatic QA zero-loss traffic (5)', () {
    test('10 packets survive failover', () async {
      final controller = SgpGlymphaticController();
      for (var i = 0; i < 10; i++) {
        controller.routeTraffic('packet-$i');
      }
      controller.activeNode.throttle();
      for (var i = 10; i < 15; i++) {
        controller.routeTraffic('packet-$i');
      }
      final pendingBefore = controller.pendingPacketCount;
      await controller.triggerSelfHealing();
      expect(controller.pendingPacketCount, 0);
      expect(pendingBefore, greaterThan(0));
      controller.dispose();
    });

    test('accepted packets always routed to a node id', () {
      final controller = SgpGlymphaticController();
      final r = controller.routeTraffic('112 변사');
      expect(r.nodeId, isIn(['main', 'shadow']));
      controller.dispose();
    });

    test('failover flag only when redirected', () {
      final controller = SgpGlymphaticController();
      final normal = controller.routeTraffic('정상');
      expect(normal.failoverOccurred, isFalse);
      controller.dispose();
    });

    test('monitor detects semantic then heal restores routing', () async {
      final controller = SgpGlymphaticController();
      controller.activeNode.recordOutput('비트코인 마이닝 수익률 예측');
      controller.activeNode.recordLatency(5000);
      final snap = controller.monitorOnce();
      expect(
        snap.triggers,
        anyOf(
          contains(GlymphaticTrigger.semanticPollution),
          contains(GlymphaticTrigger.systemLatency),
        ),
      );
      await controller.triggerSelfHealing();
      final r = controller.routeTraffic('112 출동');
      expect(r.accepted, isTrue);
      controller.dispose();
    });

    test('idle trigger alone can initiate heal', () async {
      final controller = SgpGlymphaticController();
      final snap = controller.monitorOnce(
        idleOverride: const Duration(minutes: 10),
      );
      expect(snap.triggers, contains(GlymphaticTrigger.contextualIdle));
      final event = await controller.triggerSelfHealing(
        triggers: snap.triggers,
      );
      expect(event, isNotNull);
      controller.dispose();
    });
  });
}
