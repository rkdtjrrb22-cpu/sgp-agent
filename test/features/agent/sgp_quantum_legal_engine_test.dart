import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:sgp_agent/features/agent/sgp_agent_law_filters.dart';
import 'package:sgp_agent/features/agent/sgp_quantum_legal_engine.dart';
import 'package:sgp_agent/features/agent/sgp_voice_legal_binder.dart';

void main() {
  group('SgpQuantumLegalEngine', () {
    test('반려견 사고 — 동물보호법 vs 과실치상 비교', () {
      final result = SgpQuantumLegalEngine.analyze(
        rawText: '진돗개가 목줄 없이 행인을 물어 교상 발생. 견주 현장 확인.',
        checklist: const LawCheckList(),
      );

      expect(result.incidentType, IncidentType.dogBiteIncident);
      expect(result.perspectives.length, greaterThanOrEqualTo(2));
      final special = result.perspectives.firstWhere((p) => p.id.contains('B_special'));
      expect(special.law, contains('동물보호법'));
      expect(special.precedentGuide, isNotNull);
      expect(result.actionGuidance, contains('안전조치'));
    });

    test('정당방위 추세 — 쌍방 폭행 시 경합 감지', () {
      final result = SgpQuantumLegalEngine.analyze(
        rawText: '쌍방 폭행. 피의자가 먼저 밀쳤으나 피해자도 막으려 했다.',
        checklist: const LawCheckList(),
      );

      expect(result.incidentType, IncidentType.mutualCombat);
      expect(result.perspectives.any((p) => p.law.contains('정당방위')), isTrue);
    });

    test('교통사고 — 도로교통법 관점 트리거', () {
      final result = SgpQuantumLegalEngine.analyze(
        rawText: '교차로 신호위반 추돌. 운전자 음주운전 의심.',
        checklist: const LawCheckList(),
      );

      expect(result.incidentType, IncidentType.trafficIncident);
      expect(result.perspectives.any((p) => p.law.contains('도로교통')), isTrue);
    });

    test('압수·강제수사 필터 — 5번째 체크 추천', () {
      final rules = matchLawFilters('휴대폰 압수수색 영장 없이 디지털 포렌식 요청');
      expect(rules.suggestedChecklist.isSeizureConstraintReviewed, isTrue);
    });
  });

  group('SgpVoiceLegalBinder', () {
    test('미란다 고지 STT — 도주 변수 하이라이트', () {
      final match = SgpVoiceLegalBinder.analyze('피의자에게 미란다 고지 및 묵비권 안내 완료');
      expect(match.mirandaAdvised, isTrue);
      expect(match.highlightFields, contains(LawChecklistField.fleeing));
      expect(match.autoCheckFields, isEmpty);
    });
  });
}
