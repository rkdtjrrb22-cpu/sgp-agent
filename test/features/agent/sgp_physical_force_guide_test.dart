import 'package:flutter_test/flutter_test.dart';
import 'package:sgp_agent/features/agent/sgp_physical_force_guide.dart';

void main() {
  group('SgpPhysicalForceGuide', () {
    test('폭력적 공격 시 테이저·경찰봉 매핑', () {
      final r = SgpPhysicalForceGuide.responseFor(PhysicalThreatLevel.violentAttack);
      expect(r.allowedEquipment.any((e) => e.contains('테이저')), isTrue);
      expect(r.allowedEquipment.any((e) => e.contains('경찰봉')), isTrue);
      expect(
        r.proceduralRequirements.any((e) => e.contains('미란다')),
        isTrue,
      );
    });

    test('소극적 저항은 최소 물리력', () {
      final r = SgpPhysicalForceGuide.responseFor(PhysicalThreatLevel.passiveResistance);
      expect(r.allowedEquipment.any((e) => e.contains('구속끈')), isTrue);
      expect(r.summary, contains('유도'));
    });
  });
}
