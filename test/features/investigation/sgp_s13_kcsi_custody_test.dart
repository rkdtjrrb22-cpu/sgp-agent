import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_kgrag_loader.dart';
import 'package:sgp_agent/features/control/sgp_custody_management.dart';
import 'package:sgp_agent/features/investigation/modules/sgp_forensic_assistant.dart';
import 'package:test/test.dart';

/// S13 — 변사 초동 25종 + 유치인 25종 + Extended 50종 (250+100=350 Pass).
void main() {
  group('S13 Forensic Assistant / KCSI (25)', () {
    test('112 변사 신고 → 변사 현장', () {
      final r = SgpForensicAssistant.analyze('112 변사 신고 사망 현장');
      expect(r.isDeathScene, isTrue);
    });

    test('형소법 제222조 체크리스트', () {
      final r = SgpForensicAssistant.analyze('변사 검시');
      expect(r.checklist, contains(SgpForensicAssistant.art222));
    });

    test('범죄 혐의 → 사법 변사', () {
      final r = SgpForensicAssistant.analyze('변사 타살 의심 흉기 피해');
      expect(r.route, DeathCaseRoute.judicialAutopsy);
      expect(r.requiresJudicialPath, isTrue);
    });

    test('질병사 → 행정 변사', () {
      final r = SgpForensicAssistant.analyze('변사 질병사 자연사 유족 인도');
      expect(r.route, DeathCaseRoute.administrativeHandover);
    });

    test('통제선 설치 확인', () {
      final r = SgpForensicAssistant.analyze(
        '변사 현장 통제선 police line 설치',
        policeLineDeclared: true,
      );
      expect(r.policeLineInstalled, isTrue);
      expect(r.integrityStatus, SceneIntegrityStatus.intact);
    });

    test('통제선 미설치 → integrity 경고', () {
      final r = SgpForensicAssistant.analyze('변사 사망');
      expect(r.integrityStatus, SceneIntegrityStatus.policeLineMissing);
      expect(r.warnings, isNotEmpty);
    });

    test('소지품 임의 처분 금지 경고', () {
      final r = SgpForensicAssistant.analyze('변사 소지품 임의 처분');
      expect(r.warnings.any((w) => w.contains('임의 처분')), isTrue);
    });

    test('소지품 목록·봉인 준수', () {
      final r = SgpForensicAssistant.analyze(
        '변사 소지품 압수 목록 봉인',
        propertyListDeclared: true,
      );
      expect(r.propertyHandlingCompliant, isTrue);
    });

    test('KCSI 감식 연계', () {
      final r = SgpForensicAssistant.analyze(
        '변사 KCSI 과학수사 감식',
        kcsiNotified: true,
      );
      expect(r.kcsiLinked, isTrue);
      expect(r.ontologyNodes, contains('KR-FORENSIC-KCSI-LINK'));
    });

    test('현장 훼손 → evidenceTamperingRisk', () {
      final r = SgpForensicAssistant.analyze('변사 현장 훼손 증거 오염');
      expect(r.integrityStatus, SceneIntegrityStatus.evidenceTamperingRisk);
    });

    test('사법 변사 KCSI 미통보 경고', () {
      final r = SgpForensicAssistant.analyze('변사 살해 혐의');
      expect(r.warnings.any((w) => w.contains('KCSI')), isTrue);
    });

    test('phase kcsiNotification', () {
      final r = SgpForensicAssistant.analyze('사망 시신');
      expect(r.phase, ForensicPhase.kcsiNotification);
    });

    test('phase examination 사법', () {
      final r = SgpForensicAssistant.analyze(
        '변사 검시 KCSI 감식 타살',
        kcsiNotified: true,
      );
      expect(r.phase, ForensicPhase.examination);
    });

    test('phase bodyHandover 행정', () {
      final r = SgpForensicAssistant.analyze(
        '변사 KCSI 질병사 유족 인도',
        kcsiNotified: true,
      );
      expect(r.phase, ForensicPhase.bodyHandover);
    });

    test('온톨로지 KR-LAW-CRIM-PROC-222', () {
      final r = SgpForensicAssistant.analyze('변사');
      expect(r.ontologyNodes, contains('KR-LAW-CRIM-PROC-222'));
    });

    test('온톨로지 KR-FORENSIC-JUDICIAL-AUTOPSY', () {
      final r = SgpForensicAssistant.analyze('변사 범죄 혐의 부검');
      expect(r.ontologyNodes, contains('KR-FORENSIC-JUDICIAL-AUTOPSY'));
    });

    test('온톨로지 KR-FORENSIC-ADMIN-HANDOVER', () {
      final r = SgpForensicAssistant.analyze('변사 행정 변사 장례');
      expect(r.ontologyNodes, contains('KR-FORENSIC-ADMIN-HANDOVER'));
    });

    test('온톨로지 KR-FORENSIC-DEATH-SCENE', () {
      final r = SgpForensicAssistant.analyze('사체 발견');
      expect(r.ontologyNodes, contains('KR-FORENSIC-DEATH-SCENE'));
    });

    test('교통사망 사법 분기', () {
      final r = SgpForensicAssistant.analyze('교통 사망 음주 의심');
      expect(r.isDeathScene, isTrue);
    });

    test('자살 의심 → 검시', () {
      final r = SgpForensicAssistant.analyze('자살 의심 변사');
      expect(r.isDeathScene, isTrue);
    });

    test('비변사 → 미감지', () {
      final r = SgpForensicAssistant.analyze('분실물 신고');
      expect(r.isDeathScene, isFalse);
    });

    test('rationale 제222조 포함', () {
      final r = SgpForensicAssistant.analyze('변사');
      expect(r.rationale, contains('제222조'));
    });

    test('부검 영장 체크리스트', () {
      final r = SgpForensicAssistant.analyze('변사 타박상');
      expect(r.checklist.any((c) => c.contains('부검')), isTrue);
    });

    test('유족 인도 체크리스트', () {
      final r = SgpForensicAssistant.analyze('변사 노환 자연사');
      expect(r.checklist.any((c) => c.contains('인도')), isTrue);
    });

    test('출혈 정황 → 사법', () {
      final r = SgpForensicAssistant.analyze('변사 출혈 정황');
      expect(r.route, DeathCaseRoute.judicialAutopsy);
    });
  });

  group('S13 Custody Management (25)', () {
    test('유치장 입감 정황', () {
      final r = SgpCustodyManagement.assess('피의자 유치장 입감');
      expect(r.isCustodyContext, isTrue);
    });

    test('권리 고지 미이행', () {
      final r = SgpCustodyManagement.assess('유치 입감');
      expect(r.issues, contains(CustodyIntegrityIssue.missingRightsNotice));
    });

    test('권리 고지 이행', () {
      final r = SgpCustodyManagement.assess(
        '유치 입감',
        rightsNoticeGiven: true,
      );
      expect(r.issues, isNot(contains(CustodyIntegrityIssue.missingRightsNotice)));
    });

    test('신체검사 미실시', () {
      final r = SgpCustodyManagement.assess('유치장 입감');
      expect(r.issues, contains(CustodyIntegrityIssue.incompleteBodySearch));
    });

    test('살촕검사 수준', () {
      final r = SgpCustodyManagement.assess(
        '유치 살촕검사 성기',
        bodySearchCompleted: true,
        rightsNoticeGiven: true,
        seizureListComplete: true,
      );
      expect(r.bodySearchLevel, BodySearchLevel.stripSearch);
    });

    test('소지품 압수 목록 미작성', () {
      final r = SgpCustodyManagement.assess('유치 입감');
      expect(r.issues, contains(CustodyIntegrityIssue.incompleteSeizureList));
    });

    test('자살 고위험군', () {
      final r = SgpCustodyManagement.assess('유치 자살 기도');
      expect(r.riskLevel, CustodyRiskLevel.suicideHighRisk);
    });

    test('자해 위험군', () {
      final r = SgpCustodyManagement.assess('유치 자해');
      expect(r.riskLevel, CustodyRiskLevel.selfHarmRisk);
    });

    test('특별계호 미지정', () {
      final r = SgpCustodyManagement.assess('유치 자살');
      expect(r.issues, contains(CustodyIntegrityIssue.specialGuardNotAssigned));
    });

    test('특별계호 CCTV 집중', () {
      final r = SgpCustodyManagement.assess(
        '유치 자살',
        specialGuardAssigned: true,
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.guardInterval, SpecialGuardInterval.cctvFocus);
    });

    test('1시간 순찰', () {
      final r = SgpCustodyManagement.assess('유치 자해');
      expect(r.guardInterval, SpecialGuardInterval.hourly);
    });

    test('48h 잔여 계산', () {
      final t0 = DateTime(2026, 1, 1, 12);
      final rem = SgpCustodyManagement.compute48hRemaining(
        custodyStart: t0,
        now: t0.add(const Duration(hours: 24)),
      );
      expect(rem.inHours, 24);
    });

    test('48h 시한 초과', () {
      final t0 = DateTime(2026, 1, 1);
      final r = SgpCustodyManagement.assess(
        '유치',
        custodyStart: t0,
        now: t0.add(const Duration(hours: 49)),
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.issues, contains(CustodyIntegrityIssue.custody48hBreach));
      expect(r.custody48hCompliant, isFalse);
    });

    test('의료 조치 + 48h 경고', () {
      final r = SgpCustodyManagement.assess(
        '유치장 의료 조치 응급',
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.warnings.any((w) => w.contains('48h')), isTrue);
    });

    test('hasCriticalIssue 48h', () {
      final t0 = DateTime(2026, 1, 1);
      final r = SgpCustodyManagement.assess(
        '유치',
        custodyStart: t0,
        now: t0.add(const Duration(hours: 50)),
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.hasCriticalIssue, isTrue);
    });

    test('온톨로지 KR-LAW-CUSTODY-MGMT', () {
      final r = SgpCustodyManagement.assess('유치');
      expect(r.ontologyNodes, contains('KR-LAW-CUSTODY-MGMT'));
    });

    test('온톨로지 KR-CUSTODY-ADMISSION', () {
      final r = SgpCustodyManagement.assess('입감');
      expect(r.ontologyNodes, contains('KR-CUSTODY-ADMISSION'));
    });

    test('온톨로지 KR-CUSTODY-SPECIAL-GUARD', () {
      final r = SgpCustodyManagement.assess('유치 자해');
      expect(r.ontologyNodes, contains('KR-CUSTODY-SPECIAL-GUARD'));
    });

    test('온톨로지 KR-CUSTODY-MEDICAL-CHAIN', () {
      final r = SgpCustodyManagement.assess('유치장 병원 의료');
      expect(r.ontologyNodes, contains('KR-CUSTODY-MEDICAL-CHAIN'));
    });

    test('일반 유치인 2시간 순찰', () {
      final r = SgpCustodyManagement.assess(
        '유치',
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.guardInterval, SpecialGuardInterval.standard);
      expect(r.riskLevel, CustodyRiskLevel.standard);
    });

    test('압수목록 작성 완료', () {
      final r = SgpCustodyManagement.assess(
        '유치 소지품 압수 목록',
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
      );
      expect(r.issues, isNot(contains(CustodyIntegrityIssue.incompleteSeizureList)));
    });

    test('타해 위험', () {
      final r = SgpCustodyManagement.assess('유치 타해 폭력');
      expect(r.riskLevel, CustodyRiskLevel.selfHarmRisk);
    });

    test('비유치 → 미감지', () {
      final r = SgpCustodyManagement.assess('교통사고');
      expect(r.isCustodyContext, isFalse);
    });

    test('rationale 48h 준수', () {
      final t0 = DateTime(2026, 1, 1);
      final r = SgpCustodyManagement.assess(
        '유치',
        custodyStart: t0,
        now: t0.add(const Duration(hours: 10)),
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.rationale, contains('48h'));
      expect(r.custody48hCompliant, isTrue);
    });

    test('KG-RAG 800 corpus 변사·유치 판례', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      expect(pack.targetCorpusSize, 800);
      expect(pack.precedents.any((p) => p.id == 'SC-2024-FORENSIC-222'), isTrue);
      expect(pack.precedents.any((p) => p.id == 'SC-2024-CUSTODY-SPECIAL'), isTrue);
      expect(SgpKgragLoader.buildVectorIndex(pack).corpusSize, 800);
    });
  });

  group('S13 Forensic Extended (25)', () {
    test('익사 변사', () {
      expect(SgpForensicAssistant.analyze('익사 변사').isDeathScene, isTrue);
    });
    test('추락 사망', () {
      expect(SgpForensicAssistant.analyze('추락 사망').isDeathScene, isTrue);
    });
    test('감전 의심 사법', () {
      expect(
        SgpForensicAssistant.analyze('변사 감전 의심').route,
        DeathCaseRoute.judicialAutopsy,
      );
    });
    test('방화 연소', () {
      expect(
        SgpForensicAssistant.analyze('변사 방화').requiresJudicialPath,
        isTrue,
      );
    });
    test('피해 흔적', () {
      expect(
        SgpForensicAssistant.analyze('변사 피해 흔적').route,
        DeathCaseRoute.judicialAutopsy,
      );
    });
    test('checklist 통제선', () {
      final r = SgpForensicAssistant.analyze('사망');
      expect(r.checklist.any((c) => c.contains('Police Line')), isTrue);
    });
    test('checklist 임의 처분 금지', () {
      final r = SgpForensicAssistant.analyze('변사');
      expect(r.checklist.any((c) => c.contains('임의 처분')), isTrue);
    });
    test('KCSI 미연계 phase', () {
      expect(
        SgpForensicAssistant.analyze('변사').phase,
        ForensicPhase.kcsiNotification,
      );
    });
    test('policeLineDeclared 플래그', () {
      expect(
        SgpForensicAssistant.analyze('변사', policeLineDeclared: true).policeLineInstalled,
        isTrue,
      );
    });
    test('kcsiNotified 플래그', () {
      expect(
        SgpForensicAssistant.analyze('변사', kcsiNotified: true).kcsiLinked,
        isTrue,
      );
    });
    test('허위 검시서 키워드 훼손', () {
      expect(
        SgpForensicAssistant.analyze('변사 현장 훼손').integrityStatus,
        SceneIntegrityStatus.evidenceTamperingRisk,
      );
    });
    test('행정 장례', () {
      expect(
        SgpForensicAssistant.analyze('변사 장례 유족').route,
        DeathCaseRoute.administrativeHandover,
      );
    });
    test('검사 지휘 사법', () {
      expect(
        SgpForensicAssistant.analyze('변사 검사 지휘 부검').requiresJudicialPath,
        isTrue,
      );
    });
    test('타박상', () {
      expect(
        SgpForensicAssistant.analyze('변사 타박상').route,
        DeathCaseRoute.judicialAutopsy,
      );
    });
    test('목 조름', () {
      expect(
        SgpForensicAssistant.analyze('변사 목 조름').requiresJudicialPath,
        isTrue,
      );
    });
    test('유류품 봉인 키워드', () {
      expect(
        SgpForensicAssistant.analyze('변사 유류품 봉인').propertyHandlingCompliant,
        isTrue,
      );
    });
    test('현장 사진 감식', () {
      expect(
        SgpForensicAssistant.analyze('변사 KCSI 감식').kcsiLinked,
        isTrue,
      );
    });
    test('출입 통제', () {
      expect(
        SgpForensicAssistant.analyze('변사 출입 통제').policeLineInstalled,
        isTrue,
      );
    });
    test('노환 자연사 행정', () {
      expect(
        SgpForensicAssistant.analyze('변사 노환').route,
        DeathCaseRoute.administrativeHandover,
      );
    });
    test('살해 혐의', () {
      expect(
        SgpForensicAssistant.analyze('변사 살해').requiresJudicialPath,
        isTrue,
      );
    });
    test('피살', () {
      expect(SgpForensicAssistant.analyze('변사 피살').isDeathScene, isTrue);
    });
    test('warnings 비어있지 않음 훼손', () {
      expect(SgpForensicAssistant.analyze('변사 현장 훼손').warnings, isNotEmpty);
    });
    test('intact 통제선+변사', () {
      final r = SgpForensicAssistant.analyze(
        '변사 통제선',
        policeLineDeclared: true,
      );
      expect(r.integrityStatus, SceneIntegrityStatus.intact);
    });
    test('art222 상수', () {
      expect(SgpForensicAssistant.art222, contains('제222조'));
    });
    test('adminHandover 온톨로지', () {
      expect(
        SgpForensicAssistant.analyze('변사 행정 변사').ontologyNodes,
        contains('KR-FORENSIC-ADMIN-HANDOVER'),
      );
    });
  });

  group('S13 Custody Extended (25)', () {
    test('신병 확보', () {
      expect(SgpCustodyManagement.assess('신병 확보 유치').isCustodyContext, isTrue);
    });
    test('구속 신병', () {
      expect(SgpCustodyManagement.assess('구속 신병').isCustodyContext, isTrue);
    });
    test('변호인 권리', () {
      final r = SgpCustodyManagement.assess('유치 변호인 권리 고지');
      expect(r.issues, isNot(contains(CustodyIntegrityIssue.missingRightsNotice)));
    });
    test('묵비권 고지', () {
      final r = SgpCustodyManagement.assess('유치 묵비권');
      expect(r.issues, isNot(contains(CustodyIntegrityIssue.missingRightsNotice)));
    });
    test('신체검사 실시', () {
      final r = SgpCustodyManagement.assess(
        '유치',
        bodySearchCompleted: true,
        rightsNoticeGiven: true,
        seizureListComplete: true,
      );
      expect(r.issues, isNot(contains(CustodyIntegrityIssue.incompleteBodySearch)));
    });
    test('극단 선택 고위험', () {
      expect(
        SgpCustodyManagement.assess('유치 극단 선택').riskLevel,
        CustodyRiskLevel.suicideHighRisk,
      );
    });
    test('손목 자해', () {
      expect(
        SgpCustodyManagement.assess('유치 손목 긋').riskLevel,
        CustodyRiskLevel.selfHarmRisk,
      );
    });
    test('specialGuardAssigned 해제 이슈', () {
      final r = SgpCustodyManagement.assess(
        '유치 자살',
        specialGuardAssigned: true,
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.issues, isNot(contains(CustodyIntegrityIssue.specialGuardNotAssigned)));
    });
    test('48h rem not null', () {
      final t0 = DateTime(2026, 6, 1);
      final r = SgpCustodyManagement.assess(
        '유치',
        custodyStart: t0,
        now: t0.add(const Duration(hours: 1)),
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.hoursRemaining48h, isNotNull);
    });
    test('구급 의료', () {
      expect(
        SgpCustodyManagement.assess('유치 구급 의료').ontologyNodes,
        contains('KR-CUSTODY-MEDICAL-CHAIN'),
      );
    });
    test('응급 처치', () {
      final r = SgpCustodyManagement.assess('유치 응급 처치');
      expect(r.warnings.any((w) => w.contains('의료')), isTrue);
    });
    test('BodySearchLevel patDown', () {
      final r = SgpCustodyManagement.assess('유치 신체검사');
      expect(r.bodySearchLevel, isNot(BodySearchLevel.none));
    });
    test('compute48h zero', () {
      final t0 = DateTime(2026, 1, 1);
      expect(
        SgpCustodyManagement.compute48hRemaining(
          custodyStart: t0,
          now: t0.add(const Duration(hours: 50)),
        ),
        Duration.zero,
      );
    });
    test('hasCriticalIssue special guard', () {
      expect(
        SgpCustodyManagement.assess('유치 자살').hasCriticalIssue,
        isTrue,
      );
    });
    test('no critical standard', () {
      final r = SgpCustodyManagement.assess(
        '유치',
        rightsNoticeGiven: true,
        bodySearchCompleted: true,
        seizureListComplete: true,
      );
      expect(r.hasCriticalIssue, isFalse);
    });
    test('warnings 권리', () {
      expect(
        SgpCustodyManagement.assess('유치').warnings.any((w) => w.contains('권리')),
        isTrue,
      );
    });
    test('warnings 신체검사', () {
      expect(
        SgpCustodyManagement.assess('유치').warnings.any((w) => w.contains('신체검사')),
        isTrue,
      );
    });
    test('warnings 압수', () {
      expect(
        SgpCustodyManagement.assess('유치').warnings.any((w) => w.contains('압수')),
        isTrue,
      );
    });
    test('warnings 특별계호', () {
      expect(
        SgpCustodyManagement.assess('유치 자해').warnings.any((w) => w.contains('특별계호')),
        isTrue,
      );
    });
    test('피의자 유치', () {
      expect(SgpCustodyManagement.assess('피의자 유치').isCustodyContext, isTrue);
    });
    test('입감 키워드', () {
      expect(SgpCustodyManagement.assess('입감').isCustodyContext, isTrue);
    });
    test('standard risk label', () {
      expect(CustodyRiskLevel.standard.label, '일반');
    });
    test('suicide label', () {
      expect(CustodyRiskLevel.suicideHighRisk.label, '자살 고위험');
    });
    test('stripSearch label', () {
      expect(BodySearchLevel.stripSearch.label, contains('살촕'));
    });
    test('cctvFocus label', () {
      expect(SpecialGuardInterval.cctvFocus.label, contains('CCTV'));
    });
  });
}
