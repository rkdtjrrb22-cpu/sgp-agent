import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_kgrag_loader.dart';
import 'package:sgp_agent/features/control/sgp_emergency_admission_router.dart';
import 'package:sgp_agent/features/investigation/modules/sgp_domestic_abuse_shield.dart';
import 'package:sgp_agent/features/investigation/modules/sgp_narcotics_handler.dart';
import 'package:test/test.dart';

/// S12 — 가폭·아동학대·응급입원·마약류 50종 (200+50=250 Pass).
void main() {
  group('S12 Domestic Abuse Shield (17)', () {
    test('가정폭력 현장 → 격리·접근금지·전기통신 금지 권고', () {
      final r = SgpDomesticAbuseShield.analyze('배우자 폭행 가정폭력 현장');
      expect(r.isDomesticViolenceContext, isTrue);
      expect(r.recommendedMeasures, contains(EmergencyTempMeasureType.isolation));
      expect(r.recommendedMeasures, contains(EmergencyTempMeasureType.approachBan100m));
    });

    test('아동학대 정황 → 아동학대 온톨로지', () {
      final r = SgpDomesticAbuseShield.analyze('아동학대 신체학대 정황');
      expect(r.isChildAbuseContext, isTrue);
      expect(r.ontologyNodes, contains('KR-LAW-CHILD-ABUSE'));
    });

    test('100m 접근금지 키워드', () {
      final r = SgpDomesticAbuseShield.analyze('100m 접근금지 조치');
      expect(r.recommendedMeasures, contains(EmergencyTempMeasureType.approachBan100m));
    });

    test('전기통신 접근금지', () {
      final r = SgpDomesticAbuseShield.analyze('전화 문자 연락 금지');
      expect(r.recommendedMeasures, contains(EmergencyTempMeasureType.telecomBan));
    });

    test('격리·분리 키워드', () {
      final r = SgpDomesticAbuseShield.analyze('피해자 보호 시설 격리');
      expect(r.recommendedMeasures, contains(EmergencyTempMeasureType.isolation));
    });

    test('조치 시한 유효', () {
      final issued = DateTime(2026, 1, 1);
      final status = SgpDomesticAbuseShield.deadlineStatus(
        issuedAt: issued,
        now: issued.add(const Duration(days: 1)),
      );
      expect(status, TempMeasureDeadlineStatus.valid);
    });

    test('조치 만료 임박', () {
      final issued = DateTime(2026, 1, 1);
      final status = SgpDomesticAbuseShield.deadlineStatus(
        issuedAt: issued,
        now: issued.add(const Duration(days: 13, hours: 12)),
      );
      expect(status, TempMeasureDeadlineStatus.expiringSoon);
    });

    test('조치 시한 만료', () {
      final issued = DateTime(2026, 1, 1);
      final status = SgpDomesticAbuseShield.deadlineStatus(
        issuedAt: issued,
        now: issued.add(const Duration(days: 15)),
      );
      expect(status, TempMeasureDeadlineStatus.expired);
    });

    test('접근금지 위반 → 형사처벌', () {
      final r = SgpDomesticAbuseShield.analyze('가정폭력 100m 접근금지 위반');
      expect(r.violationDisposition, MeasureViolationDisposition.criminal);
    });

    test('아동학대 조치 위반 → 형사·과태료', () {
      final r = SgpDomesticAbuseShield.analyze('아동 학대 조치 위반 연락');
      expect(r.violationDisposition, MeasureViolationDisposition.criminalAndFine);
    });

    test('requiresEmergencyMeasure', () {
      final r = SgpDomesticAbuseShield.analyze('남편 폭행 피해자 보호');
      expect(r.requiresEmergencyMeasure, isTrue);
    });

    test('온톨로지 KR-DV-TEMP-ISOLATION', () {
      final r = SgpDomesticAbuseShield.analyze('가해자 분리 격리');
      expect(r.ontologyNodes, contains('KR-DV-TEMP-ISOLATION'));
    });

    test('온톨로지 KR-DV-TEMP-APPROACH-100M', () {
      final r = SgpDomesticAbuseShield.analyze('100m 이내 접근금지');
      expect(r.ontologyNodes, contains('KR-DV-TEMP-APPROACH-100M'));
    });

    test('온톨로지 KR-DV-TEMP-TELECOM-BAN', () {
      final r = SgpDomesticAbuseShield.analyze('SNS 카톡 연락 금지');
      expect(r.ontologyNodes, contains('KR-DV-TEMP-TELECOM-BAN'));
    });

    test('hoursRemaining 계산', () {
      final issued = DateTime(2026, 1, 1, 12);
      final rem = SgpDomesticAbuseShield.hoursRemaining(
        issuedAt: issued,
        now: issued.add(const Duration(days: 1)),
      );
      expect(rem!.inHours, greaterThan(300));
    });

    test('방임·유기 아동학대', () {
      final r = SgpDomesticAbuseShield.analyze('아동 방임 유기 학대');
      expect(r.isChildAbuseContext, isTrue);
    });

    test('정상 민원 → 조치 없음', () {
      final r = SgpDomesticAbuseShield.analyze('분실물 신고');
      expect(r.requiresEmergencyMeasure, isFalse);
    });
  });

  group('S12 Emergency Admission MHW-50 (17)', () {
    test('자해 위험 감지', () {
      final r = SgpEmergencyAdmissionRouter.route('자살 자해 목매 정신질환');
      expect(r.selfHarmRisk, isTrue);
      expect(r.isHighRisk, isTrue);
    });

    test('타해 위험 감지', () {
      final r = SgpEmergencyAdmissionRouter.route('타해 흉기 휘두 정신과');
      expect(r.harmToOthersRisk, isTrue);
    });

    test('의사·경찰 동의 충족', () {
      final r = SgpEmergencyAdmissionRouter.route(
        '정신질환 자해 의사 경찰관 동의 응급입원',
        doctorConsentDeclared: true,
        policeConsentDeclared: true,
      );
      expect(r.consentStatus, EmergencyAdmissionConsent.doctorAndPolice);
      expect(r.isLawfulAdmission, isTrue);
    });

    test('동의 미충족 경고', () {
      final r = SgpEmergencyAdmissionRouter.route('자해 정신질환');
      expect(r.consentStatus, EmergencyAdmissionConsent.insufficient);
      expect(r.warnings, isNotEmpty);
    });

    test('의사만 동의', () {
      final r = SgpEmergencyAdmissionRouter.route(
        '우울 자해 의사',
        doctorConsentDeclared: true,
      );
      expect(r.consentStatus, EmergencyAdmissionConsent.doctorOnly);
    });

    test('72h 잔여 계산', () {
      final t0 = DateTime(2026, 1, 1, 12);
      final rem = SgpEmergencyAdmissionRouter.compute72hRemaining(
        admissionAt: t0,
        now: t0.add(const Duration(hours: 24)),
      );
      expect(rem.inHours, 48);
    });

    test('72h 초과 경고', () {
      final t0 = DateTime(2026, 1, 1);
      final r = SgpEmergencyAdmissionRouter.route(
        '정신질환',
        admissionAt: t0,
        now: t0.add(const Duration(hours: 73)),
      );
      expect(r.guardRisk, CustodyGuardRisk.seventyTwoHourBreach);
    });

    test('이송 중 자해 리스크', () {
      final r = SgpEmergencyAdmissionRouter.route('자해 구급차 병원 이송');
      expect(r.guardRisk, CustodyGuardRisk.transitSelfHarm);
    });

    test('인치·계호 한계 경고', () {
      final r = SgpEmergencyAdmissionRouter.route('정신질환 인치 신병 계호');
      expect(r.guardRisk, CustodyGuardRisk.preHospitalCustodyLimit);
    });

    test('온톨로지 KR-LAW-MHW-50', () {
      final r = SgpEmergencyAdmissionRouter.route('조현병 환각');
      expect(r.ontologyNodes, contains('KR-LAW-MHW-50'));
    });

    test('온톨로지 KR-MHW-SELF-HARM', () {
      final r = SgpEmergencyAdmissionRouter.route('자해 손목');
      expect(r.ontologyNodes, contains('KR-MHW-SELF-HARM'));
    });

    test('온톨로지 KR-MHW-HARM-OTHERS', () {
      final r = SgpEmergencyAdmissionRouter.route('타해 위협');
      expect(r.ontologyNodes, contains('KR-MHW-HARM-OTHERS'));
    });

    test('112 출동 경찰 동의', () {
      final r = SgpEmergencyAdmissionRouter.route('112 출동 경찰관 자해');
      expect(r.consentStatus, EmergencyAdmissionConsent.insufficient);
      expect(r.warnings, isNotEmpty);
    });

    test('6h 이내 72h 잔여 경고', () {
      final t0 = DateTime(2026, 1, 1);
      final r = SgpEmergencyAdmissionRouter.route(
        '정신질환',
        admissionAt: t0,
        now: t0.add(const Duration(hours: 67)),
      );
      expect(r.warnings.any((w) => w.contains('72시간')), isTrue);
    });

    test('정신질환 미감지', () {
      final r = SgpEmergencyAdmissionRouter.route('교통사고');
      expect(r.isHighRisk, isFalse);
    });

    test('응급입원 온톨로지 노드', () {
      final r = SgpEmergencyAdmissionRouter.route('정신 이상 조증');
      expect(r.ontologyNodes, contains('KR-MHW-EMERGENCY-ADMISSION'));
    });

    test('경찰관 동의 누락 경고', () {
      final r = SgpEmergencyAdmissionRouter.route(
        '자해 타해',
        doctorConsentDeclared: true,
      );
      expect(r.warnings.any((w) => w.contains('경찰관')), isTrue);
    });
  });

  group('S12 Narcotics Handler (11)', () {
    test('마약 정황 → 간이시약 단계', () {
      final r = SgpNarcoticsHandler.analyze('마약 필로폰 소지 혐의');
      expect(r.narcoticsContext, isTrue);
      expect(r.stage, NarcoticsScreeningStage.fieldRapidTest);
    });

    test('간이시약 거부 → 감정처분 단계', () {
      final r = SgpNarcoticsHandler.analyze('마약 간이시약 검사 거부');
      expect(r.refusedRapidTest, isTrue);
      expect(r.stage, NarcoticsScreeningStage.forensicWarrantApplication);
    });

    test('영장 신청 단계', () {
      final r = SgpNarcoticsHandler.analyze(
        '마약 검사 거부 감정처분 압수수색 영장',
        hasWarrantDraft: true,
        hasSuspicionBasis: true,
        hasRefusalRecord: true,
        hasSampleChain: true,
      );
      expect(r.stage, NarcoticsScreeningStage.searchSeizureWarrant);
    });

    test('소명 누락 — 혐의 정황', () {
      final r = SgpNarcoticsHandler.analyze('마약 거부');
      expect(r.justificationComplete, isFalse);
      expect(r.missingJustifications, isNotEmpty);
    });

    test('소명 충족', () {
      final r = SgpNarcoticsHandler.analyze(
        '마약 혐의 정황 검사 거부 영장',
        hasSuspicionBasis: true,
        hasRefusalRecord: true,
        hasWarrantDraft: true,
        hasSampleChain: true,
      );
      expect(r.justificationComplete, isTrue);
    });

    test('타임라인 onTrack', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(
        SgpNarcoticsHandler.timelineStatus(
          refusalAt: t0,
          now: t0.add(const Duration(hours: 2)),
        ),
        NarcoticsTimelineStatus.onTrack,
      );
    });

    test('타임라인 urgent', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(
        SgpNarcoticsHandler.timelineStatus(
          refusalAt: t0,
          now: t0.add(const Duration(hours: 21)),
        ),
        NarcoticsTimelineStatus.urgent,
      );
    });

    test('타임라인 overdue', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(
        SgpNarcoticsHandler.timelineStatus(
          refusalAt: t0,
          now: t0.add(const Duration(hours: 25)),
        ),
        NarcoticsTimelineStatus.overdue,
      );
    });

    test('온톨로지 KR-NARC-RAPID-TEST', () {
      final r = SgpNarcoticsHandler.analyze('대마 투약 정황');
      expect(r.ontologyNodes, contains('KR-NARC-RAPID-TEST'));
    });

    test('온톨로지 KR-NARC-FORCED-MEASURE', () {
      final r = SgpNarcoticsHandler.analyze('마약 시약 거부');
      expect(r.ontologyNodes, contains('KR-NARC-FORCED-MEASURE'));
    });

    test('requiresForcedMeasure', () {
      final r = SgpNarcoticsHandler.analyze('향정 마약 검사 거부');
      expect(r.requiresForcedMeasure, isTrue);
    });
  });

  group('S12 KG-RAG 750 Corpus (5)', () {
    late KgragPrecedentPack pack;

    setUp(() {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      pack = SgpKgragLoader.parsePack(json);
    });

    test('target_corpus_size 800', () {
      expect(pack.targetCorpusSize, 800);
    });

    test('벡터 인덱스 800종', () {
      final store = SgpKgragLoader.buildVectorIndex(pack);
      expect(store.corpusSize, 800);
    });

    test('가폭 긴급임시조치 판례 시드', () {
      expect(pack.precedents.any((p) => p.id == 'SC-2024-DV-TEMP-ISOLATION'), isTrue);
    });

    test('응급입원 판례 시드', () {
      expect(pack.precedents.any((p) => p.id == 'SC-2024-MHW-72H'), isTrue);
    });

    test('마약류 영장 판례 시드', () {
      expect(pack.precedents.any((p) => p.id == 'SC-2024-NARC-WARRANT'), isTrue);
    });
  });
}
