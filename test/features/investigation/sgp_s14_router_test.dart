import 'dart:io';

import 'package:sgp_agent/features/agent/sgp_kgrag_loader.dart';
import 'package:sgp_agent/features/investigation/modules/sgp_death_logic_hub.dart';
import 'package:test/test.dart';

SgpDeathLogicHub _hub() {
  final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
  final pack = SgpKgragLoader.parsePack(json);
  return SgpDeathLogicHub(SgpKgragLoader.buildVectorIndex(pack));
}

void main() {
  group('S14 Death Logic Hub route decisions (15)', () {
    test('has_foul_play true routes criminal', () {
      final r = _hub().processDeathCase({
        'case_id': 'D-001',
        'narrative': '112 변사 신고 타살 의심',
        'has_foul_play': true,
      });
      expect(r.route, SgpDeathCaseRoute.investigationCriminal);
    });

    test('has_foul_play false routes administrative', () {
      final r = _hub().processDeathCase({
        'case_id': 'D-002',
        'narrative': '112 변사 신고 자연사 추정',
        'has_foul_play': false,
      });
      expect(r.route, SgpDeathCaseRoute.administrativeClose);
    });

    test('타살 text routes criminal without explicit flag', () {
      final r = _hub().processDeathCase({'narrative': '변사 타살 의심'});
      expect(r.requiresAutopsyWarrant, isTrue);
    });

    test('흉기 text routes criminal', () {
      final r = _hub().processDeathCase({'narrative': '시신 주변 흉기 발견'});
      expect(r.route.code, 'INVESTIGATION_CRIMINAL');
    });

    test('질병사 text routes administrative', () {
      final r = _hub().processDeathCase({'narrative': '변사 질병사 유족 인도'});
      expect(r.isAdministrativeClose, isTrue);
    });

    test('노환 text routes administrative', () {
      final r = _hub().processDeathCase({'narrative': '사망 노환 병사 장례'});
      expect(r.documentTemplate, contains('사체 인도서'));
    });

    test('목 조름 routes autopsy', () {
      final r = _hub().processDeathCase({'narrative': '변사 목 조름 의심'});
      expect(r.documentTemplate, contains('부검'));
    });

    test('방화 routes autopsy', () {
      final r = _hub().processDeathCase({'narrative': '변사 방화 흔적'});
      expect(r.actionRequired, contains('강력계'));
    });

    test('피 흔적 routes autopsy', () {
      final r = _hub().processDeathCase({'narrative': '사체 주변 피 흔적'});
      expect(r.applicableLaw, contains('형사소송법'));
    });

    test('case id preserved snake case', () {
      final r = _hub().processDeathCase({
        'case_id': 'CASE-777',
        'narrative': '변사 질병사',
        'has_foul_play': false,
      });
      expect(r.caseId, 'CASE-777');
    });

    test('case id preserved camel case', () {
      final r = _hub().processDeathCase({
        'caseId': 'CASE-778',
        'narrative': '변사 타살',
      });
      expect(r.caseId, 'CASE-778');
    });

    test('toMap route code', () {
      final r = _hub().processDeathCase({'narrative': '변사 타살'});
      expect(r.toMap()['route'], 'INVESTIGATION_CRIMINAL');
    });

    test('administrative law label', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 자연사 유족 인도',
        'has_foul_play': false,
      });
      expect(r.applicableLaw, contains('변사자 처리 규칙'));
    });

    test('criminal law label', () {
      final r = _hub().processDeathCase({'narrative': '변사 피살'});
      expect(r.applicableLaw, contains('제222조'));
    });

    test('forensic result is attached', () {
      final r = _hub().processDeathCase({'narrative': '112 변사 신고'});
      expect(r.forensicResult.isDeathScene, isTrue);
    });
  });

  group('S14 Field checklist and offline handoff (10)', () {
    test('field checklist contains police line', () {
      final r = _hub().processDeathCase({'narrative': '112 변사 신고'});
      expect(r.fieldChecklist.first, contains('폴리스라인'));
    });

    test('field checklist contains KCSI movement ban', () {
      final r = _hub().processDeathCase({'narrative': '112 변사 신고'});
      expect(r.fieldChecklist.any((e) => e.contains('임의 이동 금지')), isTrue);
    });

    test('field checklist contains witness recording', () {
      final r = _hub().processDeathCase({'narrative': '112 변사 신고'});
      expect(r.fieldChecklist.any((e) => e.contains('녹음창')), isTrue);
    });

    test('missing police line adds warning', () {
      final r = _hub().processDeathCase({'narrative': '변사 신고'});
      expect(r.fieldChecklist.any((e) => e.contains('통제선 미설치')), isTrue);
    });

    test('police line removes missing warning', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 신고 통제선 설치',
      });
      expect(r.fieldChecklist.any((e) => e.contains('통제선 미설치')), isFalse);
    });

    test('missing evidence adds warning', () {
      final r = _hub().processDeathCase({'narrative': '변사 신고'});
      expect(r.fieldChecklist.any((e) => e.contains('증거/현장 보존')), isTrue);
    });

    test('evidence preserved removes warning', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 신고 현장 보존 사진 촬영 유류품 봉인',
      });
      expect(r.fieldChecklist.any((e) => e.contains('미완료')), isFalse);
    });

    test('missing witness adds warning', () {
      final r = _hub().processDeathCase({'narrative': '변사 신고'});
      expect(r.fieldChecklist.any((e) => e.contains('최초 진술 확보')), isTrue);
    });

    test('complete field packet makes handoff ready', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 통제선 현장 보존 최초 발견자 진술 녹음',
      });
      expect(r.offlineHandoffReady, isTrue);
    });

    test('explicit offline handoff request makes ready', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 신고',
        'offline_handoff_requested': true,
      });
      expect(r.offlineHandoffReady, isTrue);
    });
  });

  group('S14 Investigation guides and documents (10)', () {
    test('guides contain route inference', () {
      final r = _hub().processDeathCase({'narrative': '변사 타살'});
      expect(r.investigationGuides.first, contains('행정 변사'));
    });

    test('guides contain prosecutor command form', () {
      final r = _hub().processDeathCase({'narrative': '변사 타살'});
      expect(r.investigationGuides.any((e) => e.contains('검시 지휘')), isTrue);
    });

    test('guides contain anti-corruption shield', () {
      final r = _hub().processDeathCase({'narrative': '변사 타살'});
      expect(r.investigationGuides.any((e) => e.contains('감찰 방패')), isTrue);
    });

    test('criminal action button guide', () {
      final r = _hub().processDeathCase({'narrative': '변사 살해'});
      expect(r.investigationGuides.last, contains('부검 지휘'));
    });

    test('administrative action guide', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 질병사',
        'has_foul_play': false,
      });
      expect(r.investigationGuides.last, contains('검시 보고서'));
    });

    test('criminal document template', () {
      final r = _hub().processDeathCase({'narrative': '변사 둔기'});
      expect(r.documentTemplate, '사체 부검 영장 신청서 초안');
    });

    test('administrative document template', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 병사 장례',
        'has_foul_play': false,
      });
      expect(r.documentTemplate, '사체 인도서 및 검시 보고서');
    });

    test('criminal action required', () {
      final r = _hub().processDeathCase({'narrative': '변사 출혈 정황'});
      expect(r.actionRequired, contains('사법 변사'));
    });

    test('administrative action required', () {
      final r = _hub().processDeathCase({
        'narrative': '변사 자연사',
        'has_foul_play': false,
      });
      expect(r.actionRequired, contains('유족 인도'));
    });

    test('toMap includes document template', () {
      final r = _hub().processDeathCase({'narrative': '변사 타살'});
      expect(r.toMap()['document_template'], contains('부검'));
    });
  });

  group('S14 KG-RAG corpus and vector linkage (10)', () {
    test('S14 20 precedent seeds exist', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      final s14 = pack.precedents.where((p) => p.id.contains('S14-DEATH'));
      expect(s14.length, 20);
    });

    test('target corpus remains 800', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      expect(pack.targetCorpusSize, 800);
    });

    test('vector index still expands to 800', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      expect(SgpKgragLoader.buildVectorIndex(pack).corpusSize, 800);
    });

    test('police line precedent is searchable', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      final store = SgpKgragLoader.buildVectorIndex(pack);
      final hits = store.search('변사 폴리스라인 통제선 증거능력', minScore: 0.05);
      expect(hits.any((h) => h.record.id.contains('S14-DEATH')), isTrue);
    });

    test('autopsy precedent is searchable', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      final store = SgpKgragLoader.buildVectorIndex(pack);
      final hits = store.search('부검영장 타살 의심 변사', minScore: 0.05);
      expect(hits, isNotEmpty);
    });

    test('decision carries precedent matches', () {
      final r = _hub().processDeathCase({'narrative': '변사 폴리스라인 통제선'});
      expect(r.precedentMatches, isNotEmpty);
    });

    test('decision map carries precedent matches', () {
      final r = _hub().processDeathCase({'narrative': '변사 부검영장'});
      expect(r.toMap()['precedent_matches'], isA<List<dynamic>>());
    });

    test('S14 false report seed exists', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      expect(
        pack.precedents.any((p) => p.domain == 'false_examination_report'),
        isTrue,
      );
    });

    test('S14 offline handoff seed exists', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      expect(
        pack.precedents.any((p) => p.domain == 'offline_death_handoff'),
        isTrue,
      );
    });

    test('S14 document builder seed exists', () {
      final json = File('assets/data/kgrag_precedents.json').readAsStringSync();
      final pack = SgpKgragLoader.parsePack(json);
      expect(
        pack.precedents.any((p) => p.domain == 'death_document_builder'),
        isTrue,
      );
    });
  });

  group('S14 Router source contract (5)', () {
    final source = File(
      'lib/features/investigation/screens/sgp_death_scene_router.dart',
    ).readAsStringSync();

    test('router class exists', () {
      expect(source, contains('class SgpDeathSceneRouter'));
    });

    test('field panel class exists', () {
      expect(source, contains('class SgpFieldDeathPanel'));
    });

    test('investigation panel class exists', () {
      expect(source, contains('class SgpInvestigationDeathPanel'));
    });

    test('field mode branch exists', () {
      expect(source, contains('SgpOperationalMode.field'));
    });

    test('offline handoff button text exists', () {
      expect(source, contains('오프라인 인계'));
    });
  });
}
