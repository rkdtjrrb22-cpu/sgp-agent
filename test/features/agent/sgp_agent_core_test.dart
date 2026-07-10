import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';

void main() {
  group('LawCheckList', () {
    test('copyWith preserves unchanged fields', () {
      const original = LawCheckList(isDomesticViolence: true);
      final updated = original.copyWith(isFleeing: true);

      expect(updated.isDomesticViolence, isTrue);
      expect(updated.isFleeing, isTrue);
      expect(updated.isWeaponUsed, isFalse);
    });
  });

  group('matchLawFilters', () {
    test('스토킹 scenario triggers relational filter', () {
      final result = matchLawFilters(
        '전 남친이 2주간 전화. 피해자 거주지 앞에서 대기.',
      );
      expect(result.isTriggered('relational_violence'), isTrue);
    });
  });

  group('buildStrictPrompt', () {
    test('includes pipeline structure', () {
      const checklist = LawCheckList(
        isWeaponUsed: true,
        isDomesticViolence: true,
        isIntoxicated: true,
        isFleeing: true,
      );

      final prompt = buildStrictPrompt(
        rawText: '피의자가 흉기를 들고 폭행.',
        checklist: checklist,
      );

      expect(prompt, contains('weapon:true'));
      expect(prompt, contains('dv:true'));
      expect(prompt, contains('[OutputFormat]'));
    });

    test('주취폭행 scenario maps law references', () {
      final prompt = buildStrictPrompt(
        rawText: '112 신고. 피해자 남편이 술 취한 상태에서 주먹으로 얼굴 폭행.',
        checklist: const LawCheckList(),
      );

      expect(prompt, contains('관계성 폭력 필터'));
      expect(prompt, contains('자의적 주취·약물 필터'));
      expect(prompt, contains('형법 제10조'));
    });
  });

  group('hallucination guard', () {
    test('hasAmbiguousFacts detects uncertain language', () {
      expect(hasAmbiguousFacts('피의자가 아마도 폭행한 것 같다'), isTrue);
      expect(hasAmbiguousFacts('피의자가 주먹으로 폭행'), isFalse);
    });

    test('containsHallucinationRisk flags invented time', () {
      expect(
        containsHallucinationRisk('오전 3시에 발생', '피의자가 폭행'),
        isTrue,
      );
      expect(
        containsHallucinationRisk('폭행 발생', '오전 3시에 폭행'),
        isFalse,
      );
    });
  });

  group('SgpAgentEngine benchmark', () {
    test('주취폭행 and 스토킹 scenarios produce tokens/sec', () async {
      final engine = SgpAgentEngine();
      await engine.loadModel();

      final drunkAssault = await engine.runBenchmark('주취폭행');
      final stalking = await engine.runBenchmark('스토킹');

      expect(drunkAssault.tokensPerSec, greaterThan(0));
      expect(stalking.tokensPerSec, greaterThan(0));
      expect(drunkAssault.outputTokens, greaterThan(0));
      expect(stalking.outputTokens, greaterThan(0));
      expect(drunkAssault.toString(), contains('tokens/sec'));

      engine.dispose();
      expect(engine.isLoaded, isFalse);
    });
  });
}
