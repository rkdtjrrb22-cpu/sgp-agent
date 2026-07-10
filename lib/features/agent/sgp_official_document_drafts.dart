/// 범죄 발생보고서·현행범/긴급체포서 — 판례·현장 근거 간략 초안.
library;

import 'sgp_physical_force_guide.dart';
import 'sgp_precedent_dictionary.dart';
import 'sgp_procedure_timeline.dart';
import 'sgp_report_generator.dart';

/// 공식 서류 초안 묶음.
class SgpOfficialDocuments {
  const SgpOfficialDocuments({
    required this.crimeIncidentReport,
    required this.arrestWarrantDraft,
  });

  final String crimeIncidentReport;
  final String arrestWarrantDraft;

  String get combinedPlainText =>
      '$crimeIncidentReport\n\n${'=' * 40}\n\n$arrestWarrantDraft';
}

/// 범죄 발생보고서·체포서 예시 합성기.
class SgpOfficialDocumentDrafts {
  const SgpOfficialDocumentDrafts._();

  static SgpOfficialDocuments generate(SgpReportInput input) {
    final precedents = _matchedPrecedents(input);
    return SgpOfficialDocuments(
      crimeIncidentReport: _buildCrimeIncidentReport(input, precedents),
      arrestWarrantDraft: _buildArrestWarrantDraft(input, precedents),
    );
  }

  static List<PrecedentRef> _matchedPrecedents(SgpReportInput input) {
    final dict = getPrecedentDictionary();
    final ids = <String>{};
    final result = <PrecedentRef>[];

    void addById(String id) {
      if (ids.add(id)) {
        final p = dict.where((e) => e.id == id).firstOrNull;
        if (p != null) result.add(p);
      }
    }

    final adv = input.advancedAnalysis;
    if (adv != null) {
      for (final id in adv.appliedPrecedentIds) {
        addById(id);
      }
    }

    for (final p in matchPrecedents(
      text: input.rawText,
      isDomesticViolence: input.checklist.isDomesticViolence,
      isIntoxicated: input.checklist.isIntoxicated,
      isWeaponUsed: input.checklist.isWeaponUsed,
    )) {
      if (ids.add(p.id)) result.add(p);
    }
    return result.take(4).toList();
  }

  static String _buildCrimeIncidentReport(
    SgpReportInput input,
    List<PrecedentRef> precedents,
  ) {
    final adv = input.advancedAnalysis;
    final q = input.quantumComparison;
    final t = input.timeline;
    final excerpt = _excerpt(input.rawText, 200);
    final dt = _fmt(input.generatedAt);

    final crimeFact = adv != null && adv.suspectVictimStatus.isNotEmpty
        ? adv.suspectVictimStatus
        : excerpt;

    final appliedLaw = q?.recommendedPath?.law ??
        (input.checklist.isWeaponUsed
            ? '형법 특수폭행·상해 / 폭력행위등처벌에관한법률'
            : '형법 폭행·상해');

    final actions = <String>[
      if (t != null) '${t.arrestType.displayName} 실시 (${_fmt(t.t0)})',
      '피해자·피의자 분리 및 현장 채증',
      if (input.checklist.isDomesticViolence) '가정폭력 임시조치·긴급응급조치 검토',
      if (q != null) q.actionGuidance,
    ];

    final precedentNotes = precedents.isEmpty
        ? '- (판례 자동 매칭 없음 — 수사관 보완)'
        : precedents.map((p) => '- ${p.holding}').join('\n');

    return '''
# 범죄 발생 보고서 (SGP-Agent 초안)

**작성 시각**: $dt

## 1. 신고·인지
- 접수 경로: 112 신고 / 현장 인지 (무전·STT 원문 근거)
- 현장 요약: $excerpt

## 2. 범죄 사실 요지
$crimeFact

## 3. 인적·대상 구분
- 실질 공격 유발자 추정: ${adv?.primaryAggressor ?? '[담당 수사관 확인]'}
- 피해·방어 당사자 추정: ${adv?.primaryVictim ?? '[담당 수사관 확인]'}
- 적용 죄명·법조: $appliedLaw

## 4. 현장 신고·조치 내용
${actions.map((a) => '- $a').join('\n')}

## 5. 판례 참고 (조치 근거)
$precedentNotes

## 6. 비고
- 본 초안은 SGP-Agent가 현장 입력·판례 딕셔너리를 근거로 생성한 예시이며, 최종 보고서는 담당 수사관이 확인·보완한다.
'''.trim();
  }

  static String _buildArrestWarrantDraft(
    SgpReportInput input,
    List<PrecedentRef> precedents,
  ) {
    final t = input.timeline;
    final adv = input.advancedAnalysis;
    final arrestType = t?.arrestType ?? _inferArrestType(input);
    final t0 = t?.t0 ?? input.generatedAt;
    final excerpt = _excerpt(input.rawText, 160);

    final isEmergency = arrestType == ArrestType.emergency;
    final title = isEmergency ? '긴급체포 보고서' : '현행범 체포서';
    final legalBasis = arrestType.legalBasis;

    final necessity = <String>[
      if (input.checklist.isFleeing) '도주 염려 (현장 도주·신분 확인 거부 정황)',
      '증거인멸·현장 훼손 염려 (채증 전 보전 필요)',
      if (adv?.preemptiveAttackDetected == true) '선제 공격 정황 — 대법원 판례상 실질 가해자 구분 필요',
    ];
    if (necessity.isEmpty) {
      necessity.add('범죄사실 명백·체포 후 조사 필요성');
    }

    final precedentLine = precedents.isEmpty
        ? '적법 절차·위수증 방지 채증 준수 (형소법 제308조의2)'
        : precedents.map((p) => p.holding).join(' / ');

    final miranda = t != null
        ? '미란다 원칙 고지 ${_checkDone(t, 't0', 'miranda') ? '완료' : '필요'}'
        : '미란다 원칙 고지 [체포 직후 이행]';

    final forceLevel = t?.physicalThreatLevel?.displayName ?? '현장 평가 [기재]';

    return '''
# $title (SGP-Agent 예시 초안)

**체포 시각**: ${_fmt(t0)}
**법적 근거**: $legalBasis

## 1. 체포 대상·범죄사실
- 피의자: ${adv?.primaryAggressor != null && adv!.primaryAggressor.length < 40 ? adv.primaryAggressor : '[성명·주소 수사관 기재]'}
- 범죄사실 요약: $excerpt
${adv != null ? '- 가·피해자 판단: ${adv.suspectVictimStatus}' : ''}

## 2. 체포·구속 필요성
${necessity.map((n) => '- $n').join('\n')}

## 3. 체포 경위·물리력
- 체포 방식: ${arrestType.displayName}
- 위해 수준·대응: $forceLevel
- $miranda

## 4. 판례·법리 참고
- $precedentLine
${input.checklist.isIntoxicated ? '- 형법 제10조 3항: 자의적 음주 시 심신미약 감경 주장 제한 검토' : ''}
${adv != null && adv.defenseActDetected ? '- 정당방위 요건(침해 현재성·상당성) 대법원 기준 대조' : ''}

## 5. 후속 조치
- 채증 법적 고지 및 바디캠·녹화 개시
- 피의자 체포 통지서 24시간 이내 발송 (형소법 제212조)
${isEmergency || arrestType == ArrestType.currentOffender ? '- 구속영장 신청 45시간 이내 (형소법 제200조의2·제213조의2)' : ''}

※ 본 서면은 판례·현장 조치 내역을 근거로 한 핵심 예시 초안입니다.
'''.trim();
  }

  static ArrestType _inferArrestType(SgpReportInput input) {
    if (input.checklist.isFleeing) return ArrestType.currentOffender;
    if (RegExp(r'(긴급체포|제200조)').hasMatch(input.rawText)) {
      return ArrestType.emergency;
    }
    return ArrestType.currentOffender;
  }

  static bool _checkDone(SgpProcedureTimeline t, String nodeId, String checkId) {
    for (final n in t.nodes) {
      if (n.id != nodeId) continue;
      return n.checkItems.any((c) => c.id == checkId && c.checked);
    }
    return false;
  }

  static String _excerpt(String text, int max) {
    final s = text.trim();
    if (s.isEmpty) return '[현장 무전·진술 원문 미입력 — 수사관 기재]';
    return s.length > max ? '${s.substring(0, max)}…' : s;
  }

  static String _fmt(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$m';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
