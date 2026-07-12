import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_constitutional_force_engine.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology_session.dart';
import 'package:test/test.dart';

void main() {
  group('SgpConstitutionalForceEngine', () {
    setUp(() {
      SgpLegalOntologySession.instance.reset();
      final seed =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      SgpLegalHierarchyRegistry.instance.loadFromJson(seed);
      SgpLegalOntologySession.instance.loadFromRegistry();
    });

    test('2단계 저항 + 전자충격기(4단계) → IsExcessive=true', () {
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: ResistanceStage.passiveResistance,
        forceTier: PoliceForceTier.mediumRiskForce,
      );
      expect(a.isExcessive, isTrue);
      expect(a.isExcessiveFlag, isTrue);
      expect(a.constitutionalBasis, contains('헌법'));
    });

    test('2단계 저항 + 접촉 통제 → 적법', () {
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: ResistanceStage.passiveResistance,
        forceTier: PoliceForceTier.contactControl,
      );
      expect(a.isExcessive, isFalse);
      expect(a.principle, ConstitutionalPrinciple.minimumHarm);
    });

    test('1단계 순응 + 언어적 통제 → 최소침해성', () {
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: ResistanceStage.compliance,
        forceTier: PoliceForceTier.verbalControl,
      );
      expect(a.isExcessive, isFalse);
      expect(a.badgeLabel, contains('최소침해'));
    });

    test('5단계 저항 + 권총 → 적법·전체화면 경고', () {
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: ResistanceStage.lethalResistance,
        forceTier: PoliceForceTier.highRiskForce,
      );
      expect(a.isExcessive, isFalse);
      expect(a.requiresFullScreenAlert, isTrue);
    });

    test('3단계 + 5단계 물리력 → 과잉', () {
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: ResistanceStage.activeResistance,
        forceTier: PoliceForceTier.highRiskForce,
      );
      expect(a.isExcessive, isTrue);
    });

    test('무전 텍스트 — 소극적 저항·테이저 과잉 시나리오', () {
      const text =
          '피의자 소극적 저항. 손을 뒤로 숨김. 전자충격기 발사 — 테이저 사용 요청.';
      final resistance =
          SgpConstitutionalForceEngine.detectResistanceFromText(text)!;
      final force = SgpConstitutionalForceEngine.detectForceTierFromText(text)!;
      final a = SgpConstitutionalForceEngine.assess(
        resistanceStage: resistance,
        forceTier: force,
      );
      expect(resistance, ResistanceStage.passiveResistance);
      expect(force, PoliceForceTier.mediumRiskForce);
      expect(a.isExcessive, isTrue);
    });

    test('assessWithOntology — PF-STAGE 체인 triples', () {
      final a = SgpConstitutionalForceEngine.assessWithOntology(
        resistanceStage: ResistanceStage.passiveResistance,
        forceTier: PoliceForceTier.contactControl,
      );
      expect(a.ontologyTripleCount, greaterThan(0));
      expect(a.ontologySource, isNot('uninitialized'));
    });
  });
}
