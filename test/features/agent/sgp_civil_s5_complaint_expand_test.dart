import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_civil_complaint_data.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_demo_scenarios.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_router.dart';
import 'package:sgp_agent/features/agent/sgp_civil_guidance_assembler.dart';
import 'package:sgp_agent/features/agent/sgp_civil_non_intervention_filter.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_controller.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_guard.dart';
import 'package:sgp_agent/features/glymphatic/sgp_glymphatic_flush_policy.dart';
import 'package:test/test.dart';

void main() {
  late CivilComplaintNodePack pack;

  setUp(() {
    final json =
        File('assets/data/civil_complaint_nodes.json').readAsStringSync();
    pack = CivilComplaintNodePack.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  });

  group('S5 Civil complaint 8-pack', () {
    test('demo scenarios are exactly 8', () {
      expect(SgpCivilComplaintDemoScenarios.all.length, 8);
    });

    test('new ontology types exist', () {
      final ids = pack.types.map((t) => t.id).toSet();
      expect(ids, contains('CC-TYPE-PRIVATE-PARKING'));
      expect(ids, contains('CC-TYPE-DATING-STALKING'));
      expect(pack.types.length, greaterThanOrEqualTo(17));
    });

    test('routes 사유지 무단주차 → PRIVATE-PARKING', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        SgpCivilComplaintDemoScenarios.all
            .firstWhere((d) => d.id == 'private_parking')
            .radioText,
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-PRIVATE-PARKING');
    });

    test('routes 보증금·채무 → CIVIL-DISPUTE + yellow filter', () {
      final text = SgpCivilComplaintDemoScenarios.all
          .firstWhere((d) => d.id == 'lease_debt')
          .radioText;
      final route = SgpCivilComplaintRouter.routeFromText(text, pack);
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-CIVIL-DISPUTE');
      final hit = SgpCivilNonInterventionFilter.evaluate(
        text,
        routedTypeId: route.type.id,
      );
      expect(hit.matched, isTrue);
      expect(hit.bannerTitle, contains('민사불개입'));
    });

    test('routes 데이트폭력·스토킹 → DATING-STALKING', () {
      final route = SgpCivilComplaintRouter.routeFromText(
        SgpCivilComplaintDemoScenarios.all
            .firstWhere((d) => d.id == 'dating_stalking')
            .radioText,
        pack,
      );
      expect(route, isNotNull);
      expect(route!.type.id, 'CC-TYPE-DATING-STALKING');
    });

    test('free text debt phrases trigger civil non-intervention', () {
      expect(
        SgpCivilNonInterventionFilter.evaluate('돈을 안 갚는다며 찾아왔어요').matched,
        isTrue,
      );
      expect(
        SgpCivilNonInterventionFilter.evaluate('보증금을 안 돌려준다').matched,
        isTrue,
      );
      expect(
        SgpCivilNonInterventionFilter.evaluate('면허증 재발급 문의').matched,
        isFalse,
      );
    });

    test('guidance assembler emits 3-section markdown', () {
      final demo =
          SgpCivilComplaintDemoScenarios.all.firstWhere((d) => d.id == 'noise');
      final route =
          SgpCivilComplaintRouter.routeFromText(demo.radioText, pack)!;
      final card = SgpCivilGuidanceAssembler.assemble(
        route: route,
        rawText: demo.radioText,
      );
      expect(card.markdown, contains('## 1. 법리적 판단'));
      expect(card.markdown, contains('## 2. 경찰 조치 한계'));
      expect(card.markdown, contains('## 3. 전문 구제 기관 연계'));
      expect(card.plainText, isNotEmpty);
    });
  });

  group('S5 Glymphatic rapid complaint switching', () {
    test('8-scenario burst keeps minor lane without overlay lock', () async {
      final controller = SgpGlymphaticController();
      final guard = SgpGlymphaticFlushGuard();
      var maxTokens = 0;

      for (final demo in SgpCivilComplaintDemoScenarios.all) {
        final bulky = '${demo.radioText}\n${'민원전문 ' * 40}';
        controller.noteUserInteraction();
        controller.routeTraffic(bulky);
        if (controller.activeNode.contextTokenCount > maxTokens) {
          maxTokens = controller.activeNode.contextTokenCount;
        }

        final lane = SgpGlymphaticFlushPolicy.resolve(
          isUrgentSituation: true,
          lastUserInteractionTime: controller.lastUserInteractionTime,
        );
        expect(lane, GlymphaticFlushPresentation.minorBackground);
        expect(SgpGlymphaticFlushPolicy.allowsOverlay(lane), isFalse);

        await guard.runFlushSession(
          allowOverlay: false,
          () async {
            await controller.triggerSelfHealing(
              mode: GlymphaticFlushMode.minor,
            );
          },
        );
        expect(guard.overlayVisible, isFalse);
        expect(guard.forcedUnlockByTimeout, isFalse);
      }

      expect(maxTokens, greaterThan(0));
      expect(controller.activeNode.tokenRatio, lessThanOrEqualTo(1.0));

      guard.dispose();
      controller.dispose();
    });
  });
}
