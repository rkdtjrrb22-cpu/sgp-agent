import 'dart:convert';
import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_civil_complaint_data.dart';
import 'package:sgp_agent/features/agent/sgp_civil_complaint_router.dart';
import 'package:sgp_agent/features/agent/sgp_kgrag_loader.dart';
import 'package:sgp_agent/features/agent/sgp_kgrag_router.dart';
import 'package:sgp_agent/features/agent/sgp_legal_hierarchy.dart';
import 'package:sgp_agent/features/agent/sgp_legal_ontology.dart';
import 'package:sgp_agent/features/agent/sgp_statute_domain_engine.dart';
import 'package:sgp_agent/features/control/sgp_anti_corruption_filter.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // Anti-Corruption Shield (내부 감찰 통제)
  // -------------------------------------------------------------------------
  group('S11 Anti-Corruption Shield', () {
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
      expect(flag.ontologyNodes, contains('KR-CRIM-155-EVIDENCE'));
    });

    test('수사기밀 유출(자취방 비밀번호 인계) → 공무상비밀누설 CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '피의자 가족에게 자취방 비밀번호를 알려주었다',
      );
      expect(a.flags.any((f) => f.id == 'AC-SECRET-LEAK'), isTrue);
      expect(a.hasCritical, isTrue);
    });

    test('허위공문서작성(압수목록 누락) CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '압수목록 누락된 채로 조서를 허위 작성했다',
      );
      expect(a.flags.any((f) => f.id == 'AC-FALSE-DOCUMENT'), isTrue);
    });

    test('강압수사(욕설·폭언 진술 강요) → 독직폭행 CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '욕설과 폭언으로 자백을 강요했다',
      );
      expect(a.flags.any((f) => f.id == 'AC-COERCION'), isTrue);
      expect(a.hasCritical, isTrue);
    });

    test('직권남용 정황 WARNING', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '직권남용으로 의무없는 일을 하게 했다',
      );
      final flag = a.flags.firstWhere((f) => f.id == 'AC-ABUSE-OF-AUTHORITY');
      expect(flag.severity, AntiCorruptionSeverity.warning);
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
      expect(a.terminalBanner, isNull);
    });

    test('압수물 목록 누락 정황(SeizureContext) CRITICAL', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: '압수를 진행했다',
        seizure: const SeizureExecutionContext(
          digitalEvidenceLogged: false,
          evidenceListAttached: false,
        ),
      );
      expect(a.flags.any((f) => f.id == 'AC-SEIZURE-LIST-OMISSION'), isTrue);
      expect(a.hasCritical, isTrue);
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

    test('terminalBanner 네온레드 문구 포함', () {
      final a = SgpAntiCorruptionFilter.assess(
        documentText: 'CCTV 흑백 전환하고 증거물 유출했다',
      );
      expect(a.terminalBanner, contains('파면·해임'));
      expect(a.terminalBanner, contains('ANTI-CORRUPTION'));
    });

    test('네온레드 노출·색상 코드', () {
      final a = SgpAntiCorruptionFilter.assess(documentText: '증거 조작했다');
      expect(a.showsNeonRed, isTrue);
      expect(SgpAntiCorruptionFilter.neonRedHex, 0xFFFF1744);
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
  });

  // -------------------------------------------------------------------------
  // 교통사고처리특례법 — 12대 중과실·공소권 분기
  // -------------------------------------------------------------------------
  group('S11 Traffic Accident (교특법)', () {
    test('신호위반 → 12대 중과실 형사 입건', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('신호위반으로 교통사고를 냈다');
      expect(r.isGrossNegligence, isTrue);
      expect(r.isCriminal, isTrue);
      expect(r.grossNegligence, contains(GrossNegligenceType.signalViolation));
    });

    test('중앙선 침범 → 형사 입건', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('중앙선 침범 사고');
      expect(r.disposition, TrafficDisposition.criminalCharge);
    });

    test('음주운전 사고 → 12대 중과실', () {
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

    test('뺑소니 → 형사 입건(공소권없음 배제)', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('사고 후 구호조치 없이 도주했다');
      expect(r.isCriminal, isTrue);
    });

    test('스쿨존 사고 → 12대 중과실', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('어린이보호구역에서 사고');
      expect(r.grossNegligence, contains(GrossNegligenceType.schoolZone));
    });

    test('보험 미가입 단순사고 → 합의 조건부 형사', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic(
        '접촉사고 났는데 보험이 없다',
        hasComprehensiveInsurance: false,
      );
      expect(r.isCriminal, isTrue);
    });

    test('온톨로지 노드 KR-TSA-12-GROSS', () {
      final r = SgpStatuteDomainEngine.analyzeTraffic('신호위반 교통사고');
      expect(r.ontologyNodes, contains('KR-TSA-12-GROSS'));
    });

    test('도메인 감지 trafficAccident', () {
      expect(
        SgpStatuteDomainEngine.detectDomain('교통사고 접촉사고'),
        StatuteDomain.trafficAccident,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 스토킹처벌법 — 지속성·반복성 + 조치 타임라인
  // -------------------------------------------------------------------------
  group('S11 Stalking (스토킹처벌법)', () {
    test('반복적 접근 → 지속성 충족', () {
      final r = SgpStatuteDomainEngine.analyzeStalking(
        '매일 계속 따라다니고 반복해서 찾아온다',
      );
      expect(r.persistenceMet, isTrue);
      expect(r.isStalkingCrime, isTrue);
    });

    test('일회성 → 지속성 미충족·응급조치', () {
      final r = SgpStatuteDomainEngine.analyzeStalking(
        '한 번 찾아왔다',
        explicitRepetitionCount: 1,
      );
      expect(r.persistenceMet, isFalse);
      expect(r.recommendedStage, StalkingMeasureStage.emergency);
    });

    test('흉기·위해 우려 → 잠정조치 제4호(유치장)', () {
      final r = SgpStatuteDomainEngine.analyzeStalking(
        '계속 반복해서 찾아오며 흉기로 협박한다',
      );
      expect(r.recommendedStage, StalkingMeasureStage.provisionalDetention);
      expect(r.ontologyNodes, contains('KR-STALK-PROVISIONAL'));
    });

    test('재발·불응 → 잠정조치', () {
      final r = SgpStatuteDomainEngine.analyzeStalking(
        '접근금지에도 불응하고 다시 접근하며 반복 연락',
      );
      expect(r.recommendedStage, StalkingMeasureStage.provisional);
    });

    test('지속성 충족 기본 → 긴급응급조치', () {
      final r = SgpStatuteDomainEngine.analyzeStalking(
        '자꾸 반복해서 문자를 보낸다',
      );
      expect(r.recommendedStage, StalkingMeasureStage.urgentTemporary);
    });

    test('명시적 반복 횟수 반영', () {
      final r = SgpStatuteDomainEngine.analyzeStalking(
        '스토킹 신고',
        explicitRepetitionCount: 5,
      );
      expect(r.repetitionCount, 5);
      expect(r.persistenceMet, isTrue);
    });

    test('온톨로지 노드 KR-STALK-PERSISTENCE', () {
      final r = SgpStatuteDomainEngine.analyzeStalking('계속 반복 미행');
      expect(r.ontologyNodes, contains('KR-STALK-PERSISTENCE'));
    });

    test('도메인 감지 stalking', () {
      expect(
        SgpStatuteDomainEngine.detectDomain('전 남친이 계속 미행하고 감시해요'),
        StatuteDomain.stalking,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 소년법 — 연령별 판정·소년부 송치
  // -------------------------------------------------------------------------
  group('S11 Juvenile (소년법)', () {
    test('8세 → 범법소년(형사·보호처분 아님)', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(8);
      expect(r.category, JuvenileCategory.beombeop);
      expect(r.requiresFamilyCourtTransfer, isFalse);
      expect(r.criminalPunishable, isFalse);
    });

    test('12세 → 촉법소년(소년부 송치)', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(12);
      expect(r.category, JuvenileCategory.chokbeop);
      expect(r.requiresFamilyCourtTransfer, isTrue);
      expect(r.criminalPunishable, isFalse);
    });

    test('14세 → 범죄소년(형사처벌 가능)', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(14);
      expect(r.category, JuvenileCategory.crimeJuvenile);
      expect(r.criminalPunishable, isTrue);
    });

    test('20세 → 성인(소년법 미적용)', () {
      final r = SgpStatuteDomainEngine.analyzeJuvenile(20);
      expect(r.category, JuvenileCategory.adult);
      expect(r.requiresFamilyCourtTransfer, isFalse);
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
      expect(r.ontologyNodes, contains('KR-JUV-PROTECTIVE-ORDER'));
    });

    test('연령 텍스트 추출 "만 13세"', () {
      expect(SgpStatuteDomainEngine.extractAge('만 13세 학생'), 13);
    });

    test('연령 텍스트 추출 "15살"', () {
      expect(SgpStatuteDomainEngine.extractAge('15살 청소년'), 15);
    });

    test('도메인 감지 juvenile', () {
      expect(
        SgpStatuteDomainEngine.detectDomain('촉법소년 중학생 사건'),
        StatuteDomain.juvenile,
      );
    });
  });

  // -------------------------------------------------------------------------
  // KG-RAG 700 코퍼스 + 신규 도메인 판례 매칭
  // -------------------------------------------------------------------------
  group('S11 KG-RAG 700 Corpus & Ontology', () {
    late KgragPrecedentPack pack;
    late List<LegalHierarchyNode> seedNodes;

    setUp(() {
      final kgragJson =
          File('assets/data/kgrag_precedents.json').readAsStringSync();
      pack = SgpKgragLoader.parsePack(kgragJson);
      final seedJson =
          File('assets/data/legal_hierarchy_seed.json').readAsStringSync();
      seedNodes = (jsonDecode(seedJson) as List<dynamic>)
          .map((e) => LegalHierarchyNode.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('target_corpus_size 700', () {
      expect(pack.targetCorpusSize, 700);
    });

    test('벡터 인덱스 700종 구축', () {
      final store = SgpKgragLoader.buildVectorIndex(pack);
      expect(store.corpusSize, 700);
    });

    test('교특법 판례 시드 존재', () {
      expect(
        pack.precedents.any((p) => p.id == 'SC-2024-TRAFFIC-SIGNAL'),
        isTrue,
      );
    });

    test('스토킹 잠정조치 판례 시드 존재', () {
      expect(
        pack.precedents.any((p) => p.id == 'SC-2024-STALK-PROVISIONAL'),
        isTrue,
      );
    });

    test('소년법 촉법소년 판례 시드 존재', () {
      expect(
        pack.precedents.any((p) => p.id == 'SC-2024-JUV-CHOKBEOP'),
        isTrue,
      );
    });

    test('직무범 증거인멸 판례 시드 존재', () {
      expect(
        pack.precedents.any((p) => p.id == 'SC-2024-CORRUPT-EVIDENCE'),
        isTrue,
      );
    });

    test('S11 온톨로지 노드 8종 이상 신설', () {
      final ids = seedNodes.map((n) => n.id).toSet();
      const required = [
        'KR-LAW-TSA',
        'KR-TSA-12-GROSS',
        'KR-STALK-PERSISTENCE',
        'KR-STALK-PROVISIONAL',
        'KR-LAW-JUVENILE',
        'KR-JUV-CHOKBEOP',
        'KR-CRIM-155-EVIDENCE',
        'KR-CRIM-227-FALSEDOC',
        'ORG-POLICE-DISCIPLINE',
      ];
      for (final id in required) {
        expect(ids, contains(id), reason: 'missing $id');
      }
    });

    test('KG-RAG 신호위반 판례 매칭', () {
      final store = SgpKgragLoader.buildVectorIndex(pack);
      final hits = store.search('신호위반 교통사고 12대 중과실', topK: 5);
      expect(hits, isNotEmpty);
    });

    test('KG-RAG 증거인멸 판례 매칭', () {
      final store = SgpKgragLoader.buildVectorIndex(pack);
      final hits = store.search('증거인멸 허위공문서작성 수사서류', topK: 5);
      expect(hits, isNotEmpty);
    });

    test('KG-RAG 라우터 교통사고 시나리오 추론', () {
      final ccJson =
          File('assets/data/civil_complaint_nodes.json').readAsStringSync();
      final complaintPack = CivilComplaintNodePack.fromJson(
        jsonDecode(ccJson) as Map<String, dynamic>,
      );
      final base = LegalOntologyMigrator.graphFromNodes(seedNodes);
      final graph = SgpCivilComplaintRouter.mergeComplaintTriples(
        base: base,
        pack: complaintPack,
      );
      final store = SgpKgragLoader.buildVectorIndex(pack);
      final r = SgpKgragRouter.reasonFromText(
        '신호위반으로 교통사고를 냈고 상대방이 다쳤다',
        complaintPack: complaintPack,
        graph: graph,
        vectorStore: store,
      );
      expect(r, isNotNull);
      expect(r!.precedentHits, isNotEmpty);
    });
  });
}
