import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_agent_node.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_controller.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_monitor.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_patent_qa.dart';
import 'package:test/test.dart';

void main() {
  group('Glymphatic Patent QA — Noise Injector (6)', () {
    test('injectSemanticPollution reaches >= 0.70 entropy', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      final entropy = GlymphaticNoiseInjector.injectSemanticPollution(node);
      expect(entropy, greaterThanOrEqualTo(0.70));
      expect(
        node.semanticDeviation(GlymphaticNoiseInjector.defaultOntologyAnchors),
        greaterThan(SgpGlymphaticMonitor.semanticDeviationThreshold),
      );
    });

    test('injectContextOverload reaches >= 80% saturation', () {
      final node = SgpGlymphaticAgentNode(
        nodeId: 'main',
        maxWindowTokens: 1000,
      );
      final ratio = GlymphaticNoiseInjector.injectContextOverload(
        node,
        targetRatio: 0.80,
      );
      expect(ratio, greaterThanOrEqualTo(0.80));
      expect(node.tokenRatio * 100, greaterThanOrEqualTo(80.0));
    });

    test('injectMixedFieldNoise triggers monitor heal', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 1000);
      GlymphaticNoiseInjector.injectMixedFieldNoise(node);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: GlymphaticNoiseInjector.defaultOntologyAnchors,
        idleDuration: Duration.zero,
      );
      expect(snap.shouldHeal, isTrue);
      expect(snap.triggers, isNotEmpty);
    });

    test('pollution exceeds patent semantic threshold 0.65', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main');
      GlymphaticNoiseInjector.injectSemanticPollution(node, targetMin: 0.70);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: GlymphaticNoiseInjector.defaultOntologyAnchors,
        idleDuration: Duration.zero,
      );
      expect(snap.triggers, contains(GlymphaticTrigger.semanticPollution));
    });

    test('overload exceeds patent context threshold 75%', () {
      final node = SgpGlymphaticAgentNode(nodeId: 'main', maxWindowTokens: 500);
      GlymphaticNoiseInjector.injectContextOverload(node, targetRatio: 0.80);
      final snap = SgpGlymphaticMonitor.evaluate(
        node: node,
        ontologyAnchors: GlymphaticNoiseInjector.defaultOntologyAnchors,
        idleDuration: Duration.zero,
      );
      expect(snap.triggers, contains(GlymphaticTrigger.contextSaturation));
    });

    test('monitor interval constant is 1 second', () {
      expect(SgpGlymphaticMonitor.monitorInterval, const Duration(seconds: 1));
    });
  });

  group('Glymphatic Patent QA — Self-Heal E2E (8)', () {
    late GlymphaticPatentQaSimulator simulator;

    setUp(() {
      SgpGlymphaticSession.reset();
      simulator = GlymphaticPatentQaSimulator();
    });

    tearDown(() {
      simulator.dispose();
      SgpGlymphaticSession.reset();
    });

    test('monitor daemon captures threshold breach', () async {
      final controller = simulator.controller;
      GlymphaticNoiseInjector.injectSemanticPollution(controller.activeNode);
      GlymphaticNoiseInjector.injectContextOverload(
        controller.activeNode,
        targetRatio: 0.80,
      );

      await controller.startMonitorLoop(
        interval: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));
      controller.stopMonitorLoop();

      expect(controller.healLog, isNotEmpty);
      expect(controller.healLog.first.previousActiveId, 'main');
      expect(controller.activeNode.nodeId, 'shadow');
    });

    test('lossless handshake active to shadow on heal', () async {
      final controller = simulator.controller;
      controller.routeTraffic('packet-A');
      controller.routeTraffic('packet-B');
      GlymphaticNoiseInjector.injectSemanticPollution(controller.activeNode);

      final event = await controller.triggerSelfHealing();
      expect(event, isNotNull);
      expect(event!.handshake.confirmed, isTrue);
      expect(event.handshake.isLossless, isTrue);
      expect(event.handshake.transferredFragments, greaterThan(0));
      expect(controller.activeNode.nodeId, 'shadow');
      expect(controller.pendingPacketCount, 0);
    });

    test('background flush resets standby to clean 0 entropy 0% saturation', () async {
      final controller = simulator.controller;
      GlymphaticNoiseInjector.injectSemanticPollution(
        controller.activeNode,
        targetMin: 0.70,
      );
      GlymphaticNoiseInjector.injectContextOverload(
        controller.activeNode,
        targetRatio: 0.80,
      );

      await controller.triggerSelfHealing();
      final standby = controller.standbyNode;

      await expectLater(
        Future<void>.sync(() {
          expect(standby.readyForSwap, isTrue);
          expect(standby.state, GlymphaticAgentState.ready);
          expect(
            standby.semanticDeviation(
              GlymphaticNoiseInjector.defaultOntologyAnchors,
            ),
            0.0,
          );
          expect(standby.tokenRatio, 0.0);
          expect(standby.contextTokenCount, 0);
        }),
        completes,
      );
    });

    test('flush report marks readyForSwap and clean state', () async {
      final result = await simulator.runSelfHealScenario(
        daemonWaitOverride: const Duration(milliseconds: 50),
      );
      final report = result.healEvent.flushReport;
      expect(report.success, isTrue);
      expect(report.readyForSwap, isTrue);
      expect(report.readyState?.isClean, isTrue);
      expect(report.readyState?.readyForSwap, isTrue);
    });

    test('full scenario: before dashboard shows danger', () async {
      final result = await simulator.runSelfHealScenario(
        daemonWaitOverride: const Duration(milliseconds: 50),
      );
      expect(result.beforeDashboard.semanticEntropy, greaterThanOrEqualTo(0.70));
      expect(
        result.beforeDashboard.contextSaturationRatio,
        greaterThanOrEqualTo(0.80),
      );
      expect(result.beforeDashboard.semanticDanger, isTrue);
      expect(result.beforeDashboard.contextDanger, isTrue);
      expect(result.beforeDashboard.isHealthy, isFalse);
    });

    test('full scenario: after flush standby metrics are zeroed', () async {
      final result = await simulator.runSelfHealScenario(
        daemonWaitOverride: const Duration(milliseconds: 50),
      );
      expect(result.afterFlushStandby.semanticEntropy, 0.0);
      expect(result.afterFlushStandby.contextSaturationPercent, 0.0);
      expect(result.afterFlushStandby.contextSaturationRatio, 0.0);
      expect(
        result.afterFlushStandby.readyReport?.readyForSwap,
        isTrue,
      );
    });

    test('full scenario: dashboard recovers to healthy after field recovery', () async {
      final result = await simulator.runSelfHealScenario(
        daemonWaitOverride: const Duration(milliseconds: 50),
      );
      expect(result.afterRecoveryDashboard.isHealthy, isTrue);
      expect(result.afterRecoveryDashboard.semanticDanger, isFalse);
      expect(result.afterRecoveryDashboard.contextDanger, isFalse);
      expect(
        result.afterRecoveryDashboard.semanticEntropy,
        lessThan(SgpGlymphaticMonitor.semanticDeviationThreshold),
      );
      expect(result.afterRecoveryDashboard.activeNodeId, 'shadow');
    });

    test('monitor daemon path triggers heal via 1s loop contract', () async {
      final result = await simulator.runSelfHealScenario(
        useMonitorDaemon: true,
        daemonWaitOverride: const Duration(milliseconds: 50),
      );
      expect(result.healEvent.handshake.confirmed, isTrue);
      expect(result.monitorDetected.shouldHeal, isTrue);
    });

    test('patent application number embedded in controller', () {
      expect(
        SgpGlymphaticController.patentApplicationNo,
        '10-2026-0128052',
      );
    });
  });
}
