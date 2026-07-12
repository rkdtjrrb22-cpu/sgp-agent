import 'package:sgp_agent/features/agent/sgp_constitutional_force_engine.dart';
import 'package:sgp_agent/features/agent/sgp_physical_force_matrix.dart';
import 'package:sgp_agent/features/agent/sgp_physical_threat_level.dart';
import 'package:test/test.dart';

void main() {
  group('SgpPhysicalForceMatrix', () {
    test('1단계 순응 — 언어적 통제만', () {
      final r = SgpPhysicalForceMatrix.responseFor(PhysicalThreatLevel.compliance);
      expect(r.allowedEquipment, isEmpty);
      expect(r.recommendedForceTier, PoliceForceTier.verbalControl);
    });

    test('4단계 폭력적 저항 — 테이저·경찰봉', () {
      final r = SgpPhysicalForceMatrix.responseFor(PhysicalThreatLevel.violentAttack);
      expect(r.allowedEquipment.any((e) => e.contains('테이저')), isTrue);
      expect(r.recommendedForceTier, PoliceForceTier.mediumRiskForce);
    });

    test('2단계 소극적 저항 — 접촉성 통제', () {
      final r = SgpPhysicalForceMatrix.responseFor(PhysicalThreatLevel.passiveResistance);
      expect(r.allowedEquipment.any((e) => e.contains('구속끈')), isTrue);
      expect(r.recommendedForceTier, PoliceForceTier.contactControl);
    });

    test('5단계 enum — resistanceStage 매핑', () {
      expect(PhysicalThreatLevel.lethalAttack.stageNumber, 5);
      expect(
        PhysicalThreatLevel.passiveResistance.resistanceStage,
        ResistanceStage.passiveResistance,
      );
    });
  });
}
