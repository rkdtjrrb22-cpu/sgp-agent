import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_agent_core.dart';
import 'package:sgp_agent/features/agent/sgp_quantum_legal_engine.dart';

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
  });
}
