import 'package:sgp_agent/features/agent/sgp_constitutional_force_engine.dart';
import 'package:sgp_agent/features/agent/sgp_officer_defense_shield_assembler.dart';
import 'package:sgp_agent/features/agent/sgp_physical_threat_level.dart';
import 'package:test/test.dart';

void main() {
  group('SgpOfficerDefenseShieldAssembler', () {
    test('Blue legal-aid shield activates at stage 3+', () {
      expect(
        SgpOfficerDefenseShieldAssembler.isLegalAidShieldActive(
          ResistanceStage.passiveResistance,
        ),
        isFalse,
      );
      expect(
        SgpOfficerDefenseShieldAssembler.isLegalAidShieldActive(
          ResistanceStage.activeResistance,
        ),
        isTrue,
      );
      expect(
        SgpOfficerDefenseShieldAssembler.isLegalAidShieldActiveFromThreat(
          PhysicalThreatLevel.violentAttack,
        ),
        isTrue,
      );
    });

    test('defense tab exposes on force execution / stage 2+', () {
      expect(
        SgpOfficerDefenseShieldAssembler.shouldExposeDefenseTab(
          threatLevel: PhysicalThreatLevel.compliance,
        ),
        isFalse,
      );
      expect(
        SgpOfficerDefenseShieldAssembler.shouldExposeDefenseTab(
          threatLevel: PhysicalThreatLevel.passiveResistance,
        ),
        isTrue,
      );
      expect(
        SgpOfficerDefenseShieldAssembler.shouldExposeDefenseTab(
          forceExecutionLogged: true,
        ),
        isTrue,
      );
    });

    test('parses resistance timeline 14:12 → 14:25 → 14:31', () {
      const radio =
          '14:12 피의자 소극적 저항. 손을 뒤로 숨김.\n'
          '14:25 피의자 적극적 저항. 밀침·도주 시도.\n'
          '14:31 폭력적 저항. 테이저건 중위험 물리력 대응.';
      final entries =
          SgpOfficerDefenseShieldAssembler.parseResistanceTimeline(radio);
      expect(entries.length, 3);
      expect(entries[0].timeLabel, '14:12');
      expect(entries[0].stageLabel, '소극적 저항');
      expect(entries[1].timeLabel, '14:25');
      expect(entries[1].stageNumber, 3);
      expect(entries[2].timeLabel, '14:31');
      expect(entries[2].stageLabel, '폭력적 저항');
      final arrow = entries.map((e) => e.arrowLine).join(' ➔ ');
      expect(arrow, contains('14:12'));
      expect(arrow, contains('➔'));
    });

    test('assembles post-litigation pack with table + duty insurance + exemption',
        () {
      const radio =
          '14:12 소극적 저항 · 14:25 적극적 저항 · 14:31 폭력적 저항. 테이저건 발사.';
      final pack = SgpOfficerDefenseShieldAssembler.assemble(
        threatLevel: PhysicalThreatLevel.violentAttack,
        forceTier: PoliceForceTier.mediumRiskForce,
        rawText: radio,
        generatedAt: DateTime(2026, 7, 14, 14, 35),
      );

      expect(pack.legalDefenseMarkdown, contains('제11조의5'));
      expect(pack.legalDefenseMarkdown, contains('형법 제20조'));
      expect(pack.legalDefenseMarkdown, contains('맞대응 변론서'));
      expect(pack.timelineTableMarkdown, contains('| 시각 |'));
      expect(pack.timelineTableMarkdown, contains('소극적 저항'));
      expect(pack.integrityReportMarkdown, contains('무결성 보고서'));
      expect(pack.dutyLiabilityInsuranceMarkdown, contains('청문감사과'));
      expect(pack.activeAdminExemptionMarkdown, contains('적극행정 면책'));
      expect(pack.combinedMarkdown, contains('독직폭행'));
      expect(pack.timelineEntries.length, greaterThanOrEqualTo(3));
    });
  });

  group('ForceDefensePackageSnapshot (engine backend)', () {
    test('capture + toPack from field radio without Flutter engine', () {
      const radio =
          '14:12 소극적 저항. 14:25 적극적 저항. 14:31 폭력적 저항. 테이저건 발사.';
      final snap = ForceDefensePackageSnapshot.capture(
        rawText: radio,
        threatLevel: PhysicalThreatLevel.violentAttack,
        forceTier: PoliceForceTier.mediumRiskForce,
        forceExecutionLogged: true,
        forceExecutionNote: '테이저건 발사',
        capturedAt: DateTime(2026, 7, 14, 15, 0),
      );

      expect(snap.hasUsableDefenseData, isTrue);
      final pack = snap.toPack(officerIdHint: 'INSP_4066');
      expect(pack.timelineTableMarkdown, contains('14:12'));
      expect(pack.dutyLiabilityInsuranceMarkdown, contains('청문감사과'));
      expect(pack.activeAdminExemptionMarkdown, contains('면책신청서'));
      expect(pack.legalDefenseMarkdown, contains('맞대응 변론서'));
    });
  });
}
