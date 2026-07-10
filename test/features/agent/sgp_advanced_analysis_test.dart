import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';

void main() {
  group('runAdvancedAnalysis — 3대 혁신 엔진', () {
    test('선제 공격 + 방어 행위 교차 분석', () {
      const checklist = LawCheckList(isDomesticViolence: true);
      final rules = matchLawFilters(
        '남편이 먼저 시비를 걸었고, 피해자가 밀치는 것을 막으려 손을 잡았다. 피해자가 112 신고.',
      );
      final result = runAdvancedAnalysis(
        rawText: '남편이 먼저 시비를 걸었고, 피해자가 밀치는 것을 막으려 손을 잡았다. 피해자가 112 신고.',
        checklist: checklist,
        ruleResult: rules,
      );

      expect(result.preemptiveAttackDetected, isTrue);
      expect(result.defenseActDetected, isTrue);
      expect(result.selfDefenseLikelihood, greaterThan(0.4));
      expect(result.primaryVictim, contains('피해'));
    });

    test('흉기 주도권 + 공소유지율 계산', () {
      const checklist = LawCheckList(isWeaponUsed: true, isFleeing: true);
      final rules = matchLawFilters('피의자가 칼을 들고 폭행 후 도주. 휴대폰 문자 확인 필요.');
      final result = runAdvancedAnalysis(
        rawText: '피의자가 칼을 들고 폭행 후 도주. 휴대폰 문자 확인 필요.',
        checklist: checklist,
        ruleResult: rules,
      );

      expect(result.weaponDominanceHolder, isNot('미확인'));
      expect(result.prosecutionSuccessRate, inInclusiveRange(5.0, 92.0));
      expect(result.appliedPrecedentIds, isNotEmpty);
      expect(result.hasCriticalProceduralAlert, isTrue);
      expect(
        result.proceduralAlerts.any((a) => a.contains('임의제출')),
        isTrue,
      );
    });

    test('쌍방 폭행 의심 시 mutualCombat 플래그', () {
      final rules = matchLawFilters('쌍방으로 서로 맞붙어 폭행. 먼저 시비를 건 쪽 불명.');
      final result = runAdvancedAnalysis(
        rawText: '쌍방으로 서로 맞붙어 폭행. 먼저 시비를 건 쪽 불명.',
        checklist: const LawCheckList(),
        ruleResult: rules,
      );

      expect(result.mutualCombatSuspected, isTrue);
      expect(result.legalRisks.any((r) => r.contains('쌍방')), isTrue);
    });
  });

  group('kSystemPrompt', () {
    test('SGP-Agent Pro 고도화 프롬프트 포함', () {
      expect(kSystemPrompt, contains('SGP-Agent Pro'));
      expect(kSystemPrompt, contains('정당방위'));
      expect(kSystemPrompt, contains('형소법 제216조'));
      expect(kSystemPrompt, contains('Action Item'));
    });
  });
}
