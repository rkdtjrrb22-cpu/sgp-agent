import 'package:sgp_agent/features/agent/sgp_statute_domain_engine.dart';
import 'package:sgp_agent/features/control/sgp_anti_corruption_filter.dart';
import 'package:sgp_agent/features/investigation/sgp_arrest_timeline_phase.dart';
import 'package:test/test.dart';

/// S11 — 3대 특수법 30종 + 감찰/신분범 20종 (총 50).
void main() {
  group('S11 Anti-Corruption / 신분범 (20)', () {
    test('CCTV 컬러→흑백 전환 → 증거인멸 CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: 'CCTV 컬러화면을 흑백으로 전환하여 제출했다',
      );
      expect(a.hasCritical, isTrue);
      expect(a.flags.any((f) => f.id == 'AC-EVIDENCE-TAMPER'), isTrue);
    });

    test('증거인멸 플래그 형법 제155조 근거', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '증거를 은닉했다');
      final flag = a.flags.firstWhere((f) => f.id == 'AC-EVIDENCE-TAMPER');
      expect(flag.legalBasis.any((b) => b.contains('제155조')), isTrue);
    });

    test('수사기밀 유출 → 공무상비밀누설 CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '피의자 가족에게 자취방 비밀번호를 알려주었다',
      );
      expect(a.flags.any((f) => f.id == 'AC-SECRET-LEAK'), isTrue);
    });

    test('허위공문서작성(압수목록 누락) CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '압수목록 누락된 채로 조서를 허위 작성했다',
      );
      expect(a.flags.any((f) => f.id == 'AC-FALSE-DOCUMENT'), isTrue);
    });

    test('강압수사(욕설·폭언) → 독직폭행 CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '욕설과 폭언으로 자백을 강요했다',
      );
      expect(a.flags.any((f) => f.id == 'AC-COERCION'), isTrue);
    });

    test('직권남용 정황 WARNING', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '직권남용으로 의무없는 일을 하게 했다',
      );
      expect(a.flags.firstWhere((f) => f.id == 'AC-ABUSE-OF-AUTHORITY').severity,
          AntiCorruptionSeverity.warning);
    });

    test('직무유기 정황 WARNING', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '신고를 묵살하고 방치했다');
      expect(a.flags.any((f) => f.id == 'AC-DERELICTION'), isTrue);
    });

    test('정상 서류는 clean', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '현장에 출동하여 피해자를 안전하게 보호하고 적법하게 조사했다',
      );
      expect(a.isClean, isTrue);
    });

    test('압수물 목록 누락(SeizureContext) CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '압수를 진행했다',
        seizure: const SeizureExecutionContext(
          digitalEvidenceLogged: false,
          evidenceListAttached: false,
        ),
      );
      expect(a.flags.any((f) => f.id == 'AC-SEIZURE-LIST-OMISSION'), isTrue);
    });

    test('영장 집행 시한·서명 하자 WARNING', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '수색을 진행했다',
        seizure: const SeizureExecutionContext(
          warrantExecutionWithinDeadline: false,
          participantSignaturePresent: false,
        ),
      );
      expect(a.flags.any((f) => f.id == 'AC-WARRANT-PROCEDURE'), isTrue);
    });

    test('terminalBanner 네온레드 문구', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: 'CCTV 흑백 전환하고 증거물 유출했다',
      );
      expect(a.terminalBanner, contains('파면·해임'));
    });

    test('네온레드 색상 코드 #FF1744', () {
      expect(SgpAntiCorruptionFilter.neonRedHex, 0xFFFF1744);
      final a = SgpAntiCorruptionFilter.assess(documentText: '증거 조작했다');
      expect(a.showsNeonRed, isTrue);
    });

    test('topSeverity critical > warning', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '직무유기 방치하고 증거를 조작했다',
      );
      expect(a.topSeverity, AntiCorruptionSeverity.critical);
    });

    test('disciplineWarning 파면·해임 명시', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '증거 인멸했다');
      expect(a.disciplineWarning, contains('파면'));
    });

    test('복합 위반 다중 플래그', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '수사기밀을 유출하고 CCTV를 흑백 전환했으며 폭언으로 진술을 강요했다',
      );
      expect(a.flags.length, greaterThanOrEqualTo(3));
    });

    test('경찰공무원법 제56조 성실의무 연계', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '증거를 조작 은닉했다');
      final flag = a.flags.firstWhere((f) => f.id == 'AC-EVIDENCE-TAMPER');
      expect(flag.disciplineBasis.any((b) => b.contains('제56조')), isTrue);
    });

    test('형법 제125조 독직폭행 키워드', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '욕설과 폭언으로 진술을 강요했다');
      expect(a.flags.any((f) => f.legalBasis.any((b) => b.contains('제125조'))), isTrue);
    });

    test('형법 제127조 직권남용 키워드', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '직권남용으로 부당하게 압수했다');
      expect(a.flags.any((f) => f.id == 'AC-ABUSE-OF-AUTHORITY'), isTrue);
    });

    test('디지털 증거 미기록 CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '휴대폰을 압수했다',
        seizure: const SeizureExecutionContext(digitalEvidenceLogged: false),
      );
      expect(a.hasCritical, isTrue);
    });

    test('감찰 배너 ANTI-CORRUPTION 태그', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '증거를 조작 은닉했다');
      expect(a.terminalBanner, contains('ANTI-CORRUPTION'));
    });
  });

  group('S11 Traffic 교특법 (10)', () {
    test('신호위반 → 12대 중과실', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('신호위반으로 교통사고를 냈다');
      expect(r.grossNegligence, contains(GrossNegligenceType.signalViolation));
      expect(r.isCriminal, isTrue);
    });

    test('중앙선 침범 → 형사 입건', () {
      expect(
        SgpStatuteDomainEngine.analyzeTraffic('중앙선 침범 사고').disposition,
        TrafficDisposition.criminalCharge,
      );
    });

    test('음주운전 → 12대 중과실', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('음주운전 상태로 추돌사고');
      expect(r.grossNegligence, contains(GrossNegligenceType.drunkDriving));
    });

    test('무면허 → 12대 중과실', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('무면허로 운전하다 사고');
      expect(r.grossNegligence, contains(GrossNegligenceType.unlicensed));
    });

    test('종합보험 + 단순과실 → 공소권 없음', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic(
        '종합보험 가입되어 있고 단순 접촉사고',
        hasComprehensiveInsurance: true,
      );
      expect(r.disposition, TrafficDisposition.noProsecution);
    });

    test('뺑소니 → 형사 입건', () {
      expect(
        SgpStatuteDomainEngine.analyzeTraffic('사고 후 구호조치 없이 도주했다').isCriminal,
        isTrue,
      );
    });

    test('스쿨존 사고 → 12대 중과실', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('어린이보호구역에서 사고');
      expect(r.grossNegligence, contains(GrossNegligenceType.schoolZone));
    });

    test('보험 미가입 → 형사', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic(
        '접촉사고 났는데 보험이 없다',
        hasComprehensiveInsurance: false,
      );
      expect(r.isCriminal, isTrue);
    });

    test('온톨로지 KR-TSA-12-GROSS', () {
      expect(
        SgpStatuteDomainEngine.analyzeTraffic('신호위반 교통사고').ontologyNodes,
        contains('KR-TSA-12-GROSS'),
      );
    });

    test('도메인 감지 trafficAccident', () {
      expect(
        SgpStatuteDomainEngine.detectDomain('교통사고 접촉사고'),
        StatuteDomain.trafficAccident,
      );
    });
  });

  group('S11 Stalking 스토킹처벌법 (8)', () {
    test('반복적 접근 → 지속성 충족', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('매일 계속 따라다니고 반복해서 찾아온다');
      expect(r.persistenceMet, isTrue);
      expect(r.isStalkingCrime, isTrue);
    });

    test('일회성 → 응급조치', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('한 번 찾아왔다', explicitRepetitionCount: 1);
      expect(r.persistenceMet, isFalse);
      expect(r.recommendedStage, StalkingMeasureStage.emergency);
    });

    test('흉기 협박 → 잠정조치 제4호', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('계속 반복해서 찾아오며 흉기로 협박한다');
      expect(r.recommendedStage, StalkingMeasureStage.provisionalDetention);
    });

    test('재발·불응 → 잠정조치', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('접근금지에도 불응하고 다시 접근하며 반복 연락');
      expect(r.recommendedStage, StalkingMeasureStage.provisional);
    });

    test('지속성 충족 → 긴급응급조치', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('자꾸 반복해서 문자를 보낸다');
      expect(r.recommendedStage, StalkingMeasureStage.urgentTemporary);
    });

    test('명시적 반복 횟수 반영', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('스토킹 신고', explicitRepetitionCount: 5);
      expect(r.repetitionCount, 5);
      expect(r.persistenceMet, isTrue);
    });

    test('온톨로지 KR-STALK-PERSISTENCE', () {
      expect(
        SgpStatuteDomainEngine.analyzeStalking('계속 반복 미행').ontologyNodes,
        contains('KR-STALK-PERSISTENCE'),
      );
    });

    test('도메인 감지 stalking', () {
      expect(
        SgpStatuteDomainEngine.detectDomain('전 남친이 계속 미행하고 감시해요'),
        StatuteDomain.stalking,
      );
    });
  });

  group('S11 Juvenile 소년법 (12)', () {
    test('8세 → 범법소년', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(8);
      expect(r.category, JuvenileCategory.beombeop);
      expect(r.criminalPunishable, isFalse);
    });

    test('12세 → 촉법소년·소년부 송치', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(12);
      expect(r.category, JuvenileCategory.chokbeop);
      expect(r.requiresFamilyCourtTransfer, isTrue);
    });

    test('14세 → 범죄소년', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(14);
      expect(r.category, JuvenileCategory.crimeJuvenile);
      expect(r.criminalPunishable, isTrue);
    });

    test('20세 → 성인', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(20);
      expect(r.category, JuvenileCategory.adult);
    });

    test('경계값 10세 → 촉법소년', () {
      expect(SgpStatuteDomainEngine.categorize(10), JuvenileCategory.chokbeop);
    });

    test('경계값 13세 → 촉법소년', () {
      expect(SgpStatuteDomainEngine.categorize(13), JuvenileCategory.chokbeop);
    });

    test('경계값 18세 → 범죄소년', () {
      expect(SgpStatuteDomainEngine.categorize(18), JuvenileCategory.crimeJuvenile);
    });

    test('촉법소년 온톨로지 노드', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(13);
      expect(r.ontologyNodes, contains('KR-JUV-CHOKBEOP'));
    });

    test('연령 추출 "만 13세"', () {
      expect(SgpStatuteDomainEngine.extractAge('만 13세 학생'), 13);
    });

    test('연령 추출 "15살"', () {
      expect(SgpStatuteDomainEngine.extractAge('15살 청소년'), 15);
    });

    test('도메인 감지 juvenile', () {
      expect(
        SgpStatuteDomainEngine.detectDomain('촉법소년 중학생 사건'),
        StatuteDomain.juvenile,
      );
    });

    test('48h 타임라인 GREEN→YELLOW→RED 단계', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(
        resolveArrestBarPhase(t0: t0, now: t0.add(const Duration(hours: 10))),
        ArrestTimelineBarPhase.safe,
      );
      expect(
        resolveArrestBarPhase(t0: t0, now: t0.add(const Duration(hours: 45, minutes: 30))),
        ArrestTimelineBarPhase.warrantReview,
      );
      expect(
        resolveArrestBarPhase(t0: t0, now: t0.add(const Duration(hours: 47))),
        ArrestTimelineBarPhase.critical,
      );
    });
  });
}
