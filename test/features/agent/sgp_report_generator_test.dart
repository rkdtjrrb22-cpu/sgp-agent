import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:sgp_agent/features/agent/sgp_procedure_timeline.dart';
import 'package:sgp_agent/features/agent/sgp_physical_force_guide.dart';
import 'package:sgp_agent/features/agent/sgp_report_generator.dart';

void main() {
  group('SgpReportGenerator', () {
    test('타임라인·분석 데이터로 보고서 합성', () {
      final t0 = DateTime(2026, 7, 10, 14, 0);
      var timeline = buildProcedureTimeline(
        arrestType: ArrestType.currentOffender,
        t0: t0,
      ).copyWith(physicalThreatLevel: PhysicalThreatLevel.violentAttack);

      timeline = timeline
          .toggleCheck('evidence_notice', 'evidence_legal_notice', true)
          .toggleCheck('victim_separation', 'separate_room', true);

      final advanced = runAdvancedAnalysis(
        rawText: '피의자가 먼저 시비를 걸고 칼을 휘둘렀으며 피해자가 막으려 했다.',
        checklist: const LawCheckList(isWeaponUsed: true, isDomesticViolence: true),
        ruleResult: const RuleMatchResult(
          triggeredFilters: [],
          suggestedChecklist: LawCheckList(),
        ),
      );

      final report = SgpReportGenerator.generate(
        SgpReportInput(
          rawText: '피의자가 먼저 시비를 걸고 칼을 휘둘렀으며 피해자가 막으려 했다.',
          checklist: const LawCheckList(isWeaponUsed: true, isDomesticViolence: true),
          generatedAt: t0.add(const Duration(hours: 1)),
          advancedAnalysis: advanced,
          timeline: timeline,
        ),
      );

      expect(report.markdown, contains('사법 무결성 초동조치 보고서'));
      expect(report.markdown, contains('가·피해자 분리'));
      expect(report.markdown, contains('폭력적 공격'));
      expect(report.markdown, contains('대법원'));
      expect(report.citedPrecedentIds, isNotEmpty);
      expect(report.plainText, isNot(contains('**')));
    });

    test('JSON 세션에서 입력 복원', () {
      final json = SgpReportInput(
        rawText: '테스트',
        checklist: const LawCheckList(isIntoxicated: true),
        generatedAt: DateTime(2026, 7, 10),
      ).toSessionJson();

      final restored = SgpReportInput.fromSessionJson(json);
      expect(restored.rawText, '테스트');
      expect(restored.checklist.isIntoxicated, isTrue);
    });
  });
}
