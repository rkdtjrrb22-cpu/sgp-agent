// VM-native core tests — `dart test` (Flutter test runner 불필요).
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('LawCheckList', () {
    test('copyWith preserves unchanged fields', () {
      const original = LawCheckList(isDomesticViolence: true);
      final updated = original.copyWith(isFleeing: true);

      expect(updated.isDomesticViolence, isTrue);
      expect(updated.isFleeing, isTrue);
      expect(updated.isWeaponUsed, isFalse);
    });

    test('mergeChecklists ORs all flags', () {
      const manual = LawCheckList(isWeaponUsed: true);
      const suggested = LawCheckList(isIntoxicated: true);
      final merged = mergeChecklists(manual, suggested);

      expect(merged.isWeaponUsed, isTrue);
      expect(merged.isIntoxicated, isTrue);
      expect(merged.isDomesticViolence, isFalse);
    });
  });

  group('matchLawFilters', () {
    test('weapon_and_danger triggers on 소주병', () {
      final result = matchLawFilters('피의자가 소주병을 들고 위협');
      expect(result.isTriggered('weapon_and_danger'), isTrue);
      expect(result.suggestedChecklist.isWeaponUsed, isTrue);
    });

    test('relational_violence triggers on 남편', () {
      final result = matchLawFilters('피해자 남편이 폭행');
      expect(result.isTriggered('relational_violence'), isTrue);
      expect(result.suggestedChecklist.isDomesticViolence, isTrue);
    });

    test('voluntary_intoxication triggers on 술 취해', () {
      final result = matchLawFilters('술 취한 상태에서 소란');
      expect(result.isTriggered('voluntary_intoxication'), isTrue);
      expect(result.suggestedChecklist.isIntoxicated, isTrue);
    });

    test('주취폭행 scenario triggers multiple filters', () {
      const text =
          '112 신고. 피해자 남편이 술 취한 상태에서 주먹으로 얼굴 폭행. 도주 시도.';
      final result = matchLawFilters(text);

      expect(result.triggeredFilters.length, greaterThanOrEqualTo(3));
      expect(result.suggestedChecklist.isDomesticViolence, isTrue);
      expect(result.suggestedChecklist.isIntoxicated, isTrue);
      expect(result.suggestedChecklist.isFleeing, isTrue);
    });
  });

  group('buildStrictPrompt / pipeline prompt', () {
    test('includes compact checklist and req dict', () {
      const checklist = LawCheckList(isWeaponUsed: true);
      final prompt = buildStrictPrompt(
        rawText: '소주병 들고 폭행',
        checklist: checklist,
      );

      expect(prompt, contains('[Role]'));
      expect(prompt, contains('weapon:true'));
      expect(prompt, contains('흉기·위험물 사용 필터'));
      expect(prompt, contains('[CoT]'));
      expect(prompt, contains('■ 1단계'));
    });

    test('embeds hallucination guard', () {
      final prompt = buildStrictPrompt(
        rawText: '테스트',
        checklist: const LawCheckList(),
      );

      expect(prompt, contains('[Guard]'));
      expect(prompt, contains('창작 금지'));
    });

    test('empty rawText yields [추후 보완] in input block', () {
      final prompt = buildStrictPrompt(
        rawText: '',
        checklist: const LawCheckList(),
      );

      expect(prompt, contains('[추후 보완]'));
    });
  });

  group('buildPipeline / generateStructuredOutput', () {
    test('produces 4-stage markdown output with case draft', () {
      const text = '112 신고. 피해자 남편이 술 취한 상태에서 주먹으로 얼굴 폭행. 도주 시도.';
      final result = buildPipeline(
        rawText: text,
        checklist: const LawCheckList(),
      );

      expect(result.output, contains('■ 1단계'));
      expect(result.output, contains('■ 5단계'));
      expect(result.advancedAnalysis.prosecutionSuccessRate, greaterThan(0));
      expect(result.advancedAnalysis.primaryAggressor, isNotEmpty);
      expect(result.advancedAnalysis.proceduralAlerts, isNotEmpty);
    });

    test('runAdvancedAnalysis detects mutual combat defense', () {
      const text = '서로 맞붙었으나 피해자가 먼저 시비를 걸고 남편이 막으려 손을 잡음';
      final rules = matchLawFilters(text);
      final adv = runAdvancedAnalysis(
        rawText: text,
        checklist: const LawCheckList(isDomesticViolence: true),
        ruleResult: rules,
      );

      expect(adv.mutualCombatSuspected, isTrue);
      expect(adv.suspectVictimStatus, contains('쌍방 폭행 방어 분석'));
    });
  });

  group('SgpAgentEngine', () {
    test('runPipeline returns structured result', () async {
      final engine = SgpAgentEngine();
      await engine.loadModel();

      final result = await engine.runPipeline(
        rawText: '전남친이 집 앞에서 따라옴',
        checklist: const LawCheckList(),
      );

      expect(result.output, contains('스토킹'));
      expect(result.prompt.length, lessThan(2500));

      engine.dispose();
    });

    test('benchmark scenarios produce tokens/sec', () async {
      final engine = SgpAgentEngine();
      await engine.loadModel();

      final drunkAssault = await engine.runBenchmark('주취폭행');
      final stalking = await engine.runBenchmark('스토킹');

      expect(drunkAssault.tokensPerSec, greaterThan(0));
      expect(stalking.tokensPerSec, greaterThan(0));
      expect(drunkAssault.promptTokens, lessThan(800));

      engine.dispose();
      expect(engine.isLoaded, isFalse);
    });
  });
}
