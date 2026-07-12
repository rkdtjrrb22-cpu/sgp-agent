import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sgp_agent/features/agent/sgp_kgrag_router.dart';
import 'package:sgp_agent/features/investigation/modules/sgp_mock_defense_engine.dart';
import 'package:sgp_agent/features/security/sgp_secure_crypto.dart';
import 'package:test/test.dart';

MockDefenseAnalyzeInput _input(
  String text, {
  MockDefenseChecklist checklist = const MockDefenseChecklist(),
  bool evidenceNoticeComplete = false,
}) =>
    MockDefenseAnalyzeInput(
      rawText: text,
      checklist: checklist,
      evidenceNoticeComplete: evidenceNoticeComplete,
    );

KgragReasoningResult _kgrag({
  double selfDef = 0.55,
  bool guard = true,
}) =>
    KgragReasoningResult(
      query: 'test',
      ontologyShield: const KgragOntologyShield(legalNodeIds: [], triples: []),
      precedentHits: const [],
      promptContext: '',
      recommendedAction: '',
      selfDefenseProbability: selfDef,
      confidenceLabel: 'test',
      matchedCorpusCount: 3,
      hallucinationGuardPass: guard,
      confidence: 0.5,
    );

void main() {
  group('S13 Mock Defense — fleeing/residence (10)', () {
    test('도주 정황 + 주거 미기재 → critical', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('피의자 도주 우려'),
      );
      expect(r.overallRisk, MockDefenseRiskLevel.critical);
      expect(r.tackles.any((t) => t.id == 'MD-FLEE-RESIDENCE'), isTrue);
    });

    test('도주 체크리스트 + 주거 확인 → warning', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input(
          '주거 확인 등본',
          checklist: const MockDefenseChecklist(isFleeing: true),
        ),
      );
      expect(r.tackles.any((t) => t.riskLevel == MockDefenseRiskLevel.warning), isTrue);
    });

    test('신원 불명 키워드 감지', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('신원 불명'));
      expect(r.tackles.any((t) => t.vulnerability == MockDefenseVulnerability.fleeingAndResidence), isTrue);
    });

    test('허위 주소 → flee axis', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('허위 주소 기재'));
      expect(r.tackles, isNotEmpty);
    });

    test('주소 확인 + 도주 없음 → flee clear', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('주소 확인 실거주 등본 확인 완료'),
      );
      expect(
        r.tackles.any((t) => t.vulnerability == MockDefenseVulnerability.fleeingAndResidence),
        isFalse,
      );
    });

    test('빈 조서 + 체크리스트 도주 → warning 이상', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('', checklist: const MockDefenseChecklist(isFleeing: true)),
      );
      expect(r.tackles, isNotEmpty);
    });

    test('거짓 주소 remediation 포함', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('거짓 주소'));
      final t = r.tackles.firstWhere((x) => x.id == 'MD-FLEE-RESIDENCE');
      expect(t.remediation, contains('등본'));
    });

    test('검사·법원 라인 존재', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('도망'));
      final t = r.tackles.first;
      expect(t.prosecutorLine, isNotEmpty);
      expect(t.courtLine, isNotEmpty);
    });

    test('matchedSignals 비어있지 않음', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('도주'));
      expect(r.tackles.first.matchedSignals, isNotEmpty);
    });

    test('주거 미기재 단독 → warning', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('현행범 체포'));
      expect(
        r.tackles.any((t) =>
            t.vulnerability == MockDefenseVulnerability.fleeingAndResidence &&
            t.riskLevel == MockDefenseRiskLevel.warning),
        isTrue,
      );
    });
  });

  group('S13 Mock Defense — chain of custody (10)', () {
    test('위수증 미언급 → chain critical', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('현장 체포'));
      expect(
        r.tackles.any((t) =>
            t.id == 'MD-CHAIN-CUSTODY' &&
            t.riskLevel == MockDefenseRiskLevel.critical),
        isTrue,
      );
    });

    test('위수증 + 압수 검토 체크 → chain clear', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input(
          '위수증 압수 목록 채증 고지',
          checklist: const MockDefenseChecklist(isSeizureConstraintReviewed: true),
        ),
      );
      expect(
        r.tackles.any((t) => t.vulnerability == MockDefenseVulnerability.chainOfCustody),
        isFalse,
      );
    });

    test('압수목록 키워드만 → warning', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('압수 목록 작성'),
      );
      expect(
        r.tackles.any((t) =>
            t.id == 'MD-CHAIN-CUSTODY' &&
            t.riskLevel == MockDefenseRiskLevel.warning),
        isTrue,
      );
    });

    test('봉인 키워드', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('증거 봉인'));
      expect(r.tackles.any((t) => t.id == 'MD-CHAIN-CUSTODY'), isTrue);
    });

    test('chain remediation 증거능력', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('체포'));
      final t = r.tackles.firstWhere((x) => x.id == 'MD-CHAIN-CUSTODY');
      expect(t.remediation, contains('위수증'));
    });

    test('검사 line 압수', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('체포'));
      final t = r.tackles.firstWhere((x) => x.id == 'MD-CHAIN-CUSTODY');
      expect(t.prosecutorLine, contains('압수'));
    });

    test('법원 line 증거능력', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('체포'));
      final t = r.tackles.firstWhere((x) => x.id == 'MD-CHAIN-CUSTODY');
      expect(t.courtLine, contains('증거'));
    });

    test('체크리스트 압수만 → warning', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input(
          '체포',
          checklist: const MockDefenseChecklist(isSeizureConstraintReviewed: true),
        ),
      );
      expect(
        r.tackles.firstWhere((t) => t.id == 'MD-CHAIN-CUSTODY').riskLevel,
        MockDefenseRiskLevel.warning,
      );
    });

    test('녹화 개시 키워드', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('녹화 개시'));
      expect(r.tackles.any((t) => t.id == 'MD-CHAIN-CUSTODY'), isTrue);
    });

    test('인도 기록 키워드', () {
      final r = SgpMockDefenseEngine.analyze(input: _input('인도 기록'));
      expect(r.tackles.any((t) => t.id == 'MD-CHAIN-CUSTODY'), isTrue);
    });
  });

  group('S13 Mock Defense — force proportionality (10)', () {
    test('과잉 물리력 → critical', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('과잉 물리력 행사'),
        kgrag: _kgrag(),
      );
      expect(
        r.tackles.any((t) =>
            t.id == 'MD-FORCE-PROP' &&
            t.riskLevel == MockDefenseRiskLevel.critical),
        isTrue,
      );
    });

    test('흉기 + 낮은 정당방위 → critical', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('흉기'),
        kgrag: _kgrag(selfDef: 0.2),
      );
      expect(r.overallRisk, MockDefenseRiskLevel.critical);
    });

    test('흉기 체크리스트 → force tackle', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input(
          '위수증 압수 목록',
          checklist: const MockDefenseChecklist(
            isWeaponUsed: true,
            isSeizureConstraintReviewed: true,
          ),
        ),
        kgrag: _kgrag(selfDef: 0.6),
      );
      expect(r.tackles.any((t) => t.id == 'MD-FORCE-PROP'), isTrue);
    });

    test('환각 가드 미통과 → warning', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('위수증 압수 목록 주소 확인'),
        kgrag: _kgrag(guard: false),
      );
      expect(
        r.tackles.any((t) =>
            t.id == 'MD-FORCE-PROP' &&
            t.riskLevel == MockDefenseRiskLevel.warning),
        isTrue,
      );
    });

    test('force remediation CoT', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('과도 force'),
        kgrag: _kgrag(),
      );
      final t = r.tackles.firstWhere((x) => x.id == 'MD-FORCE-PROP');
      expect(t.remediation, contains('KG-RAG'));
    });

    test('테이저 키워드', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('테이저'),
        kgrag: _kgrag(),
      );
      expect(r.tackles.any((t) => t.id == 'MD-FORCE-PROP'), isTrue);
    });

    test('정당방위 확률 낮음 signal', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('삼단 봉'),
        kgrag: _kgrag(selfDef: 0.1),
      );
      expect(
        r.tackles.firstWhere((t) => t.id == 'MD-FORCE-PROP').matchedSignals,
        contains('정당방위 확률 낮음'),
      );
    });

    test('kgrag null + 흉기 없음 → force clear', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input(
          '위수증 압수 목록 주소 확인 등본',
          checklist: const MockDefenseChecklist(isSeizureConstraintReviewed: true),
        ),
      );
      expect(
        r.tackles.any((t) => t.vulnerability == MockDefenseVulnerability.forceProportionality),
        isFalse,
      );
    });

    test('비례 위반 키워드', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('비례 위반'),
        kgrag: _kgrag(),
      );
      expect(r.tackles.any((t) => t.id == 'MD-FORCE-PROP'), isTrue);
    });

    test('overall critical when any axis critical', () {
      final r = SgpMockDefenseEngine.analyze(
        input: _input('도주 과잉 물리력'),
        kgrag: _kgrag(),
      );
      expect(r.overallRisk, MockDefenseRiskLevel.critical);
      expect(r.defenseReady, isFalse);
    });
  });

  group('S13 Secure Crypto kernel (20)', () {
    final key = SgpSecureCrypto.corpusKeyMaterial();
    late String corpusJson;

    setUp(() {
      SgpSecureCrypto.wipeRamCorpus();
      corpusJson = File('assets/data/kgrag_precedents.json').readAsStringSync();
    });

    tearDown(() {
      SgpSecureCrypto.wipeRamCorpus();
    });

    test('corpusKeyMaterial 32 bytes', () {
      expect(key, hasLength(32));
    });

    test('targetCorpusSize 800', () {
      expect(SgpSecureCrypto.targetCorpusSize, 800);
    });

    test('sealCorpus 평문 비노출', () {
      final env = SgpSecureCrypto.sealCorpus(plainJson: corpusJson, key: key);
      expect(env.cipherText.length, greaterThan(32));
      expect(utf8.decode(env.cipherText, allowMalformed: true), isNot(contains('precedents')));
    });

    test('생체인증 성공 → RAM unlock', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      final env = SgpSecureCrypto.sealCorpus(plainJson: corpusJson, key: key);
      await SgpSecureCrypto.unlockCorpusToRam(
        envelope: env,
        key: key,
        biometric: bio,
      );
      expect(SgpSecureCrypto.isCorpusUnlockedInRam, isTrue);
    });

    test('생체인증 실패 → 거부', () async {
      final bio = SgpSimulatedBiometricAuth();
      final env = SgpSecureCrypto.sealCorpus(plainJson: corpusJson, key: key);
      await expectLater(
        () => SgpSecureCrypto.unlockCorpusToRam(
          envelope: env,
          key: key,
          biometric: bio,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('RAM 없이 loadPackFromRam 거부', () {
      expect(() => SgpSecureCrypto.loadPackFromRam(), throwsA(isA<StateError>()));
    });

    test('unlockAndParse 800 corpus', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      final pack = await SgpSecureCrypto.unlockAndParse(
        plainJson: corpusJson,
        key: key,
        biometric: bio,
      );
      expect(pack.targetCorpusSize, 800);
    });

    test('wipeRamCorpus 소거', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      await SgpSecureCrypto.unlockAndParse(
        plainJson: corpusJson,
        key: key,
        biometric: bio,
      );
      SgpSecureCrypto.wipeRamCorpus();
      expect(SgpSecureCrypto.isCorpusUnlockedInRam, isFalse);
    });

    test('envelope encode/decode 왕복', () {
      final env = SgpSecureCrypto.sealCorpus(plainJson: 'test', key: key);
      final restored = SgpSecureCrypto.decodeEnvelope(
        SgpSecureCrypto.encodeEnvelope(env),
      );
      expect(restored.nonce, env.nonce);
      expect(restored.cipherText, env.cipherText);
    });

    test('잘못된 키 복호화 거부', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      final env = SgpSecureCrypto.sealCorpus(plainJson: corpusJson, key: key);
      final wrong = Uint8List.fromList(List<int>.filled(32, 0xFF));
      await expectLater(
        () => SgpSecureCrypto.unlockCorpusToRam(
          envelope: env,
          key: wrong,
          biometric: bio,
        ),
        throwsA(anything),
      );
    });

    test('corpusFingerprint 결정적', () {
      expect(
        SgpSecureCrypto.corpusFingerprint(corpusJson),
        SgpSecureCrypto.corpusFingerprint(corpusJson),
      );
    });

    test('corpusFingerprint 변경 감지', () {
      final a = SgpSecureCrypto.corpusFingerprint(corpusJson);
      final b = SgpSecureCrypto.corpusFingerprint('{"mutated":true}');
      expect(a, isNot(equals(b)));
    });

    test('loadPackFromRam precedents 비어있지 않음', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      await SgpSecureCrypto.unlockAndParse(
        plainJson: corpusJson,
        key: key,
        biometric: bio,
      );
      final pack = SgpSecureCrypto.loadPackFromRam();
      expect(pack.precedents, isNotEmpty);
    });

    test('biometric revoke 후 unlock 실패', () async {
      final bio = SgpSimulatedBiometricAuth()
        ..grantForTest()
        ..revoke();
      final env = SgpSecureCrypto.sealCorpus(plainJson: corpusJson, key: key);
      await expectLater(
        () => SgpSecureCrypto.unlockCorpusToRam(
          envelope: env,
          key: key,
          biometric: bio,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('unlock reason 문자열 전달', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      final env = SgpSecureCrypto.sealCorpus(plainJson: corpusJson, key: key);
      await SgpSecureCrypto.unlockCorpusToRam(
        envelope: env,
        key: key,
        biometric: bio,
        reason: 'KG-RAG 800종 판례 DB 접근',
      );
      expect(SgpSecureCrypto.isCorpusUnlockedInRam, isTrue);
    });

    test('corpusKeyAlias 상수', () {
      expect(SgpSecureCrypto.corpusKeyAlias, 'sgp_kgrag_corpus_v1');
    });

    test('작은 JSON seal/unlock', () async {
      const mini = '{"target_corpus_size":800,"precedents":[]}';
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      final pack = await SgpSecureCrypto.unlockAndParse(
        plainJson: mini,
        key: key,
        biometric: bio,
      );
      expect(pack.targetCorpusSize, 800);
    });

    test('잘못된 corpus size 예외', () async {
      const bad = '{"target_corpus_size":799,"precedents":[]}';
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      await expectLater(
        () => SgpSecureCrypto.unlockAndParse(
          plainJson: bad,
          key: key,
          biometric: bio,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('RAM JSON 파싱 후 wipe 재잠금', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      await SgpSecureCrypto.unlockAndParse(
        plainJson: corpusJson,
        key: key,
        biometric: bio,
      );
      SgpSecureCrypto.wipeRamCorpus();
      expect(() => SgpSecureCrypto.loadPackFromRam(), throwsA(isA<StateError>()));
    });

    test('800 실제 asset 무결성', () async {
      final bio = SgpSimulatedBiometricAuth()..grantForTest();
      final pack = await SgpSecureCrypto.unlockAndParse(
        plainJson: corpusJson,
        key: key,
        biometric: bio,
      );
      expect(pack.targetCorpusSize, 800);
      expect(pack.precedents, isNotEmpty);
    });
  });
}
